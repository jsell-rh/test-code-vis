"""Tests for the scene graph schema definitions.

Validates that the schema TypedDicts match the requirements described in
specs/extraction/scene-graph-schema.spec.md.
"""

from __future__ import annotations

import json

from extractor.schema import (
    AggregateMetrics,
    BeaconInfo,
    Cluster,
    Edge,
    InvariantInfo,
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


def make_aggregate_edge() -> Edge:
    return {
        "source": "graph",
        "target": "shared_kernel",
        "type": "aggregate",
        "weight": 12,
    }


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

    def test_module_node_with_independence_group(self) -> None:
        """Module nodes MAY carry an independence_group field."""
        node = make_module_node()
        node["independence_group"] = "iam:0"
        assert node["independence_group"] == "iam:0"

    def test_independence_group_format(self) -> None:
        """independence_group follows the '<bc>:<N>' format."""
        node = make_module_node()
        node["independence_group"] = "iam:1"
        bc_part, idx_part = node["independence_group"].rsplit(":", 1)
        assert bc_part == "iam"
        assert idx_part.isdigit()


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

    def test_aggregate_edge_type(self) -> None:
        """Aggregate edge MUST have type='aggregate'."""
        edge = make_aggregate_edge()
        assert edge["type"] == "aggregate"

    def test_aggregate_edge_has_weight(self) -> None:
        """Aggregate edge MUST carry a weight field."""
        edge = make_aggregate_edge()
        assert "weight" in edge
        assert edge["weight"] == 12

    def test_aggregate_edge_weight_is_int(self) -> None:
        edge = make_aggregate_edge()
        assert isinstance(edge["weight"], int)


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


# ---------------------------------------------------------------------------
# Requirement: validate_scene_graph — optional depth field (Cascade Depth)
# ---------------------------------------------------------------------------


class TestValidateSceneGraphDepth:
    """validate_scene_graph correctly validates the optional node depth field.

    Per the schema contract (task-072):
    - depth is absent in static scene graph output: validator must not require it.
    - depth present with integer value >= 1: validator must accept it.
    - depth present but not an integer or < 1: validator must raise ValueError.
    """

    def test_node_without_depth_passes_validation(self) -> None:
        """Static graph nodes carry no depth — absence is valid."""
        graph = make_scene_graph()
        validate_scene_graph(graph)  # must not raise

    def test_node_with_depth_1_passes_validation(self) -> None:
        """A direct dependent node (depth=1) is a valid simulation output."""
        graph = make_scene_graph()
        graph["nodes"][0]["depth"] = 1  # type: ignore[typeddict-unknown-key]
        validate_scene_graph(graph)  # must not raise

    def test_node_with_depth_2_passes_validation(self) -> None:
        """A second-order dependent node (depth=2) is a valid simulation output."""
        graph = make_scene_graph()
        graph["nodes"][0]["depth"] = 2  # type: ignore[typeddict-unknown-key]
        validate_scene_graph(graph)  # must not raise

    def test_depth_zero_raises(self) -> None:
        """depth=0 violates the minimum-value-1 constraint."""
        graph = make_scene_graph()
        graph["nodes"][0]["depth"] = 0  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for depth=0"
        except ValueError as e:
            assert "depth" in str(e)

    def test_depth_negative_raises(self) -> None:
        """Negative depth is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["depth"] = -1  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for depth=-1"
        except ValueError as e:
            assert "depth" in str(e)

    def test_depth_string_raises(self) -> None:
        """String depth value is not an integer and must be rejected."""
        graph = make_scene_graph()
        graph["nodes"][0]["depth"] = "one"  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for depth='one'"
        except ValueError as e:
            assert "depth" in str(e)

    def test_depth_float_raises(self) -> None:
        """Float depth value is not an integer and must be rejected."""
        graph = make_scene_graph()
        graph["nodes"][0]["depth"] = 1.5  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for depth=1.5"
        except ValueError as e:
            assert "depth" in str(e)

    def test_depth_bool_raises(self) -> None:
        """bool is a subtype of int in Python but must be rejected as depth.

        True == 1 would pass integer and range checks, but a boolean is not
        a meaningful cascade depth value.
        """
        graph = make_scene_graph()
        graph["nodes"][0]["depth"] = True  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for depth=True"
        except ValueError as e:
            assert "depth" in str(e)

    def test_multiple_nodes_mixed_depth_valid(self) -> None:
        """Some nodes may carry depth (affected) while others do not (unaffected)."""
        graph = make_scene_graph()
        # First node: affected (depth=1), second node: not affected (no depth)
        graph["nodes"][0]["depth"] = 1  # type: ignore[typeddict-unknown-key]
        validate_scene_graph(graph)  # must not raise


# ---------------------------------------------------------------------------
# Spec Scenario: Cluster does not prescribe collapsed position
# spec: scene-graph-schema.spec.md § Cluster Schema
# THEN the cluster entry does not prescribe the collapsed position —
# Godot computes the supernode position as the centroid of member positions.
# ---------------------------------------------------------------------------


class TestClusterNoPosition:
    """Cluster entries produced by the schema MUST NOT carry a position field.

    The Godot application computes the supernode position as the centroid of
    member positions at render time — the cluster entry is a grouping hint only.
    Spec: scene-graph-schema.spec.md § Cluster Schema.
    """

    def test_cluster_typeddict_has_no_position_key(self) -> None:
        """The Cluster TypedDict does not define a position field."""
        from extractor.schema import Cluster

        annotations = Cluster.__annotations__
        assert "position" not in annotations, (
            "Cluster TypedDict must not define a 'position' key — "
            "the Godot app computes supernode position as member centroid."
        )

    def test_cluster_instance_has_no_position_field(self) -> None:
        """A constructed cluster dict must not carry a position key."""
        cluster = make_cluster()
        assert "position" not in cluster, (
            "Cluster dict must not carry 'position' — Godot computes centroid."
        )


# ---------------------------------------------------------------------------
# Spec Scenario: Aggregate edge weight is the total import count
# spec: scene-graph-schema.spec.md § Edge Schema / Weighted edge
# THEN ... the extractor also emits an aggregate edge with weight: N
# where N is the total number of individual import statements.
# ---------------------------------------------------------------------------


class TestAggregateEdgeWeight:
    """Aggregate edge weight represents the number of individual import statements.

    The schema requires weight to be a non-negative integer.  A weight of 0 is
    logically invalid (an aggregate edge with no imports would not be emitted).
    Spec: scene-graph-schema.spec.md § Edge Schema.
    """

    def test_aggregate_edge_weight_is_positive_int(self) -> None:
        """Aggregate edge weight must be a positive integer (>= 1)."""
        edge = make_aggregate_edge()
        assert isinstance(edge["weight"], int), (
            f"aggregate edge weight must be int; got {type(edge['weight'])}"
        )
        assert edge["weight"] >= 1, (
            f"aggregate edge weight must be >= 1; got {edge['weight']}"
        )

    def test_aggregate_edge_type_literal(self) -> None:
        """The type field of an aggregate edge must be exactly 'aggregate'."""
        edge = make_aggregate_edge()
        assert edge["type"] == "aggregate"

    def test_aggregate_edge_source_and_target_are_bc_ids(self) -> None:
        """Aggregate edge source and target reference bounded-context IDs.

        Spec: 'the extractor also emits an aggregate edge with source: "A",
        target: "B"' — both are bounded-context level IDs (no dots).
        """
        edge = make_aggregate_edge()
        # In the fixture: source="graph", target="shared_kernel" (no dots = BC-level IDs)
        assert "." not in edge["source"], (
            f"aggregate edge source should be a bounded-context ID (no dots); "
            f"got '{edge['source']}'"
        )
        assert "." not in edge["target"], (
            f"aggregate edge target should be a bounded-context ID (no dots); "
            f"got '{edge['target']}'"
        )


# ---------------------------------------------------------------------------
# Spec Scenario: Schema Structure — validate_scene_graph called at write time
# spec: scene-graph-schema.spec.md § Schema Structure
# The validator ensures the interface contract is honoured at the boundary.
# ---------------------------------------------------------------------------


class TestValidateSceneGraphContract:
    """validate_scene_graph enforces the interface contract at the output boundary.

    The function is the runtime guard that ensures the JSON written by the
    extractor is always schema-conformant before it reaches the Godot app.
    """

    def test_validator_accepts_minimal_valid_graph(self) -> None:
        """A minimal scene graph (one BC node, no edges, no clusters) is valid."""
        graph: dict = {
            "nodes": [make_bounded_context_node()],
            "edges": [],
            "metadata": make_metadata(),
            "clusters": [],
        }
        validate_scene_graph(graph)  # must not raise

    def test_validator_rejects_missing_edges_key(self) -> None:
        """A graph missing the 'edges' key fails validation."""
        graph: dict = {
            "nodes": [make_bounded_context_node()],
            "metadata": make_metadata(),
            "clusters": [],
        }
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for missing 'edges'"
        except ValueError as exc:
            assert "edges" in str(exc)

    def test_validator_rejects_node_missing_position(self) -> None:
        """A node without a 'position' field fails validation."""
        node = make_bounded_context_node()
        del node["position"]
        graph: dict = {
            "nodes": [node],
            "edges": [],
            "metadata": make_metadata(),
            "clusters": [],
        }
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for missing 'position'"
        except ValueError as exc:
            assert "position" in str(exc)

    def test_validator_rejects_position_without_z(self) -> None:
        """A position missing the 'z' coordinate fails validation."""
        node = make_bounded_context_node()
        node["position"] = {"x": 1.0, "y": 0.0}  # type: ignore[typeddict-item]
        graph: dict = {
            "nodes": [node],
            "edges": [],
            "metadata": make_metadata(),
            "clusters": [],
        }
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for position missing 'z'"
        except ValueError as exc:
            assert "z" in str(exc)

    def test_validator_rejects_non_numeric_position_coordinate(self) -> None:
        """A position with a non-numeric coordinate fails validation."""
        node = make_bounded_context_node()
        node["position"] = {"x": "one", "y": 0.0, "z": 0.0}  # type: ignore[typeddict-item]
        graph: dict = {
            "nodes": [node],
            "edges": [],
            "metadata": make_metadata(),
            "clusters": [],
        }
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for non-numeric x coordinate"
        except ValueError as exc:
            assert "x" in str(exc)

    def test_validator_accepts_graph_with_clusters(self) -> None:
        """A valid graph with cluster entries passes validation."""
        graph = make_scene_graph()
        graph["clusters"] = [make_cluster()]
        validate_scene_graph(graph)  # must not raise

    def test_validator_rejects_cluster_missing_aggregate_metrics(self) -> None:
        """A cluster without aggregate_metrics fails validation."""
        cluster: dict = {
            "id": "x:cluster_0",
            "members": ["x.a", "x.b"],
            "context": "x",
            # aggregate_metrics intentionally absent
        }
        graph: dict = {
            "nodes": [],
            "edges": [],
            "metadata": make_metadata(),
            "clusters": [cluster],
        }
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for missing aggregate_metrics"
        except ValueError as exc:
            assert "aggregate_metrics" in str(exc)


# ---------------------------------------------------------------------------
# Requirement: Annotation Fields — purpose_annotation, beacons, invariants
# Spec: visual-primitives.spec.md § Requirement: Purpose-Level Annotation
# Task: task-095
# ---------------------------------------------------------------------------


class TestPurposeAnnotationField:
    """purpose_annotation MAY appear on module and bounded_context nodes.

    Spec requirement: The system MUST support attaching purpose-level annotations
    to structural elements.
    - absent: annotation not computed — validator MUST NOT error.
    - string: human-readable purpose sentence.
    - null: annotation key present but intentionally blank.
    """

    def test_bounded_context_node_without_purpose_annotation_is_valid(self) -> None:
        """Absence of purpose_annotation is valid — annotation not computed."""
        graph = make_scene_graph()
        validate_scene_graph(graph)  # must not raise

    def test_bounded_context_node_with_purpose_annotation_string_is_valid(self) -> None:
        """purpose_annotation may be a non-empty string."""
        graph = make_scene_graph()
        graph["nodes"][0]["purpose_annotation"] = (  # type: ignore[typeddict-unknown-key]
            "Identity and Access Management — ensures every request is authenticated."
        )
        validate_scene_graph(graph)  # must not raise

    def test_bounded_context_node_with_purpose_annotation_null_is_valid(self) -> None:
        """purpose_annotation may be null (key present, intentionally blank)."""
        graph = make_scene_graph()
        graph["nodes"][0]["purpose_annotation"] = None  # type: ignore[typeddict-unknown-key]
        validate_scene_graph(graph)  # must not raise

    def test_module_node_with_purpose_annotation_string_is_valid(self) -> None:
        """purpose_annotation may appear on module nodes with a string value."""
        graph = make_scene_graph()
        graph["nodes"][1]["purpose_annotation"] = (  # type: ignore[typeddict-unknown-key]
            "Domain logic for IAM — enforces policy checks before token issuance."
        )
        validate_scene_graph(graph)  # must not raise

    def test_purpose_annotation_wrong_type_raises(self) -> None:
        """purpose_annotation must be string or null — integer is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["purpose_annotation"] = 42  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for purpose_annotation=42"
        except ValueError as exc:
            assert "purpose_annotation" in str(exc)

    def test_purpose_annotation_list_raises(self) -> None:
        """purpose_annotation must be string or null — list is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["purpose_annotation"] = ["bad"]  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for purpose_annotation=['bad']"
        except ValueError as exc:
            assert "purpose_annotation" in str(exc)

    def test_purpose_annotation_typeddict_field_on_node(self) -> None:
        """Node TypedDict declares purpose_annotation as a NotRequired field."""
        annotations = Node.__annotations__
        assert "purpose_annotation" in annotations, (
            "Node TypedDict must declare 'purpose_annotation'"
        )

    def test_purpose_annotation_schema_example(self) -> None:
        """Verify the spec's worked JSON example is representable in the schema."""
        node: Node = {
            "id": "iam",
            "name": "IAM",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 3.2,
            "parent": None,
            "purpose_annotation": (  # type: ignore[typeddict-unknown-key]
                "Identity and Access Management — ensures every request is"
                " authenticated before reaching business logic, and enforces"
                " role-based access control across all bounded contexts."
            ),
        }
        assert node["purpose_annotation"].startswith("Identity")  # type: ignore[typeddict-item]


class TestBeaconsField:
    """beacons MAY appear on any node type.

    Spec requirement: The system MUST support attaching beacons — recognized
    programming patterns — to structural elements.
    - absent: no beacon analysis run — validator MUST NOT error.
    - empty array: analysis ran but no patterns recognized.
    - array of BeaconInfo entries: each has pattern (non-empty string) and
      description (string).  pattern is NOT validated against a fixed vocabulary.
    """

    def test_node_without_beacons_is_valid(self) -> None:
        """Absence of beacons is valid — beacon analysis has not run."""
        graph = make_scene_graph()
        validate_scene_graph(graph)  # must not raise

    def test_node_with_empty_beacons_array_is_valid(self) -> None:
        """Empty beacons array is valid — analysis ran, no patterns recognized."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = []  # type: ignore[typeddict-unknown-key]
        validate_scene_graph(graph)  # must not raise

    def test_node_with_single_beacon_is_valid(self) -> None:
        """A node with one beacon entry is valid."""
        graph = make_scene_graph()
        graph["nodes"][1]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {
                "pattern": "retry_loop",
                "description": (
                    "Retries the token validation call up to 3 times with"
                    " exponential backoff on transient failures."
                ),
            }
        ]
        validate_scene_graph(graph)  # must not raise

    def test_node_with_multiple_beacons_is_valid(self) -> None:
        """A node with multiple beacon entries is valid."""
        graph = make_scene_graph()
        graph["nodes"][1]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"pattern": "retry_loop", "description": "Retries token validation."},
            {"pattern": "circuit_breaker", "description": "Trips after 5 failures."},
        ]
        validate_scene_graph(graph)  # must not raise

    def test_beacon_pattern_open_vocabulary_is_valid(self) -> None:
        """beacon pattern is open-vocabulary — novel pattern names are accepted."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {
                "pattern": "novel_pattern_not_in_any_list",
                "description": "A pattern the spec author did not anticipate.",
            }
        ]
        validate_scene_graph(graph)  # must not raise

    def test_beacons_not_array_raises(self) -> None:
        """beacons must be an array — string is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = "retry_loop"  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for beacons='retry_loop'"
        except ValueError as exc:
            assert "beacons" in str(exc)

    def test_beacon_entry_missing_pattern_raises(self) -> None:
        """Each beacon entry MUST have a pattern field."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"description": "Missing pattern field."}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for beacon missing 'pattern'"
        except ValueError as exc:
            assert "pattern" in str(exc)

    def test_beacon_entry_missing_description_raises(self) -> None:
        """Each beacon entry MUST have a description field."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"pattern": "retry_loop"}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for beacon missing 'description'"
        except ValueError as exc:
            assert "description" in str(exc)

    def test_beacon_pattern_empty_string_raises(self) -> None:
        """beacon pattern must be a non-empty string."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"pattern": "", "description": "Empty pattern is invalid."}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for empty beacon pattern"
        except ValueError as exc:
            assert "pattern" in str(exc)

    def test_beacon_pattern_non_string_raises(self) -> None:
        """beacon pattern must be a string — integer is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"pattern": 42, "description": "Non-string pattern."}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for beacon pattern=42"
        except ValueError as exc:
            assert "pattern" in str(exc)

    def test_beacon_description_non_string_raises(self) -> None:
        """beacon description must be a string — integer is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"pattern": "retry_loop", "description": 99}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for beacon description=99"
        except ValueError as exc:
            assert "description" in str(exc)

    def test_beacons_typeddict_field_on_node(self) -> None:
        """Node TypedDict declares beacons as a NotRequired field."""
        annotations = Node.__annotations__
        assert "beacons" in annotations, "Node TypedDict must declare 'beacons'"

    def test_beacon_info_typeddict_has_pattern_and_description(self) -> None:
        """BeaconInfo TypedDict declares pattern and description."""
        beacon: BeaconInfo = {
            "pattern": "accumulator",
            "description": "Accumulates payments into a running total.",
        }
        assert beacon["pattern"] == "accumulator"
        assert beacon["description"].startswith("Accumulates")

    def test_beacon_spec_example_is_representable(self) -> None:
        """Verify the spec's worked beacon JSON example is representable."""
        node: Node = {
            "id": "iam.application",
            "name": "Application",
            "type": "module",
            "position": {"x": 1.0, "y": 0.0, "z": 1.0},
            "size": 2.0,
            "parent": "iam",
            "beacons": [  # type: ignore[typeddict-unknown-key]
                {
                    "pattern": "retry_loop",
                    "description": (
                        "Retries the token validation call up to 3 times with"
                        " exponential backoff on transient failures."
                    ),
                }
            ],
        }
        assert len(node["beacons"]) == 1  # type: ignore[typeddict-item]
        assert node["beacons"][0]["pattern"] == "retry_loop"  # type: ignore[typeddict-item]


class TestInvariantsField:
    """invariants MAY appear on module and bounded_context nodes.

    Spec requirement: The system MUST support attaching invariants — business
    rules collectively enforced by the node — to structural elements.
    - absent: no invariant analysis run — validator MUST NOT error.
    - empty array: analysis ran but no invariants identified.
    - array of InvariantInfo entries: each has rule (non-empty string) and
      enforced_by (array of node id strings, may be empty).
    """

    def test_node_without_invariants_is_valid(self) -> None:
        """Absence of invariants is valid — invariant analysis has not run."""
        graph = make_scene_graph()
        validate_scene_graph(graph)  # must not raise

    def test_node_with_empty_invariants_array_is_valid(self) -> None:
        """Empty invariants array is valid — analysis ran, no invariants found."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = []  # type: ignore[typeddict-unknown-key]
        validate_scene_graph(graph)  # must not raise

    def test_node_with_single_invariant_is_valid(self) -> None:
        """A node with one invariant entry is valid."""
        graph = make_scene_graph()
        graph["nodes"][1]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {
                "rule": "A token cannot be issued unless the requesting identity"
                " has passed all active policy checks.",
                "enforced_by": ["iam.domain", "iam.application"],
            }
        ]
        validate_scene_graph(graph)  # must not raise

    def test_node_with_multiple_invariants_is_valid(self) -> None:
        """A node with multiple invariant entries is valid."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {
                "rule": "Order cannot ship if payment is pending.",
                "enforced_by": ["payments.domain"],
            },
            {
                "rule": "No refund issued if order not yet delivered.",
                "enforced_by": ["payments.domain", "fulfillment.domain"],
            },
        ]
        validate_scene_graph(graph)  # must not raise

    def test_invariant_enforced_by_may_be_empty_list(self) -> None:
        """enforced_by may be an empty array when enforcement path is unclear."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {"rule": "Some constraint is upheld.", "enforced_by": []}
        ]
        validate_scene_graph(graph)  # must not raise

    def test_invariants_not_array_raises(self) -> None:
        """invariants must be an array — string is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = "some rule"  # type: ignore[typeddict-unknown-key]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for invariants='some rule'"
        except ValueError as exc:
            assert "invariants" in str(exc)

    def test_invariant_entry_missing_rule_raises(self) -> None:
        """Each invariant entry MUST have a rule field."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {"enforced_by": ["iam.domain"]}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for invariant missing 'rule'"
        except ValueError as exc:
            assert "rule" in str(exc)

    def test_invariant_entry_missing_enforced_by_raises(self) -> None:
        """Each invariant entry MUST have an enforced_by field."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {"rule": "Order cannot ship if payment is pending."}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for invariant missing 'enforced_by'"
        except ValueError as exc:
            assert "enforced_by" in str(exc)

    def test_invariant_rule_empty_string_raises(self) -> None:
        """invariant rule must be a non-empty string."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {"rule": "", "enforced_by": []}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for empty invariant rule"
        except ValueError as exc:
            assert "rule" in str(exc)

    def test_invariant_rule_non_string_raises(self) -> None:
        """invariant rule must be a string — integer is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {"rule": 99, "enforced_by": []}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for invariant rule=99"
        except ValueError as exc:
            assert "rule" in str(exc)

    def test_invariant_enforced_by_not_list_raises(self) -> None:
        """enforced_by must be a list — string is invalid."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {"rule": "Some rule.", "enforced_by": "iam.domain"}
        ]
        try:
            validate_scene_graph(graph)
            assert False, "Expected ValueError for enforced_by='iam.domain'"
        except ValueError as exc:
            assert "enforced_by" in str(exc)

    def test_invariants_typeddict_field_on_node(self) -> None:
        """Node TypedDict declares invariants as a NotRequired field."""
        annotations = Node.__annotations__
        assert "invariants" in annotations, "Node TypedDict must declare 'invariants'"

    def test_invariant_info_typeddict_has_rule_and_enforced_by(self) -> None:
        """InvariantInfo TypedDict declares rule and enforced_by."""
        inv: InvariantInfo = {
            "rule": "Order cannot ship if payment is pending.",
            "enforced_by": ["payments.domain"],
        }
        assert inv["rule"].startswith("Order")
        assert inv["enforced_by"] == ["payments.domain"]

    def test_invariant_spec_example_is_representable(self) -> None:
        """Verify the spec's worked invariant JSON example is representable."""
        node: Node = {
            "id": "iam.domain",
            "name": "Domain",
            "type": "module",
            "position": {"x": 1.0, "y": 0.0, "z": 1.0},
            "size": 2.0,
            "parent": "iam",
            "invariants": [  # type: ignore[typeddict-unknown-key]
                {
                    "rule": (
                        "A token cannot be issued unless the requesting identity"
                        " has passed all active policy checks."
                    ),
                    "enforced_by": ["iam.domain", "iam.application"],
                }
            ],
        }
        assert len(node["invariants"]) == 1  # type: ignore[typeddict-item]
        assert "token" in node["invariants"][0]["rule"]  # type: ignore[typeddict-item]


class TestAnnotationFieldsAbsenceIsValid:
    """All three annotation fields (purpose_annotation, beacons, invariants) are optional.

    Spec: 'None of the three fields is required on any node.
    Absent means the annotation has not been computed; the validator
    MUST NOT error on absence.'
    """

    def test_all_three_absent_passes_validation(self) -> None:
        """Nodes with none of the three annotation fields pass validation."""
        graph = make_scene_graph()
        # Neither node has any annotation field
        assert "purpose_annotation" not in graph["nodes"][0]
        assert "beacons" not in graph["nodes"][0]
        assert "invariants" not in graph["nodes"][0]
        validate_scene_graph(graph)  # must not raise

    def test_all_three_present_passes_validation(self) -> None:
        """Nodes with all three annotation fields simultaneously pass validation."""
        graph = make_scene_graph()
        graph["nodes"][0]["purpose_annotation"] = "Payment safety gateway."  # type: ignore[typeddict-unknown-key]
        graph["nodes"][0]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"pattern": "circuit_breaker", "description": "Trips after 5 failures."}
        ]
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {
                "rule": "Order cannot ship if payment is pending.",
                "enforced_by": ["payments.domain"],
            }
        ]
        validate_scene_graph(graph)  # must not raise

    def test_only_beacons_present_passes_validation(self) -> None:
        """Having only beacons (without purpose_annotation or invariants) is valid."""
        graph = make_scene_graph()
        graph["nodes"][1]["beacons"] = [  # type: ignore[typeddict-unknown-key]
            {"pattern": "accumulator", "description": "Accumulates running total."}
        ]
        validate_scene_graph(graph)  # must not raise

    def test_only_invariants_present_passes_validation(self) -> None:
        """Having only invariants (without purpose_annotation or beacons) is valid."""
        graph = make_scene_graph()
        graph["nodes"][0]["invariants"] = [  # type: ignore[typeddict-unknown-key]
            {"rule": "All orders must have a valid address.", "enforced_by": []}
        ]
        validate_scene_graph(graph)  # must not raise
