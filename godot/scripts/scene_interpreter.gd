class_name SceneInterpreter
extends RefCounted

## Scene Interpreter — Stage 2 of the moldable-views pipeline.
##
## Consumes a view specification dictionary produced by LlmViewGenerator.parse_response()
## and applies it to the live 3D scene by mutating Node3D properties.
##
## Supported operations (the fixed visual primitive set):
##   show      — set anchor.visible = true
##   hide      — set anchor.visible = false  (de-emphasizes irrelevant components)
##   highlight — change MeshInstance3D material albedo_color to HIGHLIGHT_COLOR
##   arrange   — set anchor.position to the specified Vector3
##   annotate  — add a Label3D text annotation above the target node
##   connect   — draw an ImmediateMesh line between two nodes
##
## Parameters to apply_spec():
##   spec       — dict {"operations": [...]} from LlmViewGenerator.parse_response()
##   anchors    — Dictionary mapping node_id (String) → Node3D
##   scene_root — Node3D that owns annotations and connection lines

## Highlight color applied by the 'highlight' operation.
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.85, 0.0, 1.0)


## Apply all operations in a view spec to the live 3D scene.
##
## For each operation in spec["operations"], the matching handler mutates
## the corresponding anchor's scene-tree properties.  Unknown targets are
## silently skipped.
func apply_spec(spec: Dictionary, anchors: Dictionary, scene_root: Node3D) -> void:
	var ops: Array = spec.get("operations", [])
	for op in ops:
		var op_name: String = op.get("op", "")
		match op_name:
			"show":
				_apply_show(op, anchors)
			"hide":
				_apply_hide(op, anchors)
			"highlight":
				_apply_highlight(op, anchors)
			"arrange":
				_apply_arrange(op, anchors)
			"annotate":
				_apply_annotate(op, anchors, scene_root)
			"connect":
				_apply_connect(op, anchors, scene_root)


# ---------------------------------------------------------------------------
# show — make a node visible
# ---------------------------------------------------------------------------

func _apply_show(op: Dictionary, anchors: Dictionary) -> void:
	var target: String = op.get("target", "")
	var anchor: Node3D = anchors.get(target) as Node3D
	if anchor == null:
		return
	anchor.visible = true


# ---------------------------------------------------------------------------
# hide — de-emphasize / hide a node
# ---------------------------------------------------------------------------

func _apply_hide(op: Dictionary, anchors: Dictionary) -> void:
	var target: String = op.get("target", "")
	var anchor: Node3D = anchors.get(target) as Node3D
	if anchor == null:
		return
	anchor.visible = false


# ---------------------------------------------------------------------------
# highlight — change material color to draw attention
# ---------------------------------------------------------------------------

func _apply_highlight(op: Dictionary, anchors: Dictionary) -> void:
	var target: String = op.get("target", "")
	var anchor: Node3D = anchors.get(target) as Node3D
	if anchor == null:
		return
	# Apply highlight color to the first MeshInstance3D child.
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = HIGHLIGHT_COLOR
			(child as MeshInstance3D).material_override = mat
			break


# ---------------------------------------------------------------------------
# arrange — move a node to a specified position
# ---------------------------------------------------------------------------

func _apply_arrange(op: Dictionary, anchors: Dictionary) -> void:
	var target: String = op.get("target", "")
	var anchor: Node3D = anchors.get(target) as Node3D
	if anchor == null:
		return
	var pos = op.get("position", null)
	if pos is Dictionary:
		anchor.position = Vector3(
			float(pos.get("x", anchor.position.x)),
			float(pos.get("y", anchor.position.y)),
			float(pos.get("z", anchor.position.z))
		)


# ---------------------------------------------------------------------------
# annotate — add a Label3D text annotation above the target node
# ---------------------------------------------------------------------------

func _apply_annotate(op: Dictionary, anchors: Dictionary, scene_root: Node3D) -> void:
	var target: String = op.get("target", "")
	var text: String = op.get("text", "")
	var anchor: Node3D = anchors.get(target) as Node3D
	if anchor == null or text.is_empty():
		return

	var label := Label3D.new()
	label.text = text
	# Mandatory for legibility in 3D — a Label3D at default settings is illegible.
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.05
	label.no_depth_test = true
	# Position the annotation above the anchor node.
	label.position = anchor.position + Vector3(0.0, 2.0, 0.0)
	scene_root.add_child(label)


# ---------------------------------------------------------------------------
# connect — draw a line between two nodes
# ---------------------------------------------------------------------------

func _apply_connect(op: Dictionary, anchors: Dictionary, scene_root: Node3D) -> void:
	var source_id: String = op.get("source", "")
	var target_id: String = op.get("target", "")
	var src_anchor: Node3D = anchors.get(source_id) as Node3D
	var tgt_anchor: Node3D = anchors.get(target_id) as Node3D
	if src_anchor == null or tgt_anchor == null:
		return

	var from_pos: Vector3 = src_anchor.position
	var to_pos: Vector3 = tgt_anchor.position

	if from_pos.is_equal_approx(to_pos):
		return  # No line for coincident nodes.

	var imesh := ImmediateMesh.new()
	imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	imesh.surface_set_color(Color(0.2, 0.8, 1.0))
	imesh.surface_add_vertex(from_pos)
	imesh.surface_set_color(Color(0.2, 0.8, 1.0))
	imesh.surface_add_vertex(to_pos)
	imesh.surface_end()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = imesh
	mesh_instance.material_override = mat
	scene_root.add_child(mesh_instance)
