"""Standalone layout algorithm for the scene graph.

Implements the Pre-Computed Layout requirement from
specs/extraction/scene-graph-schema.spec.md:

  Node positions MUST be computed by the Python extractor, not by the Godot
  application.  The extractor is responsible for running a layout algorithm
  that positions nodes so that coupled nodes are closer together.

Key guarantees:
- Nodes connected by more edges end up closer together (spring-force attraction).
- Child nodes (modules) are placed within the spatial bounds of their parent
  bounded context (within parent_size radius of the parent centre).
- Positions are returned as a dict[str, Position] ready to be written to JSON.
"""

from __future__ import annotations

import math

from extractor.schema import Edge, Node, Position


def _distance_2d(a: Position, b: Position) -> float:
    """Euclidean distance in the XZ plane (y is ignored in the flat layout)."""
    return math.sqrt((a["x"] - b["x"]) ** 2 + (a["z"] - b["z"]) ** 2)


def compute_layout(nodes: list[Node], edges: list[Edge]) -> dict[str, Position]:
    """Compute pre-computed 2D positions (y=0) for all nodes.

    Algorithm:
    1. Top-level (parent=None) nodes are initialised on a circle of radius 10.
    2. For each edge an attraction force pulls the two endpoints together.
       More edges between a pair => stronger pull => smaller final distance.
    3. Child nodes are then placed at 30% of *parent_size* from their parent
       centre, ensuring they are well within the parent's spatial bound.

    Returns a mapping of node id => Position (all y=0, x/z rounded to 4 dp).
    Tightly coupled nodes will have smaller inter-node distances than uncoupled
    nodes, satisfying the spec's ordering guarantee.
    """
    top_level = [n for n in nodes if n["parent"] is None]
    children = [n for n in nodes if n["parent"] is not None]

    n_top = len(top_level)
    # pos stores [x, z] for each node id
    pos: dict[str, list[float]] = {}

    # 1. Place top-level nodes on a circle
    for i, node in enumerate(top_level):
        angle = 2.0 * math.pi * i / max(n_top, 1)
        pos[node["id"]] = [math.cos(angle) * 10.0, math.sin(angle) * 10.0]

    # 2. Spring-force edge attraction (100 iterations)
    for _ in range(100):
        for edge in edges:
            src = edge["source"]
            tgt = edge["target"]
            if src not in pos or tgt not in pos:
                continue
            dx = pos[tgt][0] - pos[src][0]
            dz = pos[tgt][1] - pos[src][1]
            # Each edge pulls endpoints toward each other by 5%
            pos[src][0] += dx * 0.05
            pos[src][1] += dz * 0.05
            pos[tgt][0] -= dx * 0.05
            pos[tgt][1] -= dz * 0.05

    # 3. Place child nodes within parent spatial bounds
    parent_to_children: dict[str, list[Node]] = {}
    for child in children:
        pid = child["parent"]
        if pid is not None:
            parent_to_children.setdefault(pid, []).append(child)

    for parent_id, child_nodes in parent_to_children.items():
        if parent_id not in pos:
            pos[parent_id] = [0.0, 0.0]

        parent_pos = pos[parent_id]
        parent_size = next(
            (n["size"] for n in nodes if n["id"] == parent_id),
            5.0,
        )
        # 30% of parent_size keeps children clearly inside the parent bound
        offset_r = parent_size * 0.3
        n_children = len(child_nodes)
        for j, child in enumerate(child_nodes):
            angle = 2.0 * math.pi * j / max(n_children, 1)
            pos[child["id"]] = [
                parent_pos[0] + math.cos(angle) * offset_r,
                parent_pos[1] + math.sin(angle) * offset_r,
            ]

    return {
        nid: {"x": round(coords[0], 4), "y": 0.0, "z": round(coords[1], 4)}
        for nid, coords in pos.items()
    }
