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

    If module nodes carry an ``independence_group`` field (set by
    :func:`compute_independence_groups`), modules in different groups are
    spatially separated: each group occupies its own sub-cluster within the
    parent BC's volume, with a visible gap between groups.  Single-group BCs
    (or BCs whose modules have no ``independence_group``) keep the original
    circular layout.

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
        # Group children by independence_group.  Nodes without the field are
        # all assigned to a synthetic single group so they fall through to the
        # standard circular layout path.
        _SINGLETON = "__single__"
        children_by_group: dict[str, list[Node]] = {}
        for child in children:
            gid = child.get("independence_group", _SINGLETON)
            children_by_group.setdefault(gid, []).append(child)

        n_groups = len(children_by_group)
        # Total available radius for modules within this BC (same cap as before).
        mod_radius = min(
            max(1.5, len(children) * 0.9), bc_radius * 0.4
        )  # cap inside parent

        if n_groups <= 1:
            # Single group (or no group info): original circular layout.
            # Store LOCAL offsets only (relative to the parent BC's origin).
            # main.gd resolves world positions by adding parent world pos + local offset,
            # so storing absolute coords here would cause double-offset rendering.
            mod_positions = _circular_positions(len(children), mod_radius, y=0.0)
            for child, pos in zip(children, mod_positions):
                child["position"] = {
                    "x": pos[0],
                    "y": pos[1],
                    "z": pos[2],
                }
        else:
            # Multiple independence groups: arrange each group as a sub-cluster.
            # group_orbit_r: orbit radius for group centres (from BC origin).
            # sub_r: orbit radius for modules within each group.
            # Constraint: group_orbit_r + sub_r <= mod_radius keeps all modules
            # within the parent BC's spatial bounds.
            # # sub_r occupies ~35 % of available radius (modules stay within group).
            sub_r = min(max(0.4, mod_radius * 0.3), mod_radius * 0.35)
            # group_orbit_r pushes groups apart to create a visible gap.
            group_orbit_r = min(
                max(sub_r + 0.3, mod_radius * 0.55), mod_radius - sub_r
            )
            group_ids = sorted(children_by_group.keys())  # deterministic ordering
            group_centers = _circular_positions(n_groups, group_orbit_r, y=0.0)
            for gid, (gcx, gcy, gcz) in zip(group_ids, group_centers):
                members = children_by_group[gid]
                # Sub-ring around each group centre; coupling-aware layout still
                # applies within the group (modules in a tight cluster).
                member_positions = _circular_positions(len(members), sub_r, y=0.0)
                for member, (mx, my, mz) in zip(members, member_positions):
                    # Store LOCAL offset from BC origin (gcx + mx is still relative
                    # to the BC anchor, which sits at the BC world position).
                    member["position"] = {
                        "x": gcx + mx,
                        "y": 0.0,
                        "z": gcz + mz,
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

    Duplicate edges are deduplicated.
    """
    all_ids = {n["id"] for n in all_nodes}
    context_ids = {n["id"] for n in all_nodes if n["type"] == "bounded_context"}

    raw_edges: set[tuple[str, str, EdgeType]] = set()

    # Count unique module-level cross-context imports per BC pair.
    # Keyed by (source_bc, target_bc) → import count.
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
                raw_edges.add((edge_src, edge_tgt, "cross_context"))
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
                raw_edges.add((source_id, target_id, "internal"))

    # Individual cross-context and internal edges.
    edges: list[Edge] = [
        {"source": src, "target": tgt, "type": etype}
        for src, tgt, etype in sorted(raw_edges)
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
# Structural Significance
# ---------------------------------------------------------------------------

# Fraction of nodes whose in-degree must exceed the median for a node to be
# considered a hub.  Set to 2× the mean in-degree.  Any node with in-degree
# above this multiple is flagged as a hub.
_HUB_MULTIPLIER: float = 2.0


def compute_structural_significance(nodes: list[Node], edges: list[Edge]) -> None:
    """Annotate every node with structural significance metrics (in-place).

    Computes:
    - ``in_degree``/``out_degree``: raw edge counts.
    - ``is_hub``: True when in_degree > 2 × mean(in_degree) across all nodes
      AND in_degree ≥ 2 (a hub must have at least two dependents).
    - ``is_bridge``: True when the node is a graph articulation point whose
      removal would disconnect the undirected version of the module graph.
    - ``is_peripheral``: True when in_degree == 0 and out_degree ≤ 1.
    - ``community_id``: connected-component index in the undirected module graph.
    - ``community_drift``: True when the node's community contains nodes from
      more than one bounded context (cross-context component).

    Spec: visual-primitives.spec.md § Structural Significance Extraction.
    """
    # Build adjacency for all node IDs.
    node_ids: set[str] = {n["id"] for n in nodes}

    # ── In-degree / out-degree ────────────────────────────────────────────────
    in_deg: dict[str, int] = {nid: 0 for nid in node_ids}
    out_deg: dict[str, int] = {nid: 0 for nid in node_ids}

    for edge in edges:
        src, tgt = edge["source"], edge["target"]
        if src in out_deg:
            out_deg[src] += 1
        if tgt in in_deg:
            in_deg[tgt] += 1

    # ── Hub detection ─────────────────────────────────────────────────────────
    # A hub is a node whose in-degree exceeds _HUB_MULTIPLIER × the mean
    # in-degree AND has at least 2 incoming edges.
    total_in = sum(in_deg.values())
    n_nodes = len(node_ids)
    mean_in = total_in / n_nodes if n_nodes > 0 else 0.0
    hub_threshold = _HUB_MULTIPLIER * mean_in

    # ── Undirected adjacency for bridge/community detection ───────────────────
    adj: dict[str, set[str]] = {nid: set() for nid in node_ids}
    for edge in edges:
        src, tgt = edge["source"], edge["target"]
        if src in adj and tgt in adj:
            adj[src].add(tgt)
            adj[tgt].add(src)

    # ── Bridge detection via articulation-point DFS ──────────────────────────
    # A node is an articulation point if removing it increases the number of
    # connected components in the undirected graph.
    discovery: dict[str, int] = {}
    low: dict[str, int] = {}
    parent_dfs: dict[str, str | None] = {}
    articulation_points: set[str] = set()
    timer: list[int] = [0]  # mutable counter in closure

    def _dfs_ap(u: str) -> None:
        children = 0
        discovery[u] = low[u] = timer[0]
        timer[0] += 1
        for v in adj[u]:
            if v not in discovery:
                children += 1
                parent_dfs[v] = u
                _dfs_ap(v)
                low[u] = min(low[u], low[v])
                # Root of DFS tree: articulation if it has ≥ 2 DFS children.
                if parent_dfs.get(u) is None and children > 1:
                    articulation_points.add(u)
                # Non-root: articulation if no back edge from subtree.
                if parent_dfs.get(u) is not None and low[v] >= discovery[u]:
                    articulation_points.add(u)
            elif v != parent_dfs.get(u):
                low[u] = min(low[u], discovery[v])

    for nid in node_ids:
        if nid not in discovery:
            parent_dfs[nid] = None
            _dfs_ap(nid)

    # ── Community detection via connected components ──────────────────────────
    community_map: dict[str, int] = {}
    component_idx = 0

    def _bfs_component(start: str, comp_id: int) -> None:
        frontier = [start]
        community_map[start] = comp_id
        while frontier:
            next_frontier: list[str] = []
            for u in frontier:
                for v in adj[u]:
                    if v not in community_map:
                        community_map[v] = comp_id
                        next_frontier.append(v)
            frontier = next_frontier

    for nid in node_ids:
        if nid not in community_map:
            _bfs_component(nid, component_idx)
            component_idx += 1

    # For each community, collect the set of bounded contexts represented.
    component_contexts: dict[int, set[str]] = {}
    node_by_id: dict[str, Node] = {n["id"]: n for n in nodes}
    for nid, comp_id in community_map.items():
        nd = node_by_id[nid]
        # A bounded context's "own" context is itself; a module's is its parent.
        context = nd["parent"] if nd["parent"] is not None else nid
        component_contexts.setdefault(comp_id, set()).add(context)

    # ── Annotate nodes ────────────────────────────────────────────────────────
    for node in nodes:
        nid = node["id"]
        node["in_degree"] = in_deg[nid]
        node["out_degree"] = out_deg[nid]

        # Hub: above threshold AND at least 2 dependents.
        node["is_hub"] = in_deg[nid] >= 2 and in_deg[nid] > hub_threshold

        # Bridge: articulation point in the undirected graph.
        node["is_bridge"] = nid in articulation_points

        # Peripheral: no incoming edges and at most one outgoing edge.
        node["is_peripheral"] = in_deg[nid] == 0 and out_deg[nid] <= 1

        comp_id = community_map.get(nid, 0)
        node["community_id"] = comp_id

        # Drift: the community spans more than one bounded context.
        node["community_drift"] = len(component_contexts.get(comp_id, set())) > 1


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

    # 5. Assign independence groups BEFORE layout so that compute_layout can
    #    use the groups for spatial separation.  Modules in different groups
    #    are placed in distinct sub-clusters within the BC's volume (a visible
    #    gap between them) while modules within a group stay close together.
    compute_independence_groups(nodes, edges)

    # 6. Compute layout with coupling-aware BC ordering (mutates positions in-place).
    #    Spec nodes are positioned beyond the code circle by compute_layout().
    #    Module nodes with independence_group set receive group-aware layout.
    compute_layout(nodes, edges)

    # 7. Compute cluster suggestions for tightly-coupled module groups.
    clusters = compute_clusters(nodes, edges)

    # 8. Compute structural significance (hub, bridge, peripheral, community).
    #    This annotates every node with in_degree/out_degree/is_hub/is_bridge/
    #    is_peripheral/community_id/community_drift so the Godot renderer can
    #    display Landmark visual treatment for structurally important nodes.
    compute_structural_significance(nodes, edges)

    # 9. Detect ubiquitous dependencies and mark edges accordingly.
    #    Edges to ubiquitous targets get ubiquitous=True; the Godot renderer
    #    suppresses these edges and shows a Power Rail indicator instead.
    compute_ubiquitous_flags(nodes, edges)

    # 10. Assemble metadata.
    metadata: Metadata = {
        "source_path": str(src_path),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "ubiquity_threshold": _DEFAULT_UBIQUITY_THRESHOLD,
    }

    return {"nodes": nodes, "edges": edges, "metadata": metadata, "clusters": clusters}
