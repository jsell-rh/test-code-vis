"""
Scene graph schema definitions.

Defines the JSON format that serves as the sole interface contract
between the Python extractor and the Godot application.
"""

from __future__ import annotations

from typing import Literal, NotRequired, TypedDict


class Position(TypedDict):
    """3D position in scene space."""

    x: float
    y: float
    z: float


NodeType = Literal["bounded_context", "module", "spec"]
EdgeType = Literal["cross_context", "internal"]


class NodeMetrics(TypedDict):
    """Raw complexity metrics for a node."""

    loc: int
    """Total lines of code (Python source files, recursive)."""


class Node(TypedDict):
    """A node in the scene graph.

    Represents a bounded context or module extracted from the codebase.
    """

    id: str
    """Unique identifier, e.g. 'iam' or 'iam.domain'."""

    name: str
    """Human-readable display name, e.g. 'IAM' or 'Domain'."""

    type: NodeType
    """Level of the node: 'bounded_context', 'module', or 'spec'."""

    position: Position
    """Pre-computed 3D position. Coordinates are relative to the parent node."""

    size: float
    """Visual size derived from the node's complexity metric."""

    parent: str | None
    """ID of the containing node, or null for top-level nodes."""

    metrics: NotRequired[NodeMetrics]
    """Raw complexity metrics. Present for code-derived nodes."""


class Edge(TypedDict):
    """A directed dependency edge between two nodes."""

    source: str
    """ID of the node that has the dependency."""

    target: str
    """ID of the node being depended upon."""

    type: EdgeType
    """'cross_context' for inter-bounded-context deps, 'internal' for intra-context."""


class Metadata(TypedDict):
    """Extraction metadata recorded alongside the graph."""

    source_path: str
    """Absolute path to the source codebase that was analysed."""

    timestamp: str
    """ISO-8601 UTC timestamp of when the extraction was performed."""


class SceneGraph(TypedDict):
    """Root of the JSON scene graph file.

    This is the complete contract between the Python extractor and the
    Godot application.  The JSON file MUST contain exactly these three
    top-level fields.
    """

    nodes: list[Node]
    edges: list[Edge]
    metadata: Metadata


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

_REQUIRED_NODE_KEYS: frozenset[str] = frozenset(
    {"id", "name", "type", "position", "size", "parent"}
)
_REQUIRED_POSITION_KEYS: frozenset[str] = frozenset({"x", "y", "z"})
_REQUIRED_EDGE_KEYS: frozenset[str] = frozenset({"source", "target", "type"})
_REQUIRED_METADATA_KEYS: frozenset[str] = frozenset({"source_path", "timestamp"})
_REQUIRED_GRAPH_KEYS: frozenset[str] = frozenset({"nodes", "edges", "metadata"})


def validate_scene_graph(graph: object) -> None:
    """Assert that *graph* conforms to the scene graph schema.

    Raises :class:`ValueError` with a descriptive message if any required
    field is absent or has the wrong type.  Designed to be called by the
    output writer (task-006) before persisting the JSON file.

    Args:
        graph: The object to validate — must be a dict with the three
               top-level keys ``nodes``, ``edges``, and ``metadata``.

    Raises:
        ValueError: If any required field is missing or has the wrong type.
    """
    if not isinstance(graph, dict):
        raise ValueError(f"Scene graph must be a dict, got {type(graph).__name__!r}")

    missing = _REQUIRED_GRAPH_KEYS - graph.keys()
    if missing:
        raise ValueError(f"Scene graph missing top-level key(s): {sorted(missing)}")

    extra = set(graph.keys()) - _REQUIRED_GRAPH_KEYS
    if extra:
        raise ValueError(
            f"Scene graph has unexpected top-level key(s): {sorted(extra)}"
        )

    if not isinstance(graph["nodes"], list):
        raise ValueError("'nodes' must be a list")
    if not isinstance(graph["edges"], list):
        raise ValueError("'edges' must be a list")
    if not isinstance(graph["metadata"], dict):
        raise ValueError("'metadata' must be a dict")

    for i, node in enumerate(graph["nodes"]):
        if not isinstance(node, dict):
            raise ValueError(f"nodes[{i}] must be a dict, got {type(node).__name__!r}")
        missing_node = _REQUIRED_NODE_KEYS - node.keys()
        if missing_node:
            raise ValueError(
                f"nodes[{i}] missing required key(s): {sorted(missing_node)}"
            )
        pos = node.get("position")
        if not isinstance(pos, dict):
            raise ValueError(
                f"nodes[{i}]['position'] must be a dict, got {type(pos).__name__!r}"
            )
        missing_pos = _REQUIRED_POSITION_KEYS - pos.keys()
        if missing_pos:
            raise ValueError(
                f"nodes[{i}]['position'] missing key(s): {sorted(missing_pos)}"
            )
        for coord in ("x", "y", "z"):
            if not isinstance(pos[coord], (int, float)):
                raise ValueError(
                    f"nodes[{i}]['position'][{coord!r}] must be numeric, "
                    f"got {type(pos[coord]).__name__!r}"
                )

    for i, edge in enumerate(graph["edges"]):
        if not isinstance(edge, dict):
            raise ValueError(f"edges[{i}] must be a dict, got {type(edge).__name__!r}")
        missing_edge = _REQUIRED_EDGE_KEYS - edge.keys()
        if missing_edge:
            raise ValueError(
                f"edges[{i}] missing required key(s): {sorted(missing_edge)}"
            )

    meta = graph["metadata"]
    missing_meta = _REQUIRED_METADATA_KEYS - meta.keys()
    if missing_meta:
        raise ValueError(f"metadata missing key(s): {sorted(missing_meta)}")
