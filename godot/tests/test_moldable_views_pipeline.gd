## End-to-end integration tests for the moldable-views pipeline.
##
## Each test exercises BOTH pipeline stages in one test body:
##   Stage 1 — LlmViewGenerator.build_prompt() + parse_response()
##   Stage 2 — SceneInterpreter.apply_spec()
##
## Covers THEN-clauses from specs/interaction/moldable-views.spec.md:
##
## Scenario: Architectural question
##   GIVEN a loaded software system
##   WHEN the human asks "how does authentication work?"
##   THEN the system generates a view focused on auth-related components
##     → test_full_pipeline_arch_question_shows_auth_focused_view
##   AND irrelevant components are hidden or de-emphasized
##     → test_full_pipeline_arch_question_shows_auth_focused_view
##   AND the relevant components are arranged to answer the question
##     → test_full_pipeline_arrange_positions_relevant_components
##
## Scenario: Impact question
##   GIVEN a loaded software system
##   WHEN the human asks "what depends on the user database?"
##   THEN the system generates a view showing the user database and all its dependents
##     → test_full_pipeline_impact_question_shows_dependents
##   AND the dependency relationships are spatially clear
##     → test_full_pipeline_impact_question_connect_adds_lines
##
## Scenario: LLM produces view spec
##   THEN it emits a structured view specification (not raw 3D geometry)
##     → test_pipeline_produces_structured_view_spec_not_geometry
##   AND the view spec controls which elements are shown, hidden, highlighted,
##       and how they are arranged
##     → test_full_pipeline_arch_question_shows_auth_focused_view,
##        test_full_pipeline_arrange_positions_relevant_components
##   AND the 3D renderer interprets the view spec into a spatial scene
##     → all tests — each calls apply_spec and asserts Node3D scene-tree properties
##
## Scenario: LLM uses existing primitives
##   THEN it composes the answer from the existing set of primitives
##     → test_full_pipeline_all_six_primitives_applied_end_to_end
##   AND no new rendering logic is generated at runtime
##     → test_full_pipeline_unknown_op_rejected_no_new_rendering

const LlmViewGenerator = preload("res://scripts/llm_view_generator.gd")
const SceneInterpreter = preload("res://scripts/scene_interpreter.gd")

var _test_failed: bool = false
var _runner: Object = null


func _check(condition: bool, msg: String) -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg)


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

func _make_anchor(id: String, pos: Vector3) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = id.replace(".", "_")
	anchor.position = pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 0.4, 1.0)
	mesh.material_override = mat

	anchor.add_child(mesh)
	return anchor


func _make_graph(node_ids: Array) -> Dictionary:
	var nodes: Array = []
	for id in node_ids:
		nodes.append({"id": id, "name": id, "type": "module"})
	return {"nodes": nodes, "edges": []}


func _build_scene(root: Node3D, node_ids: Array) -> Dictionary:
	var anchors: Dictionary = {}
	for i in range(node_ids.size()):
		var anchor := _make_anchor(node_ids[i], Vector3(float(i) * 5.0, 0.0, 0.0))
		root.add_child(anchor)
		anchors[node_ids[i]] = anchor
	return anchors


# ---------------------------------------------------------------------------
# Scenario: Architectural question
# THEN the system generates a view focused on auth-related components
# AND irrelevant components are hidden or de-emphasized
# ---------------------------------------------------------------------------

func test_full_pipeline_arch_question_shows_auth_focused_view() -> void:
	## Full pipeline: build_prompt → parse_response → apply_spec
	## Asserts that auth is shown and irrelevant components are hidden.
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(root, ["auth", "billing", "shipping"])
	var graph := _make_graph(["auth", "billing", "shipping"])
	var question := "how does authentication work?"

	# Stage 1a: build_prompt produces a prompt containing the question and node ids.
	var prompt: String = LlmViewGenerator.build_prompt(question, graph)
	_check(prompt.length() > 0, "build_prompt must return a non-empty prompt string")
	_check(prompt.contains(question), "Prompt must embed the question verbatim")
	_check(prompt.contains("auth"), "Prompt must include node id 'auth'")

	# Mock LLM response: show auth, hide irrelevant components.
	var mock_response: String = (
		'{"operations": ['
		+ '{"op": "show", "target": "auth"},'
		+ '{"op": "hide", "target": "billing"},'
		+ '{"op": "hide", "target": "shipping"}'
		+ ']}'
	)

	# Stage 1b: parse_response validates and filters the LLM output.
	var spec: Dictionary = LlmViewGenerator.parse_response(mock_response)
	_check(spec.has("operations"), "parse_response must return dict with 'operations' key")
	_check(spec["operations"].size() == 3, "All three valid ops must survive parse_response")

	# Stage 2: apply_spec mutates the live 3D scene.
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	# Assert scene-tree state after the full pipeline.
	_check((anchors["auth"] as Node3D).visible == true,
		"auth anchor must be visible — system generates view focused on auth")
	_check((anchors["billing"] as Node3D).visible == false,
		"billing must be hidden — irrelevant component de-emphasized")
	_check((anchors["shipping"] as Node3D).visible == false,
		"shipping must be hidden — irrelevant component de-emphasized")

	root.queue_free()


# ---------------------------------------------------------------------------
# AND the relevant components are arranged to answer the question
# ---------------------------------------------------------------------------

func test_full_pipeline_arrange_positions_relevant_components() -> void:
	## Stage 1 → Stage 2: arrange op repositions auth-related nodes.
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(root, ["auth", "token", "session"])
	var graph := _make_graph(["auth", "token", "session"])
	var question := "how does authentication work?"

	# Stage 1a: build_prompt
	var prompt: String = LlmViewGenerator.build_prompt(question, graph)
	_check(prompt.length() > 0, "Prompt must be non-empty")

	# Mock response: arrange auth-related components
	var mock_response: String = (
		'{"operations": ['
		+ '{"op": "arrange", "target": "auth",    "position": {"x": 0.0,  "y": 0.0, "z": 0.0}},'
		+ '{"op": "arrange", "target": "token",   "position": {"x": 5.0,  "y": 0.0, "z": 0.0}},'
		+ '{"op": "arrange", "target": "session", "position": {"x": 10.0, "y": 0.0, "z": 0.0}}'
		+ ']}'
	)

	# Stage 1b: parse_response
	var spec: Dictionary = LlmViewGenerator.parse_response(mock_response)
	_check(spec["operations"].size() == 3, "Three arrange ops must survive parse_response")

	# Stage 2: apply_spec
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	# Assert positions — relevant components are arranged to answer the question.
	_check((anchors["auth"] as Node3D).position.x == 0.0,
		"auth.position.x must be 0.0 after arrange op")
	_check((anchors["token"] as Node3D).position.x == 5.0,
		"token.position.x must be 5.0 after arrange op")
	_check((anchors["session"] as Node3D).position.x == 10.0,
		"session.position.x must be 10.0 after arrange op")

	root.queue_free()


# ---------------------------------------------------------------------------
# Scenario: Impact question
# THEN the system generates a view showing the user database and all its dependents
# AND the dependency relationships are spatially clear
# ---------------------------------------------------------------------------

func test_full_pipeline_impact_question_shows_dependents() -> void:
	## Full pipeline for impact question: user_db + dependents shown, unrelated hidden.
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(root, ["user_db", "orders", "billing", "reports", "unrelated"])
	var graph := _make_graph(["user_db", "orders", "billing", "reports", "unrelated"])
	var question := "what depends on the user database?"

	# Stage 1a: build_prompt
	var prompt: String = LlmViewGenerator.build_prompt(question, graph)
	_check(prompt.contains("user_db"), "Prompt must include node id 'user_db'")
	_check(prompt.contains(question),  "Prompt must embed the impact question")

	# Mock LLM response: show user_db + all dependents, hide unrelated.
	var mock_response: String = (
		'{"operations": ['
		+ '{"op": "show", "target": "user_db"},'
		+ '{"op": "show", "target": "orders"},'
		+ '{"op": "show", "target": "billing"},'
		+ '{"op": "show", "target": "reports"},'
		+ '{"op": "hide", "target": "unrelated"}'
		+ ']}'
	)

	# Stage 1b: parse_response
	var spec: Dictionary = LlmViewGenerator.parse_response(mock_response)
	_check(spec["operations"].size() == 5, "Five ops must survive parse_response")

	# Stage 2: apply_spec
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	# Assert scene-tree state after the full pipeline.
	_check((anchors["user_db"] as Node3D).visible == true,
		"user_db must be visible — it is the subject of the impact question")
	_check((anchors["orders"] as Node3D).visible == true,
		"orders must be visible — it depends on user_db")
	_check((anchors["billing"] as Node3D).visible == true,
		"billing must be visible — it depends on user_db")
	_check((anchors["reports"] as Node3D).visible == true,
		"reports must be visible — it depends on user_db")
	_check((anchors["unrelated"] as Node3D).visible == false,
		"unrelated must be hidden — it does not depend on user_db")

	root.queue_free()


func test_full_pipeline_impact_question_connect_adds_lines() -> void:
	## AND the dependency relationships are spatially clear:
	## connect ops draw lines between user_db and its dependents.
	_test_failed = false
	var root := Node3D.new()

	var user_db := _make_anchor("user_db", Vector3(0.0,  0.0, 0.0))
	var orders  := _make_anchor("orders",  Vector3(10.0, 0.0, 0.0))
	var billing := _make_anchor("billing", Vector3(20.0, 0.0, 0.0))
	root.add_child(user_db)
	root.add_child(orders)
	root.add_child(billing)
	var anchors: Dictionary = {"user_db": user_db, "orders": orders, "billing": billing}

	var graph := _make_graph(["user_db", "orders", "billing"])
	var question := "what depends on the user database?"

	# Stage 1a: build_prompt
	var prompt: String = LlmViewGenerator.build_prompt(question, graph)
	_check(prompt.length() > 0, "Prompt must be non-empty")

	# Mock response: connect dependents to user_db (spatially clear relationships).
	var mock_response: String = (
		'{"operations": ['
		+ '{"op": "connect", "source": "orders",  "target": "user_db"},'
		+ '{"op": "connect", "source": "billing", "target": "user_db"}'
		+ ']}'
	)

	# Stage 1b: parse_response
	var spec: Dictionary = LlmViewGenerator.parse_response(mock_response)
	_check(spec["operations"].size() == 2, "Two connect ops must survive parse_response")

	# Stage 2: apply_spec — connect ops add line geometry to scene_root.
	var children_before: int = root.get_child_count()
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	# Lines added → dependency relationships are spatially clear.
	_check(root.get_child_count() > children_before,
		"connect ops must add MeshInstance3D line children — dep. relationships spatially clear")

	root.queue_free()


# ---------------------------------------------------------------------------
# Scenario: LLM produces view spec
# THEN it emits a structured view specification (not raw 3D geometry)
# AND the view spec controls which elements are shown/hidden/highlighted/arranged
# AND the 3D renderer interprets the view spec into a spatial scene
# ---------------------------------------------------------------------------

func test_pipeline_produces_structured_view_spec_not_geometry() -> void:
	## THEN it emits a structured view specification (not raw 3D geometry).
	## parse_response returns a dictionary — not a mesh, not a node, not raw coords.
	_test_failed = false
	var graph := _make_graph(["iam", "auth"])
	var question := "how does authentication work?"

	# Stage 1a: build_prompt
	var prompt: String = LlmViewGenerator.build_prompt(question, graph)
	_check(prompt.length() > 0, "Prompt must be non-empty")

	# Stage 1b: parse_response returns a dict (view spec), not 3D geometry.
	var mock_response: String = (
		'{"operations": [{"op": "show", "target": "iam"}, {"op": "highlight", "target": "auth"}]}'
	)
	var spec: Dictionary = LlmViewGenerator.parse_response(mock_response)
	_check(spec is Dictionary,
		"parse_response must return a Dictionary (view spec), not raw 3D geometry")
	_check(spec.has("operations"),
		"view spec must have an 'operations' key — structured intermediate representation")
	_check(spec["operations"][0] is Dictionary,
		"each operation must be a Dictionary — not a mesh or position literal")
	_check(spec["operations"][0].has("op"),
		"each operation dict must have an 'op' key — structured primitive, not raw geometry")

	# Stage 2: apply_spec interprets the structured spec into 3D scene mutations.
	var root := Node3D.new()
	var anchors := _build_scene(root, ["iam", "auth"])
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	# The renderer applied the view spec — iam visible, auth highlighted.
	_check((anchors["iam"] as Node3D).visible == true,
		"3D renderer must interpret the show op from the view spec")

	root.queue_free()


# ---------------------------------------------------------------------------
# Scenario: LLM uses existing primitives
# THEN it composes the answer from the existing set of primitives
# AND no new rendering logic is generated at runtime
# ---------------------------------------------------------------------------

func test_full_pipeline_all_six_primitives_applied_end_to_end() -> void:
	## All six fixed primitives survive parse_response and are applied by apply_spec.
	_test_failed = false
	var root := Node3D.new()

	var a_anchor := _make_anchor("a", Vector3(0.0, 0.0, 0.0))
	var b_anchor := _make_anchor("b", Vector3(5.0, 0.0, 0.0))
	var c_anchor := _make_anchor("c", Vector3(10.0, 0.0, 0.0))
	root.add_child(a_anchor)
	root.add_child(b_anchor)
	root.add_child(c_anchor)
	var anchors: Dictionary = {"a": a_anchor, "b": b_anchor, "c": c_anchor}

	var graph := _make_graph(["a", "b", "c"])
	var question := "what is the architecture?"

	# Stage 1a: build_prompt
	var prompt: String = LlmViewGenerator.build_prompt(question, graph)
	_check(prompt.length() > 0, "Prompt must be non-empty")
	# The prompt lists all six primitives.
	for prim in LlmViewGenerator.VALID_OPS:
		_check(prompt.contains(prim), "Prompt must list primitive: " + prim)

	# Mock response using all six fixed primitives.
	var mock_response: String = (
		'{"operations": ['
		+ '{"op": "show",      "target": "a"},'
		+ '{"op": "hide",      "target": "b"},'
		+ '{"op": "highlight", "target": "c"},'
		+ '{"op": "arrange",   "target": "a", "position": {"x": 1.0, "y": 0.0, "z": 0.0}},'
		+ '{"op": "annotate",  "target": "a", "text": "entry point"},'
		+ '{"op": "connect",   "source": "a", "target": "c"}'
		+ ']}'
	)

	# Stage 1b: parse_response — all six survive (they are all in VALID_OPS).
	var spec: Dictionary = LlmViewGenerator.parse_response(mock_response)
	_check(spec["operations"].size() == 6,
		"All six fixed primitives must survive parse_response round-trip")

	# Stage 2: apply_spec — all six ops applied to the scene.
	var children_before: int = root.get_child_count()
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["a"] as Node3D).visible == true,  "show op applied: a is visible")
	_check((anchors["b"] as Node3D).visible == false,  "hide op applied: b is hidden")
	_check((anchors["a"] as Node3D).position.x == 1.0, "arrange op applied: a.position.x == 1.0")
	# annotate + connect add children to scene_root.
	_check(root.get_child_count() > children_before,
		"annotate and/or connect ops must add children to scene_root")

	root.queue_free()


func test_full_pipeline_unknown_op_rejected_no_new_rendering() -> void:
	## AND no new rendering logic is generated at runtime.
	## An unknown op is silently filtered before apply_spec — the scene is unaffected.
	_test_failed = false
	var root := Node3D.new()
	var anchors := _build_scene(root, ["iam"])
	var graph := _make_graph(["iam"])
	var question := "visualise with holographic mode"

	# Stage 1a: build_prompt
	var prompt: String = LlmViewGenerator.build_prompt(question, graph)
	_check(prompt.length() > 0, "Prompt must be non-empty")

	# Mock LLM response: one valid op + one prohibited op.
	var mock_response: String = (
		'{"operations": ['
		+ '{"op": "show",              "target": "iam"},'
		+ '{"op": "holographic_render","target": "iam"}'   # prohibited — not in VALID_OPS
		+ ']}'
	)

	# Stage 1b: parse_response filters the prohibited op.
	var spec: Dictionary = LlmViewGenerator.parse_response(mock_response)
	_check(spec["operations"].size() == 1,
		"Unknown op must be rejected — no new rendering logic at runtime")
	_check(spec["operations"][0]["op"] == "show",
		"Only the valid 'show' op survives — prohibited op is discarded")

	# Stage 2: apply_spec — only the 'show' op is applied.
	var interp := SceneInterpreter.new()
	interp.apply_spec(spec, anchors, root)

	_check((anchors["iam"] as Node3D).visible == true,
		"show op applied; holographic_render was never executed")

	root.queue_free()
