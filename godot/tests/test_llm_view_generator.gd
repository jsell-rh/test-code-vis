## Tests for LlmViewGenerator — Stage 1 of the moldable-views pipeline.
##
## Covers THEN-clauses from specs/interaction/moldable-views.spec.md:
##
## Scenario: LLM produces view spec
##   THEN it emits a structured view specification (not raw 3D geometry)
##     → test_parse_response_returns_dict, test_parse_response_has_operations_key
##   AND the view spec controls which elements are shown, hidden, highlighted,
##       and how they are arranged
##     → test_parse_response_show_op_survives … test_parse_response_connect_op_survives
##   AND the 3D renderer interprets the view spec into a spatial scene
##     → (covered in test_scene_interpreter.gd)
##
## Scenario: LLM uses existing primitives
##   THEN it composes the answer from the existing set of primitives
##     → test_all_six_primitives_survive_round_trip,
##        test_prompt_lists_all_six_primitives
##   AND no new rendering logic is generated at runtime
##     → test_parse_response_rejects_unknown_op,
##        test_parse_response_mixed_valid_and_invalid_ops
##
## Scenario: Architectural / Impact questions
##   THEN the system generates a view focused on relevant components
##     → test_prompt_contains_question, test_prompt_contains_node_ids

const LlmViewGenerator = preload("res://scripts/llm_view_generator.gd")

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

func _simple_graph() -> Dictionary:
	return {
		"nodes": [
			{"id": "iam", "name": "IAM", "type": "bounded_context"},
			{"id": "graph", "name": "Graph", "type": "bounded_context"},
			{"id": "auth.service", "name": "AuthService", "type": "module"},
		],
		"edges": []
	}


# ---------------------------------------------------------------------------
# build_prompt tests
# ---------------------------------------------------------------------------

func test_prompt_contains_question() -> void:
	_test_failed = false
	var prompt: String = LlmViewGenerator.build_prompt("how does auth work?", _simple_graph())
	_check(prompt.contains("how does auth work?"), "Prompt must contain the question verbatim")


func test_prompt_contains_all_node_ids() -> void:
	_test_failed = false
	var prompt: String = LlmViewGenerator.build_prompt("test question", _simple_graph())
	_check(prompt.contains("iam"), "Prompt must contain node id 'iam'")
	_check(prompt.contains("graph"), "Prompt must contain node id 'graph'")
	_check(prompt.contains("auth.service"), "Prompt must contain node id 'auth.service'")


func test_prompt_lists_all_six_primitives() -> void:
	_test_failed = false
	var prompt: String = LlmViewGenerator.build_prompt("q", _simple_graph())
	for prim in ["show", "hide", "highlight", "arrange", "annotate", "connect"]:
		_check(prompt.contains(prim), "Prompt must list primitive: " + prim)


func test_prompt_is_non_empty_string() -> void:
	_test_failed = false
	var prompt: String = LlmViewGenerator.build_prompt("q", {})
	_check(prompt.length() > 0, "Prompt must be a non-empty string")


func test_prompt_with_empty_graph_still_includes_question() -> void:
	_test_failed = false
	var prompt: String = LlmViewGenerator.build_prompt("what depends on x?", {})
	_check(prompt.contains("what depends on x?"), "Prompt with empty graph must still include question")


func test_prompt_valid_ops_constant_has_six_entries() -> void:
	_test_failed = false
	_check(LlmViewGenerator.VALID_OPS.size() == 6, "VALID_OPS must have exactly 6 primitives")


func test_prompt_valid_ops_contains_show() -> void:
	_test_failed = false
	_check("show" in LlmViewGenerator.VALID_OPS, "VALID_OPS must include 'show'")


func test_prompt_valid_ops_contains_hide() -> void:
	_test_failed = false
	_check("hide" in LlmViewGenerator.VALID_OPS, "VALID_OPS must include 'hide'")


func test_prompt_valid_ops_contains_highlight() -> void:
	_test_failed = false
	_check("highlight" in LlmViewGenerator.VALID_OPS, "VALID_OPS must include 'highlight'")


func test_prompt_valid_ops_contains_arrange() -> void:
	_test_failed = false
	_check("arrange" in LlmViewGenerator.VALID_OPS, "VALID_OPS must include 'arrange'")


func test_prompt_valid_ops_contains_annotate() -> void:
	_test_failed = false
	_check("annotate" in LlmViewGenerator.VALID_OPS, "VALID_OPS must include 'annotate'")


func test_prompt_valid_ops_contains_connect() -> void:
	_test_failed = false
	_check("connect" in LlmViewGenerator.VALID_OPS, "VALID_OPS must include 'connect'")


# ---------------------------------------------------------------------------
# parse_response tests
# ---------------------------------------------------------------------------

func test_parse_response_returns_dict() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response('{"operations": []}')
	_check(spec is Dictionary, "parse_response must return a Dictionary")


func test_parse_response_has_operations_key() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response('{"operations": []}')
	_check(spec.has("operations"), "parse_response result must have 'operations' key")


func test_parse_response_show_op_survives() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "show", "target": "iam"}]}'
	)
	_check(spec["operations"].size() == 1, "'show' op must survive parse_response")
	_check(spec["operations"][0]["op"] == "show", "op field must be 'show'")


func test_parse_response_hide_op_survives() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "hide", "target": "graph"}]}'
	)
	_check(spec["operations"].size() == 1, "'hide' op must survive")
	_check(spec["operations"][0]["op"] == "hide", "op must be 'hide'")


func test_parse_response_highlight_op_survives() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "highlight", "target": "iam"}]}'
	)
	_check(spec["operations"].size() == 1, "'highlight' op must survive")
	_check(spec["operations"][0]["op"] == "highlight", "op must be 'highlight'")


func test_parse_response_arrange_op_survives() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "arrange", "target": "iam", "position": {"x": 1.0, "y": 0.0, "z": 0.0}}]}'
	)
	_check(spec["operations"].size() == 1, "'arrange' op must survive")
	_check(spec["operations"][0]["op"] == "arrange", "op must be 'arrange'")


func test_parse_response_annotate_op_survives() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "annotate", "target": "iam", "text": "entry point"}]}'
	)
	_check(spec["operations"].size() == 1, "'annotate' op must survive")
	_check(spec["operations"][0]["op"] == "annotate", "op must be 'annotate'")


func test_parse_response_connect_op_survives() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "connect", "source": "iam", "target": "graph"}]}'
	)
	_check(spec["operations"].size() == 1, "'connect' op must survive")
	_check(spec["operations"][0]["op"] == "connect", "op must be 'connect'")


func test_parse_response_rejects_unknown_op() -> void:
	## AND no new rendering logic is generated at runtime
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "explode", "target": "iam"}]}'
	)
	_check(spec["operations"].size() == 0, "Unknown op must be rejected — no new rendering at runtime")


func test_parse_response_strips_markdown_fence() -> void:
	_test_failed = false
	var json_with_fence: String = (
		"```json\n"
		+ '{"operations": [{"op": "show", "target": "iam"}]}'
		+ "\n```"
	)
	var spec: Dictionary = LlmViewGenerator.parse_response(json_with_fence)
	_check(spec["operations"].size() == 1, "Markdown fences must be stripped before parsing")


func test_parse_response_invalid_json_returns_empty_ops() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response("not valid json {{{")
	_check(spec is Dictionary, "Invalid JSON must return a Dictionary, not crash")
	_check(spec["operations"].size() == 0, "Invalid JSON must return empty operations list")


func test_parse_response_mixed_ops_filters_invalid() -> void:
	## AND no new rendering logic is generated at runtime — unknown ops silently discarded
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "show", "target": "iam"}, {"op": "new_render_mode", "target": "graph"}]}'
	)
	_check(spec["operations"].size() == 1, "Only valid ops must survive; invalid ones are discarded")
	_check(spec["operations"][0]["op"] == "show", "Valid 'show' op must be retained")


func test_all_six_primitives_survive_round_trip() -> void:
	## THEN it composes the answer from the existing set of primitives (show, hide, highlight, arrange, annotate, connect)
	_test_failed = false
	var json_ops: String = (
		'{"operations": ['
		+ '{"op": "show", "target": "a"},'
		+ '{"op": "hide", "target": "b"},'
		+ '{"op": "highlight", "target": "c"},'
		+ '{"op": "arrange", "target": "d", "position": {"x": 0, "y": 0, "z": 0}},'
		+ '{"op": "annotate", "target": "e", "text": "note"},'
		+ '{"op": "connect", "source": "a", "target": "b"}'
		+ ']}'
	)
	var spec: Dictionary = LlmViewGenerator.parse_response(json_ops)
	_check(spec["operations"].size() == 6,
		"All six fixed primitives must survive parse_response round-trip")


func test_parse_response_preserves_target_field() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "show", "target": "iam.auth"}]}'
	)
	_check(spec["operations"][0].get("target") == "iam.auth", "target field must be preserved")


func test_parse_response_preserves_arrange_position() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "arrange", "target": "iam", "position": {"x": 5.0, "y": 1.0, "z": -3.0}}]}'
	)
	var op: Dictionary = spec["operations"][0]
	var pos: Dictionary = op.get("position", {})
	_check(float(pos.get("x", 0)) == 5.0, "arrange position.x must be preserved")
	_check(float(pos.get("y", 0)) == 1.0, "arrange position.y must be preserved")
	_check(float(pos.get("z", 0)) == -3.0, "arrange position.z must be preserved")


func test_parse_response_preserves_annotate_text() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "annotate", "target": "iam", "text": "auth entry point"}]}'
	)
	var op: Dictionary = spec["operations"][0]
	_check(op.get("text") == "auth entry point", "annotate text field must be preserved")


func test_parse_response_preserves_connect_source_and_target() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response(
		'{"operations": [{"op": "connect", "source": "user_db", "target": "orders"}]}'
	)
	var op: Dictionary = spec["operations"][0]
	_check(op.get("source") == "user_db", "connect source field must be preserved")
	_check(op.get("target") == "orders", "connect target field must be preserved")


func test_parse_response_empty_string_returns_empty_ops() -> void:
	_test_failed = false
	var spec: Dictionary = LlmViewGenerator.parse_response("")
	_check(spec is Dictionary, "Empty string must return a Dictionary")
	_check(spec.has("operations"), "Empty string result must have 'operations' key")
