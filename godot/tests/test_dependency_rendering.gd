## Tests for Requirement: Dependency Rendering
##
## Spec scenario: Rendering a cross-context dependency
##   GIVEN an edge from graph context to shared_kernel context
##   WHEN the scene is rendered
##   THEN a line connects the two context volumes
##   AND the line's direction is visually indicated
##
## Implementation under test: godot/scripts/main.gd → _create_edge()
##
## Direction indicator: a CylinderMesh with top_radius=0 (cone) is placed at
## the target end, oriented along the edge direction, so the pointed tip marks
## where the dependency flows to.
extends RefCounted

const MainScript := preload("res://scripts/main.gd")


func _make_fixture_internal() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx1",
				"name": "GraphCtx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 8.0,
			},
			{
				"id": "ctx2",
				"name": "SharedKernel",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"size": 8.0,
			},
		],
		"edges": [
			{"source": "ctx1", "target": "ctx2", "type": "internal"},
		],
	}


func _make_fixture_cross_context() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx1",
				"name": "GraphCtx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 8.0,
			},
			{
				"id": "ctx2",
				"name": "SharedKernel",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"size": 8.0,
			},
		],
		"edges": [
			{"source": "ctx1", "target": "ctx2", "type": "cross_context"},
		],
	}


## THEN a line connects the two context volumes —
## _create_edge() adds an ImmediateMesh MeshInstance3D as a child of the main node.
func test_edge_line_mesh_created() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_internal())

	var found := false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			if (child as MeshInstance3D).mesh is ImmediateMesh:
				found = true
				break

	main_node.free()
	return found


## AND the line's direction is visually indicated —
## a CylinderMesh with top_radius == 0 (arrowhead cone) must exist among the
## main node's children after _create_edge() runs.
func test_direction_indicator_cone_created() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_internal())

	var found := false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is CylinderMesh:
				var cone := mi.mesh as CylinderMesh
				if cone.top_radius == 0.0:
					found = true
					break

	main_node.free()
	return found


## The direction cone must be positioned near the target end of the edge
## (within 2 units of to_pos = (20, 0, 0)) so that it marks the arrival point.
func test_direction_cone_near_target() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_internal())

	var target_pos := Vector3(20.0, 0.0, 0.0)
	var result := false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if not (mi.mesh is CylinderMesh):
				continue
			var cone := mi.mesh as CylinderMesh
			if cone.top_radius == 0.0:
				result = mi.position.distance_to(target_pos) < 2.0
				break

	main_node.free()
	return result


## Color of a cross_context edge's arrow cone must be orange
## (R > 0.8, B < 0.3) to distinguish it from internal edges.
func test_cross_context_cone_is_orange() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture_cross_context())

	var result := false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if not (mi.mesh is CylinderMesh):
				continue
			var cone := mi.mesh as CylinderMesh
			if cone.top_radius != 0.0:
				continue
			var mat := mi.material_override as StandardMaterial3D
			if mat == null:
				break
			# Orange: Color(1.0, 0.50, 0.10)
			result = mat.albedo_color.r > 0.8 and mat.albedo_color.b < 0.3
			break

	main_node.free()
	return result
