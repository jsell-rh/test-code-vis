## Headless test runner for code-vis GDScript tests.
##
## Usage:
##   godot --headless --path godot/ --script tests/run_tests.gd
##
## Each test_*.gd file is loaded, its test_* methods are discovered and called.
## Results are printed to stdout. Exits 0 on all-pass, 1 on any failure.
##
## Supports two test patterns:
##   1. _check()/_test_failed pattern  — test methods return void; failure is
##      signalled by setting _test_failed = true inside _check().
##   2. Bool-return pattern            — test methods return true (pass) or
##      false (fail) directly.

extends SceneTree

var _passes: int = 0
var _failures: int = 0


func _init() -> void:
	print("=== code-vis GDScript Tests ===")

	# --- Existing test suites (from completed prior tasks) ---
	_run_suite(preload("res://tests/test_scene_graph_loader.gd").new())
	_run_suite(preload("res://tests/test_node_renderer.gd").new())

	# --- task-009: Godot Application spec ---
	_run_suite(preload("res://tests/test_scene_graph_loading.gd").new())
	_run_suite(preload("res://tests/test_containment_rendering.gd").new())
	_run_suite(preload("res://tests/test_dependency_rendering.gd").new())
	_run_suite(preload("res://tests/test_size_encoding.gd").new())
	_run_suite(preload("res://tests/test_camera_controls.gd").new())
	_run_suite(preload("res://tests/test_engine_version.gd").new())

	# --- task-013: Godot 4.6 / Engine version scenario ---
	_run_suite(preload("res://tests/test_godot_version.gd").new())

	# --- task-014: Spatial structure spec ---
	_run_suite(preload("res://tests/test_spatial_structure.gd").new())

	# --- task-026: UX Polish spec ---
	_run_suite(preload("res://tests/test_ux_polish.gd").new())

	# --- task-015: Path overlay spec (data-flow.spec.md) ---
	_run_suite(preload("res://tests/test_flow_overlay.gd").new())

	print("")
	print("Results: %d passed, %d failed" % [_passes, _failures])

	if _failures > 0:
		quit(1)
	else:
		quit(0)


func _run_suite(obj: Object) -> void:
	var path: String = obj.get_script().get_path()
	print("\n[%s]" % path.get_file())
	for m: Dictionary in obj.get_method_list():
		var method_name: String = m["name"]
		if method_name.begins_with("test_"):
			_run_one(obj, method_name)


func _run_one(obj: Object, method_name: String) -> void:
	# Detect which test pattern this suite uses by checking for _test_failed.
	# Pattern 1: suite has _test_failed property → uses _check() to signal failure.
	# Pattern 2: test method returns bool (true = pass, false = fail).
	var script: GDScript = obj.get_script()
	var has_test_failed: bool = false
	for prop: Dictionary in script.get_script_property_list():
		if prop["name"] == "_test_failed":
			has_test_failed = true
			break

	if has_test_failed:
		# Pattern 1: _check()/_test_failed
		obj.set("_runner", self)
		obj.set("_test_failed", false)
		obj.call(method_name)
		if obj.get("_test_failed"):
			print("  FAIL: %s" % method_name)
			_failures += 1
		else:
			print("  PASS: %s" % method_name)
			_passes += 1
	else:
		# Pattern 2: method returns bool
		var result = obj.call(method_name)
		if result == true:
			print("  PASS: %s" % method_name)
			_passes += 1
		else:
			print("  FAIL: %s" % method_name)
			_failures += 1


func record_failure(msg: String) -> void:
	print("    -> %s" % msg)
