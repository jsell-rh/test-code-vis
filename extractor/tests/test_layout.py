"""Tests for the standalone scene graph layout algorithm.

Covers the Pre-Computed Layout requirement from
specs/extraction/scene-graph-schema.spec.md:

  - THEN each node's position field contains x, y, z coordinates
  - AND tightly coupled nodes have smaller distances between them
  - AND child nodes are positioned within the spatial bounds of their parent
"""

from __future__ import annotations

import pytest

from extractor.layout import _distance_2d, compute_layout
from extractor.schema import Edge, Node, Position


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def make_bc_node(nid: str, size: float = 5.0) -> Node:
    return {
        "id": nid,
        "name": nid.upper(),
        "type": "bounded_context",
        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
        "size": size,
        "parent": None,
    }


def make_module_node(nid: str, parent: str, size: float = 1.0) -> Node:
    return {
        "id": nid,
        "name": nid,
        "type": "module",
        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
        "size": size,
        "parent": parent,
    }


def make_edge(src: str, tgt: str, kind: str = "cross_context") -> Edge:
    return {"source": src, "target": tgt, "type": kind}


def dist(positions: dict[str, Position], a: str, b: str) -> float:
    return _distance_2d(positions[a], positions[b])


# ---------------------------------------------------------------------------
# THEN: each node's position field contains x, y, z coordinates
# ---------------------------------------------------------------------------


class TestAllPositionsHaveXYZ:
    """Every node produced by compute_layout must have x, y, z in its Position."""

    def test_all_positions_have_xyz(self) -> None:
        """All positions contain x, y, z keys."""
        nodes: list[Node] = [make_bc_node("a"), make_bc_node("b")]
        positions = compute_layout(nodes, [])
        for nid, pos in positions.items():
            assert "x" in pos, f"'{nid}' position missing 'x'."
            assert "y" in pos, f"'{nid}' position missing 'y'."
            assert "z" in pos, f"'{nid}' position missing 'z'."

    def test_positions_are_floats(self) -> None:
        nodes: list[Node] = [make_bc_node("c")]
        positions = compute_layout(nodes, [])
        pos = positions["c"]
        assert isinstance(pos["x"], float)
        assert isinstance(pos["y"], float)
        assert isinstance(pos["z"], float)

    def test_every_node_id_in_output(self) -> None:
        nodes: list[Node] = [
            make_bc_node("iam"),
            make_bc_node("graph"),
            make_module_node("iam.domain", parent="iam"),
        ]
        positions = compute_layout(nodes, [])
        for node in nodes:
            assert node["id"] in positions, (
                f"'{node['id']}' missing from layout output."
            )

    def test_empty_graph_returns_empty_dict(self) -> None:
        positions = compute_layout([], [])
        assert positions == {}

    def test_single_node_placed_at_deterministic_position(self) -> None:
        positions = compute_layout([make_bc_node("solo")], [])
        pos = positions["solo"]
        # With one node, angle=0 => cos(0)=1, sin(0)=0 => x=10.0, z=0.0
        assert abs(pos["x"] - 10.0) < 0.01
        assert abs(pos["z"] - 0.0) < 0.01


# ---------------------------------------------------------------------------
# AND: tightly coupled nodes have smaller distances between them
# (algorithm-quality: varies coupling, asserts distance changes)
# ---------------------------------------------------------------------------


class TestTightlyCoupledNodesAreCloser:
    """Coupled nodes must end up closer than uncoupled nodes.

    Each test VARIES the coupling in its fixture and asserts that the OUTPUT
    distance changes correspondingly.  These tests would FAIL if the layout
    algorithm ignored edges entirely.
    """

    def test_tightly_coupled_nodes_are_closer(self) -> None:
        """Coupled pair (5 edges) is closer than the same pair with no edges."""
        nodes_ab = [make_bc_node("a"), make_bc_node("b")]

        many_edges: list[Edge] = [make_edge("a", "b") for _ in range(5)]
        pos_coupled = compute_layout(nodes_ab, many_edges)
        pos_uncoupled = compute_layout(nodes_ab, [])

        d_coupled = dist(pos_coupled, "a", "b")
        d_uncoupled = dist(pos_uncoupled, "a", "b")

        assert d_coupled < d_uncoupled, (
            f"Coupled nodes (dist={d_coupled:.4f}) must be closer than "
            f"uncoupled nodes (dist={d_uncoupled:.4f})."
        )

    def test_more_edges_means_closer(self) -> None:
        """Connected pair (a-b) ends up closer than isolated pair (a-c)."""
        nodes = [make_bc_node("a"), make_bc_node("b"), make_bc_node("c")]
        edges = [make_edge("a", "b") for _ in range(3)]

        positions = compute_layout(nodes, edges)

        d_ab = dist(positions, "a", "b")
        d_ac = dist(positions, "a", "c")

        assert d_ab < d_ac, (
            f"Connected pair (a-b, dist={d_ab:.4f}) must be closer than "
            f"unconnected pair (a-c, dist={d_ac:.4f})."
        )

    def test_unconnected_third_node_stays_far(self) -> None:
        """Isolated node stays farther from the coupled pair than they are from each other."""
        nodes = [make_bc_node("core"), make_bc_node("dep"), make_bc_node("isolated")]
        edges = [make_edge("core", "dep") for _ in range(5)]

        positions = compute_layout(nodes, edges)

        d_coupled = dist(positions, "core", "dep")
        d_isolated = dist(positions, "core", "isolated")

        assert d_coupled < d_isolated, (
            f"Coupled pair (core-dep, dist={d_coupled:.4f}) should be closer "
            f"than core-isolated ({d_isolated:.4f})."
        )


# ---------------------------------------------------------------------------
# AND: child nodes are positioned within the spatial bounds of their parent
# (algorithm-quality: varies parent_size, asserts child orbit scales)
# ---------------------------------------------------------------------------


class TestChildNodesWithinParentBounds:
    """Child nodes must be placed within parent_size distance of their parent."""

    def test_child_nodes_within_parent_spatial_bounds(self) -> None:
        """A module node is within parent_size distance of its parent context."""
        parent_size = 5.0
        nodes: list[Node] = [
            make_bc_node("iam", size=parent_size),
            make_module_node("iam.domain", parent="iam"),
        ]
        positions = compute_layout(nodes, [])

        d = dist(positions, "iam", "iam.domain")
        assert d <= parent_size, (
            f"Child 'iam.domain' is {d:.4f} units from parent 'iam'; "
            f"must be <= parent_size ({parent_size})."
        )

    def test_multiple_children_all_within_parent_bounds(self) -> None:
        """All children of a context are within the context's size bound."""
        parent_size = 6.0
        nodes: list[Node] = [
            make_bc_node("graph", size=parent_size),
            make_module_node("graph.domain", parent="graph"),
            make_module_node("graph.application", parent="graph"),
            make_module_node("graph.infrastructure", parent="graph"),
        ]
        positions = compute_layout(nodes, [])

        for cid in ["graph.domain", "graph.application", "graph.infrastructure"]:
            d = dist(positions, "graph", cid)
            assert d <= parent_size, (
                f"Child '{cid}' is {d:.4f} units from parent; "
                f"must be <= parent_size ({parent_size})."
            )

    def test_larger_parent_allows_larger_child_orbit(self) -> None:
        """Larger parent_size => child placed further from parent centre."""
        small: list[Node] = [
            make_bc_node("s", size=2.0),
            make_module_node("s.m", parent="s"),
        ]
        large: list[Node] = [
            make_bc_node("l", size=10.0),
            make_module_node("l.m", parent="l"),
        ]

        pos_small = compute_layout(small, [])
        pos_large = compute_layout(large, [])

        d_small = dist(pos_small, "s", "s.m")
        d_large = dist(pos_large, "l", "l.m")

        assert d_small < d_large, (
            f"Larger parent should give wider child orbit: "
            f"small={d_small:.4f}, large={d_large:.4f}."
        )


# ---------------------------------------------------------------------------
# Utility: _distance_2d helper
# ---------------------------------------------------------------------------


class TestDistanceHelper:
    def test_distance_2d_zero_for_identical_points(self) -> None:
        p: Position = {"x": 3.0, "y": 0.0, "z": 4.0}
        assert _distance_2d(p, p) == pytest.approx(0.0)

    def test_distance_2d_ignores_y(self) -> None:
        a: Position = {"x": 0.0, "y": 100.0, "z": 0.0}
        b: Position = {"x": 3.0, "y": 0.0, "z": 4.0}
        # XZ distance = sqrt(9+16) = 5; y is ignored
        assert _distance_2d(a, b) == pytest.approx(5.0)
