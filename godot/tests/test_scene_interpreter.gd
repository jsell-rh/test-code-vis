## Behavioral tests for SceneInterpreter.
##
## Covers the rendering THEN clauses from specs/interaction/moldable-views.spec.md.
## Each test instantiates real Node3D scene objects, calls SceneInterpreter.apply()
## with fixture data, and asserts the resulting scene-tree property values — NOT
## intermediate dict keys.
##
## Scenario: Architectural question
##   THEN the system generates a view focused on auth-related components
##        → show op: anchor.visible == true
##   AND irrelevant components are hidden or de-emphasized
##        → hide op: anchor.visible == false
##   AND the relevant components are arranged to answer the question
##        → arrange op: anchor.position matches specified coordinates
##
## Scenario: Impact question
##   THEN the system generates a view showing the user database and all its dependents
##        → show op: anchor.visible == true
##   AND the dependency relationships are spatially clear
##        → connect op: ImmediateMesh line + CylinderMesh arrowhead added to scene_root
##
## Scenario: LLM produces view spec
##   AND the 3D renderer interprets the view spec into a spatial scene
##        → highlight op: material.albedo_color changes on MeshInstance3D
##        → annotate op: Label3D child added with correct text, billboard, pixel_size
##        → all 6 ops applied together mutate the correct scene-tree properties

extends RefCounted

const SceneInterpreter = preload("res://scripts/scene_interpreter.gd")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Build a Node3D anchor with an opaque MeshInstance3D child (like main.gd modules).
func _make_anchor_with_mesh() -> Node3D:
	var anchor := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 1.8, 3.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.70, 0.40, 1.0)
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	anchor.add_child(mesh_instance)
	return anchor


func _get_label3d_child(anchor: Node3D) -> Label3D:
	for child in anchor.get_children():
		if child is Label3D:
			return child as Label3D
	return null


func _get_mesh_material(anchor: Node3D) -> StandardMaterial3D:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			return child.material_override as StandardMaterial3D
	return null


# ---------------------------------------------------------------------------
# hide — Scenario: Architectural question
# AND irrelevant components are hidden or de-emphasized
# THEN: anchor.visible == false after hide op
# ---------------------------------------------------------------------------

## hide op sets anchor.visible = false.
## Implements: "irrelevant components are hidden or de-emphasized"
func test_hide_op_sets_visible_false() -> bool:
	var anchor := _make_anchor_with_mesh()
	anchor.visible = true

	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "how does authentication work?",
		"operations": [{"op": "hide", "ids": ["auth_service"]}],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return anchor.visible == false


## hide op leaves nodes not named in 'ids' with their original visibility.
func test_hide_op_leaves_other_nodes_unchanged() -> bool:
	var anchor_auth := _make_anchor_with_mesh()
	var anchor_pay := _make_anchor_with_mesh()
	anchor_auth.visible = true
	anchor_pay.visible = true

	var anchors := {"auth_service": anchor_auth, "payment_service": anchor_pay}
	var spec := {
		"question": "how does authentication work?",
		"operations": [{"op": "hide", "ids": ["auth_service"]}],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return anchor_auth.visible == false and anchor_pay.visible == true


# ---------------------------------------------------------------------------
# show — Scenario: Architectural question / Impact question
# THEN: anchor.visible == true after show op
# ---------------------------------------------------------------------------

## show op sets anchor.visible = true.
## Implements: "the system generates a view showing the user database and all its dependents"
func test_show_op_sets_visible_true() -> bool:
	var anchor := _make_anchor_with_mesh()
	anchor.visible = false

	var anchors := {"user_db": anchor}
	var spec := {
		"question": "what depends on the user database?",
		"operations": [{"op": "show", "ids": ["user_db"]}],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return anchor.visible == true


## show op does not affect nodes not named in 'ids'.
func test_show_op_leaves_other_nodes_unchanged() -> bool:
	var anchor_a := _make_anchor_with_mesh()
	var anchor_b := _make_anchor_with_mesh()
	anchor_a.visible = false
	anchor_b.visible = false

	var anchors := {"user_db": anchor_a, "other": anchor_b}
	var spec := {
		"question": "test",
		"operations": [{"op": "show", "ids": ["user_db"]}],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return anchor_a.visible == true and anchor_b.visible == false


# ---------------------------------------------------------------------------
# highlight — Scenario: Architectural question
# highlight op changes material.albedo_color on the MeshInstance3D child.
# ---------------------------------------------------------------------------

## highlight op changes albedo_color on the anchor's mesh material.
## Implements: "relevant components are highlighted"
func test_highlight_op_changes_albedo_color() -> bool:
	var anchor := _make_anchor_with_mesh()
	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "how does authentication work?",
		"operations": [
			{"op": "highlight", "ids": ["auth_service"], "color": [1.0, 0.5, 0.0]},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	var mat := _get_mesh_material(anchor)
	if mat == null:
		return false
	return (
		absf(mat.albedo_color.r - 1.0) < 0.01
		and absf(mat.albedo_color.g - 0.5) < 0.01
		and absf(mat.albedo_color.b - 0.0) < 0.01
	)


## highlight op with zero color components sets black.
func test_highlight_op_sets_black_color() -> bool:
	var anchor := _make_anchor_with_mesh()
	var anchors := {"node_a": anchor}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "highlight", "ids": ["node_a"], "color": [0.0, 0.0, 0.0]},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	var mat := _get_mesh_material(anchor)
	if mat == null:
		return false
	return (
		absf(mat.albedo_color.r - 0.0) < 0.01
		and absf(mat.albedo_color.g - 0.0) < 0.01
		and absf(mat.albedo_color.b - 0.0) < 0.01
	)


# ---------------------------------------------------------------------------
# arrange — Scenario: Architectural question
# AND the relevant components are arranged to answer the question
# arrange op MUST set anchor.position to the specified Vector3.
# ---------------------------------------------------------------------------

## arrange op sets anchor.position.x to the specified value.
## Implements: "relevant components are arranged to answer the question"
func test_arrange_op_sets_position_x() -> bool:
	var anchor := Node3D.new()
	anchor.position = Vector3.ZERO

	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "how does authentication work?",
		"operations": [
			{"op": "arrange", "id": "auth_service", "position": {"x": 5.0, "y": 0.0, "z": 0.0}},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return absf(anchor.position.x - 5.0) < 0.001


## arrange op sets anchor.position.z to the specified value.
func test_arrange_op_sets_position_z() -> bool:
	var anchor := Node3D.new()
	anchor.position = Vector3.ZERO

	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "arrange", "id": "auth_service", "position": {"x": 0.0, "y": 0.0, "z": -3.0}},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return absf(anchor.position.z - (-3.0)) < 0.001


## arrange op with all three axes.
func test_arrange_op_sets_all_three_axes() -> bool:
	var anchor := Node3D.new()
	anchor.position = Vector3.ZERO

	var anchors := {"node_x": anchor}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "arrange", "id": "node_x", "position": {"x": 1.0, "y": 2.0, "z": 3.0}},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return (
		absf(anchor.position.x - 1.0) < 0.001
		and absf(anchor.position.y - 2.0) < 0.001
		and absf(anchor.position.z - 3.0) < 0.001
	)


# ---------------------------------------------------------------------------
# annotate — add a Label3D child
# Guidelines: billboard == BILLBOARD_ENABLED and pixel_size > 0.0 are mandatory.
# ---------------------------------------------------------------------------

## annotate op adds a Label3D child to the anchor node.
## Implements: "add an annotation"
func test_annotate_op_adds_label3d() -> bool:
	var anchor := Node3D.new()
	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "annotate", "id": "auth_service", "text": "Entry point"},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	var label := _get_label3d_child(anchor)
	return label != null


## annotate op sets Label3D.text to the value from the operation.
func test_annotate_op_sets_label_text() -> bool:
	var anchor := Node3D.new()
	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "annotate", "id": "auth_service", "text": "Entry point"},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	var label := _get_label3d_child(anchor)
	if label == null:
		return false
	return label.text == "Entry point"


## annotate op enables BILLBOARD_ENABLED on the Label3D (mandatory for legibility).
func test_annotate_label_billboard_enabled() -> bool:
	var anchor := Node3D.new()
	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "annotate", "id": "auth_service", "text": "hello"},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	var label := _get_label3d_child(anchor)
	if label == null:
		return false
	return label.billboard == BaseMaterial3D.BILLBOARD_ENABLED


## annotate op sets pixel_size > 0.0 on the Label3D (mandatory for legibility).
func test_annotate_label_pixel_size_positive() -> bool:
	var anchor := Node3D.new()
	var anchors := {"auth_service": anchor}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "annotate", "id": "auth_service", "text": "hello"},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	var label := _get_label3d_child(anchor)
	if label == null:
		return false
	return label.pixel_size > 0.0


# ---------------------------------------------------------------------------
# connect — Scenario: Impact question
# AND the dependency relationships are spatially clear
# connect op MUST add a line mesh and an arrowhead to scene_root.
# ---------------------------------------------------------------------------

## connect op adds at least one MeshInstance3D (the line) to scene_root.
## Implements: "dependency relationships are spatially clear"
func test_connect_op_adds_line_geometry() -> bool:
	var anchor_a := Node3D.new()
	var anchor_b := Node3D.new()
	var anchors := {"auth_service": anchor_a, "user_db": anchor_b}
	# Supply explicit world positions so the headless test does not rely on
	# global_transform propagation (which requires a live SceneTree).
	var world_positions := {
		"auth_service": Vector3(0.0, 0.0, 0.0),
		"user_db": Vector3(5.0, 0.0, 0.0),
	}
	var spec := {
		"question": "what depends on the user database?",
		"operations": [
			{"op": "connect", "source": "auth_service", "target": "user_db"},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root, world_positions)

	# Expect at least one MeshInstance3D (the line) to have been added to root.
	for child in root.get_children():
		if child is MeshInstance3D:
			return true
	return false


## connect op draws an arrowhead: scene_root gets ≥ 2 MeshInstance3D children
## (one line + one cone arrowhead).
func test_connect_op_adds_arrowhead() -> bool:
	var anchor_a := Node3D.new()
	var anchor_b := Node3D.new()
	var anchors := {"auth_service": anchor_a, "user_db": anchor_b}
	var world_positions := {
		"auth_service": Vector3(0.0, 0.0, 0.0),
		"user_db": Vector3(5.0, 0.0, 0.0),
	}
	var spec := {
		"question": "test",
		"operations": [
			{"op": "connect", "source": "auth_service", "target": "user_db"},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root, world_positions)

	var mesh_count := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	# Expect line + arrowhead = at least 2.
	return mesh_count >= 2


## connect op with coincident endpoints draws nothing (no self-loop geometry).
func test_connect_op_skips_coincident_positions() -> bool:
	var anchor_a := Node3D.new()
	var anchor_b := Node3D.new()
	var anchors := {"a": anchor_a, "b": anchor_b}
	var world_positions := {
		"a": Vector3(3.0, 0.0, 0.0),
		"b": Vector3(3.0, 0.0, 0.0),  # same position
	}
	var spec := {
		"question": "test",
		"operations": [{"op": "connect", "source": "a", "target": "b"}],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root, world_positions)

	# Nothing should be added to root for a zero-length edge.
	return root.get_child_count() == 0


# ---------------------------------------------------------------------------
# Integration — all six operations applied together
# ---------------------------------------------------------------------------

## All 6 ops applied in sequence correctly mutate all scene-tree properties.
func test_all_six_ops_mutate_scene_correctly() -> bool:
	var anchor_a := _make_anchor_with_mesh()
	var anchor_b := _make_anchor_with_mesh()
	anchor_a.visible = false
	anchor_b.visible = true

	var anchors := {"auth_service": anchor_a, "user_db": anchor_b}
	var world_positions := {
		"auth_service": Vector3(0.0, 0.0, 0.0),
		"user_db": Vector3(5.0, 0.0, 0.0),
	}
	var spec := {
		"question": "how does authentication work?",
		"operations": [
			{"op": "show", "ids": ["auth_service"]},
			{"op": "hide", "ids": ["user_db"]},
			{"op": "highlight", "ids": ["auth_service"], "color": [0.0, 1.0, 0.0]},
			{"op": "arrange", "id": "auth_service", "position": {"x": 3.0, "y": 0.0, "z": 0.0}},
			{"op": "annotate", "id": "auth_service", "text": "focus"},
			{"op": "connect", "source": "auth_service", "target": "user_db"},
		],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root, world_positions)

	var mat_a := _get_mesh_material(anchor_a)
	var label := _get_label3d_child(anchor_a)
	var line_added := false
	for child in root.get_children():
		if child is MeshInstance3D:
			line_added = true
			break

	return (
		anchor_a.visible == true
		and anchor_b.visible == false
		and mat_a != null and absf(mat_a.albedo_color.g - 1.0) < 0.01
		and absf(anchor_a.position.x - 3.0) < 0.001
		and label != null and label.text == "focus"
		and line_added
	)


## Empty operations list applies nothing and does not crash.
func test_empty_spec_applies_nothing() -> bool:
	var anchor := _make_anchor_with_mesh()
	anchor.visible = true
	anchor.position = Vector3.ZERO

	var anchors := {"node_a": anchor}
	var spec := {"question": "test", "operations": []}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	return anchor.visible == true and anchor.position == Vector3.ZERO


## Unknown op type in operations array is silently ignored (no crash, no effect).
func test_unknown_op_is_ignored() -> bool:
	var anchor := _make_anchor_with_mesh()
	anchor.visible = true

	var anchors := {"node_a": anchor}
	var spec := {
		"question": "test",
		"operations": [{"op": "teleport", "id": "node_a"}],
	}
	var interp := SceneInterpreter.new()
	var root := Node3D.new()
	interp.apply(spec, anchors, root)

	# The unknown op must not crash and must not change visibility.
	return anchor.visible == true
