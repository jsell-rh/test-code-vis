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

from extractor.schema import Edge, EdgeType, Metadata, Node, NodeMetrics, SceneGraph

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Top-level directories that are Python packages but NOT bounded contexts.
_NON_CONTEXT_DIRS: frozenset[str] = frozenset(
    {"tests", "docs", "util", "__pycache__", "migrations", "alembic"}
)


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

    Module nodes are placed in a smaller circle and their positions are stored
    as LOCAL offsets relative to their parent BC.  Godot's main.gd adds the
    parent world position at render time.
    """
    bc_nodes = [n for n in nodes if n["type"] == "bounded_context"]

    # Optionally reorder so coupled BCs sit adjacent in the ring.
    if edges:
        bc_nodes = _order_by_coupling(bc_nodes, edges)

    # cap bc_radius so nodes stay within scene bounds  # noqa: E501
    bc_radius = min(max(5.0, len(bc_nodes) * 2.5), 100.0)
    bc_positions = _circular_positions(len(bc_nodes), bc_radius)

    for bc_node, pos in zip(bc_nodes, bc_positions):
        bc_node["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}

    # Group modules by parent
    parent_children: dict[str, list[Node]] = {}
    for n in nodes:
        if n["type"] == "module" and n["parent"]:
            parent_children.setdefault(n["parent"], []).append(n)

    for _parent_id, children in parent_children.items():
        # cap mod_radius relative to bc_radius so modules stay inside parent bounds
        mod_radius = min(max(1.5, len(children) * 0.9), bc_radius * 0.4)
        mod_positions = _circular_positions(len(children), mod_radius, y=0.0)
        # Store LOCAL offset only — Godot's main.gd adds the parent world pos
        # at render time, so storing absolute coords here causes double-offset.
        for child, pos in zip(children, mod_positions):
            child["position"] = {
                "x": pos[0],  # local x offset from parent
                "y": pos[1],  # local y offset from parent
                "z": pos[2],  # local z offset from parent
            }


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------


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
    ``graph → shared_kernel``).  Internal edges are created at the module
    level (e.g. ``iam.application → iam.domain``).

    Duplicate edges are deduplicated.
    """
    all_ids = {n["id"] for n in all_nodes}
    context_ids = {n["id"] for n in all_nodes if n["type"] == "bounded_context"}

    raw_edges: set[tuple[str, str, EdgeType]] = set()

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
            else:
                # Internal: only emit from module-level nodes to avoid duplicating
                # edges that would also be created by the bounded-context scan.
                if node["type"] != "module":
                    continue
                if target_id == source_context:
                    # The import resolves only to the BC itself — skip.
                    continue
                raw_edges.add((source_id, target_id, "internal"))

    return [
        {"source": src, "target": tgt, "type": etype}
        for src, tgt, etype in sorted(raw_edges)
    ]


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

    # 4. Compute layout with coupling-aware BC ordering (mutates positions in-place).
    compute_layout(nodes, edges)

    # 5. Assemble metadata.
    metadata: Metadata = {
        "source_path": str(src_path),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    return {"nodes": nodes, "edges": edges, "metadata": metadata}
