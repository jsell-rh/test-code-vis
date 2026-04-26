## Tests for Requirement: JSON Scene Graph Loading
##
## Spec scenario: Loading kartograph's scene graph
##   GIVEN a JSON scene graph file describing kartograph's structure
##   WHEN the Godot application starts
##   THEN it reads the JSON file
##   AND generates 3D volumes for each node
##   AND generates connections for each edge
##   AND positions elements according to the layout data in the JSON
##
## Implementation under test: godot/scripts/main.gd → build_from_graph()
extends RefCounted

const MainScript := preload("res://scripts/main.gd")


func _make_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx1",
				"name": "Context1",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 10.0,
			},
			{
				"id": "mod1",
				"name": "Module1",
				"type": "module",
				"parent": "ctx1",
				"position": {"x": 2.0, "y": 0.0, "z": 2.0},
				"size": 3.0,
			},
		],
		"edges": [
			{"source": "ctx1", "target": "mod1", "type": "internal"},
		],
	}


## THEN generates 3D volumes for each node —
## build_from_graph() must create an anchor entry in _anchors for every node id.
func test_volumes_created_for_each_node() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())
	return main_node._anchors.has("ctx1") and main_node._anchors.has("mod1")


## THEN generates 3D volumes — each anchor must contain a MeshInstance3D child.
func test_mesh_instances_exist_in_anchors() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	for node_id: String in ["ctx1", "mod1"]:
		var anchor: Node3D = main_node._anchors.get(node_id)
		if anchor == null:
			return false
		var has_mesh := false
		for child: Node in anchor.get_children():
			if child is MeshInstance3D:
				has_mesh = true
				break
		if not has_mesh:
			return false
	return true


## AND generates connections for each edge —
## build_from_graph() adds at least one MeshInstance3D to the main node for each edge
## (the line mesh) plus at least one more for the arrowhead cone.
func test_edge_mesh_instances_created() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var edge_mesh_count := 0
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			edge_mesh_count += 1

	# Each edge produces: 1 ImmediateMesh line + 1 CylinderMesh arrowhead = 2
	return edge_mesh_count >= 2


## AND positions elements according to the layout data in the JSON —
## The local position on each anchor must match the "position" field in the JSON.
func test_anchor_positions_match_json() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var ctx_anchor: Node3D = main_node._anchors.get("ctx1")
	var mod_anchor: Node3D = main_node._anchors.get("mod1")
	if ctx_anchor == null or mod_anchor == null:
		return false

	var ctx_ok := ctx_anchor.position.is_equal_approx(Vector3(0.0, 0.0, 0.0))
	# mod1's position in JSON is {x:2, y:0, z:2} relative to its parent ctx1.
	var mod_ok := mod_anchor.position.is_equal_approx(Vector3(2.0, 0.0, 2.0))
	return ctx_ok and mod_ok


## THEN it reads the JSON file —
## FileAccess.open() on the fixture data file must succeed and return non-empty text.
## This verifies the Godot project can read the JSON scene graph produced by the extractor.
func test_file_access_reads_fixture_json() -> bool:
	var file := FileAccess.open("res://data/scene_graph.json", FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	return text.length() > 0


## AND positions elements according to the layout data in the JSON —
## (spec-named alias for test_anchor_positions_match_json)
## Anchor positions must match the "position" field in the JSON exactly.
func test_volumes_positioned_from_json() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var ctx_anchor: Node3D = main_node._anchors.get("ctx1")
	var mod_anchor: Node3D = main_node._anchors.get("mod1")
	if ctx_anchor == null or mod_anchor == null:
		return false

	var ctx_ok := ctx_anchor.position.is_equal_approx(Vector3(0.0, 0.0, 0.0))
	# mod1's position in JSON is {x:2, y:0, z:2} relative to its parent ctx1.
	var mod_ok := mod_anchor.position.is_equal_approx(Vector3(2.0, 0.0, 2.0))
	return ctx_ok and mod_ok


## AND labels scale to remain readable —
## Each anchor's Label3D must use BILLBOARD_ENABLED so it always faces the camera,
## have a positive pixel_size, and no_depth_test=true so labels are visible
## through geometry at all zoom levels.
func test_labels_are_billboard_and_readable() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var anchor: Node3D = main_node._anchors.get("ctx1")
	if anchor == null:
		return false

	for child: Node in anchor.get_children():
		if child is Label3D:
			var lbl := child as Label3D
			var billboard_ok := lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED
			var pixel_size_ok := lbl.pixel_size > 0.0
			var depth_ok := lbl.no_depth_test == true
			return billboard_ok and pixel_size_ok and depth_ok

	# No Label3D found in anchor — test fails.
	return false
