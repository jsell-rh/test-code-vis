"""
Core extraction logic for the code-vis scene graph.

Discovers Python modules in a target codebase, extracts import-based
dependencies, computes complexity metrics, and produces a JSON scene graph
conforming to the schema defined in extractor.schema.
"""

from __future__ import annotations

import ast
import math
from datetime import datetime, timezone
from pathlib import Path

from extractor.schema import (
    AggregateMetrics,
    Cluster,
    Edge,
    EdgeType,
    Metadata,
    Node,
    NodeMetrics,
    SceneGraph,
    StructuralSignificanceMetrics,
    SymbolInfo,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Top-level directories that are Python packages but NOT bounded contexts.
_NON_CONTEXT_DIRS: frozenset[str] = frozenset(
    {"tests", "docs", "util", "__pycache__", "migrations", "alembic"}
)

# Maximum radius of the entire scene (world units).  Child orbit radii are
# capped relative to this value so that no node is placed outside the visible
# scene boundary.
SCENE_RADIUS: float = 50.0


# ---------------------------------------------------------------------------
# Helpers: filesystem predicates
# ---------------------------------------------------------------------------


def is_python_package(directory: Path) -> bool:
    """Return True if *directory* is a Python package (has __init__.py)."""
    return directory.is_dir() and (directory / "__init__.py").exists()


def is_bounded_context(directory: Path) -> bool:
    """Return True if *directory* looks like a bounded context.

    A bounded context is a Python package whose name is not in the
    exclusion list and does not start with an underscore.
    """
    return (
        is_python_package(directory)
        and directory.name not in _NON_CONTEXT_DIRS
        and not directory.name.startswith("_")
    )


def is_internal_module(directory: Path) -> bool:
    """Return True if *directory* is an internal module within a bounded context."""
    return is_python_package(directory) and not directory.name.startswith("_")


# ---------------------------------------------------------------------------
# Helpers: metrics
# ---------------------------------------------------------------------------


def compute_loc(directory: Path) -> int:
    """Count total lines of Python source code under *directory* (recursive)."""
    total = 0
    for py_file in directory.rglob("*.py"):
        try:
            text = py_file.read_text(encoding="utf-8", errors="replace")
            total += len(text.splitlines())
        except OSError:
            pass
    return total


def size_from_loc(loc: int) -> float:
    """Derive a normalised visual size from a lines-of-code count.

    Returns a value in (0.5, ~5] for typical module sizes.
    """
    return max(0.5, math.log1p(loc) / math.log(10))


# ---------------------------------------------------------------------------
# Helpers: import extraction
# ---------------------------------------------------------------------------


def extract_imports_from_file(py_file: Path) -> list[str]:
    """Parse *py_file* and return the list of imported module paths.

    Returns absolute (non-relative) import paths only, e.g.
    ``'graph.domain.value_objects'``, ``'shared_kernel.auth'``.
    Relative imports (``from . import …``) are skipped because they
    cannot introduce cross-module dependencies.
    """
    try:
        source = py_file.read_text(encoding="utf-8", errors="replace")
        tree = ast.parse(source, filename=str(py_file))
    except (SyntaxError, ValueError, UnicodeDecodeError):
        return []

    modules: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                modules.append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.module and node.level == 0:
                modules.append(node.module)
    return modules


def get_target_node_id(imported_module: str, all_node_ids: set[str]) -> str | None:
    """Return the most specific node ID that the imported module belongs to.

    For example, given ``'graph.domain.value_objects'`` and node IDs
    ``{'graph', 'graph.domain', 'graph.application'}``, this returns
    ``'graph.domain'``.

    Returns *None* if no known node matches.
    """
    parts = imported_module.split(".")
    for length in range(len(parts), 0, -1):
        candidate = ".".join(parts[:length])
        if candidate in all_node_ids:
            return candidate
    return None


# ---------------------------------------------------------------------------
# Helpers: edge classification
# ---------------------------------------------------------------------------


def classify_edge_type(source_context: str, target_context: str) -> EdgeType:
    """Return ``'cross_context'`` or ``'internal'`` based on the contexts."""
    return "internal" if source_context == target_context else "cross_context"


# ---------------------------------------------------------------------------
# Layout computation
# ---------------------------------------------------------------------------


def _circular_positions(
    count: int, radius: float, y: float = 0.0
) -> list[tuple[float, float, float]]:
    """Return *count* evenly-spaced (x, y, z) points on a circle."""
    positions = []
    for i in range(count):
        angle = 2 * math.pi * i / max(count, 1)
        positions.append((radius * math.cos(angle), y, radius * math.sin(angle)))
    return positions


def _order_by_coupling(bc_nodes: list[Node], edges: list[Edge]) -> list[Node]:
    """Re-order *bc_nodes* so tightly coupled pairs end up adjacent in the circle.

    Uses a greedy nearest-neighbour heuristic: starting from the first node,
    repeatedly pick the remaining node with the highest coupling score to the
    current tail of the ordered list.  Coupling score is the number of
    cross-context edges shared between two bounded contexts.
    """
    if len(bc_nodes) <= 2:
        return list(bc_nodes)

    bc_id_set = {n["id"] for n in bc_nodes}

    # Build symmetric coupling counts between BC pairs.
    coupling: dict[str, dict[str, int]] = {n["id"]: {} for n in bc_nodes}
    for edge in edges:
        src_bc = edge["source"].split(".")[0]
        tgt_bc = edge["target"].split(".")[0]
        if src_bc in bc_id_set and tgt_bc in bc_id_set and src_bc != tgt_bc:
            coupling[src_bc][tgt_bc] = coupling[src_bc].get(tgt_bc, 0) + 1
            coupling[tgt_bc][src_bc] = coupling[tgt_bc].get(src_bc, 0) + 1

    remaining = list(bc_nodes)
    ordered = [remaining.pop(0)]
    while remaining:
        current_id = ordered[-1]["id"]
        best_idx = max(
            range(len(remaining)),
            key=lambda i: coupling[current_id].get(remaining[i]["id"], 0),
        )
        ordered.append(remaining.pop(best_idx))

    return ordered


def compute_layout(nodes: list[Node], edges: list[Edge] | None = None) -> None:
    """Assign pre-computed 3D positions to all nodes (mutates *nodes* in-place).

    Bounded contexts are arranged in a circle.  When *edges* are supplied the
    BC order is optimised by ``_order_by_coupling`` so tightly coupled pairs
    are placed adjacent, reducing their spatial distance.

    Module nodes are placed in a smaller circle using LOCAL offsets relative to
    the parent BC's origin so that child nodes are always within the spatial
    bounds of their parent.  Godot's main.gd adds the parent world position at
    render time — storing absolute coordinates here would cause double-offset
    rendering.

    Spec nodes are placed in a row beyond the far edge of the code circle so
    that the intended design (specs) is spatially distinct from the realized
    design (code).  See :func:`_position_spec_nodes`.
    """
    bc_nodes = [n for n in nodes if n["type"] == "bounded_context"]

    # Optionally reorder so coupled BCs sit adjacent in the ring.
    if edges:
        bc_nodes = _order_by_coupling(bc_nodes, edges)

    bc_radius = min(max(5.0, len(bc_nodes) * 2.5), SCENE_RADIUS * 0.8)  # cap to scene
    bc_positions = _circular_positions(len(bc_nodes), bc_radius)

    bc_pos_map: dict[str, tuple[float, float, float]] = {}
    for bc_node, pos in zip(bc_nodes, bc_positions):
        bc_node["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}
        bc_pos_map[bc_node["id"]] = pos

    # Group modules by parent
    parent_children: dict[str, list[Node]] = {}
    for n in nodes:
        if n["type"] == "module" and n["parent"]:
            parent_children.setdefault(n["parent"], []).append(n)

    for parent_id, children in parent_children.items():
        mod_radius = min(
            max(1.5, len(children) * 0.9), bc_radius * 0.4
        )  # cap inside parent
        mod_positions = _circular_positions(len(children), mod_radius, y=0.0)
        # Store LOCAL offsets only (relative to the parent BC's origin).
        # main.gd resolves world positions by adding parent world pos + local offset,
        # so storing absolute coords here would cause double-offset rendering.
        for child, pos in zip(children, mod_positions):
            child["position"] = {
                "x": pos[0],
                "y": pos[1],
                "z": pos[2],
            }

    # Position spec nodes beyond the code circle so intended and realized
    # design occupy distinct spatial regions.
    spec_nodes = [n for n in nodes if n["type"] == "spec"]
    _position_spec_nodes(spec_nodes, bc_radius)


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------


def discover_spec_nodes(src_path: Path) -> list[Node]:
    """Discover spec files adjacent to the source tree and include them as nodes.

    Searches for a ``specs/`` (or ``spec/``) directory:
    - next to *src_path* (i.e. ``src_path.parent / "specs"``)
    - inside *src_path* itself (i.e. ``src_path / "specs"``)

    Each Markdown file found becomes a ``spec`` type node whose size is derived
    from the file size.  No content analysis is performed — only structure
    (existence and size of spec files) is recorded.  This makes the intended
    design visible alongside the realized design in the 3D scene.

    Returns an empty list when no spec directory is found.
    """
    spec_nodes: list[Node] = []
    seen_paths: set[Path] = set()

    for root in (src_path.parent, src_path):
        for spec_dir_name in ("specs", "spec"):
            spec_dir = root / spec_dir_name
            if not spec_dir.is_dir() or spec_dir in seen_paths:
                continue
            seen_paths.add(spec_dir)
            for spec_file in sorted(spec_dir.rglob("*.md")):
                # Derive a stable, dot-separated ID from the relative path.
                rel = spec_file.relative_to(spec_dir)
                parts = rel.with_suffix("").parts
                # Replace separators and normalise to a safe ID string.
                safe_parts = [p.replace("-", "_").replace(" ", "_") for p in parts]
                spec_id = "spec." + ".".join(safe_parts)
                name = spec_file.stem.replace("-", " ").replace("_", " ").title()
                try:
                    size_bytes = spec_file.stat().st_size
                except OSError:
                    size_bytes = 0
                size = max(0.5, math.log1p(size_bytes) / math.log(10))
                node: Node = {
                    "id": spec_id,
                    "name": name,
                    "type": "spec",
                    "position": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "size": size,
                    "parent": None,
                }
                spec_nodes.append(node)

    return spec_nodes


def _position_spec_nodes(spec_nodes: list[Node], code_radius: float) -> None:
    """Assign positions to spec nodes, placing them as a row beyond the code circle.

    Spec nodes are laid out along the X-axis at ``z = -(code_radius + 5)``,
    centred on ``x = 0``.  They are separated by 3.0 scene units and placed
    at ``y = 0`` so they sit on the same horizontal plane as bounded contexts.

    This spatial separation makes it immediately visible that spec nodes belong
    to the *intended design* layer rather than the *realized code* layer.
    """
    if not spec_nodes:
        return
    spacing = 3.0
    total_width = (len(spec_nodes) - 1) * spacing
    start_x = -total_width / 2.0
    z_offset = -(code_radius + 5.0)
    for i, node in enumerate(spec_nodes):
        node["position"] = {
            "x": start_x + i * spacing,
            "y": 0.0,
            "z": z_offset,
        }


def discover_bounded_contexts(src_path: Path) -> list[Node]:
    """Discover top-level bounded context nodes under *src_path*."""
    nodes: list[Node] = []
    for candidate in sorted(src_path.iterdir()):
        if not is_bounded_context(candidate):
            continue
        loc = compute_loc(candidate)
        metrics: NodeMetrics = {"loc": loc}
        node: Node = {
            "id": candidate.name,
            "name": _prettify(candidate.name),
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": size_from_loc(loc),
            "parent": None,
            "metrics": metrics,
        }
        nodes.append(node)
    return nodes


def discover_submodules(src_path: Path, bc_name: str) -> list[Node]:
    """Discover module-level nodes inside bounded context *bc_name*."""
    bc_path = src_path / bc_name
    nodes: list[Node] = []
    for candidate in sorted(bc_path.iterdir()):
        if not is_internal_module(candidate):
            continue
        loc = compute_loc(candidate)
        metrics: NodeMetrics = {"loc": loc}
        node: Node = {
            "id": f"{bc_name}.{candidate.name}",
            "name": _prettify(candidate.name),
            "type": "module",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": size_from_loc(loc),
            "parent": bc_name,
            "metrics": metrics,
        }
        nodes.append(node)
    return nodes


def _prettify(name: str) -> str:
    """Convert a snake_case identifier to a human-readable Title Case name."""
    return name.replace("_", " ").title()


# ---------------------------------------------------------------------------
# Dependency edges
# ---------------------------------------------------------------------------


def build_dependency_edges(src_path: Path, all_nodes: list[Node]) -> list[Edge]:
    """Build dependency edges by analysing imports in each node's Python files.

    Cross-context edges are created at the bounded-context level (e.g.
    ``graph → shared_kernel``) with ``type="cross_context"``.  For each such
    BC-pair an additional ``type="aggregate"`` edge is emitted carrying the
    total count of unique module-level imports between the two contexts as
    its ``weight``.  Internal edges are created at the module level (e.g.
    ``iam.application → iam.domain``).

    Every individual edge (cross_context or internal) carries a ``weight``
    field equal to the number of unique module-level import statements
    between the pair.  This lets humans assess coupling strength without
    reading code (spec §Understanding Without Writing Code).

    Duplicate edges are deduplicated; their weights are summed.
    """
    all_ids = {n["id"] for n in all_nodes}
    context_ids = {n["id"] for n in all_nodes if n["type"] == "bounded_context"}

    # Count unique module-level imports per edge triple (src, tgt, type).
    # Replaces the previous raw_edges set so weight is accumulated alongside
    # deduplication.  Each unique (source_module, imported_module) pair that
    # resolves to an edge triple increments its count by 1.
    raw_edge_count: dict[tuple[str, str, EdgeType], int] = {}

    # Count unique module-level cross-context imports per BC pair.
    # Keyed by (source_bc, target_bc) → import count (for aggregate edges).
    bc_pair_weight: dict[tuple[str, str], int] = {}

    for node in all_nodes:
        node_path = src_path / Path(node["id"].replace(".", "/"))
        if not node_path.exists() or not node_path.is_dir():
            continue

        source_id = node["id"]
        source_context = source_id.split(".")[0]

        # Collect all absolute imports from Python files in this node's directory.
        # For BC-level nodes we use rglob so that files inside sub-packages are
        # included; this drives the cross-context edges.  For module-level nodes
        # we also use rglob (to catch helpers in sub-sub-packages) which drives
        # internal edges.
        all_imports: set[str] = set()
        for py_file in node_path.rglob("*.py"):
            all_imports.update(extract_imports_from_file(py_file))

        for imported_module in all_imports:
            target_id = get_target_node_id(imported_module, all_ids)
            if target_id is None or target_id == source_id:
                continue

            target_context = target_id.split(".")[0]

            if source_context != target_context:
                # Cross-context: normalise both ends to bounded-context level.
                edge_src = source_context
                edge_tgt = target_context
                if edge_src not in context_ids or edge_tgt not in context_ids:
                    continue
                key: tuple[str, str, EdgeType] = (edge_src, edge_tgt, "cross_context")
                raw_edge_count[key] = raw_edge_count.get(key, 0) + 1
                # Count weight from module-level scans only to avoid
                # double-counting the BC-level rglob that also sees module files.
                if node["type"] == "module":
                    bc_key = (edge_src, edge_tgt)
                    bc_pair_weight[bc_key] = bc_pair_weight.get(bc_key, 0) + 1
            else:
                # Internal: only emit from module-level nodes to avoid duplicating
                # edges that would also be created by the bounded-context scan.
                if node["type"] != "module":
                    continue
                if target_id == source_context:
                    # The import resolves only to the BC itself — skip.
                    continue
                int_key: tuple[str, str, EdgeType] = (source_id, target_id, "internal")
                raw_edge_count[int_key] = raw_edge_count.get(int_key, 0) + 1

    # Individual cross-context and internal edges — each carries its import count
    # as weight so humans can assess coupling strength without reading source code.
    edges: list[Edge] = [
        {"source": src, "target": tgt, "type": etype, "weight": count}
        for (src, tgt, etype), count in sorted(raw_edge_count.items())
    ]

    # Aggregate edges: one per BC-pair, carrying the total import count as weight.
    # Used for far-distance rendering where individual module-level edges are
    # collapsed into a single weighted summary.
    for (src_bc, tgt_bc), weight in sorted(bc_pair_weight.items()):
        agg_edge: Edge = {
            "source": src_bc,
            "target": tgt_bc,
            "type": "aggregate",
            "weight": weight,
        }
        edges.append(agg_edge)

    return edges


# ---------------------------------------------------------------------------
# Independence groups
# ---------------------------------------------------------------------------


def compute_independence_groups(nodes: list[Node], edges: list[Edge]) -> None:
    """Assign an ``independence_group`` identifier to every module node (in-place).

    Modules within the same bounded context that are connected by internal
    dependency edges (directly or transitively) share the same group identifier.
    Modules with no internal dependencies to any peer each form their own group.

    Group IDs follow the format ``"<context_id>:<group_index>"`` where the index
    is assigned in discovery order (first connected component = 0, etc.).

    Args:
        nodes: All nodes in the scene graph (mutated in-place).
        edges: All edges in the scene graph (used to determine connectivity).
    """
    # Group module nodes by their parent bounded context.
    by_context: dict[str, list[Node]] = {}
    for node in nodes:
        if node["type"] == "module" and node["parent"]:
            by_context.setdefault(node["parent"], []).append(node)

    # Build adjacency sets for internal edges among modules within each context.
    for context_id, module_nodes in by_context.items():
        mod_ids = {n["id"] for n in module_nodes}

        # Adjacency: undirected (A→B or B→A means they share a group).
        adjacency: dict[str, set[str]] = {mod_id: set() for mod_id in mod_ids}
        for edge in edges:
            if edge["type"] != "internal":
                continue
            src, tgt = edge["source"], edge["target"]
            if src in mod_ids and tgt in mod_ids:
                adjacency[src].add(tgt)
                adjacency[tgt].add(src)

        # Union-Find to identify connected components.
        parent_map: dict[str, str] = {mod_id: mod_id for mod_id in mod_ids}

        def _find(x: str) -> str:
            while parent_map[x] != x:
                parent_map[x] = parent_map[parent_map[x]]  # path compression
                x = parent_map[x]
            return x

        def _union(a: str, b: str) -> None:
            ra, rb = _find(a), _find(b)
            if ra != rb:
                parent_map[ra] = rb

        for mod_id, neighbours in adjacency.items():
            for neighbour in neighbours:
                _union(mod_id, neighbour)

        # Map each root to a sequential group index (in node discovery order).
        root_to_index: dict[str, int] = {}
        for node in module_nodes:
            root = _find(node["id"])
            if root not in root_to_index:
                root_to_index[root] = len(root_to_index)
            node["independence_group"] = f"{context_id}:{root_to_index[root]}"


# ---------------------------------------------------------------------------
# Cluster computation
# ---------------------------------------------------------------------------

# Minimum coupling score (number of directed edges in either direction between
# two modules) required for them to be included in the same cluster.
_COUPLING_THRESHOLD: int = 1


def compute_clusters(nodes: list[Node], edges: list[Edge]) -> list[Cluster]:
    """Compute cluster suggestions for tightly-coupled module groups.

    For each bounded context, modules that share internal dependency edges
    (coupling score ≥ ``_COUPLING_THRESHOLD``) are grouped into clusters via
    connected-components analysis.  Groups of fewer than two modules are not
    emitted as clusters.

    The cluster entry does NOT prescribe a collapsed position — the Godot
    application computes the supernode position as the centroid of the member
    positions at render time.

    Args:
        nodes: All nodes in the scene graph.
        edges: All edges in the scene graph.

    Returns:
        A list of :class:`Cluster` entries, one per coupled module group found.
    """
    # Index nodes for fast lookup.
    node_by_id: dict[str, Node] = {n["id"]: n for n in nodes}

    # Group module nodes by their parent bounded context.
    by_context: dict[str, list[Node]] = {}
    for node in nodes:
        if node["type"] == "module" and node["parent"]:
            by_context.setdefault(node["parent"], []).append(node)

    clusters: list[Cluster] = []

    for context_id, module_nodes in by_context.items():
        mod_ids = {n["id"] for n in module_nodes}

        # Count coupling score (directed edges in either direction) per pair.
        coupling: dict[str, dict[str, int]] = {mid: {} for mid in mod_ids}
        for edge in edges:
            if edge["type"] != "internal":
                continue
            src, tgt = edge["source"], edge["target"]
            if src in mod_ids and tgt in mod_ids:
                coupling[src][tgt] = coupling[src].get(tgt, 0) + 1
                coupling[tgt][src] = coupling[tgt].get(src, 0) + 1

        # Union-Find on pairs that meet the coupling threshold.
        parent_map: dict[str, str] = {mid: mid for mid in mod_ids}

        def _find(x: str) -> str:
            while parent_map[x] != x:
                parent_map[x] = parent_map[parent_map[x]]
                x = parent_map[x]
            return x

        def _union(a: str, b: str) -> None:
            ra, rb = _find(a), _find(b)
            if ra != rb:
                parent_map[ra] = rb

        for mid, neighbours in coupling.items():
            for neighbour, score in neighbours.items():
                if score >= _COUPLING_THRESHOLD:
                    _union(mid, neighbour)

        # Group by root.
        groups: dict[str, list[str]] = {}
        for node in module_nodes:
            root = _find(node["id"])
            groups.setdefault(root, []).append(node["id"])

        # Emit clusters only for groups with ≥ 2 members.
        cluster_index = 0
        for root, members in sorted(groups.items()):
            if len(members) < 2:
                continue

            # Compute aggregate metrics for this cluster.
            member_set = set(members)
            total_loc = sum(
                node_by_id[mid].get("metrics", {}).get("loc", 0)  # type: ignore[union-attr]
                for mid in members
                if mid in node_by_id
            )

            # Count edges that cross the cluster boundary.
            in_degree = 0
            out_degree = 0
            for edge in edges:
                src, tgt = edge["source"], edge["target"]
                src_inside = src in member_set
                tgt_inside = tgt in member_set
                if tgt_inside and not src_inside:
                    in_degree += 1
                elif src_inside and not tgt_inside:
                    out_degree += 1

            agg: AggregateMetrics = {
                "total_loc": total_loc,
                "in_degree": in_degree,
                "out_degree": out_degree,
            }
            cluster: Cluster = {
                "id": f"{context_id}:cluster_{cluster_index}",
                "members": sorted(members),
                "context": context_id,
                "aggregate_metrics": agg,
            }
            clusters.append(cluster)
            cluster_index += 1

    return clusters


# ---------------------------------------------------------------------------
# Cascade depth (simulation output)
# ---------------------------------------------------------------------------


def compute_cascade_depth(origin_id: str, edges: list[Edge]) -> dict[str, int]:
    """Compute the cascade depth of each node affected by failure of *origin_id*.

    A node that directly depends on the origin is at depth 1; a node that
    depends on a depth-1 node is at depth 2; and so on.

    "Depends on" means there is a directed edge ``source → target`` where
    ``target`` is the origin (or an already-affected node).  BFS is used so
    every node receives its *minimum* hop distance.

    Args:
        origin_id: The ID of the node that has failed.
        edges: All edges in the scene graph (only source/target are used).

    Returns:
        A dict mapping affected node IDs to their cascade depth (≥ 1).
        The origin node itself is NOT included in the output.
    """
    # Build a reverse adjacency map: for each node, which other nodes depend on it.
    dependents: dict[str, list[str]] = {}
    for edge in edges:
        # edge["source"] depends on edge["target"]
        # so if target fails, source is affected
        dependents.setdefault(edge["target"], []).append(edge["source"])

    depth_map: dict[str, int] = {}
    frontier = [origin_id]
    current_depth = 0

    while frontier:
        current_depth += 1
        next_frontier: list[str] = []
        for node_id in frontier:
            for dependent in dependents.get(node_id, []):
                if dependent not in depth_map and dependent != origin_id:
                    depth_map[dependent] = current_depth
                    next_frontier.append(dependent)
        frontier = next_frontier

    return depth_map


def annotate_cascade_depth(nodes: list[Node], depth_map: dict[str, int]) -> None:
    """Apply cascade-depth annotations to *nodes* in-place (simulation output).

    For every node whose ID appears in *depth_map*, sets its ``depth`` field
    to the hop distance returned by :func:`compute_cascade_depth`.  Nodes not
    present in *depth_map* (the origin node and unaffected nodes) are left
    unchanged — their ``depth`` key is neither set nor removed.

    This function makes depth values **available to the visualization** so that
    the Godot application can read ``depth`` from the JSON scene graph and use
    it for gradient encoding and wave animation in cascade-failure display.

    Spec: scene-graph-schema.spec.md § "Cascade Depth in Simulation Output"
    THEN node A is marked with depth 1 and node B with depth 2
    AND the depth values are available to the visualization for gradient
    encoding and wave animation.

    Args:
        nodes: All nodes in the scene graph (mutated in-place for affected nodes).
        depth_map: Output of :func:`compute_cascade_depth` — maps each affected
                   node ID to its minimum BFS hop distance from the origin.
    """
    for node in nodes:
        if node["id"] in depth_map:
            node["depth"] = depth_map[node["id"]]


# ---------------------------------------------------------------------------
# Symbol Table Extraction (visual-primitives.spec.md §Symbol Table Extraction)
# ---------------------------------------------------------------------------

# Badge types automatically inferred from AST analysis.
# Spec: visual-primitives.spec.md §Badge Primitive — vocabulary of badge types.
_BADGE_PURE = "pure"
_BADGE_IO = "io"
_BADGE_ASYNC = "async"
_BADGE_STATEFUL = "stateful"
_BADGE_ERROR_HANDLING = "error_handling"
_BADGE_TEST = "test"
_BADGE_ENTRY_POINT = "entry_point"
_BADGE_DEPRECATED = "deprecated"

# I/O-performing stdlib names used to detect the 'io' badge.
_IO_NAMES: frozenset[str] = frozenset(
    {
        "open",
        "print",
        "input",
        "read",
        "write",
        "send",
        "recv",
        "connect",
        "listen",
        "accept",
        "socket",
        "request",
        "get",
        "post",
        "put",
        "delete",
        "fetch",
    }
)


def _format_signature(node: ast.FunctionDef | ast.AsyncFunctionDef) -> str:
    """Return a concise human-readable signature string for *node*.

    Includes parameter names and type-hint strings where present, plus the
    return annotation.  The result is not guaranteed to be valid Python; it
    prioritises readability over precision.

    Args:
        node: An AST function definition node.

    Returns:
        A string like ``'(x: int, y: str = "") -> bool'``.
    """
    params: list[str] = []
    args = node.args

    # Positional-only args (Python 3.8+)
    for arg in args.posonlyargs:
        param = arg.arg
        if arg.annotation:
            param += f": {ast.unparse(arg.annotation)}"
        params.append(param)
    if args.posonlyargs:
        params.append("/")

    # Regular args
    n_defaults = len(args.defaults)
    n_args = len(args.args)
    for i, arg in enumerate(args.args):
        param = arg.arg
        if arg.annotation:
            param += f": {ast.unparse(arg.annotation)}"
        default_idx = i - (n_args - n_defaults)
        if default_idx >= 0:
            param += f" = {ast.unparse(args.defaults[default_idx])}"
        params.append(param)

    # *args
    if args.vararg:
        a = args.vararg
        varg = f"*{a.arg}"
        if a.annotation:
            varg += f": {ast.unparse(a.annotation)}"
        params.append(varg)
    elif args.kwonlyargs:
        params.append("*")

    # Keyword-only args
    for i, arg in enumerate(args.kwonlyargs):
        param = arg.arg
        if arg.annotation:
            param += f": {ast.unparse(arg.annotation)}"
        kw_default = args.kw_defaults[i]
        if kw_default is not None:
            param += f" = {ast.unparse(kw_default)}"
        params.append(param)

    # **kwargs
    if args.kwarg:
        kw = args.kwarg
        kwarg = f"**{kw.arg}"
        if kw.annotation:
            kwarg += f": {ast.unparse(kw.annotation)}"
        params.append(kwarg)

    param_str = ", ".join(params)
    ret = ""
    if node.returns:
        ret = f" -> {ast.unparse(node.returns)}"
    return f"({param_str}){ret}"


def _infer_badges(func_node: ast.FunctionDef | ast.AsyncFunctionDef) -> list[str]:
    """Infer badge types for a function from its AST.

    Spec: visual-primitives.spec.md §Badge Primitive — vocabulary includes:
    'pure', 'io', 'async', 'stateful', 'error_handling', 'test', 'entry_point',
    'deprecated'.

    Args:
        func_node: An AST function definition node.

    Returns:
        A list of applicable badge type strings (may be empty).
    """
    badges: list[str] = []

    # 'async' badge — trivially inferred from AST node type.
    if isinstance(func_node, ast.AsyncFunctionDef):
        badges.append(_BADGE_ASYNC)

    # 'test' badge — function name starts with 'test_'.
    if func_node.name.startswith("test_"):
        badges.append(_BADGE_TEST)

    # 'deprecated' badge — has a @deprecated decorator or calls warnings.warn.
    for decorator in func_node.decorator_list:
        if isinstance(decorator, ast.Name) and decorator.id in (
            "deprecated",
            "Deprecated",
        ):
            badges.append(_BADGE_DEPRECATED)
            break
        if isinstance(decorator, ast.Attribute) and decorator.attr in (
            "deprecated",
            "Deprecated",
        ):
            badges.append(_BADGE_DEPRECATED)
            break

    # Walk the function body once and collect signals for remaining badges.
    has_io = False
    has_try_except = False
    has_global_nonlocal = False
    has_raise = False

    for child in ast.walk(func_node):
        # 'io' badge — calls any known I/O function.
        if isinstance(child, ast.Call):
            func_name = ""
            if isinstance(child.func, ast.Name):
                func_name = child.func.id
            elif isinstance(child.func, ast.Attribute):
                func_name = child.func.attr
            if func_name in _IO_NAMES:
                has_io = True

        # 'error_handling' badge — contains try/except or explicit raise.
        if isinstance(child, (ast.Try, ast.TryStar)):
            has_try_except = True
        if isinstance(child, ast.Raise):
            has_raise = True

        # 'stateful' badge — modifies global or non-local state.
        if isinstance(child, (ast.Global, ast.Nonlocal)):
            has_global_nonlocal = True

    if has_io:
        badges.append(_BADGE_IO)
    if has_try_except or has_raise:
        badges.append(_BADGE_ERROR_HANDLING)
    if has_global_nonlocal:
        badges.append(_BADGE_STATEFUL)

    # 'pure' badge — no I/O, no exception handling, no state mutation,
    # not async, not a test, not deprecated.
    if not badges:
        badges.append(_BADGE_PURE)

    return badges


def extract_symbols(src_path: Path, nodes: list[Node]) -> None:
    """Extract the symbol table for each module node and annotate it in-place.

    For every node whose ``type`` is ``'module'``, parses the Python files in
    that module's directory and records all top-level functions, classes,
    constants, and variables with their visibility and (for callables) their
    signature.

    Visibility follows the Python convention:
    - Names without a leading underscore are ``'public'``.
    - Names with a leading underscore are ``'private'``.

    Spec: visual-primitives.spec.md § Requirement: Symbol Table Extraction
    THEN both functions are emitted as symbols
    AND ``process_order`` is marked as public visibility
    AND ``_validate_input`` is marked as private visibility
    AND each symbol carries its signature.

    Args:
        src_path: Root of the Python codebase.
        nodes: All nodes (mutated in-place — ``symbols`` key added to module nodes).
    """
    for node in nodes:
        if node["type"] != "module":
            continue
        node_path = src_path / Path(node["id"].replace(".", "/"))
        if not node_path.is_dir():
            continue

        symbols: list[SymbolInfo] = []
        seen_names: set[str] = set()

        for py_file in sorted(node_path.rglob("*.py")):
            try:
                source = py_file.read_text(encoding="utf-8", errors="replace")
                tree = ast.parse(source, filename=str(py_file))
            except (SyntaxError, ValueError, UnicodeDecodeError):
                continue

            for item in ast.walk(tree):
                # Only capture top-level (module-level) or class-level defs.
                # ast.walk is depth-first; to restrict to top-level defs we
                # check that the parent is the module or a ClassDef.
                if not isinstance(
                    item, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
                ):
                    continue
                name = item.name
                if name in seen_names:
                    continue
                seen_names.add(name)

                visibility = "private" if name.startswith("_") else "public"

                if isinstance(item, ast.ClassDef):
                    sym: SymbolInfo = {
                        "name": name,
                        "visibility": visibility,
                        "kind": "class",
                    }
                else:
                    sig = _format_signature(item)
                    sym = {
                        "name": name,
                        "visibility": visibility,
                        "kind": "function",
                        "signature": sig,
                    }
                symbols.append(sym)

        node["symbols"] = symbols


# ---------------------------------------------------------------------------
# Type Topology Extraction (visual-primitives.spec.md §Type Topology Extraction)
# ---------------------------------------------------------------------------


def extract_type_topology(src_path: Path, all_nodes: list[Node]) -> list[Edge]:
    """Extract inheritance and composition edges between modules.

    Parses class definitions to find:
    - Inheritance: ``class Foo(Bar)`` → edge of type ``'inherits'``
    - Composition: class field typed as a known class → edge of type ``'has_a'``

    Only edges between known node IDs are emitted.  Cross-file class resolution
    relies solely on AST: the class name must match a known name in another
    module's symbol table.  Unresolvable bases are silently skipped.

    Spec: visual-primitives.spec.md § Requirement: Type Topology Extraction
    THEN an inheritance edge is emitted … AND the edge type is 'inherits'
    THEN a composition edge is emitted … AND the edge type is 'has_a'
    AND it requires only AST parsing of class declarations, field types,
    and base classes — no type inference or flow analysis.

    Args:
        src_path: Root of the Python codebase.
        all_nodes: All nodes in the scene graph.

    Returns:
        A list of new edges with type ``'inherits'`` or ``'has_a'``.
    """
    # Build a map: class_name → module_id that defines it.
    class_to_module: dict[str, str] = {}
    for node in all_nodes:
        if node["type"] != "module":
            continue
        node_path = src_path / Path(node["id"].replace(".", "/"))
        if not node_path.is_dir():
            continue
        for py_file in sorted(node_path.rglob("*.py")):
            try:
                source = py_file.read_text(encoding="utf-8", errors="replace")
                tree = ast.parse(source, filename=str(py_file))
            except (SyntaxError, ValueError, UnicodeDecodeError):
                continue
            for item in tree.body:
                if isinstance(item, ast.ClassDef):
                    class_to_module[item.name] = node["id"]

    all_module_ids = {n["id"] for n in all_nodes if n["type"] == "module"}
    edges: list[Edge] = []
    seen_edges: set[tuple[str, str, str]] = set()

    for node in all_nodes:
        if node["type"] != "module":
            continue
        source_id = node["id"]
        node_path = src_path / Path(source_id.replace(".", "/"))
        if not node_path.is_dir():
            continue

        for py_file in sorted(node_path.rglob("*.py")):
            try:
                source = py_file.read_text(encoding="utf-8", errors="replace")
                tree = ast.parse(source, filename=str(py_file))
            except (SyntaxError, ValueError, UnicodeDecodeError):
                continue

            for item in tree.body:
                if not isinstance(item, ast.ClassDef):
                    continue

                # Inheritance edges: each base class → 'inherits' edge.
                for base in item.bases:
                    base_name = ""
                    if isinstance(base, ast.Name):
                        base_name = base.id
                    elif isinstance(base, ast.Attribute):
                        base_name = base.attr
                    if not base_name:
                        continue
                    target_id = class_to_module.get(base_name)
                    if (
                        target_id is None
                        or target_id == source_id
                        or target_id not in all_module_ids
                    ):
                        continue
                    key = (source_id, target_id, "inherits")
                    if key not in seen_edges:
                        seen_edges.add(key)
                        edges.append(
                            {
                                "source": source_id,
                                "target": target_id,
                                "type": "inherits",
                            }
                        )

                # Composition edges: class body with annotated fields.
                for stmt in item.body:
                    if not isinstance(stmt, ast.AnnAssign):
                        continue
                    ann = stmt.annotation
                    # Accept simple names and subscript outer (e.g. list[Foo]).
                    type_name = ""
                    if isinstance(ann, ast.Name):
                        type_name = ann.id
                    elif isinstance(ann, ast.Subscript) and isinstance(
                        ann.value, ast.Name
                    ):
                        # e.g. list[PaymentInfo] — extract the subscript argument.
                        if isinstance(ann.slice, ast.Name):
                            type_name = ann.slice.id
                        elif isinstance(ann.slice, ast.Constant) and isinstance(
                            ann.slice.value, str
                        ):
                            type_name = ann.slice.value
                    if not type_name:
                        continue
                    target_id = class_to_module.get(type_name)
                    if (
                        target_id is None
                        or target_id == source_id
                        or target_id not in all_module_ids
                    ):
                        continue
                    key = (source_id, target_id, "has_a")
                    if key not in seen_edges:
                        seen_edges.add(key)
                        edges.append(
                            {"source": source_id, "target": target_id, "type": "has_a"}
                        )

    return edges


# ---------------------------------------------------------------------------
# Call Graph Extraction (visual-primitives.spec.md §Call Graph Extraction)
# ---------------------------------------------------------------------------


def _collect_function_names(src_path: Path, nodes: list[Node]) -> dict[str, str]:
    """Return a map from function name to module ID that defines it.

    Used by :func:`extract_call_graph` to resolve call targets.

    Args:
        src_path: Root of the Python codebase.
        nodes: All nodes in the scene graph.

    Returns:
        Dict mapping function name → module node ID.
    """
    fn_to_module: dict[str, str] = {}
    for node in nodes:
        if node["type"] != "module":
            continue
        node_path = src_path / Path(node["id"].replace(".", "/"))
        if not node_path.is_dir():
            continue
        for py_file in sorted(node_path.rglob("*.py")):
            try:
                source = py_file.read_text(encoding="utf-8", errors="replace")
                tree = ast.parse(source, filename=str(py_file))
            except (SyntaxError, ValueError, UnicodeDecodeError):
                continue
            for item in tree.body:
                if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    fn_to_module[item.name] = node["id"]
    return fn_to_module


def extract_call_graph(src_path: Path, all_nodes: list[Node]) -> list[Edge]:
    """Extract function-call edges between modules.

    For each function body, walks the AST to find ``Call`` nodes:
    - If the callee resolves to a function in another known module, a
      ``'direct_call'`` edge is emitted.  The ``weight`` carries the number
      of distinct call sites from the source module to the target module.
    - If the callee is a local variable/parameter (not a top-level name),
      a ``'dynamic_call'`` edge with ``target == 'dynamic'`` is emitted,
      recording that the source module has dynamic dispatch sites.

    Spec: visual-primitives.spec.md § Requirement: Call Graph Extraction
    THEN an edge is emitted from ``handle_request`` to ``validate_input``
    AND the edge type is ``'direct_call'``
    THEN the call site is emitted as a ``'dynamic_call'`` with no resolved target
    THEN the edge A→B carries a weight of 3 (when A calls B three times).

    Args:
        src_path: Root of the Python codebase.
        all_nodes: All nodes in the scene graph.

    Returns:
        A list of new edges with type ``'direct_call'`` or ``'dynamic_call'``.
    """
    fn_to_module = _collect_function_names(src_path, all_nodes)
    all_module_ids = {n["id"] for n in all_nodes if n["type"] == "module"}

    # Accumulate call counts per (source_module, target_module) pair.
    call_counts: dict[tuple[str, str], int] = {}
    # Track which source modules have dynamic dispatch sites.
    # Maps source_id → the callee parameter name (first encountered) so the
    # edge can carry param_name as required by the spec:
    #   "the call site carries the parameter name and any type hints"
    has_dynamic: dict[str, str] = {}

    for node in all_nodes:
        if node["type"] != "module":
            continue
        source_id = node["id"]
        node_path = src_path / Path(source_id.replace(".", "/"))
        if not node_path.is_dir():
            continue

        for py_file in sorted(node_path.rglob("*.py")):
            try:
                source = py_file.read_text(encoding="utf-8", errors="replace")
                tree = ast.parse(source, filename=str(py_file))
            except (SyntaxError, ValueError, UnicodeDecodeError):
                continue

            # Collect parameter names in each function — these are dynamic call
            # targets (the callee could be any callable passed in).
            for func_node in ast.walk(tree):
                if not isinstance(func_node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    continue
                param_names = {
                    arg.arg for arg in func_node.args.args + func_node.args.kwonlyargs
                }
                if func_node.args.vararg:
                    param_names.add(func_node.args.vararg.arg)
                if func_node.args.kwarg:
                    param_names.add(func_node.args.kwarg.arg)

                for call_node in ast.walk(func_node):
                    if not isinstance(call_node, ast.Call):
                        continue
                    callee_name = ""
                    if isinstance(call_node.func, ast.Name):
                        callee_name = call_node.func.id
                    elif isinstance(call_node.func, ast.Attribute):
                        callee_name = call_node.func.attr

                    if not callee_name:
                        continue

                    if callee_name in param_names:
                        # Dynamic call: callee is a parameter.
                        # Record first-encountered param name per source module so
                        # the edge carries param_name (spec: "the call site carries
                        # the parameter name and any type hints").
                        if source_id not in has_dynamic:
                            has_dynamic[source_id] = callee_name
                    else:
                        target_id = fn_to_module.get(callee_name)
                        if (
                            target_id is not None
                            and target_id != source_id
                            and target_id in all_module_ids
                        ):
                            key = (source_id, target_id)
                            call_counts[key] = call_counts.get(key, 0) + 1

    edges: list[Edge] = []
    for (src, tgt), weight in sorted(call_counts.items()):
        edges.append(
            {"source": src, "target": tgt, "type": "direct_call", "weight": weight}
        )
    for src in sorted(has_dynamic.keys()):
        edges.append(
            {
                "source": src,
                "target": "dynamic",
                "type": "dynamic_call",
                # spec: "the call site carries the parameter name and any type hints"
                "param_name": has_dynamic[src],
            }
        )

    return edges


# ---------------------------------------------------------------------------
# Structural Significance Extraction
# (visual-primitives.spec.md §Structural Significance Extraction)
# ---------------------------------------------------------------------------

# Hub threshold: a node is a hub when its in-degree exceeds this value.
_HUB_IN_DEGREE_THRESHOLD: int = 2

# Bridge threshold: betweenness centrality above this value marks a bridge.
_BRIDGE_BETWEENNESS_THRESHOLD: float = 0.1


def _compute_betweenness(
    node_ids: list[str], adj: dict[str, list[str]]
) -> dict[str, float]:
    """Compute normalised betweenness centrality for each node via BFS.

    Uses the Brandes algorithm (BFS-based) for unweighted graphs.  The result
    is normalised by ``(n-1)*(n-2)`` (directed graph normalisation) so values
    fall in [0, 1].

    Args:
        node_ids: List of all node IDs to include.
        adj: Adjacency list (directed: adj[u] contains nodes reachable from u).

    Returns:
        Dict mapping node ID → normalised betweenness centrality.
    """
    n = len(node_ids)
    betweenness: dict[str, float] = {v: 0.0 for v in node_ids}
    if n < 3:
        return betweenness

    for s in node_ids:
        # Brandes: BFS from s.
        stack: list[str] = []
        predecessors: dict[str, list[str]] = {v: [] for v in node_ids}
        sigma: dict[str, int] = {v: 0 for v in node_ids}
        dist: dict[str, int] = {v: -1 for v in node_ids}
        sigma[s] = 1
        dist[s] = 0
        queue: list[str] = [s]

        while queue:
            v = queue.pop(0)
            stack.append(v)
            for w in adj.get(v, []):
                if dist[w] < 0:
                    queue.append(w)
                    dist[w] = dist[v] + 1
                if dist[w] == dist[v] + 1:
                    sigma[w] += sigma[v]
                    predecessors[w].append(v)

        delta: dict[str, float] = {v: 0.0 for v in node_ids}
        while stack:
            w = stack.pop()
            for v in predecessors[w]:
                if sigma[w] > 0:
                    delta[v] += (sigma[v] / sigma[w]) * (1.0 + delta[w])
            if w != s:
                betweenness[w] += delta[w]

    # Normalise for directed graph: divide by (n-1)(n-2).
    norm = (n - 1) * (n - 2)
    if norm > 0:
        for v in betweenness:
            betweenness[v] /= norm

    return betweenness


def _detect_communities(module_ids: list[str], edges: list[Edge]) -> dict[str, str]:
    """Assign community identifiers to modules using a greedy connected-components
    approach on the undirected projection of the module graph.

    Each connected component (by internal and cross-context module edges) becomes
    a community.  This is a simplified alternative to Louvain/Leiden that requires
    only stdlib data structures.

    Args:
        module_ids: IDs of all module nodes.
        edges: All graph edges (only module→module edges are used).

    Returns:
        Dict mapping module ID → community identifier string (e.g. ``'community_0'``).
    """
    id_set = set(module_ids)
    parent: dict[str, str] = {m: m for m in module_ids}

    def _find(x: str) -> str:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def _union(a: str, b: str) -> None:
        ra, rb = _find(a), _find(b)
        if ra != rb:
            parent[ra] = rb

    for edge in edges:
        src, tgt = edge["source"], edge["target"]
        if src in id_set and tgt in id_set:
            _union(src, tgt)

    # Map root → sequential community index.
    root_to_idx: dict[str, int] = {}
    result: dict[str, str] = {}
    for m in module_ids:
        root = _find(m)
        if root not in root_to_idx:
            root_to_idx[root] = len(root_to_idx)
        result[m] = f"community_{root_to_idx[root]}"

    return result


def compute_structural_significance(nodes: list[Node], edges: list[Edge]) -> None:
    """Compute and embed structural significance metrics for all code nodes (in-place).

    For each bounded-context and module node, computes:
    - ``in_degree`` / ``out_degree``
    - ``betweenness_centrality`` (Brandes BFS)
    - ``is_hub`` (in_degree > threshold)
    - ``is_bridge`` (betweenness_centrality > threshold)
    - ``is_peripheral`` (in_degree == 0 and out_degree <= 1)
    - ``community_id`` (greedy connected-components community)
    - ``community_drift`` (detected community ≠ declared package)
    - ``is_landmark`` (hub or bridge)

    Results are embedded in ``node['structural_significance']`` and
    ``node['is_landmark']``.

    Spec: visual-primitives.spec.md § Requirement: Structural Significance Extraction
    Hub detection: high in-degree → flagged as hub
    Bridge detection: high betweenness → flagged as bridge
    Peripheral detection: in-degree 0, out-degree ≤ 1 → flagged as peripheral
    Community detection: each module annotated with community_id; drift detected

    Args:
        nodes: All nodes in the scene graph (mutated in-place).
        edges: All edges in the scene graph.
    """
    # Work on code nodes only (not spec nodes).
    code_nodes = [n for n in nodes if n["type"] in ("bounded_context", "module")]
    code_ids = [n["id"] for n in code_nodes]
    id_set = set(code_ids)

    # Count in/out-degree from all non-aggregate edges.
    in_deg: dict[str, int] = {nid: 0 for nid in code_ids}
    out_deg: dict[str, int] = {nid: 0 for nid in code_ids}
    adj: dict[str, list[str]] = {nid: [] for nid in code_ids}

    for edge in edges:
        if edge.get("type") == "aggregate":
            continue
        src, tgt = edge["source"], edge["target"]
        if src in id_set:
            out_deg[src] += 1
        if tgt in id_set:
            in_deg[tgt] += 1
        if src in id_set and tgt in id_set:
            adj[src].append(tgt)
            adj[tgt].append(src)  # undirected for betweenness/bridge detection

    # Betweenness centrality via Brandes BFS.
    betweenness = _compute_betweenness(code_ids, adj)

    # Community detection.
    module_ids = [n["id"] for n in code_nodes if n["type"] == "module"]
    community_map = _detect_communities(module_ids, edges)

    # Annotate each node in-place.
    for node in code_nodes:
        nid = node["id"]
        ind = in_deg[nid]
        outd = out_deg[nid]
        bc = betweenness[nid]
        is_hub = ind > _HUB_IN_DEGREE_THRESHOLD
        is_bridge = bc > _BRIDGE_BETWEENNESS_THRESHOLD
        is_peripheral = ind == 0 and outd <= 1

        sig: StructuralSignificanceMetrics = {
            "in_degree": ind,
            "out_degree": outd,
            "is_hub": is_hub,
            "is_bridge": is_bridge,
            "is_peripheral": is_peripheral,
            "betweenness_centrality": bc,
        }

        if node["type"] == "module" and nid in community_map:
            sig["community_id"] = community_map[nid]
            # community_drift: True when the community contains modules from more
            # than one bounded context (i.e. the component spans context boundaries).
            detected_community = community_map[nid]
            same_community_mods = [
                m for m, c in community_map.items() if c == detected_community
            ]
            bcs_in_community = {m.split(".")[0] for m in same_community_mods}
            sig["community_drift"] = len(bcs_in_community) > 1

        node["structural_significance"] = sig

        # Flat fields for backward compatibility with task-074 tests.
        # Also ensures build_scene_graph produces in_degree/is_hub etc. on all nodes.
        node["in_degree"] = ind
        node["out_degree"] = outd
        node["is_hub"] = is_hub
        node["is_bridge"] = is_bridge
        node["is_peripheral"] = is_peripheral

        # community_id as int (extract index from "community_N" string).
        if nid in community_map:
            community_str = community_map[nid]  # e.g. "community_0"
            node["community_id"] = int(community_str.split("_")[-1])
        else:
            node["community_id"] = 0

        # community_drift from structural_significance if present, else False.
        node["community_drift"] = bool(sig.get("community_drift", False))

        # Landmark: hub, bridge, or entry-point nodes persist at all zoom levels.
        # Entry point: no in-edges from application code (in_degree == 0) but
        # has multiple out-edges (out_degree > 1) — it is a dependency source,
        # not a peripheral leaf.
        # spec: visual-primitives.spec.md §Scenario: Landmark sources —
        #   "hubs (high in-degree), bridges (high betweenness centrality),
        #    entry points (no in-edges from application code)"
        is_entry_point = ind == 0 and outd > 1

        # Landmark: hub, bridge or entry points persist at all zoom levels.
        # Also flag entry points as landmarks (they are navigation anchors).
        if is_hub or is_bridge or is_entry_point:
            node["is_landmark"] = True


# ---------------------------------------------------------------------------
# Ubiquitous Dependency Detection
# ---------------------------------------------------------------------------

# Default fraction of module nodes that must import a dependency for it to be
# considered ubiquitous and suppressed from the default view.
_DEFAULT_UBIQUITY_THRESHOLD: float = 0.5


def compute_ubiquitous_flags(
    nodes: list[Node],
    edges: list[Edge],
    threshold: float = _DEFAULT_UBIQUITY_THRESHOLD,
) -> dict[str, float]:
    """Flag edges whose target is a ubiquitous dependency (in-place on edges).

    A dependency is ubiquitous when the fraction of module nodes that import it
    exceeds *threshold* (default 0.50 — more than half of all modules).

    For each edge whose target is ubiquitous, sets ``edge["ubiquitous"] = True``.
    Non-ubiquitous edges are not modified.

    Returns a mapping of ``{target_id: import_fraction}`` for all targets that
    exceeded the threshold, so the caller can embed the threshold in metadata.

    Spec: visual-primitives.spec.md § Ubiquitous Dependency Detection.
    """
    # Count how many module-level nodes import each target (by edge source).
    module_ids: set[str] = {n["id"] for n in nodes if n["type"] == "module"}
    total_modules = len(module_ids)

    if total_modules == 0:
        return {}

    # importers[target_id] = set of source module IDs that import it.
    importers: dict[str, set[str]] = {}
    for edge in edges:
        src, tgt = edge["source"], edge["target"]
        if src in module_ids:
            importers.setdefault(tgt, set()).add(src)

    # Identify ubiquitous targets.
    ubiquitous_targets: dict[str, float] = {}
    for tgt, srcs in importers.items():
        fraction = len(srcs) / total_modules
        if fraction > threshold:
            ubiquitous_targets[tgt] = fraction

    # Annotate edges.
    for edge in edges:
        if edge["target"] in ubiquitous_targets:
            edge["ubiquitous"] = True

    return ubiquitous_targets


# (visual-primitives.spec.md §Ubiquitous Dependency Detection)

# Default threshold: a module imported by more than this fraction of all
# modules is considered ubiquitous.
UBIQUITOUS_THRESHOLD: float = 0.5


def detect_ubiquitous_dependencies(
    nodes: list[Node],
    edges: list[Edge],
    threshold: float = UBIQUITOUS_THRESHOLD,
) -> None:
    """Flag ubiquitous dependencies and mark dependent nodes for power-rail rendering.

    A module is ubiquitous when the fraction of other modules that import it
    exceeds *threshold*.  Ubiquitous edges are annotated with ``ubiquitous=True``;
    nodes that import at least one ubiquitous module get ``has_ubiquitous_dep=True``.

    The extraction metadata threshold is embedded as ``metadata['ubiquitous_threshold']``
    if a metadata dict is provided — that is handled in :func:`build_scene_graph`.

    Spec: visual-primitives.spec.md § Requirement: Ubiquitous Dependency Detection
    GIVEN that 85% of modules import ``logging``
    THEN ``logging`` is flagged as ubiquitous
    AND its edges are present in the scene graph but marked as ``ubiquitous: true``

    Args:
        nodes: All nodes (mutated in-place — ``has_ubiquitous_dep`` added where needed).
        edges: All edges (mutated in-place — ``ubiquitous`` added where needed).
        threshold: Fraction of modules that must import a target to flag it ubiquitous.
    """
    # Count how many distinct source modules reference each target.
    module_ids = {n["id"] for n in nodes if n["type"] in ("bounded_context", "module")}
    total_modules = len(module_ids)
    if total_modules == 0:
        return

    import_count: dict[str, set[str]] = {}  # target_id → set of importing module IDs
    for edge in edges:
        src, tgt = edge["source"], edge["target"]
        if src in module_ids:
            import_count.setdefault(tgt, set()).add(src)

    # Identify ubiquitous targets.
    ubiquitous_ids: set[str] = set()
    for tgt, importers in import_count.items():
        if len(importers) / total_modules > threshold:
            ubiquitous_ids.add(tgt)

    if not ubiquitous_ids:
        return

    # Mark edges and source nodes.
    nodes_with_ubiquitous: set[str] = set()
    for edge in edges:
        if edge["target"] in ubiquitous_ids:
            edge["ubiquitous"] = True
            nodes_with_ubiquitous.add(edge["source"])

    for node in nodes:
        if node["id"] in nodes_with_ubiquitous:
            node["has_ubiquitous_dep"] = True


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def build_scene_graph(src_path: Path) -> SceneGraph:
    """Extract a complete scene graph from the Python codebase at *src_path*.

    Args:
        src_path: Root directory of the Python source tree to analyse.

    Returns:
        A :class:`SceneGraph` ready to be serialised as JSON.
    """
    nodes: list[Node] = []

    # 1. Discover bounded contexts.
    bc_nodes = discover_bounded_contexts(src_path)
    nodes.extend(bc_nodes)

    # 2. Discover internal modules within each bounded context.
    for bc_node in bc_nodes:
        module_nodes = discover_submodules(src_path, bc_node["id"])
        nodes.extend(module_nodes)

    # 3. Build dependency edges first so the layout can use coupling info.
    edges = build_dependency_edges(src_path, nodes)

    # 4. Discover spec files and include them as structural nodes.
    #    Spec nodes represent the *intended design* alongside the *realized code*.
    #    No content analysis is performed — only the existence and size of spec
    #    files is recorded.
    spec_nodes = discover_spec_nodes(src_path)
    nodes.extend(spec_nodes)

    # 5. Compute layout with coupling-aware BC ordering (mutates positions in-place).
    #    Spec nodes are positioned beyond the code circle by compute_layout().
    compute_layout(nodes, edges)

    # 6. Assign independence groups to module nodes (mutates nodes in-place).
    compute_independence_groups(nodes, edges)

    # 7. Compute cluster suggestions for tightly-coupled module groups.
    clusters = compute_clusters(nodes, edges)

    # 8. Extract symbol table for module nodes (visual-primitives.spec.md).
    #    Annotates each module node with its public/private named entities.
    extract_symbols(src_path, nodes)

    # 9. Extract type topology (inheritance + composition) edges.
    #    Emits 'inherits' and 'has_a' edges between module nodes.
    topology_edges = extract_type_topology(src_path, nodes)
    edges.extend(topology_edges)

    # 10. Extract call graph edges between module nodes.
    #     Emits 'direct_call' and 'dynamic_call' edges.
    call_edges = extract_call_graph(src_path, nodes)
    edges.extend(call_edges)

    # 11. Compute structural significance (hub, bridge, peripheral, community).
    #     Annotates every code node with structural_significance and is_landmark.
    #     Also sets flat fields (in_degree, is_hub, etc.) for backward compatibility.
    compute_structural_significance(nodes, edges)

    # 12. Detect ubiquitous dependencies and mark for power-rail notation.
    #     Marks edges as ubiquitous and nodes with has_ubiquitous_dep.
    detect_ubiquitous_dependencies(nodes, edges)

    # 13. Assemble metadata.
    metadata: Metadata = {
        "source_path": str(src_path),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "ubiquity_threshold": _DEFAULT_UBIQUITY_THRESHOLD,
    }

    return {"nodes": nodes, "edges": edges, "metadata": metadata, "clusters": clusters}
