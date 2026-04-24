## Tests for SceneInterpreter — Stage 2 of the moldable-views pipeline.
##
## Instantiates real Node3D objects and asserts actual scene-tree property values.
##
## Covers THEN-clauses from specs/interaction/moldable-views.spec.md:
##
## Scenario: Architectural question
##   THEN the system generates a view focused on auth-related components
##     → test_show_op_makes_anchor_visible
##   AND irrelevant components are hidden or de-emphasized
##     → test_hide_op_hides_irrelevant_components, test_hide_op_sets_visible_false
##   AND the relevant components are arranged to answer the question
##     → test_arrange_op_sets_node_position, test_arrange_op_positions_relevant_components
##
## Scenario: Impact question
##   THEN the system generates a view showing the user database and all its dependents
##     → test_apply_spec_with_multiple_show_hide_ops
##   AND the dependency relationships are spatially clear
##     → test_connect_op_creates_line_between_nodes
##
## Scenario: LLM produces view spec
##   AND the view spec controls which elements are shown, hidden, highlighted, and arranged
##     → show/hide/highlight/arrange test functions
##   AND the 3D renderer interprets the view spec into a spatial scene
##     → all tests — they call apply_spec() and assert Node3D scene-tree properties

const SceneInterpreter = preload("res://scripts/scene_interpreter.gd")

var _test_failed: bool = false
var _runner: Object = null


func _check(condition: bool, msg: String) -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg)


# ---------------------------------------------------------------------------
# Fixture helpers — create real Node3D objects with MeshInstance3D children
# ---------------------------------------------------------------------------

func _make_anchor_with_mesh(id: String, pos: Vector3) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = id.replace(".", "_")
	anchor.position = pos

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	mesh_instance.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 0.4, 1.0)
	mesh_instance.material_override = mat

	anchor.add_child(mesh_instance)
	return anchor


func _build_scene(ids: Array, root: Node3D) -> Dictionary:
	var anchors: Dictionary = {}
	for i in range(ids.size()):
		var anchor := _make_anchor_with_mesh(ids[i], Vector3(float(i) * 5.0, 0.0, 0.0))
		root.add_child(anchor)
		anchors[ids[i]] = anchor
	return anchors


# ---------------------------------------------------------------------------
# show operation — THEN the system generates a view focused on relevant components
# ---------------------------------------------------------------------------

func test_show_op_makes_anchor_visible() -> void:
	## THEN the system generates a view focused on auth-related components
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam", "graph"], root)

	(anchors["iam"] as Node3D).visible = false  # start hidden

	var spec: Dictionary = {"operations": [{"op": "show", "target": "iam"}]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["iam"] as Node3D).visible == true,
		"show op must set anchor.visible = true")

	root.queue_free()


func test_show_op_does_not_affect_other_nodes() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam", "graph"], root)
	(anchors["graph"] as Node3D).visible = false

	var spec: Dictionary = {"operations": [{"op": "show", "target": "iam"}]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["graph"] as Node3D).visible == false,
		"show op must not affect non-target nodes")

	root.queue_free()


# ---------------------------------------------------------------------------
# hide operation — AND irrelevant components are hidden or de-emphasized
# ---------------------------------------------------------------------------

func test_hide_op_sets_visible_false() -> void:
	## AND irrelevant components are hidden or de-emphasized
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [{"op": "hide", "target": "iam"}]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["iam"] as Node3D).visible == false,
		"hide op must set anchor.visible = false")

	root.queue_free()


func test_hide_op_hides_irrelevant_components() -> void:
	## AND irrelevant components are hidden or de-emphasized
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam", "graph", "billing"], root)

	var spec: Dictionary = {"operations": [
		{"op": "hide", "target": "graph"},
		{"op": "hide", "target": "billing"},
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["graph"] as Node3D).visible == false,
		"hide op must set graph.visible = false")
	_check((anchors["billing"] as Node3D).visible == false,
		"hide op must set billing.visible = false")
	_check((anchors["iam"] as Node3D).visible == true,
		"non-hidden node must remain visible")

	root.queue_free()


# ---------------------------------------------------------------------------
# highlight operation — view spec controls which elements are highlighted
# ---------------------------------------------------------------------------

func test_highlight_op_changes_albedo_color() -> void:
	## AND the view spec controls which elements are … highlighted
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [{"op": "highlight", "target": "iam"}]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var anchor: Node3D = anchors["iam"]
	var found_highlight: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override
			if mat != null:
				# Highlight color has high red channel (>= 0.9) — distinct from original green
				if mat.albedo_color.r >= 0.9:
					found_highlight = true
				break
	_check(found_highlight, "highlight op must change albedo_color.r to highlight value (>= 0.9)")

	root.queue_free()


func test_highlight_op_changes_color_from_original() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var original_green := Color(0.3, 0.6, 0.4, 1.0)  # fixture default

	var spec: Dictionary = {"operations": [{"op": "highlight", "target": "iam"}]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var anchor: Node3D = anchors["iam"]
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override
			if mat != null:
				_check(mat.albedo_color != original_green,
					"highlight must change albedo_color away from the original")
			break

	root.queue_free()


# ---------------------------------------------------------------------------
# arrange operation — AND the relevant components are arranged to answer the question
# ---------------------------------------------------------------------------

func test_arrange_op_sets_node_position() -> void:
	## AND the relevant components are arranged to answer the question
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [
		{"op": "arrange", "target": "iam", "position": {"x": 10.0, "y": 2.0, "z": -5.0}}
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var anchor: Node3D = anchors["iam"]
	_check(anchor.position.x == 10.0, "arrange op must set position.x = 10.0")
	_check(anchor.position.y == 2.0,  "arrange op must set position.y = 2.0")
	_check(anchor.position.z == -5.0, "arrange op must set position.z = -5.0")

	root.queue_free()


func test_arrange_op_positions_relevant_components() -> void:
	## AND the relevant components are arranged to answer the question
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["auth", "users", "billing"], root)

	var spec: Dictionary = {"operations": [
		{"op": "arrange", "target": "auth",  "position": {"x": 0.0, "y": 0.0, "z": 0.0}},
		{"op": "arrange", "target": "users", "position": {"x": 3.0, "y": 0.0, "z": 0.0}},
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["auth"] as Node3D).position.x == 0.0,
		"arrange auth.position.x must be 0.0")
	_check((anchors["users"] as Node3D).position.x == 3.0,
		"arrange users.position.x must be 3.0")

	root.queue_free()


# ---------------------------------------------------------------------------
# annotate operation — AND the 3D renderer interprets the view spec into a spatial scene
# ---------------------------------------------------------------------------

func test_annotate_op_creates_label3d() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [
		{"op": "annotate", "target": "iam", "text": "Entry point for authentication"}
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var found_label: bool = false
	for child in root.get_children():
		if child is Label3D:
			found_label = true
			break
	_check(found_label, "annotate op must create a Label3D child of scene_root")

	root.queue_free()


func test_annotate_op_sets_label_text() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [
		{"op": "annotate", "target": "iam", "text": "auth entry"}
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var label: Label3D = null
	for child in root.get_children():
		if child is Label3D:
			label = child
			break
	_check(label != null, "annotate must create a Label3D")
	if label != null:
		_check(label.text == "auth entry", "Label3D text must match the annotation text")

	root.queue_free()


func test_annotate_op_sets_billboard() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [
		{"op": "annotate", "target": "iam", "text": "note"}
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var label: Label3D = null
	for child in root.get_children():
		if child is Label3D:
			label = child
			break
	_check(label != null, "annotate must create a Label3D")
	if label != null:
		_check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
			"Label3D billboard must be BILLBOARD_ENABLED (mandatory for 3D legibility)")

	root.queue_free()


func test_annotate_op_sets_pixel_size_positive() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [
		{"op": "annotate", "target": "iam", "text": "note"}
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var label: Label3D = null
	for child in root.get_children():
		if child is Label3D:
			label = child
			break
	_check(label != null, "annotate must create a Label3D")
	if label != null:
		_check(label.pixel_size > 0.0,
			"Label3D pixel_size must be > 0.0 (mandatory for legibility in 3D)")

	root.queue_free()


# ---------------------------------------------------------------------------
# connect operation — AND the dependency relationships are spatially clear
# ---------------------------------------------------------------------------

func test_connect_op_creates_line_between_nodes() -> void:
	## AND the dependency relationships are spatially clear
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["user_db", "orders"], root)

	(anchors["user_db"] as Node3D).position = Vector3(0.0, 0.0, 0.0)
	(anchors["orders"] as Node3D).position  = Vector3(10.0, 0.0, 0.0)

	var children_before: int = root.get_child_count()

	var spec: Dictionary = {"operations": [
		{"op": "connect", "source": "user_db", "target": "orders"}
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check(root.get_child_count() > children_before,
		"connect op must add a line MeshInstance3D to the scene root")

	root.queue_free()


func test_connect_op_adds_mesh_instance() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["a", "b"], root)

	(anchors["a"] as Node3D).position = Vector3(0.0, 0.0, 0.0)
	(anchors["b"] as Node3D).position = Vector3(5.0, 0.0, 0.0)

	var spec: Dictionary = {"operations": [
		{"op": "connect", "source": "a", "target": "b"}
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	var found_mesh: bool = false
	for child in root.get_children():
		if child is MeshInstance3D:
			found_mesh = true
			break
	_check(found_mesh, "connect op must create a MeshInstance3D line in scene_root")

	root.queue_free()


# ---------------------------------------------------------------------------
# Integration / multi-operation tests
# ---------------------------------------------------------------------------

func test_apply_spec_with_multiple_show_hide_ops() -> void:
	## THEN the system generates a view showing the user database and all its dependents
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["user_db", "orders", "billing", "unrelated"], root)

	var spec: Dictionary = {"operations": [
		{"op": "show", "target": "user_db"},
		{"op": "show", "target": "orders"},
		{"op": "show", "target": "billing"},
		{"op": "hide", "target": "unrelated"},
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["user_db"] as Node3D).visible == true,  "user_db must be visible")
	_check((anchors["orders"] as Node3D).visible == true,   "orders must be visible")
	_check((anchors["billing"] as Node3D).visible == true,  "billing must be visible")
	_check((anchors["unrelated"] as Node3D).visible == false, "unrelated must be hidden")

	root.queue_free()


func test_apply_spec_combined_operations() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["auth", "users", "orders", "billing"], root)

	var spec: Dictionary = {"operations": [
		{"op": "show",      "target": "auth"},
		{"op": "show",      "target": "users"},
		{"op": "hide",      "target": "billing"},
		{"op": "highlight", "target": "auth"},
		{"op": "arrange",   "target": "auth",  "position": {"x": 0.0, "y": 0.0, "z": 0.0}},
		{"op": "arrange",   "target": "users", "position": {"x": 5.0, "y": 0.0, "z": 0.0}},
	]}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["auth"] as Node3D).visible == true,    "auth must be visible")
	_check((anchors["users"] as Node3D).visible == true,   "users must be visible")
	_check((anchors["billing"] as Node3D).visible == false, "billing must be hidden")
	_check((anchors["auth"] as Node3D).position.x == 0.0,  "auth.position.x must be 0.0")
	_check((anchors["users"] as Node3D).position.x == 5.0, "users.position.x must be 5.0")

	root.queue_free()


func test_empty_spec_changes_nothing() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)
	(anchors["iam"] as Node3D).position = Vector3(1.0, 2.0, 3.0)

	var spec: Dictionary = {"operations": []}
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["iam"] as Node3D).position.x == 1.0, "empty spec must not change position.x")
	_check((anchors["iam"] as Node3D).visible == true,    "empty spec must not change visibility")

	root.queue_free()


func test_unknown_target_is_silently_ignored() -> void:
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(["iam"], root)

	var spec: Dictionary = {"operations": [
		{"op": "hide", "target": "nonexistent_node"}
	]}
	var interp := SceneInterpreter.new()
	# Must not crash; must not affect other nodes.
	interp.apply_spec(spec, anchors, root)

	_check((anchors["iam"] as Node3D).visible == true,
		"unknown target op must not affect other nodes")

	root.queue_free()
