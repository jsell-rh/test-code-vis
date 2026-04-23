"""
Core extraction logic for the code-vis scene graph.

Discovers Python modules in a target codebase, extracts import-based
dependencies, computes complexity metrics, and produces a JSON scene graph
conforming to the schema defined in extractor.schema.
"""

from __future__ import annotations

import ast
import math
import re
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


def compute_layout(nodes: list[Node]) -> None:
    """Assign pre-computed 3D positions to all nodes (mutates *nodes* in-place).

    Bounded contexts are arranged in a circle.  The modules within each
    context are arranged in a smaller circle at a fixed y-offset so that
    child nodes are visually "inside" their parent.
    """
    bc_nodes = [n for n in nodes if n["type"] == "bounded_context"]
    bc_radius = max(5.0, len(bc_nodes) * 2.5)
    bc_positions = _circular_positions(len(bc_nodes), bc_radius)

    for bc_node, pos in zip(bc_nodes, bc_positions):
        bc_node["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}

    # Group modules by parent
    parent_children: dict[str, list[Node]] = {}
    for n in nodes:
        if n["type"] == "module" and n["parent"]:
            parent_children.setdefault(n["parent"], []).append(n)

    for children in parent_children.values():
        mod_radius = max(1.5, len(children) * 0.9)
        mod_positions = _circular_positions(len(children), mod_radius, y=1.0)
        for child, pos in zip(children, mod_positions):
            child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}


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
# Spec extraction
# ---------------------------------------------------------------------------

_SPEC_HEADING_RE = re.compile(
    r"^#{1,3}\s+(?:Bounded Context:\s*)?([A-Za-z][A-Za-z0-9 _-]+)\s*$",
    re.MULTILINE,
)
_SPEC_LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\.spec\.md\)")


def extract_spec_nodes(src_path: Path) -> list[Node]:
    """Extract spec-defined components from a codebase's ``specs/`` directory.

    Returns nodes with ``type='spec'`` so they are distinguishable from
    code-derived nodes.  Only top-level bounded-context spec directories are
    discovered; individual spec files become module-level spec nodes.
    """
    specs_path = src_path / "specs"
    if not specs_path.exists() or not specs_path.is_dir():
        return []

    nodes: list[Node] = []
    index_file = specs_path / "index.spec.md"

    # Use the index file to find top-level bounded contexts if available.
    bc_names: list[str] = []
    if index_file.exists():
        text = index_file.read_text(encoding="utf-8", errors="replace")
        # Look for section links like [IAM](iam/) or [IAM](iam/...)
        for m in re.finditer(r"\[([^\]]+)\]\(([a-z][a-z0-9_-]*)/", text):
            label, dirname = m.group(1), m.group(2)
            bc_dir = specs_path / dirname
            if bc_dir.is_dir():
                bc_names.append(dirname)
                spec_node: Node = {
                    "id": f"spec.{dirname}",
                    "name": label,
                    "type": "spec",
                    "position": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "size": 1.0,
                    "parent": None,
                }
                nodes.append(spec_node)
                # Child spec files
                for spec_file in sorted(bc_dir.glob("*.spec.md")):
                    stem = spec_file.stem.replace(".spec", "")
                    child: Node = {
                        "id": f"spec.{dirname}.{stem}",
                        "name": _prettify(stem.replace("-", "_")),
                        "type": "spec",
                        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
                        "size": 0.5,
                        "parent": f"spec.{dirname}",
                    }
                    nodes.append(child)
    else:
        # Fallback: discover spec directories by scanning the specs/ folder.
        for candidate in sorted(specs_path.iterdir()):
            if candidate.is_dir() and not candidate.name.startswith("."):
                spec_node = {
                    "id": f"spec.{candidate.name}",
                    "name": _prettify(candidate.name.replace("-", "_")),
                    "type": "spec",
                    "position": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "size": 1.0,
                    "parent": None,
                }
                nodes.append(spec_node)

    # Position spec nodes in a separate ring above the code nodes.
    _layout_spec_nodes(nodes)
    return nodes


def _layout_spec_nodes(spec_nodes: list[Node]) -> None:
    """Position spec nodes in a ring above the main scene (y=5)."""
    top_level = [n for n in spec_nodes if n["parent"] is None]
    radius = max(5.0, len(top_level) * 2.5)
    positions = _circular_positions(len(top_level), radius, y=5.0)
    parent_pos: dict[str, tuple[float, float, float]] = {}
    for node, pos in zip(top_level, positions):
        node["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}
        parent_pos[node["id"]] = pos

    children_by_parent: dict[str, list[Node]] = {}
    for n in spec_nodes:
        if n["parent"]:
            children_by_parent.setdefault(n["parent"], []).append(n)

    for parent_id, children in children_by_parent.items():
        child_radius = max(1.0, len(children) * 0.8)
        child_positions = _circular_positions(len(children), child_radius, y=5.0)
        for child, pos in zip(children, child_positions):
            child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def build_scene_graph(
    src_path: Path,
    *,
    include_specs: bool = False,
) -> SceneGraph:
    """Extract a complete scene graph from the Python codebase at *src_path*.

    Args:
        src_path: Root directory of the Python source tree to analyse.
        include_specs: When *True*, also extract spec-defined components
            from a ``specs/`` directory alongside the source tree.

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

    # 3. Compute layout (mutates positions in-place).
    compute_layout(nodes)

    # 4. Build dependency edges.
    edges = build_dependency_edges(src_path, nodes)

    # 5. Optionally add spec nodes.
    if include_specs:
        # The specs/ directory is conventionally a sibling of src_path.
        spec_search_roots = [src_path, src_path.parent, src_path.parent.parent]
        for root in spec_search_roots:
            spec_nodes = extract_spec_nodes(root)
            if spec_nodes:
                nodes.extend(spec_nodes)
                break

    # 6. Assemble metadata.
    metadata: Metadata = {
        "source_path": str(src_path),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    return {"nodes": nodes, "edges": edges, "metadata": metadata}
