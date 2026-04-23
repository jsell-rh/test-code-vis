## Behavioral tests for ViewSpec.
##
## Covers the "Fixed Visual Primitive Set" requirement from
## specs/interaction/moldable-views.spec.md.
##
## Scenario: LLM uses existing primitives
##   THEN it composes the answer from the existing set of primitives
##        (show, hide, highlight, arrange, annotate, connect)
##   AND no new rendering logic is generated at runtime

extends RefCounted

const ViewSpec = preload("res://scripts/view_spec.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Scenario: LLM uses existing primitives
# THEN it composes the answer from the existing set of primitives
#      (show, hide, highlight, arrange, annotate, connect)
# Implemented by ViewSpec.VALID_OPS containing exactly these six names.
# ---------------------------------------------------------------------------

func test_valid_ops_contains_show() -> void:
	_check(ViewSpec.VALID_OPS.has("show"), "VALID_OPS must include 'show'")


func test_valid_ops_contains_hide() -> void:
	_check(ViewSpec.VALID_OPS.has("hide"), "VALID_OPS must include 'hide'")


func test_valid_ops_contains_highlight() -> void:
	_check(ViewSpec.VALID_OPS.has("highlight"), "VALID_OPS must include 'highlight'")


func test_valid_ops_contains_arrange() -> void:
	_check(ViewSpec.VALID_OPS.has("arrange"), "VALID_OPS must include 'arrange'")


func test_valid_ops_contains_annotate() -> void:
	_check(ViewSpec.VALID_OPS.has("annotate"), "VALID_OPS must include 'annotate'")


func test_valid_ops_contains_connect() -> void:
	_check(ViewSpec.VALID_OPS.has("connect"), "VALID_OPS must include 'connect'")


func test_valid_ops_has_exactly_six_primitives() -> void:
	# The primitive set is FIXED and FINITE — exactly 6 entries.
	var ops: Array = ViewSpec.get_valid_ops()
	_check(ops.size() == 6, "VALID_OPS must have exactly 6 primitives, got %d" % ops.size())


# ---------------------------------------------------------------------------
# Scenario: LLM uses existing primitives
# AND no new rendering logic is generated at runtime
# Implemented by from_dict() filtering out any op not in VALID_OPS.
# ---------------------------------------------------------------------------

func test_unknown_op_is_filtered_out() -> void:
	# An op named "invent_new_thing" is not in VALID_OPS and must be dropped.
	var raw: Dictionary = {
		"question": "test",
		"operations": [
			{"op": "invent_new_thing", "ids": ["a"]},
			{"op": "show", "ids": ["a"]},
		],
	}
	var spec: Dictionary = ViewSpec.from_dict(raw)
	_check(spec["operations"].size() == 1,
		"Unknown op must be filtered; expected 1 op, got %d" % spec["operations"].size())
	_check(spec["operations"][0]["op"] == "show",
		"Remaining op should be 'show', got '%s'" % spec["operations"][0]["op"])


func test_all_valid_ops_pass_through() -> void:
	# All six primitives must survive from_dict() unchanged.
	var raw: Dictionary = {
		"question": "test",
		"operations": [
			{"op": "show",      "ids": ["a"]},
			{"op": "hide",      "ids": ["b"]},
			{"op": "highlight", "ids": ["a"], "color": [1.0, 0.0, 0.0]},
			{"op": "arrange",   "id": "a", "position": {"x": 1.0, "y": 0.0, "z": 0.0}},
			{"op": "annotate",  "id": "a", "text": "Entry point"},
			{"op": "connect",   "source": "a", "target": "b"},
		],
	}
	var spec: Dictionary = ViewSpec.from_dict(raw)
	_check(spec["operations"].size() == 6,
		"All 6 valid ops must pass through from_dict(), got %d" % spec["operations"].size())


func test_question_is_preserved_in_spec() -> void:
	# The question string must be retained in the returned spec.
	var raw: Dictionary = {
		"question": "how does authentication work?",
		"operations": [],
	}
	var spec: Dictionary = ViewSpec.from_dict(raw)
	_check(spec["question"] == "how does authentication work?",
		"Question must be preserved in spec, got '%s'" % spec["question"])


func test_empty_operations_list_is_valid() -> void:
	var spec: Dictionary = ViewSpec.from_dict({"question": "q", "operations": []})
	_check(spec["operations"].size() == 0,
		"Empty operations list must be valid")


func test_missing_question_defaults_to_empty_string() -> void:
	var spec: Dictionary = ViewSpec.from_dict({"operations": []})
	_check(spec["question"] == "",
		"Missing question must default to empty string, got '%s'" % spec["question"])


func test_get_valid_ops_returns_a_copy() -> void:
	# Mutating the returned array must not change VALID_OPS.
	var ops: Array = ViewSpec.get_valid_ops()
	ops.append("mutated")
	_check(not ViewSpec.VALID_OPS.has("mutated"),
		"get_valid_ops() must return a copy; mutating it must not affect VALID_OPS")
