## Behavioral tests for QuestionPanel.
##
## Covers THEN clauses from specs/interaction/moldable-views.spec.md:
##
## Scenario: Architectural question
##   THEN the system generates a view focused on auth-related components
##        → process_question("how does authentication work?") includes auth_service
##          in a "show" op                                              (line 93)
##   AND irrelevant components are hidden or de-emphasized
##        → ViewSpecRenderer.apply() with the auth spec omits nodes not in show
##          (payment_service absent from scene tree)                    (line 111)
##   AND the relevant components are arranged to answer the question
##        → spec includes a "highlight" op for auth_service             (line 103)
##          and an "annotate" op                                        (line 126)
##
## Scenario: Impact question
##   THEN the system generates a view showing the user database and all its dependents
##        → show op contains "user_db"                                  (line 143)
##        → show op contains "auth_service"                             (line 155)
##   AND the dependency relationships are spatially clear
##        → spec includes a "connect" op                                (line 166)
##        → connect op targets "user_db"                               (line 178)
##
## Scenario: LLM produces view spec
##   THEN it emits a structured view specification (not raw 3D geometry)
##        → process_question() returns a Dictionary                     (line 55)
##   AND the view spec controls which elements are shown, hidden, highlighted,
##       and how they are arranged
##        → all ops are members of ViewSpec.VALID_OPS                   (line 74)
##   AND the 3D renderer interprets the view spec into a spatial scene
##        → ViewSpecRenderer.apply() can consume the spec and build nodes (line 191)
##
## Scenario: LLM uses existing primitives
##   THEN it composes the answer from the existing set of primitives
##   AND no new rendering logic is generated at runtime
##        → ViewSpec.from_dict() filters any op outside VALID_OPS — confirmed by
##          test_all_ops_in_spec_are_valid_primitives                   (line 74)

extends RefCounted

const ViewSpec         = preload("res://scripts/view_spec.gd")
const ViewSpecRenderer = preload("res://scripts/view_spec_renderer.gd")
const QuestionPanel    = preload("res://scripts/question_panel.gd")

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

func _make_panel() -> QuestionPanel:
	return QuestionPanel.new()


## Minimal graph containing the nodes referenced in process_question().
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
# Implemented: process_question() returns ViewSpec.from_dict() output — a Dictionary.
# ---------------------------------------------------------------------------

func test_process_question_returns_dictionary() -> void:
	var panel := _make_panel()
	var spec = panel.process_question("how does authentication work?")
	_check(spec is Dictionary,
		"process_question must return a Dictionary (not raw geometry), got type %d" % typeof(spec))


func test_process_question_spec_has_question_key() -> void:
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	_check("question" in spec,
		"Returned spec must contain 'question' key")
	_check(spec["question"] == "how does authentication work?",
		"'question' key must preserve the original question, got '%s'" % spec.get("question", ""))


func test_process_question_spec_has_operations_array() -> void:
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	_check("operations" in spec,
		"Returned spec must contain 'operations' key")
	_check(spec["operations"] is Array,
		"'operations' must be an Array")


# ---------------------------------------------------------------------------
# Scenario: LLM uses existing primitives
# AND no new rendering logic is generated at runtime
# Implemented: all ops in process_question() use ViewSpec.VALID_OPS names only.
# ViewSpec.from_dict() would filter any others anyway.
# ---------------------------------------------------------------------------

func test_all_ops_in_auth_spec_are_valid_primitives() -> void:
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	for op: Dictionary in spec.get("operations", []):
		_check(ViewSpec.VALID_OPS.has(op.get("op", "")),
			"All ops must be from VALID_OPS; found unknown op '%s'" % op.get("op", ""))


func test_all_ops_in_impact_spec_are_valid_primitives() -> void:
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what depends on the user database?")
	for op: Dictionary in spec.get("operations", []):
		_check(ViewSpec.VALID_OPS.has(op.get("op", "")),
			"All ops must be from VALID_OPS; found unknown op '%s'" % op.get("op", ""))


# ---------------------------------------------------------------------------
# Scenario: Architectural question
# THEN the system generates a view focused on auth-related components
# Implemented: "show" op with ids=["auth_service"] in the returned spec.
# (view_spec_renderer.gd line 48-49: only show-listed ids appear in scene tree)
# ---------------------------------------------------------------------------

func test_auth_question_show_op_includes_auth_service() -> void:
	# THEN the system generates a view focused on auth-related components
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	var has_auth_in_show := false
	for op: Dictionary in spec.get("operations", []):
		if op.get("op", "") == "show" and "auth_service" in op.get("ids", []):
			has_auth_in_show = true
	_check(has_auth_in_show,
		"Auth question must produce 'show' op containing 'auth_service' — it is the focused component")


# ---------------------------------------------------------------------------
# Scenario: Architectural question
# AND irrelevant components are hidden or de-emphasized
# Implemented: show op limits render to auth_service; ViewSpecRenderer excludes
# nodes not in the show list (view_spec_renderer.gd lines 41-49).
# ---------------------------------------------------------------------------

func test_auth_question_excludes_unrelated_nodes_from_render() -> void:
	# AND irrelevant components are hidden or de-emphasized
	var root := Node3D.new()
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var payment := _find_child(root, "payment_service")
	_check(payment == null,
		"payment_service must be absent from the auth scene — it is irrelevant and excluded by the show op")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Architectural question
# AND the relevant components are arranged to answer the question
# Implemented: "highlight" op in the spec sets a distinct colour on auth_service.
# (view_spec_renderer.gd lines 70-79: StandardMaterial3D with albedo_color)
# ---------------------------------------------------------------------------

func test_auth_question_includes_highlight_op_for_auth_service() -> void:
	# AND the relevant components are arranged to answer the question
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	var has_highlight := false
	for op: Dictionary in spec.get("operations", []):
		if op.get("op", "") == "highlight" and "auth_service" in op.get("ids", []):
			has_highlight = true
	_check(has_highlight,
		"Auth question must include a 'highlight' op for auth_service to visually emphasise it")


func test_auth_question_includes_annotate_op_for_auth_service() -> void:
	# AND the relevant components are arranged to answer the question (annotation label)
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	var has_annotate := false
	for op: Dictionary in spec.get("operations", []):
		if op.get("op", "") == "annotate" and op.get("id", "") == "auth_service":
			has_annotate = true
	_check(has_annotate,
		"Auth question must include an 'annotate' op for auth_service to label it in the view")


func test_auth_question_highlight_sets_material_on_rendered_node() -> void:
	# AND the relevant components are arranged to answer the question
	# (highlight → StandardMaterial3D with albedo_color set on the MeshInstance3D)
	var root := Node3D.new()
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var node := _find_child(root, "auth_service") as MeshInstance3D
	_check(node != null, "auth_service must exist in scene tree")
	if node != null:
		_check(node.material_override != null,
			"highlight op must set material_override on auth_service MeshInstance3D")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Impact question
# THEN the system generates a view showing the user database and all its dependents
# Implemented: "show" op with ids=["user_db", "auth_service"].
# ---------------------------------------------------------------------------

func test_impact_question_show_op_includes_user_db() -> void:
	# THEN the system generates a view showing the user database and all its dependents
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what depends on the user database?")
	var has_user_db := false
	for op: Dictionary in spec.get("operations", []):
		if op.get("op", "") == "show" and "user_db" in op.get("ids", []):
			has_user_db = true
	_check(has_user_db,
		"Impact question must produce 'show' op containing 'user_db' (the focal node)")


func test_impact_question_show_op_includes_dependents() -> void:
	# THEN all its dependents also appear in the show op
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what depends on the user database?")
	var has_auth := false
	for op: Dictionary in spec.get("operations", []):
		if op.get("op", "") == "show" and "auth_service" in op.get("ids", []):
			has_auth = true
	_check(has_auth,
		"Impact question must include 'auth_service' in show op — it depends on user_db")


# ---------------------------------------------------------------------------
# Scenario: Impact question
# AND the dependency relationships are spatially clear
# Implemented: "connect" op between auth_service and user_db.
# (view_spec_renderer.gd lines 93-106: Node3D at midpoint between the two nodes)
# ---------------------------------------------------------------------------

func test_impact_question_includes_connect_op() -> void:
	# AND the dependency relationships are spatially clear
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what depends on the user database?")
	var has_connect := false
	for op: Dictionary in spec.get("operations", []):
		if op.get("op", "") == "connect":
			has_connect = true
	_check(has_connect,
		"Impact question must include a 'connect' op to make dependency relationships spatially clear")


func test_impact_question_connect_targets_user_db() -> void:
	# The connect op must link to user_db so the dependency is visually explicit.
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what depends on the user database?")
	var found := false
	for op: Dictionary in spec.get("operations", []):
		if op.get("op", "") == "connect" and op.get("target", "") == "user_db":
			found = true
	_check(found,
		"connect op must have 'user_db' as target to show the dependency relationship")


func test_impact_question_connect_creates_midpoint_node_in_scene() -> void:
	# AND the dependency relationships are spatially clear
	# (connector Node3D placed at the midpoint between auth_service and user_db)
	var root := Node3D.new()
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what depends on the user database?")
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var connector := _find_child(root, "conn_auth_service_user_db")
	_check(connector != null,
		"Impact spec must cause ViewSpecRenderer to create a 'conn_auth_service_user_db' node")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: LLM produces view spec
# AND the 3D renderer interprets the view spec into a spatial scene
# Implemented: the spec returned by process_question() is valid input for
# ViewSpecRenderer.apply() and causes MeshInstance3D nodes to appear in root.
# ---------------------------------------------------------------------------

func test_renderer_can_apply_auth_spec_to_scene() -> void:
	# AND the 3D renderer interprets the view spec into a spatial scene
	var root := Node3D.new()
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("how does authentication work?")
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var auth := _find_child(root, "auth_service")
	_check(auth != null,
		"Renderer must produce an auth_service node from the architectural question spec")
	if auth != null:
		_check(auth is MeshInstance3D,
			"Rendered auth_service must be a MeshInstance3D")

	root.free()


func test_renderer_can_apply_impact_spec_to_scene() -> void:
	# AND the 3D renderer interprets the view spec into a spatial scene
	var root := Node3D.new()
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what depends on the user database?")
	ViewSpecRenderer.apply(_make_graph(), spec, root)

	var user_db := _find_child(root, "user_db")
	var auth    := _find_child(root, "auth_service")
	_check(user_db != null,
		"Renderer must produce user_db node from the impact question spec")
	_check(auth != null,
		"Renderer must produce auth_service node from the impact question spec")

	root.free()


# ---------------------------------------------------------------------------
# Unknown question falls back to show-all (empty operations).
# ---------------------------------------------------------------------------

func test_unknown_question_returns_empty_operations() -> void:
	var panel := _make_panel()
	var spec: Dictionary = panel.process_question("what is the meaning of life?")
	_check(spec["operations"].size() == 0,
		"Unknown question must return empty operations list (show all nodes), got %d ops" % spec["operations"].size())


# ---------------------------------------------------------------------------
# UI structure: panel creates line_edit and submit_button in _init().
# These are checked without scene-tree membership.
# ---------------------------------------------------------------------------

func test_panel_has_line_edit() -> void:
	var panel := _make_panel()
	_check(panel.line_edit != null,
		"QuestionPanel must initialise line_edit in _init()")
	_check(panel.line_edit is LineEdit,
		"line_edit must be a LineEdit node")


func test_panel_has_submit_button() -> void:
	var panel := _make_panel()
	_check(panel.submit_button != null,
		"QuestionPanel must initialise submit_button in _init()")
	_check(panel.submit_button is Button,
		"submit_button must be a Button node")


func test_panel_line_edit_has_placeholder_text() -> void:
	var panel := _make_panel()
	_check(panel.line_edit != null, "line_edit must exist")
	if panel.line_edit != null:
		_check(panel.line_edit.placeholder_text != "",
			"LineEdit must have non-empty placeholder_text to guide the user")


func test_panel_submit_button_has_label_text() -> void:
	var panel := _make_panel()
	_check(panel.submit_button != null, "submit_button must exist")
	if panel.submit_button != null:
		_check(panel.submit_button.text != "",
			"Submit button must have a visible label text")
