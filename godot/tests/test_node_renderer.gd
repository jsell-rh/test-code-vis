## Behavioral tests: Godot renders nodes at pre-computed positions from JSON.
##
## Implements the THEN clause from specs/extraction/scene-graph-schema.spec.md:
##   "the Godot application renders nodes at these positions without recomputing layout"
##
## Each test_* method is discovered and run by tests/run_tests.gd.

extends RefCounted

const Main = preload("res://scripts/main.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Helpers
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
			},
			{
				"id": "shared_kernel",
				"name": "Shared Kernel",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -3.0, "y": 2.0, "z": 5.0},
				"size": 1.8,
			},
		],
		"edges": [],
		"metadata": {},
	}


func _find_child_by_name(parent: Node, target_name: String) -> Node:
	for child in parent.get_children():
		if child.name == target_name:
			return child
	return null


# ---------------------------------------------------------------------------
# Scenario: Layout in JSON
# THEN the Godot application renders nodes at these positions without
#      recomputing layout
# ---------------------------------------------------------------------------

func test_node_rendered_at_json_position() -> void:
	# THEN the Godot application renders nodes at these positions without
	# recomputing layout: assert iam is placed at x=1, y=0, z=0 as specified
	# in the JSON — no Godot-side layout algorithm is involved.
	var root := Main.new()
	root.build_from_graph(_make_fixture())

	var iam_node := _find_child_by_name(root, "iam")
	_check(iam_node != null, "MeshInstance3D for 'iam' must exist in scene tree after build_from_graph")
	if iam_node != null:
		_check(
			is_equal_approx(iam_node.position.x, 1.0),
			"iam position.x must be 1.0 (from JSON), got %s" % iam_node.position.x
		)
		_check(
			is_equal_approx(iam_node.position.y, 0.0),
			"iam position.y must be 0.0 (from JSON), got %s" % iam_node.position.y
		)
		_check(
			is_equal_approx(iam_node.position.z, 0.0),
			"iam position.z must be 0.0 (from JSON), got %s" % iam_node.position.z
		)

	root.free()


func test_second_node_rendered_at_json_position() -> void:
	# Verifies a second node is also placed at its JSON-specified position,
	# ruling out any hardcoded or single-node special case.
	var root := Main.new()
	root.build_from_graph(_make_fixture())

	var sk_node := _find_child_by_name(root, "shared_kernel")
	_check(sk_node != null, "MeshInstance3D for 'shared_kernel' must exist in scene tree")
	if sk_node != null:
		_check(
			is_equal_approx(sk_node.position.x, -3.0),
			"shared_kernel position.x must be -3.0 (from JSON), got %s" % sk_node.position.x
		)
		_check(
			is_equal_approx(sk_node.position.y, 2.0),
			"shared_kernel position.y must be 2.0 (from JSON), got %s" % sk_node.position.y
		)
		_check(
			is_equal_approx(sk_node.position.z, 5.0),
			"shared_kernel position.z must be 5.0 (from JSON), got %s" % sk_node.position.z
		)

	root.free()


func test_no_layout_recomputed_in_godot() -> void:
	# Confirms Godot does not run any layout algorithm: the position values
	# on scene-tree nodes must exactly equal the JSON coordinates.
	var root := Main.new()
	var graph := {
		"nodes": [
			{
				"id": "test_node",
				"name": "Test",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 7.0, "y": 3.0, "z": -2.0},
				"size": 1.0,
			}
		],
		"edges": [],
		"metadata": {},
	}
	root.build_from_graph(graph)

	var node := _find_child_by_name(root, "test_node")
	_check(node != null, "Node 'test_node' must exist in scene tree after build_from_graph")
	if node != null:
		_check(
			is_equal_approx(node.position.x, 7.0),
			"position.x must match JSON exactly — no recomputation (got %s)" % node.position.x
		)
		_check(
			is_equal_approx(node.position.y, 3.0),
			"position.y must match JSON exactly — no recomputation (got %s)" % node.position.y
		)
		_check(
			is_equal_approx(node.position.z, -2.0),
			"position.z must match JSON exactly — no recomputation (got %s)" % node.position.z
		)

	root.free()


func test_each_json_node_becomes_a_scene_tree_child() -> void:
	# Every node entry in the JSON must produce exactly one Node3D child
	# in the scene tree — no nodes silently dropped.
	var root := Main.new()
	root.build_from_graph(_make_fixture())

	_check(
		root.get_child_count() == 2,
		"Expected 2 scene-tree children (one per JSON node), got %d" % root.get_child_count()
	)

	root.free()
