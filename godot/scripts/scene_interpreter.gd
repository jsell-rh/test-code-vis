class_name SceneInterpreter
extends RefCounted

## Interprets a view-spec dictionary produced by LLMViewGenerator.parse_response()
## and applies it to the live 3D scene tree.
##
## This is Stage 2 of the moldable-views pipeline:
##   LLMViewGenerator.parse_response() → ViewSpec dict → SceneInterpreter.apply()
##                                                         ↓
##                                                  mutations on Node3D
##
## Supported operations (matching LLMViewGenerator.VALID_OPS):
##   show:      anchor.visible = true
##   hide:      anchor.visible = false
##   highlight: MeshInstance3D material.albedo_color = Color(r, g, b)
##   arrange:   anchor.position = Vector3(x, y, z)
##   annotate:  add Label3D child (billboard + pixel_size mandatory for legibility)
##   connect:   draw ImmediateMesh line + CylinderMesh arrowhead on scene_root
##
## Requirement: View Specs as Intermediate Representation
##   The LLM generates a view spec; the renderer (this class) interprets it.
##   The 3D renderer interprets the view spec into a spatial scene.
##
## Requirement: Fixed Visual Primitive Set
##   Only the fixed set of operations are handled; no new rendering logic
##   can enter this interpreter at runtime.


## Apply every operation in a view spec to the live 3D scene.
##
## spec:            Dictionary from LLMViewGenerator.parse_response(), containing
##                  "question" (String) and "operations" (Array of Dictionaries).
## anchors:         node_id → Node3D map — the scene anchors built by main.gd.
## scene_root:      Node3D that owns the scene; new geometry (lines/arrowheads) is
##                  added here.
## world_positions: Optional node_id → Vector3 for connect endpoints. When present,
##                  these world-space positions are used for the line start/end.
##                  When absent for a given id, falls back to anchor.position.
func apply(
	spec: Dictionary,
	anchors: Dictionary,
	scene_root: Node3D,
	world_positions: Dictionary = {}
) -> void:
	for op in spec.get("operations", []):
		if not op is Dictionary:
			continue
		match op.get("op", ""):
			"show":
				_apply_show(op, anchors)
			"hide":
				_apply_hide(op, anchors)
			"highlight":
				_apply_highlight(op, anchors)
			"arrange":
				_apply_arrange(op, anchors)
			"annotate":
				_apply_annotate(op, anchors)
			"connect":
				_apply_connect(op, anchors, scene_root, world_positions)


# ---------------------------------------------------------------------------
# show — set anchor.visible = true
# ---------------------------------------------------------------------------

func _apply_show(op: Dictionary, anchors: Dictionary) -> void:
	for id in op.get("ids", []):
		var anchor = anchors.get(id)
		if anchor is Node3D:
			anchor.visible = true


# ---------------------------------------------------------------------------
# hide — set anchor.visible = false
# ---------------------------------------------------------------------------

func _apply_hide(op: Dictionary, anchors: Dictionary) -> void:
	for id in op.get("ids", []):
		var anchor = anchors.get(id)
		if anchor is Node3D:
			anchor.visible = false


# ---------------------------------------------------------------------------
# highlight — change the MeshInstance3D material's albedo_color
# ---------------------------------------------------------------------------

func _apply_highlight(op: Dictionary, anchors: Dictionary) -> void:
	var color_arr: Array = op.get("color", [1.0, 1.0, 0.0])
	var r: float = float(color_arr[0]) if color_arr.size() > 0 else 1.0
	var g: float = float(color_arr[1]) if color_arr.size() > 1 else 1.0
	var b: float = float(color_arr[2]) if color_arr.size() > 2 else 0.0
	var color := Color(r, g, b)

	for id in op.get("ids", []):
		var anchor = anchors.get(id)
		if not anchor is Node3D:
			continue
		for child in anchor.get_children():
			if child is MeshInstance3D:
				var mat = child.material_override
				if mat is StandardMaterial3D:
					mat.albedo_color = color
				break


# ---------------------------------------------------------------------------
# arrange — reposition anchor to specified coordinates
# ---------------------------------------------------------------------------

func _apply_arrange(op: Dictionary, anchors: Dictionary) -> void:
	var id: String = op.get("id", "")
	var pos_dict: Dictionary = op.get("position", {})
	var anchor = anchors.get(id)
	if anchor is Node3D:
		anchor.position = Vector3(
			float(pos_dict.get("x", 0.0)),
			float(pos_dict.get("y", 0.0)),
			float(pos_dict.get("z", 0.0))
		)


# ---------------------------------------------------------------------------
# annotate — add a Label3D annotation to the anchor
# billboard and pixel_size are mandatory for 3D legibility.
# ---------------------------------------------------------------------------

func _apply_annotate(op: Dictionary, anchors: Dictionary) -> void:
	var id: String = op.get("id", "")
	var text: String = op.get("text", "")
	var anchor = anchors.get(id)
	if not anchor is Node3D:
		return

	var label := Label3D.new()
	label.text = text
	# Mandatory for legibility: always face the camera.
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Mandatory for legibility: pixel_size must be > 0.
	label.pixel_size = 0.05
	# Offset upward so the annotation floats above the node.
	label.position = Vector3(0.0, 2.0, 0.0)
	anchor.add_child(label)


# ---------------------------------------------------------------------------
# connect — draw a line + arrowhead between two anchors
# ---------------------------------------------------------------------------

func _apply_connect(
	op: Dictionary,
	anchors: Dictionary,
	scene_root: Node3D,
	world_positions: Dictionary
) -> void:
	var src_id: String = op.get("source", "")
	var tgt_id: String = op.get("target", "")

	# Resolve start/end positions — prefer explicit world_positions over anchor.position.
	var from_pos: Vector3
	if world_positions.has(src_id):
		from_pos = world_positions[src_id]
	else:
		var src_anchor = anchors.get(src_id)
		if not src_anchor is Node3D:
			return
		from_pos = src_anchor.position

	var to_pos: Vector3
	if world_positions.has(tgt_id):
		to_pos = world_positions[tgt_id]
	else:
		var tgt_anchor = anchors.get(tgt_id)
		if not tgt_anchor is Node3D:
			return
		to_pos = tgt_anchor.position

	if from_pos.is_equal_approx(to_pos):
		return  # Nothing to draw for coincident points.

	# Cyan line — visually distinct from static dependency edges (orange/grey).
	var line_color: Color = Color(0.2, 0.8, 1.0)

	# Line mesh.
	var imesh := ImmediateMesh.new()
	imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	imesh.surface_set_color(line_color)
	imesh.surface_add_vertex(from_pos)
	imesh.surface_set_color(line_color)
	imesh.surface_add_vertex(to_pos)
	imesh.surface_end()

	var line_mat := StandardMaterial3D.new()
	line_mat.vertex_color_use_as_albedo = true
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var line_instance := MeshInstance3D.new()
	line_instance.mesh = imesh
	line_instance.material_override = line_mat
	scene_root.add_child(line_instance)

	# Arrowhead — CylinderMesh with top_radius=0 gives a pointed cone.
	var dir: Vector3 = (to_pos - from_pos).normalized()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.2
	cone_mesh.height = 0.6
	cone_mesh.radial_segments = 8

	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = line_color
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var arrow := MeshInstance3D.new()
	arrow.mesh = cone_mesh
	arrow.material_override = cone_mat
	# Orient cone tip (+Y) along the edge direction.
	arrow.basis = Basis(Quaternion(Vector3.UP, dir))
	# Centre the cone so its tip lands at to_pos.
	arrow.position = to_pos - dir * (cone_mesh.height * 0.5)
	scene_root.add_child(arrow)
