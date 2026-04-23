## Behavioral tests for LLMViewGenerator.
##
## Covers all THEN clauses from specs/interaction/moldable-views.spec.md:
##
## Scenario: LLM produces view spec
##   THEN it emits a structured view specification (not raw 3D geometry)
##        → parse_response() returns a Dictionary, not a Node or geometry object
##   AND the view spec controls which elements are shown, hidden, highlighted,
##       and how they are arranged
##        → parse_response() with each valid op passes it through
##   AND the 3D renderer interprets the view spec into a spatial scene
##        → the returned dict has "question" and "operations" keys ready for
##          ViewSpecRenderer.apply()
##
## Scenario: LLM uses existing primitives
##   THEN it composes the answer from the existing set of primitives
##        → build_prompt() includes all VALID_OPS so the LLM knows what to use
##   AND no new rendering logic is generated at runtime
##        → parse_response() delegates to ViewSpec.from_dict(), which drops
##          any op not in VALID_OPS
##
## Scenario: Architectural question
##   WHEN the human asks "how does authentication work?"
##   THEN the system generates a view focused on auth-related components
##        → build_prompt() includes node ids so the LLM can identify them
##   AND irrelevant components are hidden or de-emphasized
##        → parse_response() passes through "hide" ops from the LLM
##   AND the relevant components are arranged to answer the question
##        → parse_response() passes through "arrange" ops from the LLM
##
## Scenario: Impact question
##   WHEN the human asks "what depends on the user database?"
##   THEN the system generates a view showing the user database and its dependents
##        → parse_response() passes through "show" ops from the LLM
##   AND the dependency relationships are spatially clear
##        → parse_response() passes through "connect" ops from the LLM

extends RefCounted

const LLMViewGenerator = preload("res://scripts/llm_view_generator.gd")
const ViewSpec = preload("res://scripts/view_spec.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


## Fixture: a minimal two-node graph for testing prompt construction.
func _make_graph() -> Dictionary:
	return {
		"nodes": [
			{"id": "auth_service", "name": "Auth Service", "type": "bounded_context"},
			{"id": "user_db", "name": "User DB", "type": "bounded_context"},
		],
		"edges": [],
		"metadata": {},
	}


# ---------------------------------------------------------------------------
# build_prompt — Scenario: LLM uses existing primitives
# THEN it composes the answer from the existing set of primitives
# Implemented by build_prompt() embedding ViewSpec.VALID_OPS in the prompt text.
# ---------------------------------------------------------------------------

func test_build_prompt_is_non_empty() -> void:
	var prompt: String = LLMViewGenerator.build_prompt("test", {})
	_check(prompt.length() > 0,
		"build_prompt() must return a non-empty string")


func test_build_prompt_contains_question() -> void:
	# WHEN the human asks "how does authentication work?"
	# The prompt must contain that exact question so the LLM can answer it.
	var prompt: String = LLMViewGenerator.build_prompt("how does authentication work?", _make_graph())
	_check(prompt.contains("how does authentication work?"),
		"Prompt must contain the original question text")


func test_build_prompt_contains_show_primitive() -> void:
	# AND no new rendering logic is generated at runtime
	# The prompt must list all valid primitives so the LLM knows the contract.
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("show"),
		"Prompt must mention the 'show' primitive")


func test_build_prompt_contains_hide_primitive() -> void:
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("hide"),
		"Prompt must mention the 'hide' primitive")


func test_build_prompt_contains_highlight_primitive() -> void:
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("highlight"),
		"Prompt must mention the 'highlight' primitive")


func test_build_prompt_contains_arrange_primitive() -> void:
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("arrange"),
		"Prompt must mention the 'arrange' primitive")


func test_build_prompt_contains_annotate_primitive() -> void:
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("annotate"),
		"Prompt must mention the 'annotate' primitive")


func test_build_prompt_contains_connect_primitive() -> void:
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("connect"),
		"Prompt must mention the 'connect' primitive")


func test_build_prompt_contains_node_id_auth_service() -> void:
	# THEN the system generates a view focused on auth-related components
	# The prompt must expose node ids so the LLM can refer to them in the spec.
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("auth_service"),
		"Prompt must include node id 'auth_service' from the graph")


func test_build_prompt_contains_node_id_user_db() -> void:
	var prompt: String = LLMViewGenerator.build_prompt("test", _make_graph())
	_check(prompt.contains("user_db"),
		"Prompt must include node id 'user_db' from the graph")


func test_build_prompt_handles_empty_graph() -> void:
	# No crash when there are no nodes — prompt is still valid.
	var prompt: String = LLMViewGenerator.build_prompt("test", {"nodes": [], "edges": []})
	_check(prompt.length() > 0,
		"build_prompt() must handle an empty graph without error")


func test_build_prompt_handles_missing_nodes_key() -> void:
	# No crash when "nodes" key is absent from the graph dict.
	var prompt: String = LLMViewGenerator.build_prompt("test", {})
	_check(prompt.length() > 0,
		"build_prompt() must handle a graph dict with no 'nodes' key")


# ---------------------------------------------------------------------------
# parse_response — Scenario: LLM produces view spec
# THEN it emits a structured view specification (not raw 3D geometry)
# Implemented by parse_response() returning a plain Dictionary.
# ---------------------------------------------------------------------------

func test_parse_response_returns_dictionary() -> void:
	var llm_json: String = '{"question": "how does auth work?", "operations": []}'
	var result = LLMViewGenerator.parse_response(llm_json)
	_check(result is Dictionary,
		"parse_response() must return a Dictionary (not raw geometry), got type %d" % typeof(result))


func test_parse_response_has_question_key() -> void:
	var llm_json: String = '{"question": "how does auth work?", "operations": []}'
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check("question" in spec,
		"parse_response() result must have a 'question' key")


func test_parse_response_has_operations_key() -> void:
	var llm_json: String = '{"question": "test", "operations": []}'
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check("operations" in spec,
		"parse_response() result must have an 'operations' key")


func test_parse_response_operations_is_array() -> void:
	var llm_json: String = '{"question": "test", "operations": []}'
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec.get("operations") is Array,
		"parse_response() 'operations' must be an Array")


func test_parse_response_preserves_question() -> void:
	# The LLM echoes back the original question; parse_response must preserve it.
	var llm_json: String = '{"question": "how does authentication work?", "operations": []}'
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec.get("question", "") == "how does authentication work?",
		"parse_response() must preserve the question, got '%s'" % spec.get("question", ""))


# ---------------------------------------------------------------------------
# parse_response — Scenario: Architectural question
# AND the relevant components are arranged to answer the question
# Implemented by parse_response() passing through "show", "hide", "arrange" ops.
# ---------------------------------------------------------------------------

func test_parse_response_passes_through_show_op() -> void:
	# THEN the system generates a view showing the user database and all its dependents
	var llm_json: String = (
		'{"question": "test", "operations": [{"op": "show", "ids": ["auth_service"]}]}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 1,
		"parse_response() must pass through 'show' op, expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "show",
		"Op must be 'show', got '%s'" % spec["operations"][0]["op"])


func test_parse_response_passes_through_hide_op() -> void:
	# AND irrelevant components are hidden or de-emphasized
	var llm_json: String = (
		'{"question": "test", "operations": [{"op": "hide", "ids": ["payment_service"]}]}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 1,
		"parse_response() must pass through 'hide' op, expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "hide",
		"Op must be 'hide', got '%s'" % spec["operations"][0]["op"])


func test_parse_response_passes_through_arrange_op() -> void:
	# AND the relevant components are arranged to answer the question
	var llm_json: String = (
		'{"question": "test", "operations": [{"op": "arrange", "id": "auth_service", '
		+ '"position": {"x": 5.0, "y": 0.0, "z": 0.0}}]}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 1,
		"parse_response() must pass through 'arrange' op, expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "arrange",
		"Op must be 'arrange', got '%s'" % spec["operations"][0]["op"])


func test_parse_response_passes_through_connect_op() -> void:
	# AND the dependency relationships are spatially clear
	var llm_json: String = (
		'{"question": "test", "operations": [{"op": "connect", "source": "auth_service", '
		+ '"target": "user_db"}]}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 1,
		"parse_response() must pass through 'connect' op, expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "connect",
		"Op must be 'connect', got '%s'" % spec["operations"][0]["op"])


func test_parse_response_passes_through_highlight_op() -> void:
	var llm_json: String = (
		'{"question": "test", "operations": [{"op": "highlight", "ids": ["auth_service"], '
		+ '"color": [1.0, 0.5, 0.0]}]}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 1,
		"parse_response() must pass through 'highlight' op, expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "highlight",
		"Op must be 'highlight', got '%s'" % spec["operations"][0]["op"])


func test_parse_response_passes_through_annotate_op() -> void:
	var llm_json: String = (
		'{"question": "test", "operations": [{"op": "annotate", "id": "auth_service", '
		+ '"text": "Entry point"}]}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 1,
		"parse_response() must pass through 'annotate' op, expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "annotate",
		"Op must be 'annotate', got '%s'" % spec["operations"][0]["op"])


func test_parse_response_all_six_ops_pass_through() -> void:
	# THEN it composes the answer from the existing set of primitives
	# (show, hide, highlight, arrange, annotate, connect)
	var llm_json: String = (
		'{"question": "test", "operations": ['
		+ '{"op": "show", "ids": ["a"]},'
		+ '{"op": "hide", "ids": ["b"]},'
		+ '{"op": "highlight", "ids": ["a"], "color": [1,0,0]},'
		+ '{"op": "arrange", "id": "a", "position": {"x":1,"y":0,"z":0}},'
		+ '{"op": "annotate", "id": "a", "text": "hello"},'
		+ '{"op": "connect", "source": "a", "target": "b"}'
		+ ']}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 6,
		"All 6 valid ops must pass through parse_response(), got %d" % spec["operations"].size())


# ---------------------------------------------------------------------------
# parse_response — Scenario: LLM uses existing primitives
# AND no new rendering logic is generated at runtime
# Implemented by parse_response() delegating to ViewSpec.from_dict() which
# drops any op not in VALID_OPS.
# ---------------------------------------------------------------------------

func test_parse_response_filters_unknown_ops() -> void:
	# AND no new rendering logic is generated at runtime
	# An unknown op in the LLM response must be filtered out.
	var llm_json: String = (
		'{"question": "test", "operations": ['
		+ '{"op": "invent_new_renderer", "ids": ["a"]},'
		+ '{"op": "show", "ids": ["a"]}'
		+ ']}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 1,
		"Unknown ops from LLM must be filtered; expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "show",
		"Only 'show' must survive filtering, got '%s'" % spec["operations"][0]["op"])


func test_parse_response_with_all_unknown_ops_returns_empty_operations() -> void:
	# If the LLM invents entirely new ops, the result has zero operations.
	var llm_json: String = (
		'{"question": "test", "operations": ['
		+ '{"op": "render_as_graph"},'
		+ '{"op": "explode_view"}'
		+ ']}'
	)
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec["operations"].size() == 0,
		"All-unknown ops must yield zero operations, got %d" % spec["operations"].size())


# ---------------------------------------------------------------------------
# parse_response — error handling
# ---------------------------------------------------------------------------

func test_parse_response_handles_malformed_json() -> void:
	# Malformed JSON must not crash; return an empty but valid spec.
	var spec: Dictionary = LLMViewGenerator.parse_response("this is not valid json {")
	_check(spec is Dictionary,
		"parse_response() must return a Dictionary even on malformed JSON")
	_check(spec.has("operations"),
		"Result must have 'operations' key even on parse failure")
	_check(spec["operations"] is Array,
		"'operations' must be an Array even on parse failure")


func test_parse_response_handles_empty_string() -> void:
	var spec: Dictionary = LLMViewGenerator.parse_response("")
	_check(spec is Dictionary,
		"parse_response() must handle empty string input")
	_check(spec.has("operations"), "Result must have 'operations' key on empty input")


func test_parse_response_handles_json_array_instead_of_object() -> void:
	# If the LLM returns a JSON array instead of an object, return empty spec.
	var spec: Dictionary = LLMViewGenerator.parse_response("[1, 2, 3]")
	_check(spec is Dictionary,
		"parse_response() must return a Dictionary even when LLM returns a JSON array")
	_check(spec.has("operations"), "Result must have 'operations' key")


func test_parse_response_strips_markdown_code_fences() -> void:
	# LLMs sometimes wrap JSON in ``` ... ``` — parse_response must strip them.
	var llm_json: String = "```json\n{\"question\": \"test\", \"operations\": []}\n```"
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec is Dictionary,
		"parse_response() must handle markdown code fences")
	_check(spec.has("question"),
		"Result must have 'question' key after stripping fences")
	_check(spec.get("question", "MISSING") == "test",
		"Question must be 'test' after stripping fences, got '%s'" % spec.get("question", "MISSING"))


func test_parse_response_strips_plain_code_fences() -> void:
	# Some LLMs emit ``` without the language tag.
	var llm_json: String = "```\n{\"question\": \"test\", \"operations\": []}\n```"
	var spec: Dictionary = LLMViewGenerator.parse_response(llm_json)
	_check(spec is Dictionary and spec.has("question"),
		"parse_response() must handle plain ``` code fences")
