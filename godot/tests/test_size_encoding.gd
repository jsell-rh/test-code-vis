## Tests for Requirement: Size Encoding
##
## Spec scenario: Large module vs small module
##   GIVEN two modules with different lines-of-code metrics
##   WHEN the scene is rendered
##   THEN the module with more code appears as a larger volume
##   AND the relative sizes are proportional to the metric
##
## Implementation under test: godot/scripts/main.gd → _create_volume()
##   sz = float(nd["size"]) is applied directly as BoxMesh.size dimensions,
##   so the mesh width (x) ratio equals the input size ratio.
extends RefCounted

const MainScript := preload("res://scripts/main.gd")


func _make_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "small_mod",
				"name": "SmallModule",
				"type": "module",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "large_mod",
				"name": "LargeModule",
				"type": "module",
				"parent": null,
				"position": {"x": 15.0, "y": 0.0, "z": 0.0},
				"size": 9.0,
			},
		],
		"edges": [],
	}


func _get_box_mesh(main_node: Node3D, node_id: String) -> BoxMesh:
	var anchor: Node3D = main_node._anchors.get(node_id)
	if anchor == null:
		return null
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).mesh as BoxMesh
	return null


## THEN the module with more code appears as a larger volume —
## the large module's BoxMesh.size.x must exceed the small module's.
func test_large_module_has_bigger_mesh() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var small_mesh: BoxMesh = _get_box_mesh(main_node, "small_mod")
	var large_mesh: BoxMesh = _get_box_mesh(main_node, "large_mod")
	if small_mesh == null or large_mesh == null:
		return false

	return large_mesh.size.x > small_mesh.size.x


## THEN the module with more code appears as a larger volume —
## All size dimensions of every module mesh must be strictly positive.
func test_module_size_is_positive() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	for nid: String in ["small_mod", "large_mod"]:
		var mesh: BoxMesh = _get_box_mesh(main_node, nid)
		if mesh == null:
			return false
		if mesh.size.x <= 0.0 or mesh.size.y <= 0.0 or mesh.size.z <= 0.0:
			return false
	return true


## AND the relative sizes are proportional to the metric —
## large_mod size=9, small_mod size=3 → expected ratio = 3.0.
## BoxMesh.size.x ratio must match within floating-point tolerance.
func test_mesh_sizes_proportional_to_metric() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var small_mesh: BoxMesh = _get_box_mesh(main_node, "small_mod")
	var large_mesh: BoxMesh = _get_box_mesh(main_node, "large_mod")
	if small_mesh == null or large_mesh == null:
		return false

	var expected_ratio: float = 9.0 / 3.0  # 3.0
	var actual_ratio: float = large_mesh.size.x / small_mesh.size.x
	return abs(actual_ratio - expected_ratio) < 0.001
