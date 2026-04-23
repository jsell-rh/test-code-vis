## Tests for Requirement: Containment Rendering
##
## Spec scenario: Modules inside a bounded context
##   GIVEN a bounded context node containing module nodes
##   WHEN the scene is rendered
##   THEN the bounded context appears as a larger translucent volume
##   AND its child modules appear as smaller opaque volumes inside it
##   AND the boundary of the parent is visually distinct from the children
##
## Implementation under test: godot/scripts/main.gd → _create_volume()
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
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
		],
		"edges": [],
	}


func _get_mesh_material(anchor: Node3D) -> StandardMaterial3D:
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).material_override as StandardMaterial3D
	return null


func _get_box_mesh(anchor: Node3D) -> BoxMesh:
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).mesh as BoxMesh
	return null


## THEN the bounded context appears as a larger translucent volume —
## its material must use TRANSPARENCY_ALPHA and have alpha < 1.
func test_bounded_context_is_translucent() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var ctx_anchor: Node3D = main_node._anchors.get("ctx1")
	if ctx_anchor == null:
		return false
	var mat: StandardMaterial3D = _get_mesh_material(ctx_anchor)
	if mat == null:
		return false

	return (
		mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		and mat.albedo_color.a < 1.0
	)


## AND its child modules appear as smaller opaque volumes —
## module material must have alpha == 1 (fully opaque).
func test_module_is_opaque() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var mod_anchor: Node3D = main_node._anchors.get("mod1")
	if mod_anchor == null:
		return false
	var mat: StandardMaterial3D = _get_mesh_material(mod_anchor)
	if mat == null:
		return false

	return mat.albedo_color.a >= 1.0


## AND its child modules appear inside it —
## the module anchor must be a direct child of the context anchor.
func test_module_parented_inside_context() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var ctx_anchor: Node3D = main_node._anchors.get("ctx1")
	var mod_anchor: Node3D = main_node._anchors.get("mod1")
	if ctx_anchor == null or mod_anchor == null:
		return false

	return mod_anchor.get_parent() == ctx_anchor


## THEN the bounded context appears as a larger volume —
## its BoxMesh.size.x must exceed the module's BoxMesh.size.x.
func test_bounded_context_larger_than_module() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var ctx_mesh: BoxMesh = _get_box_mesh(main_node._anchors.get("ctx1"))
	var mod_mesh: BoxMesh = _get_box_mesh(main_node._anchors.get("mod1"))
	if ctx_mesh == null or mod_mesh == null:
		return false

	return ctx_mesh.size.x > mod_mesh.size.x


## AND the boundary of the parent is visually distinct —
## bounded_context uses CULL_DISABLED so it is visible from all angles,
## distinguishing it from children which use default back-face culling.
func test_bounded_context_cull_disabled() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_fixture())

	var ctx_anchor: Node3D = main_node._anchors.get("ctx1")
	if ctx_anchor == null:
		return false
	var mat: StandardMaterial3D = _get_mesh_material(ctx_anchor)
	if mat == null:
		return false

	return mat.cull_mode == BaseMaterial3D.CULL_DISABLED
