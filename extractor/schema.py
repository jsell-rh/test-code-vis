"""
Scene graph schema definitions.

Defines the JSON format that serves as the sole interface contract
between the Python extractor and the Godot application.
"""

from __future__ import annotations

from typing import Literal, TypedDict


class Position(TypedDict):
    """3D position in scene space."""

    x: float
    y: float
    z: float


NodeType = Literal["bounded_context", "module"]
EdgeType = Literal["cross_context", "internal"]


class Node(TypedDict):
    """A node in the scene graph.

    Represents a bounded context or module extracted from the codebase.
    """

    id: str
    """Unique identifier, e.g. 'iam' or 'iam.domain'."""

    name: str
    """Human-readable display name, e.g. 'IAM' or 'Domain'."""

    type: NodeType
    """Level of the node: 'bounded_context' or 'module'."""

    position: Position
    """Pre-computed 3D position. Coordinates are relative to the parent node."""

    size: float
    """Visual size derived from the node's complexity metric."""

    parent: str | None
    """ID of the containing node, or null for top-level nodes."""


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
