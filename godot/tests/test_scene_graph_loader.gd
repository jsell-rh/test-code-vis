## Behavioral tests for SceneGraphLoader.
##
## Validates every THEN clause from specs/extraction/code-extraction.spec.md
## that describes the JSON format consumed by the Godot visualiser.
##
## Each test_* method is discovered and run by tests/run_tests.gd.

extends RefCounted

const SceneGraphLoader = preload("res://scripts/scene_graph_loader.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------

func _make_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "iam",
				"name": "IAM",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 1.0, "y": 0.0, "z": 0.0},
				"size": 2.5,
				"metrics": {"loc": 150},
			},
			{
				"id": "iam.domain",
				"name": "Domain",
				"type": "module",
				"parent": "iam",
				"position": {"x": 0.5, "y": 1.0, "z": 0.0},
				"size": 1.2,
				"metrics": {"loc": 80},
			},
			{
				"id": "shared_kernel",
				"name": "Shared Kernel",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -1.0, "y": 0.0, "z": 0.0},
				"size": 1.8,
				"metrics": {"loc": 60},
			},
		],
		"edges": [
			{"source": "iam", "target": "shared_kernel", "type": "cross_context"},
			{"source": "iam.application", "target": "iam.domain", "type": "internal"},
		],
		"metadata": {
			"source_path": "/tmp/kartograph",
			"timestamp": "2026-04-22T00:00:00Z",
		},
	}


# ---------------------------------------------------------------------------
# Scenario: Output format — the JSON contains a list of nodes
# THEN the JSON contains a list of nodes (id, name, type, parent, metrics)
# ---------------------------------------------------------------------------

func test_nodes_list_is_returned() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	_check("nodes" in result, "Result must contain 'nodes' key")
	_check(result["nodes"] is Array, "'nodes' must be an Array")


func test_node_count_matches_input() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	_check(result["nodes"].size() == 3, "Expected 3 nodes, got %d" % result["nodes"].size())


func test_node_has_id_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var node: Dictionary = result["nodes"][0]
	_check("id" in node, "Node must have 'id' field")
	_check(node["id"] == "iam", "First node id should be 'iam'")


func test_node_has_name_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var node: Dictionary = result["nodes"][0]
	_check("name" in node, "Node must have 'name' field")
	_check(node["name"] == "IAM", "First node name should be 'IAM'")


func test_node_has_type_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var node: Dictionary = result["nodes"][0]
	_check("type" in node, "Node must have 'type' field")
	_check(node["type"] == "bounded_context", "First node type should be 'bounded_context'")


func test_node_top_level_has_null_parent() -> void:
	# THEN: parent field is null for top-level bounded contexts
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var bc_node: Dictionary = result["nodes"][0]
	_check("parent" in bc_node, "Node must have 'parent' field")
	_check(bc_node["parent"] == null, "Top-level node parent should be null")


func test_node_module_parent_references_bounded_context() -> void:
	# THEN: containment relationship — module X is inside bounded context Y
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var module_node: Dictionary = result["nodes"][1]
	_check("parent" in module_node, "Module node must have 'parent' field")
	_check(module_node["parent"] == "iam", "Module node parent should be 'iam'")


func test_node_has_metrics_field() -> void:
	# THEN: it computes the total lines of code for the module AND
	#       this metric is included in the node's metadata
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var node: Dictionary = result["nodes"][0]
	_check("metrics" in node, "Node must have 'metrics' field")
	_check("loc" in node["metrics"], "metrics must contain 'loc'")
	_check(node["metrics"]["loc"] == 150, "Node metrics loc should be 150")


func test_node_has_position_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var node: Dictionary = result["nodes"][0]
	_check("position" in node, "Node must have 'position' field")
	_check("x" in node["position"], "Position must have x")
	_check("y" in node["position"], "Position must have y")
	_check("z" in node["position"], "Position must have z")


func test_node_has_size_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var node: Dictionary = result["nodes"][0]
	_check("size" in node, "Node must have 'size' field")
	_check(node["size"] == 2.5, "Node size should be 2.5")


# ---------------------------------------------------------------------------
# Scenario: Output format — the JSON contains a list of edges
# THEN the JSON contains a list of edges (source, target, type)
# ---------------------------------------------------------------------------

func test_edges_list_is_returned() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	_check("edges" in result, "Result must contain 'edges' key")
	_check(result["edges"] is Array, "'edges' must be an Array")


func test_edge_count_matches_input() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	_check(result["edges"].size() == 2, "Expected 2 edges, got %d" % result["edges"].size())


func test_edge_has_source_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var edge: Dictionary = result["edges"][0]
	_check("source" in edge, "Edge must have 'source' field")
	_check(edge["source"] == "iam", "First edge source should be 'iam'")


func test_edge_has_target_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var edge: Dictionary = result["edges"][0]
	_check("target" in edge, "Edge must have 'target' field")
	_check(edge["target"] == "shared_kernel", "First edge target should be 'shared_kernel'")


func test_edge_has_type_field() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var edge: Dictionary = result["edges"][0]
	_check("type" in edge, "Edge must have 'type' field")


# ---------------------------------------------------------------------------
# Scenario: Cross-context dependency — direction of the dependency
# THEN a dependency edge is created from graph to shared_kernel
# AND the edge includes the direction of the dependency
# ---------------------------------------------------------------------------

func test_edge_direction_preserved_source_to_target() -> void:
	# Direction is encoded as source (importer) → target (imported-from).
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var cross_edge: Dictionary = result["edges"][0]
	_check(cross_edge["source"] != cross_edge["target"], "Source and target must differ")
	_check(cross_edge["source"] == "iam", "Cross-context edge source is the importer")
	_check(cross_edge["target"] == "shared_kernel", "Cross-context edge target is the imported-from")


# ---------------------------------------------------------------------------
# Scenario: Internal vs cross-context edges are distinguishable
# AND the edge is distinguishable from cross-context dependencies
# ---------------------------------------------------------------------------

func test_cross_context_edge_type_is_cross_context() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var cross_edge: Dictionary = result["edges"][0]
	_check(cross_edge["type"] == "cross_context", "Cross-context edge type should be 'cross_context'")


func test_internal_edge_type_is_internal() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var internal_edge: Dictionary = result["edges"][1]
	_check(internal_edge["type"] == "internal", "Internal edge type should be 'internal'")


func test_edge_types_are_distinguishable() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	var cross_type: String = result["edges"][0]["type"]
	var internal_type: String = result["edges"][1]["type"]
	_check(cross_type != internal_type, "cross_context and internal edge types must differ")


# ---------------------------------------------------------------------------
# Scenario: Format consumable without transformation
# AND the format is consumable by the Godot visualization without transformation
# ---------------------------------------------------------------------------

func test_metadata_is_returned() -> void:
	var result = SceneGraphLoader.load_from_dict(_make_fixture())
	_check("metadata" in result, "Result must contain 'metadata' key")
	_check(result["metadata"]["source_path"] == "/tmp/kartograph", "metadata.source_path should match")
	_check("timestamp" in result["metadata"], "metadata must have timestamp")


func test_empty_graph_is_handled_gracefully() -> void:
	var data: Dictionary = {"nodes": [], "edges": [], "metadata": {}}
	var result = SceneGraphLoader.load_from_dict(data)
	_check(result["nodes"].size() == 0, "Empty graph should have 0 nodes")
	_check(result["edges"].size() == 0, "Empty graph should have 0 edges")


func test_missing_top_level_keys_default_to_empty() -> void:
	var result = SceneGraphLoader.load_from_dict({})
	_check(result["nodes"].size() == 0, "Missing nodes key should default to empty")
	_check(result["edges"].size() == 0, "Missing edges key should default to empty")


# ---------------------------------------------------------------------------
# Scenario: Spec nodes are distinguishable from code nodes
# AND spec nodes are distinguishable from code-derived nodes
# ---------------------------------------------------------------------------

func test_spec_node_type_is_preserved() -> void:
	var data: Dictionary = {
		"nodes": [
			{
				"id": "spec.iam",
				"name": "IAM",
				"type": "spec",
				"parent": null,
				"position": {"x": 0.0, "y": 5.0, "z": 0.0},
				"size": 1.0,
			}
		],
		"edges": [],
		"metadata": {},
	}
	var result = SceneGraphLoader.load_from_dict(data)
	_check(result["nodes"].size() == 1, "Should have 1 spec node")
	_check(result["nodes"][0]["type"] == "spec", "Spec node type must be 'spec'")


func test_spec_nodes_have_id_prefixed_with_spec() -> void:
	var data: Dictionary = {
		"nodes": [
			{
				"id": "spec.graph",
				"name": "Graph",
				"type": "spec",
				"parent": null,
				"position": {"x": 0.0, "y": 5.0, "z": 0.0},
				"size": 1.0,
			}
		],
		"edges": [],
		"metadata": {},
	}
	var result = SceneGraphLoader.load_from_dict(data)
	var node: Dictionary = result["nodes"][0]
	_check(node["id"].begins_with("spec."), "Spec node id should begin with 'spec.'")
