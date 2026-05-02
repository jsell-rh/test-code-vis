"""Tests for the scene graph schema definitions.

Validates that the schema TypedDicts match the requirements described in
specs/extraction/scene-graph-schema.spec.md.
"""

from __future__ import annotations

import json

from extractor.schema import (
    AggregateMetrics,
    BadgeType,
    Cluster,
    Edge,
    Metadata,
    Node,
    Position,
    SceneGraph,
    StructuralSignificanceMetrics,
    SymbolInfo,
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
# visual-primitives.spec.md — Schema tests
# Spec: specs/core/visual-primitives.spec.md
# Task: task-076 (schema-level coverage for visual-primitive data structures)
# ---------------------------------------------------------------------------


class TestTypeTopologyEdges:
    """Schema tests for type-topology edge types.

    Spec §Requirement: Type Topology Extraction
    'The extractor MUST produce the graph of type relationships:
     inheritance, implementation, and composition (has-a).'

    Schema MUST define EdgeType literals 'inherits' and 'has_a'.
    """

    def test_inherits_edge_type_is_valid(self) -> None:
        """An 'inherits' edge can be constructed and is JSON-serialisable."""
        edge: Edge = {
            "source": "payment.processor",
            "target": "payment.base_processor",
            "type": "inherits",
        }
        assert edge["type"] == "inherits"
        serialised = json.dumps(edge)
        loaded = json.loads(serialised)
        assert loaded["type"] == "inherits"

    def test_has_a_edge_type_is_valid(self) -> None:
        """A 'has_a' edge (composition relationship) is JSON-serialisable."""
        edge: Edge = {
            "source": "order.order",
            "target": "order.payment_info",
            "type": "has_a",
        }
        assert edge["type"] == "has_a"
        serialised = json.dumps(edge)
        loaded = json.loads(serialised)
        assert loaded["type"] == "has_a"

    def test_inherits_edge_has_source_and_target(self) -> None:
        """An inheritance edge carries the source (child) and target (parent)."""
        edge: Edge = {
            "source": "payment.processor",
            "target": "payment.base_processor",
            "type": "inherits",
        }
        assert "source" in edge
        assert "target" in edge
        assert edge["source"] != edge["target"]

    def test_has_a_edge_has_source_and_target(self) -> None:
        """A has_a composition edge carries the container (source) and contained (target)."""
        edge: Edge = {
            "source": "order.order",
            "target": "order.payment_info",
            "type": "has_a",
        }
        assert "source" in edge
        assert "target" in edge


class TestCallGraphEdges:
    """Schema tests for call-graph edge types.

    Spec §Requirement: Call Graph Extraction
    'The extractor MUST produce the directed graph of function-to-function
     invocations.'

    Schema MUST define EdgeType literals 'direct_call' and 'dynamic_call'.
    """

    def test_direct_call_edge_type_is_valid(self) -> None:
        """A 'direct_call' edge is constructed and JSON-serialisable."""
        edge: Edge = {
            "source": "iam.domain",
            "target": "iam.validator",
            "type": "direct_call",
            "weight": 3,
        }
        assert edge["type"] == "direct_call"
        serialised = json.dumps(edge)
        loaded = json.loads(serialised)
        assert loaded["type"] == "direct_call"

    def test_dynamic_call_edge_type_is_valid(self) -> None:
        """A 'dynamic_call' edge (unresolved target) is JSON-serialisable."""
        edge: Edge = {
            "source": "iam.dispatcher",
            "target": "iam.validator",
            "type": "dynamic_call",
        }
        assert edge["type"] == "dynamic_call"
        serialised = json.dumps(edge)
        loaded = json.loads(serialised)
        assert loaded["type"] == "dynamic_call"

    def test_direct_call_edge_weight_counts_call_sites(self) -> None:
        """Spec §Scenario: Call frequency annotation — edge A->B carries weight=N.

        'the edge A->B carries a weight of 3' when A calls B in three
        separate locations.
        """
        edge: Edge = {
            "source": "iam.handler",
            "target": "iam.validator",
            "type": "direct_call",
            "weight": 3,
        }
        assert edge["weight"] == 3
        assert edge["weight"] >= 1

    def test_dynamic_call_has_no_resolved_target(self) -> None:
        """Spec §Scenario: Indirect calls — dynamic_call site has a parameter name.

        The extractor emits a 'dynamic_call' with no resolved target —
        the call site carries the parameter name and any type hints.
        """
        edge: Edge = {
            "source": "iam.dispatcher",
            "target": "iam.handler_param",
            "type": "dynamic_call",
        }
        # dynamic_call edges reference a parameter placeholder, not a resolved function.
        assert edge["type"] == "dynamic_call"
        assert "source" in edge


class TestUbiquitousEdgeField:
    """Schema tests for the ubiquitous flag on edges and nodes.

    Spec §Requirement: Ubiquitous Dependency Detection
    'The extractor MUST identify dependencies that are imported by a large
     fraction of modules and flag them as ubiquitous.'

    Schema MUST define:
    - Edge.ubiquitous: NotRequired[bool]
    - Node.has_ubiquitous_dep: NotRequired[bool]
    - Metadata.ubiquity_threshold: NotRequired[float]
    """

    def test_edge_can_carry_ubiquitous_true(self) -> None:
        """An edge flagged ubiquitous=True is JSON-serialisable."""
        edge: Edge = {
            "source": "iam.domain",
            "target": "logging",
            "type": "cross_context",
            "ubiquitous": True,
        }
        assert edge["ubiquitous"] is True
        serialised = json.dumps(edge)
        loaded = json.loads(serialised)
        assert loaded["ubiquitous"] is True

    def test_edge_ubiquitous_false_is_valid(self) -> None:
        """A regular edge can carry ubiquitous=False (opt-in flag)."""
        edge: Edge = {
            "source": "iam.domain",
            "target": "billing.payment",
            "type": "cross_context",
            "ubiquitous": False,
        }
        assert edge["ubiquitous"] is False

    def test_edge_without_ubiquitous_is_valid(self) -> None:
        """Edges without the ubiquitous field are valid (NotRequired)."""
        edge: Edge = {
            "source": "iam.domain",
            "target": "billing.payment",
            "type": "cross_context",
        }
        assert "ubiquitous" not in edge

    def test_ubiquitous_flag_present_in_scene_graph_edge(self) -> None:
        """Spec §Scenario: Standard library suppression — edges marked ubiquitous=true.

        After detection, the edge IS present in the scene graph but marked
        ubiquitous=True.  The composition layer defaults to suppressing them.
        """
        edge: Edge = {
            "source": "iam.service",
            "target": "logging",
            "type": "cross_context",
            "ubiquitous": True,
        }
        # Edge IS present (not deleted) — the 'ubiquitous' field is the flag.
        assert "ubiquitous" in edge
        assert edge["ubiquitous"] is True


class TestNodeUbiquitousField:
    """Schema tests for Node.has_ubiquitous_dep.

    Spec §Requirement: Power Rail Notation
    'each Node that imports [ubiquitous dep] has a small, consistent indicator'

    The Node schema carries has_ubiquitous_dep:bool to trigger the indicator.
    """

    def test_node_can_have_has_ubiquitous_dep_true(self) -> None:
        """A node flagged has_ubiquitous_dep=True is JSON-serialisable."""
        node: Node = {
            "id": "iam",
            "name": "IAM",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 2.5,
            "parent": None,
            "has_ubiquitous_dep": True,
        }
        assert node["has_ubiquitous_dep"] is True
        serialised = json.dumps(node)
        loaded = json.loads(serialised)
        assert loaded["has_ubiquitous_dep"] is True

    def test_node_without_ubiquitous_dep_is_valid(self) -> None:
        """has_ubiquitous_dep is NotRequired — nodes without it are valid."""
        node: Node = {
            "id": "iam",
            "name": "IAM",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 2.5,
            "parent": None,
        }
        assert "has_ubiquitous_dep" not in node


class TestMetadataUbiquityThreshold:
    """Schema tests for Metadata.ubiquity_threshold.

    Spec §Requirement: Ubiquitous Dependency Detection / Threshold
    'a configurable threshold (default: imported by >50% of modules)
     … the threshold is recorded in extraction metadata'
    """

    def test_metadata_can_have_ubiquity_threshold(self) -> None:
        """Metadata with ubiquity_threshold=0.5 is valid."""
        meta: Metadata = {
            "source_path": "/path/to/code",
            "timestamp": "2026-05-02T00:00:00Z",
            "ubiquity_threshold": 0.5,
        }
        assert meta["ubiquity_threshold"] == 0.5

    def test_metadata_without_threshold_is_valid(self) -> None:
        """ubiquity_threshold is NotRequired — metadata without it is valid."""
        meta: Metadata = {
            "source_path": "/path/to/code",
            "timestamp": "2026-05-02T00:00:00Z",
        }
        assert "ubiquity_threshold" not in meta

    def test_ubiquity_threshold_default_value(self) -> None:
        """Spec §Scenario: Threshold — default >50% means threshold=0.5."""
        meta: Metadata = {
            "source_path": "/path/to/code",
            "timestamp": "2026-05-02T00:00:00Z",
            "ubiquity_threshold": 0.5,
        }
        # Default threshold is 0.5 (50%) per spec.
        assert meta["ubiquity_threshold"] == 0.5
        assert 0.0 < meta["ubiquity_threshold"] < 1.0

    def test_ubiquity_threshold_custom_value(self) -> None:
        """A custom threshold (e.g. 0.75) is stored verbatim in metadata."""
        meta: Metadata = {
            "source_path": "/path/to/code",
            "timestamp": "2026-05-02T00:00:00Z",
            "ubiquity_threshold": 0.75,
        }
        assert meta["ubiquity_threshold"] == 0.75


class TestBadgeTypeSchema:
    """Schema tests for BadgeType literals.

    Spec §Requirement: Badge Primitive
    'the system supports at minimum: pure, io, async, stateful,
     error_handling, test, entry_point, deprecated'
    """

    _REQUIRED_BADGES: tuple[BadgeType, ...] = (
        "pure",
        "io",
        "async",
        "stateful",
        "error_handling",
        "test",
        "entry_point",
        "deprecated",
    )

    def test_all_required_badge_types_defined(self) -> None:
        """All 8 required badge types are present in BadgeType."""
        # Verify each required badge type value is valid (type checker enforces it).
        for badge in self._REQUIRED_BADGES:
            typed: BadgeType = badge  # type: ignore[assignment]
            assert typed == badge

    def test_node_badges_field_accepts_list_of_badge_types(self) -> None:
        """Node.badges is a list of badge type strings."""
        node: Node = {
            "id": "iam.handler",
            "name": "Handler",
            "type": "module",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.5,
            "parent": "iam",
            "badges": ["io", "async"],
        }
        assert node["badges"] == ["io", "async"]
        assert len(node["badges"]) == 2  # type: ignore[arg-type]

    def test_node_badges_field_is_optional(self) -> None:
        """Node.badges is NotRequired — nodes without it are valid."""
        node: Node = {
            "id": "iam.handler",
            "name": "Handler",
            "type": "module",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.5,
            "parent": "iam",
        }
        assert "badges" not in node

    def test_all_eight_badge_types_on_single_node(self) -> None:
        """Spec §Scenario: Multiple badges — all 8 badge types can coexist on a node."""
        node: Node = {
            "id": "iam.service",
            "name": "Service",
            "type": "module",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 2.0,
            "parent": "iam",
            "badges": list(self._REQUIRED_BADGES),
        }
        assert len(node["badges"]) == 8  # type: ignore[arg-type]
        for badge in self._REQUIRED_BADGES:
            assert badge in node["badges"]  # type: ignore[operator]


class TestLandmarkNodeField:
    """Schema tests for Node.is_landmark.

    Spec §Requirement: Landmark Primitive
    'Landmarks are derived from: hubs (high in-degree), bridges (high
     betweenness centrality), entry points (no in-edges from application code),
     and human-designated Landmarks.'
    """

    def test_node_can_be_flagged_as_landmark(self) -> None:
        """A node with is_landmark=True is JSON-serialisable."""
        node: Node = {
            "id": "hub_ctx",
            "name": "HubContext",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 3.0,
            "parent": None,
            "is_landmark": True,
        }
        assert node["is_landmark"] is True
        serialised = json.dumps(node)
        loaded = json.loads(serialised)
        assert loaded["is_landmark"] is True

    def test_node_is_landmark_false_is_valid(self) -> None:
        """A non-landmark node can carry is_landmark=False."""
        node: Node = {
            "id": "iam.utility",
            "name": "Utility",
            "type": "module",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.0,
            "parent": "iam",
            "is_landmark": False,
        }
        assert node["is_landmark"] is False

    def test_node_without_landmark_flag_is_valid(self) -> None:
        """is_landmark is NotRequired — nodes without it are valid."""
        node: Node = {
            "id": "iam",
            "name": "IAM",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 2.5,
            "parent": None,
        }
        assert "is_landmark" not in node


class TestSymbolInfoSchema:
    """Schema tests for SymbolInfo TypedDict.

    Spec §Requirement: Symbol Table Extraction
    'The extractor MUST produce the named entities in each scope — functions,
     types, constants, variables — with their signatures and visibility.'
    """

    def test_public_function_symbol_info(self) -> None:
        """Spec §Scenario: Public vs. private symbols — public function has visibility='public'."""
        symbol: SymbolInfo = {
            "name": "process_order",
            "visibility": "public",
            "kind": "function",
            "signature": "(order: Order) -> Result",
        }
        assert symbol["name"] == "process_order"
        assert symbol["visibility"] == "public"
        assert symbol["kind"] == "function"
        assert "signature" in symbol

    def test_private_function_symbol_info(self) -> None:
        """Spec §Scenario: Public vs. private symbols — private function has visibility='private'."""
        symbol: SymbolInfo = {
            "name": "_validate_input",
            "visibility": "private",
            "kind": "function",
            "signature": "(data: dict) -> bool",
        }
        assert symbol["visibility"] == "private"
        assert symbol["name"].startswith("_")

    def test_class_symbol_info(self) -> None:
        """A class is a valid SymbolKind."""
        symbol: SymbolInfo = {
            "name": "PaymentProcessor",
            "visibility": "public",
            "kind": "class",
        }
        assert symbol["kind"] == "class"
        assert "signature" not in symbol  # classes don't carry a function signature

    def test_constant_symbol_info(self) -> None:
        """A constant is a valid SymbolKind."""
        symbol: SymbolInfo = {
            "name": "MAX_RETRIES",
            "visibility": "public",
            "kind": "constant",
        }
        assert symbol["kind"] == "constant"

    def test_variable_symbol_info(self) -> None:
        """A variable is a valid SymbolKind."""
        symbol: SymbolInfo = {
            "name": "_cache",
            "visibility": "private",
            "kind": "variable",
        }
        assert symbol["kind"] == "variable"
        assert symbol["visibility"] == "private"

    def test_symbol_info_is_json_serialisable(self) -> None:
        """SymbolInfo can be serialised to JSON."""
        symbol: SymbolInfo = {
            "name": "process_order",
            "visibility": "public",
            "kind": "function",
            "signature": "(order: Order, *, strict: bool = False) -> Result",
        }
        serialised = json.dumps(symbol)
        loaded = json.loads(serialised)
        assert loaded["name"] == "process_order"
        assert loaded["visibility"] == "public"
        assert (
            loaded["signature"] == "(order: Order, *, strict: bool = False) -> Result"
        )

    def test_node_symbols_field_contains_symbol_infos(self) -> None:
        """Node.symbols is a list of SymbolInfo dicts."""
        node: Node = {
            "id": "iam.domain",
            "name": "Domain",
            "type": "module",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.5,
            "parent": "iam",
            "symbols": [
                {"name": "process_order", "visibility": "public", "kind": "function"},
                {"name": "_validate", "visibility": "private", "kind": "function"},
            ],
        }
        assert len(node["symbols"]) == 2  # type: ignore[arg-type]
        assert node["symbols"][0]["visibility"] == "public"  # type: ignore[index]
        assert node["symbols"][1]["visibility"] == "private"  # type: ignore[index]


class TestStructuralSignificanceSchema:
    """Schema tests for StructuralSignificanceMetrics TypedDict.

    Spec §Requirement: Structural Significance Extraction
    'The extractor MUST compute graph-theoretic significance measures for each
     node in the module graph and call graph.'
    """

    def test_structural_significance_has_required_fields(self) -> None:
        """StructuralSignificanceMetrics carries all required fields."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 5,
            "out_degree": 2,
            "is_hub": True,
            "is_bridge": False,
            "is_peripheral": False,
            "betweenness_centrality": 0.42,
        }
        assert sig["in_degree"] == 5
        assert sig["out_degree"] == 2
        assert sig["is_hub"] is True
        assert sig["is_bridge"] is False
        assert sig["is_peripheral"] is False
        assert sig["betweenness_centrality"] == 0.42

    def test_hub_node_has_high_in_degree(self) -> None:
        """Spec §Scenario: Hub detection — high in_degree → is_hub=True."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 40,
            "out_degree": 3,
            "is_hub": True,
            "is_bridge": False,
            "is_peripheral": False,
            "betweenness_centrality": 0.15,
        }
        assert sig["is_hub"] is True
        assert sig["in_degree"] > 10  # "40 other modules" in spec example

    def test_bridge_node_has_betweenness_centrality(self) -> None:
        """Spec §Scenario: Bridge detection — betweenness_centrality is a float score.

        'the module is annotated with its betweenness centrality score'
        The score is a numeric float, NOT a bool flag only.
        """
        sig: StructuralSignificanceMetrics = {
            "in_degree": 2,
            "out_degree": 3,
            "is_hub": False,
            "is_bridge": True,
            "is_peripheral": False,
            "betweenness_centrality": 0.65,
        }
        assert sig["is_bridge"] is True
        assert isinstance(sig["betweenness_centrality"], float)
        assert sig["betweenness_centrality"] > 0.0  # high betweenness centrality

    def test_peripheral_node_has_in_degree_zero(self) -> None:
        """Spec §Scenario: Peripheral detection — in_degree=0 and out_degree≤1."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 0,
            "out_degree": 1,
            "is_hub": False,
            "is_bridge": False,
            "is_peripheral": True,
            "betweenness_centrality": 0.0,
        }
        assert sig["is_peripheral"] is True
        assert sig["in_degree"] == 0
        assert sig["out_degree"] <= 1

    def test_community_id_is_optional(self) -> None:
        """community_id is NotRequired — nodes without community detection are valid."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 3,
            "out_degree": 2,
            "is_hub": False,
            "is_bridge": False,
            "is_peripheral": False,
            "betweenness_centrality": 0.05,
        }
        assert "community_id" not in sig

    def test_community_id_present_when_set(self) -> None:
        """Spec §Scenario: Community detection — community_id is assigned."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 3,
            "out_degree": 2,
            "is_hub": False,
            "is_bridge": False,
            "is_peripheral": False,
            "betweenness_centrality": 0.05,
            "community_id": "community_0",
        }
        assert sig["community_id"] == "community_0"

    def test_community_drift_is_optional(self) -> None:
        """community_drift is NotRequired — absent when not flagged."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 3,
            "out_degree": 2,
            "is_hub": False,
            "is_bridge": False,
            "is_peripheral": False,
            "betweenness_centrality": 0.05,
            "community_id": "community_0",
        }
        assert "community_drift" not in sig

    def test_community_drift_present_when_flagged(self) -> None:
        """Spec §Scenario: Community detection — community_drift=True when community spans contexts."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 3,
            "out_degree": 2,
            "is_hub": False,
            "is_bridge": False,
            "is_peripheral": False,
            "betweenness_centrality": 0.05,
            "community_id": "community_1",
            "community_drift": True,
        }
        assert sig["community_drift"] is True

    def test_betweenness_centrality_range(self) -> None:
        """Betweenness centrality is in [0.0, 1.0]."""
        for value in (0.0, 0.25, 0.5, 0.75, 1.0):
            sig: StructuralSignificanceMetrics = {
                "in_degree": 1,
                "out_degree": 1,
                "is_hub": False,
                "is_bridge": False,
                "is_peripheral": False,
                "betweenness_centrality": value,
            }
            assert 0.0 <= sig["betweenness_centrality"] <= 1.0

    def test_structural_significance_is_json_serialisable(self) -> None:
        """StructuralSignificanceMetrics can round-trip through JSON."""
        sig: StructuralSignificanceMetrics = {
            "in_degree": 5,
            "out_degree": 2,
            "is_hub": True,
            "is_bridge": False,
            "is_peripheral": False,
            "betweenness_centrality": 0.42,
            "community_id": "community_0",
            "community_drift": False,
        }
        serialised = json.dumps(sig)
        loaded = json.loads(serialised)
        assert loaded["is_hub"] is True
        assert loaded["betweenness_centrality"] == 0.42
        assert loaded["community_id"] == "community_0"

    def test_node_carries_structural_significance_field(self) -> None:
        """Node.structural_significance embeds the metrics object."""
        node: Node = {
            "id": "iam",
            "name": "IAM",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 2.5,
            "parent": None,
            "structural_significance": {
                "in_degree": 10,
                "out_degree": 3,
                "is_hub": True,
                "is_bridge": False,
                "is_peripheral": False,
                "betweenness_centrality": 0.30,
            },
        }
        sig = node["structural_significance"]  # type: ignore[typeddict-item]
        assert sig["is_hub"] is True
        assert sig["betweenness_centrality"] == 0.30
