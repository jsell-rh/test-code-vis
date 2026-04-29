"""Tests for the scene graph schema definitions.

Validates that the schema TypedDicts match the requirements described in
specs/extraction/scene-graph-schema.spec.md.
"""

from __future__ import annotations

import json

from extractor.schema import (
    AggregateMetrics,
    Cluster,
    Edge,
    Metadata,
    Node,
    Position,
    SceneGraph,
    validate_scene_graph,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def make_position(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Position:
    return {"x": x, "y": y, "z": z}


def make_bounded_context_node() -> Node:
    """Return a minimal valid bounded-context node (spec: § Bounded context node)."""
    return {
        "id": "iam",
        "name": "IAM",
        "type": "bounded_context",
        "position": make_position(0.0, 0.0, 0.0),
        "size": 5.0,
        "parent": None,
    }


def make_module_node() -> Node:
    """Return a minimal valid module node (spec: § Module node inside a bounded context)."""
    return {
        "id": "iam.domain",
        "name": "Domain",
        "type": "module",
        "position": make_position(1.0, 0.0, 1.0),
        "size": 2.0,
        "parent": "iam",
    }


def make_cross_context_edge() -> Edge:
    return {"source": "graph", "target": "shared_kernel", "type": "cross_context"}


def make_internal_edge() -> Edge:
    return {"source": "iam.application", "target": "iam.domain", "type": "internal"}


def make_metadata() -> Metadata:
    return {
        "source_path": "/home/user/code/kartograph",
        "timestamp": "2026-04-22T00:00:00Z",
    }


def make_aggregate_metrics() -> AggregateMetrics:
    return {"total_loc": 100, "in_degree": 2, "out_degree": 1}


def make_cluster() -> Cluster:
    return {
        "id": "iam:cluster_0",
        "members": ["iam.application", "iam.domain"],
        "context": "iam",
        "aggregate_metrics": make_aggregate_metrics(),
    }


def make_scene_graph() -> SceneGraph:
    return {
        "nodes": [make_bounded_context_node(), make_module_node()],
        "edges": [make_cross_context_edge(), make_internal_edge()],
        "metadata": make_metadata(),
        "clusters": [],
    }


# ---------------------------------------------------------------------------
# Requirement: Schema Structure
# ---------------------------------------------------------------------------


class TestSchemaStructure:
    """The JSON scene graph MUST contain nodes, edges, metadata, and clusters."""

    def test_scene_graph_has_nodes_key(self) -> None:
        graph = make_scene_graph()
        assert "nodes" in graph

    def test_scene_graph_has_edges_key(self) -> None:
        graph = make_scene_graph()
        assert "edges" in graph

    def test_scene_graph_has_metadata_key(self) -> None:
        graph = make_scene_graph()
        assert "metadata" in graph

    def test_scene_graph_has_clusters_key(self) -> None:
        graph = make_scene_graph()
        assert "clusters" in graph

    def test_scene_graph_has_no_extra_top_level_fields(self) -> None:
        graph = make_scene_graph()
        assert set(graph.keys()) == {"nodes", "edges", "metadata", "clusters"}

    def test_scene_graph_is_json_serialisable(self) -> None:
        graph = make_scene_graph()
        serialised = json.dumps(graph)
        restored = json.loads(serialised)
        assert restored["nodes"] == graph["nodes"]
        assert restored["edges"] == graph["edges"]
        assert restored["metadata"] == graph["metadata"]
        assert restored["clusters"] == graph["clusters"]

    def test_nodes_is_a_list(self) -> None:
        graph = make_scene_graph()
        assert isinstance(graph["nodes"], list)

    def test_edges_is_a_list(self) -> None:
        graph = make_scene_graph()
        assert isinstance(graph["edges"], list)

    def test_metadata_is_a_dict(self) -> None:
        graph = make_scene_graph()
        assert isinstance(graph["metadata"], dict)

    def test_clusters_is_a_list(self) -> None:
        graph = make_scene_graph()
        assert isinstance(graph["clusters"], list)


# ---------------------------------------------------------------------------
# Requirement: Node Schema
# ---------------------------------------------------------------------------


class TestNodeSchema:
    """Each node MUST contain id, name, type, position, size, and optional parent."""

    def test_bounded_context_node_has_required_keys(self) -> None:
        node = make_bounded_context_node()
        for key in ("id", "name", "type", "position", "size", "parent"):
            assert key in node, f"Missing key: {key}"

    def test_bounded_context_node_id(self) -> None:
        node = make_bounded_context_node()
        assert node["id"] == "iam"

    def test_bounded_context_node_name(self) -> None:
        node = make_bounded_context_node()
        assert node["name"] == "IAM"

    def test_bounded_context_node_type(self) -> None:
        node = make_bounded_context_node()
        assert node["type"] == "bounded_context"

    def test_bounded_context_node_position_has_xyz(self) -> None:
        node = make_bounded_context_node()
        pos = node["position"]
        assert "x" in pos
        assert "y" in pos
        assert "z" in pos

    def test_bounded_context_node_position_values_are_numeric(self) -> None:
        node = make_bounded_context_node()
        pos = node["position"]
        assert isinstance(pos["x"], (int, float))
        assert isinstance(pos["y"], (int, float))
        assert isinstance(pos["z"], (int, float))

    def test_bounded_context_node_size_is_numeric(self) -> None:
        node = make_bounded_context_node()
        assert isinstance(node["size"], (int, float))

    def test_bounded_context_node_parent_is_null(self) -> None:
        node = make_bounded_context_node()
        assert node["parent"] is None

    def test_module_node_has_required_keys(self) -> None:
        node = make_module_node()
        for key in ("id", "name", "type", "position", "size", "parent"):
            assert key in node, f"Missing key: {key}"

    def test_module_node_id_dotted(self) -> None:
        node = make_module_node()
        assert node["id"] == "iam.domain"

    def test_module_node_type_is_module(self) -> None:
        node = make_module_node()
        assert node["type"] == "module"

    def test_module_node_parent_references_context(self) -> None:
        node = make_module_node()
        assert node["parent"] == "iam"

    def test_node_ids_are_unique(self) -> None:
        graph = make_scene_graph()
        ids = [n["id"] for n in graph["nodes"]]
        assert len(ids) == len(set(ids))


# ---------------------------------------------------------------------------
# Requirement: Edge Schema
# ---------------------------------------------------------------------------


class TestEdgeSchema:
    """Each edge MUST contain source, target, and type."""

    def test_cross_context_edge_has_required_keys(self) -> None:
        edge = make_cross_context_edge()
        for key in ("source", "target", "type"):
            assert key in edge, f"Missing key: {key}"

    def test_cross_context_edge_source(self) -> None:
        edge = make_cross_context_edge()
        assert edge["source"] == "graph"

    def test_cross_context_edge_target(self) -> None:
        edge = make_cross_context_edge()
        assert edge["target"] == "shared_kernel"

    def test_cross_context_edge_type(self) -> None:
        edge = make_cross_context_edge()
        assert edge["type"] == "cross_context"

    def test_internal_edge_has_required_keys(self) -> None:
        edge = make_internal_edge()
        for key in ("source", "target", "type"):
            assert key in edge, f"Missing key: {key}"

    def test_internal_edge_source(self) -> None:
        edge = make_internal_edge()
        assert edge["source"] == "iam.application"

    def test_internal_edge_target(self) -> None:
        edge = make_internal_edge()
        assert edge["target"] == "iam.domain"

    def test_internal_edge_type(self) -> None:
        edge = make_internal_edge()
        assert edge["type"] == "internal"


# ---------------------------------------------------------------------------
# Requirement: Metadata
# ---------------------------------------------------------------------------


class TestMetadataSchema:
    """The metadata object MUST contain source_path and timestamp."""

    def test_metadata_has_source_path(self) -> None:
        meta = make_metadata()
        assert "source_path" in meta

    def test_metadata_has_timestamp(self) -> None:
        meta = make_metadata()
        assert "timestamp" in meta

    def test_metadata_source_path_is_str(self) -> None:
        meta = make_metadata()
        assert isinstance(meta["source_path"], str)

    def test_metadata_timestamp_is_str(self) -> None:
        meta = make_metadata()
        assert isinstance(meta["timestamp"], str)


# ---------------------------------------------------------------------------
# Requirement: Pre-Computed Layout
# ---------------------------------------------------------------------------


class TestPreComputedLayout:
    """Node positions MUST be pre-computed by the extractor."""

    def test_every_node_has_a_position(self) -> None:
        graph = make_scene_graph()
        for node in graph["nodes"]:
            pos = node["position"]
            assert "x" in pos and "y" in pos and "z" in pos

    def test_positions_are_floats(self) -> None:
        graph = make_scene_graph()
        for node in graph["nodes"]:
            pos = node["position"]
            for coord in (pos["x"], pos["y"], pos["z"]):
                assert isinstance(coord, (int, float))

    def test_scene_graph_nodes_have_distinct_positions(self) -> None:
        """Tightly coupled nodes should be close; different nodes should not
        all share the exact same position (layout must have been applied)."""
        graph = make_scene_graph()
        if len(graph["nodes"]) < 2:
            return  # nothing to compare
        positions = [
            (n["position"]["x"], n["position"]["y"], n["position"]["z"])
            for n in graph["nodes"]
        ]
        # At least one pair of nodes must differ in position.
        assert len(set(positions)) > 1 or len(positions) == 1


# ---------------------------------------------------------------------------
# Requirement: Cluster Schema
# ---------------------------------------------------------------------------


class TestClusterSchema:
    """The clusters array MUST contain pre-computed coupling group suggestions."""

    def test_cluster_has_required_keys(self) -> None:
        cluster = make_cluster()
        for key in ("id", "members", "context", "aggregate_metrics"):
            assert key in cluster, f"Cluster missing key: {key}"

    def test_cluster_id_format(self) -> None:
        cluster = make_cluster()
        assert cluster["id"] == "iam:cluster_0"

    def test_cluster_members_is_list(self) -> None:
        cluster = make_cluster()
        assert isinstance(cluster["members"], list)

    def test_cluster_members_contain_node_ids(self) -> None:
        cluster = make_cluster()
        assert "iam.application" in cluster["members"]
        assert "iam.domain" in cluster["members"]

    def test_cluster_context_is_parent_bc_id(self) -> None:
        cluster = make_cluster()
        assert cluster["context"] == "iam"

    def test_aggregate_metrics_has_required_keys(self) -> None:
        am = make_aggregate_metrics()
        for key in ("total_loc", "in_degree", "out_degree"):
            assert key in am, f"AggregateMetrics missing key: {key}"

    def test_aggregate_metrics_values_are_ints(self) -> None:
        am = make_aggregate_metrics()
        assert isinstance(am["total_loc"], int)
        assert isinstance(am["in_degree"], int)
        assert isinstance(am["out_degree"], int)

    def test_empty_clusters_is_valid(self) -> None:
        graph = make_scene_graph()
        assert graph["clusters"] == []

    def test_cluster_with_members_in_scene_graph(self) -> None:
        graph = make_scene_graph()
        graph["clusters"] = [make_cluster()]
        assert len(graph["clusters"]) == 1
        assert graph["clusters"][0]["context"] == "iam"

    def test_cluster_is_json_serialisable(self) -> None:
        cluster = make_cluster()
        serialised = json.dumps(cluster)
        restored = json.loads(serialised)
        assert restored["id"] == cluster["id"]
        assert restored["members"] == cluster["members"]


# ---------------------------------------------------------------------------
# Requirement: Independence Group on Node
# ---------------------------------------------------------------------------


class TestIndependenceGroup:
    """Module nodes MAY carry an independence_group identifier."""

    def test_module_node_can_have_independence_group(self) -> None:
        node = make_module_node()
        node["independence_group"] = "iam:0"  # type: ignore[typeddict-unknown-key]
        assert node["independence_group"] == "iam:0"

    def test_independence_group_format(self) -> None:
        # Format must be "<context_id>:<group_index>"
        node = make_module_node()
        node["independence_group"] = "iam:1"  # type: ignore[typeddict-unknown-key]
        context_id, group_index = node["independence_group"].split(":")
        assert context_id == "iam"
        assert group_index.isdigit()

    def test_bounded_context_has_no_independence_group(self) -> None:
        node = make_bounded_context_node()
        assert "independence_group" not in node


# ---------------------------------------------------------------------------
# Requirement: Cascade Depth
# ---------------------------------------------------------------------------


class TestCascadeDepth:
    """Affected nodes in simulation output carry a depth value."""

    def test_node_can_have_depth(self) -> None:
        node = make_module_node()
        node["depth"] = 1  # type: ignore[typeddict-unknown-key]
        assert node["depth"] == 1

    def test_depth_is_integer(self) -> None:
        node = make_module_node()
        node["depth"] = 2  # type: ignore[typeddict-unknown-key]
        assert isinstance(node["depth"], int)

    def test_direct_dependency_has_depth_1(self) -> None:
        node = make_module_node()
        node["depth"] = 1  # type: ignore[typeddict-unknown-key]
        assert node["depth"] == 1

    def test_transitive_dependency_has_depth_2(self) -> None:
        node = make_bounded_context_node()
        node["depth"] = 2  # type: ignore[typeddict-unknown-key]
        assert node["depth"] == 2


# ---------------------------------------------------------------------------
# Requirement: Weighted Edge
# ---------------------------------------------------------------------------


class TestWeightedEdge:
    """Edges MAY carry a weight indicating the number of individual imports."""

    def test_edge_can_have_weight(self) -> None:
        edge = make_cross_context_edge()
        edge["weight"] = 12  # type: ignore[typeddict-unknown-key]
        assert edge["weight"] == 12

    def test_aggregate_edge_type(self) -> None:
        edge: Edge = {
            "source": "A",
            "target": "B",
            "type": "aggregate",
            "weight": 12,
        }
        assert edge["type"] == "aggregate"
        assert edge["weight"] == 12

    def test_individual_edge_weight_defaults_to_1(self) -> None:
        edge = make_internal_edge()
        # weight is optional — absence implies 1
        assert edge.get("weight", 1) == 1


# ---------------------------------------------------------------------------
# Requirement: validate_scene_graph
# ---------------------------------------------------------------------------


class TestValidateSceneGraph:
    """validate_scene_graph raises ValueError on malformed graphs."""

    def test_valid_graph_passes(self) -> None:
        graph = make_scene_graph()
        validate_scene_graph(graph)  # must not raise

    def test_missing_nodes_raises(self) -> None:
        graph = {"edges": [], "metadata": make_metadata(), "clusters": []}
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError"
        except ValueError as e:
            assert "nodes" in str(e)

    def test_missing_clusters_raises(self) -> None:
        graph = {
            "nodes": [],
            "edges": [],
            "metadata": make_metadata(),
        }
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError"
        except ValueError as e:
            assert "clusters" in str(e)

    def test_extra_top_level_key_raises(self) -> None:
        graph = make_scene_graph()
        graph["extra"] = "bad"  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError"
        except ValueError as e:
            assert "extra" in str(e)

    def test_non_dict_raises(self) -> None:
        try:
            validate_scene_graph([])
            assert False, "Expected ValueError"
        except ValueError as e:
            assert "dict" in str(e)

    def test_node_missing_required_key_raises(self) -> None:
        graph = make_scene_graph()
        del graph["nodes"][0]["id"]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError"
        except ValueError as e:
            assert "id" in str(e)

    def test_cluster_missing_required_key_raises(self) -> None:
        graph = make_scene_graph()
        graph["clusters"] = [{"id": "x:cluster_0", "members": [], "context": "x"}]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError"
        except ValueError as e:
            assert "aggregate_metrics" in str(e)
