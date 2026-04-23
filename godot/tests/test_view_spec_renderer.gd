## Behavioral tests for ViewSpecRenderer.
##
## Covers all THEN clauses from specs/interaction/moldable-views.spec.md:
##
## Scenario: Architectural question
##   THEN the system generates a view focused on auth-related components
##        → only nodes listed in "show" ops appear in the scene tree
##   AND irrelevant components are hidden or de-emphasized
##        → nodes listed in "hide" ops are absent from the scene tree
##   AND the relevant components are arranged to answer the question
##        → "arrange" op overrides a node's position on the MeshInstance3D
##
## Scenario: Impact question
##   THEN the system generates a view showing the user database and all its dependents
##        → both nodes listed in "show" appear in the scene tree
##   AND the dependency relationships are spatially clear
##        → a "connect" op creates a connector Node3D at the midpoint
##
## Scenario: LLM produces view spec
##   THEN it emits a structured view specification (not raw 3D geometry)
##        → ViewSpec.from_dict() returns a Dict, not a Node or geometry object
##   AND the view spec controls which elements are shown, hidden, highlighted,
##       and how they are arranged
##        → each primitive is tested individually below
##   AND the 3D renderer interprets the view spec into a spatial scene
##        → ViewSpecRenderer.apply() builds MeshInstance3D children under root

extends RefCounted

const ViewSpec         = preload("res://scripts/view_spec.gd")
const ViewSpecRenderer = preload("res://scripts/view_spec_renderer.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

## A minimal graph with three nodes: auth_service, user_db, payment_service.
func _make_graph() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "auth_service",
				"name": "Auth Service",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"metrics": {},
			},
			{
				"id": "user_db",
				"name": "User DB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 5.0, "y": 0.0, "z": 0.0},
				"size": 1.5,
				"metrics": {},
			},
			{
				"id": "payment_service",
				"name": "Payment Service",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -5.0, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"metrics": {},
			},
		],
		"edges": [
			{"source": "auth_service", "target": "user_db", "type": "internal"},
		],
		"metadata": {},
	}


func _find_child(parent: Node, name: String) -> Node:
	for child in parent.get_children():
		if child.name == name:
			return child
	return null


# ---------------------------------------------------------------------------
# Scenario: LLM produces view spec
# THEN it emits a structured view specification (not raw 3D geometry)
# Implemented by ViewSpec.from_dict() returning a plain Dictionary.
# ---------------------------------------------------------------------------

func test_view_spec_from_dict_returns_dictionary() -> void:
	var raw: Dictionary = {"question": "how does auth work?", "operations": []}
	var spec = ViewSpec.from_dict(raw)
	_check(spec is Dictionary,
		"ViewSpec.from_dict() must return a Dictionary (not raw geometry), got %s" % type_string(typeof(spec)))


func test_view_spec_has_operations_key() -> void:
	var spec: Dictionary = ViewSpec.from_dict({"question": "q", "operations": []})
	_check("operations" in spec, "Spec must have 'operations' key")
	_check(spec["operations"] is Array, "'operations' must be an Array")


# ---------------------------------------------------------------------------
# Scenario: Architectural question
# THEN the system generates a view focused on auth-related components
# Implemented by ViewSpecRenderer.apply() rendering only "show" ids when present.
# ---------------------------------------------------------------------------

func test_show_op_includes_listed_node_in_scene_tree() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "how does authentication work?",
		"operations": [
			{"op": "show", "ids": ["auth_service"]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service")
	_check(node != null,
		"auth_service must appear in scene tree after 'show' op — it is a relevant component")

	root.free()


func test_show_op_excludes_non_listed_nodes_from_scene_tree() -> void:
	# AND irrelevant components are hidden or de-emphasized
	# Implemented: nodes not in any "show" op are absent when show ops exist.
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "how does authentication work?",
		"operations": [
			{"op": "show", "ids": ["auth_service"]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var payment := _find_child(root, "payment_service")
	_check(payment == null,
		"payment_service must NOT appear in scene tree — it is irrelevant and excluded by 'show' op")
	var user_db := _find_child(root, "user_db")
	_check(user_db == null,
		"user_db must NOT appear in scene tree — it is irrelevant and excluded by 'show' op")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Architectural question
# AND irrelevant components are hidden or de-emphasized
# Implemented by "hide" op: node is absent from the scene tree.
# ---------------------------------------------------------------------------

func test_hide_op_removes_node_from_scene_tree() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "how does authentication work?",
		"operations": [
			{"op": "hide", "ids": ["payment_service"]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var payment := _find_child(root, "payment_service")
	_check(payment == null,
		"payment_service must be absent from scene tree after 'hide' op — it is de-emphasized")

	root.free()


func test_hide_op_does_not_remove_other_nodes() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "hide", "ids": ["payment_service"]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var auth := _find_child(root, "auth_service")
	_check(auth != null,
		"auth_service must still appear in scene tree — only payment_service is hidden")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Architectural question
# AND the relevant components are arranged to answer the question
# Implemented by "arrange" op setting mesh.position to spec-provided coords.
# ---------------------------------------------------------------------------

func test_arrange_op_overrides_node_position_x() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "how does authentication work?",
		"operations": [
			{"op": "arrange", "id": "auth_service", "position": {"x": 10.0, "y": 2.0, "z": -3.0}},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service")
	_check(node != null, "auth_service must exist in scene tree")
	if node != null:
		_check(is_equal_approx(node.position.x, 10.0),
			"arrange must set position.x=10.0, got %s" % node.position.x)

	root.free()


func test_arrange_op_overrides_node_position_y() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "arrange", "id": "auth_service", "position": {"x": 10.0, "y": 2.0, "z": -3.0}},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service")
	_check(node != null, "auth_service must exist in scene tree")
	if node != null:
		_check(is_equal_approx(node.position.y, 2.0),
			"arrange must set position.y=2.0, got %s" % node.position.y)

	root.free()


func test_arrange_op_overrides_node_position_z() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "arrange", "id": "auth_service", "position": {"x": 10.0, "y": 2.0, "z": -3.0}},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service")
	_check(node != null, "auth_service must exist in scene tree")
	if node != null:
		_check(is_equal_approx(node.position.z, -3.0),
			"arrange must set position.z=-3.0, got %s" % node.position.z)

	root.free()


func test_arrange_op_does_not_change_json_position_of_other_nodes() -> void:
	# Nodes without an "arrange" op keep their JSON position.
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "arrange", "id": "auth_service", "position": {"x": 99.0, "y": 0.0, "z": 0.0}},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var user_db := _find_child(root, "user_db")
	_check(user_db != null, "user_db must exist in scene tree")
	if user_db != null:
		_check(is_equal_approx(user_db.position.x, 5.0),
			"user_db position.x must stay at JSON value 5.0 (no arrange op), got %s" % user_db.position.x)

	root.free()


# ---------------------------------------------------------------------------
# Scenario: LLM produces view spec
# AND the view spec controls … highlighted … elements
# Implemented by "highlight" op: StandardMaterial3D.albedo_color on mesh.material_override.
# ---------------------------------------------------------------------------

func test_highlight_op_sets_material_override_on_node() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "highlight", "ids": ["auth_service"], "color": [1.0, 0.5, 0.0]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service")
	_check(node != null, "auth_service must exist in scene tree")
	if node != null:
		var mesh := node as MeshInstance3D
		_check(mesh != null, "auth_service node must be a MeshInstance3D")
		if mesh != null:
			_check(mesh.material_override != null,
				"highlight must set material_override on MeshInstance3D")

	root.free()


func test_highlight_op_albedo_color_red_component() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "highlight", "ids": ["auth_service"], "color": [1.0, 0.5, 0.0]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service") as MeshInstance3D
	if node != null and node.material_override != null:
		var mat := node.material_override as StandardMaterial3D
		_check(mat != null, "material_override must be a StandardMaterial3D")
		if mat != null:
			_check(is_equal_approx(mat.albedo_color.r, 1.0),
				"highlight albedo_color.r must be 1.0, got %s" % mat.albedo_color.r)

	root.free()


func test_highlight_op_albedo_color_green_component() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "highlight", "ids": ["auth_service"], "color": [1.0, 0.5, 0.0]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service") as MeshInstance3D
	if node != null and node.material_override != null:
		var mat := node.material_override as StandardMaterial3D
		if mat != null:
			_check(is_equal_approx(mat.albedo_color.g, 0.5),
				"highlight albedo_color.g must be 0.5, got %s" % mat.albedo_color.g)

	root.free()


func test_highlight_op_albedo_color_blue_component() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "highlight", "ids": ["auth_service"], "color": [1.0, 0.5, 0.0]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service") as MeshInstance3D
	if node != null and node.material_override != null:
		var mat := node.material_override as StandardMaterial3D
		if mat != null:
			_check(is_equal_approx(mat.albedo_color.b, 0.0),
				"highlight albedo_color.b must be 0.0, got %s" % mat.albedo_color.b)

	root.free()


func test_non_highlighted_node_has_no_material_override() -> void:
	# Nodes without a highlight op must not have a material_override.
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "highlight", "ids": ["auth_service"], "color": [1.0, 0.0, 0.0]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var user_db := _find_child(root, "user_db") as MeshInstance3D
	_check(user_db != null, "user_db must exist in scene tree")
	if user_db != null:
		_check(user_db.material_override == null,
			"user_db must not have material_override — it was not highlighted")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: LLM produces view spec
# AND the view spec controls … how they are arranged (annotate)
# Implemented by "annotate" op: Label3D child named "annotation" with .text set.
# ---------------------------------------------------------------------------

func test_annotate_op_adds_label3d_child() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "annotate", "id": "auth_service", "text": "Entry point"},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var auth := _find_child(root, "auth_service")
	_check(auth != null, "auth_service must exist in scene tree")
	if auth != null:
		var label := _find_child(auth, "annotation")
		_check(label != null,
			"annotate op must create a child node named 'annotation' on auth_service")

	root.free()


func test_annotate_op_sets_label3d_text() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "annotate", "id": "auth_service", "text": "Entry point"},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var auth := _find_child(root, "auth_service")
	if auth != null:
		var label := _find_child(auth, "annotation") as Label3D
		_check(label != null,
			"annotation child must be a Label3D")
		if label != null:
			_check(label.text == "Entry point",
				"Label3D.text must be 'Entry point', got '%s'" % label.text)
			_check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
				"annotation Label3D must have billboard enabled for readability in 3D space")
			_check(label.pixel_size > 0.0,
				"annotation Label3D must have pixel_size > 0.0 for legibility, got %s" % label.pixel_size)

	root.free()


func test_non_annotated_node_has_no_label3d_child() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "annotate", "id": "auth_service", "text": "Entry point"},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var user_db := _find_child(root, "user_db")
	_check(user_db != null, "user_db must exist in scene tree")
	if user_db != null:
		var label := _find_child(user_db, "annotation")
		_check(label == null,
			"user_db must not have an 'annotation' child — it was not annotated")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Impact question
# THEN the system generates a view showing the user database and all its dependents
# Implemented by "show" op including both user_db and auth_service.
# ---------------------------------------------------------------------------

func test_show_multiple_ids_all_appear_in_scene_tree() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "what depends on the user database?",
		"operations": [
			{"op": "show", "ids": ["user_db", "auth_service"]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var user_db := _find_child(root, "user_db")
	var auth := _find_child(root, "auth_service")
	_check(user_db != null,
		"user_db must appear in scene tree — it is the focal node of the impact question")
	_check(auth != null,
		"auth_service must appear in scene tree — it depends on user_db")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Impact question
# AND the dependency relationships are spatially clear
# Implemented by "connect" op: Node3D named "conn_{src}_{tgt}" at the midpoint.
# ---------------------------------------------------------------------------

func test_connect_op_creates_connector_node_in_scene_tree() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "what depends on the user database?",
		"operations": [
			{"op": "connect", "source": "auth_service", "target": "user_db"},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var connector := _find_child(root, "conn_auth_service_user_db")
	_check(connector != null,
		"connect op must create a Node3D named 'conn_auth_service_user_db' in the scene tree")

	root.free()


func test_connect_op_connector_position_is_midpoint_x() -> void:
	# auth_service.x=0, user_db.x=5 → midpoint.x=2.5
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "connect", "source": "auth_service", "target": "user_db"},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var connector := _find_child(root, "conn_auth_service_user_db")
	_check(connector != null, "Connector node must exist")
	if connector != null:
		_check(is_equal_approx(connector.position.x, 2.5),
			"Connector midpoint.x must be 2.5 (average of 0 and 5), got %s" % connector.position.x)

	root.free()


func test_connect_op_connector_position_is_midpoint_y() -> void:
	# Both nodes have y=0 → midpoint.y=0
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "connect", "source": "auth_service", "target": "user_db"},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var connector := _find_child(root, "conn_auth_service_user_db")
	if connector != null:
		_check(is_equal_approx(connector.position.y, 0.0),
			"Connector midpoint.y must be 0.0, got %s" % connector.position.y)

	root.free()


func test_connect_op_skipped_when_source_not_in_scene() -> void:
	# If source is hidden, no connector should be created.
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "hide",    "ids": ["auth_service"]},
			{"op": "connect", "source": "auth_service", "target": "user_db"},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var connector := _find_child(root, "conn_auth_service_user_db")
	_check(connector == null,
		"connect op must be skipped when source node is hidden (not in scene)")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: LLM produces view spec
# AND the 3D renderer interprets the view spec into a spatial scene
# Implemented by ViewSpecRenderer.apply() creating MeshInstance3D children.
# ---------------------------------------------------------------------------

func test_renderer_creates_mesh_instance_3d_for_each_shown_node() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [],  # no show/hide → render all graph nodes
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	_check(root.get_child_count() == 3,
		"Renderer must create one MeshInstance3D per graph node, expected 3, got %d" % root.get_child_count())

	root.free()


func test_renderer_nodes_are_mesh_instance_3d() -> void:
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [
			{"op": "show", "ids": ["auth_service"]},
		],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service")
	_check(node != null, "auth_service must exist in scene tree")
	if node != null:
		_check(node is MeshInstance3D,
			"Rendered node must be a MeshInstance3D; got %s" % node.get_class())

	root.free()


func test_renderer_uses_json_position_when_no_arrange_op() -> void:
	# Without an arrange op, the graph's JSON position must be used verbatim.
	var root := Node3D.new()
	var spec: Dictionary = ViewSpec.from_dict({
		"question": "test",
		"operations": [],
	})
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var user_db := _find_child(root, "user_db")
	_check(user_db != null, "user_db must exist in scene tree")
	if user_db != null:
		_check(is_equal_approx(user_db.position.x, 5.0),
			"user_db position.x must equal JSON value 5.0, got %s" % user_db.position.x)
		_check(is_equal_approx(user_db.position.y, 0.0),
			"user_db position.y must equal JSON value 0.0, got %s" % user_db.position.y)
		_check(is_equal_approx(user_db.position.z, 0.0),
			"user_db position.z must equal JSON value 0.0, got %s" % user_db.position.z)

	root.free()
