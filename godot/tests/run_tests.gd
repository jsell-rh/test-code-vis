## Minimal headless test runner for CodeVis GDScript tests.
##
## Usage (from repo root):
##   godot --headless --path godot --script tests/run_tests.gd
##
## Each test_*.gd file must:
##   - extend RefCounted
##   - define one or more methods whose names start with "test_"
##   - return true (PASS) or false (FAIL) from each test method
##
## The runner prints PASS/FAIL per test and exits 0 if all pass, 1 otherwise.
extends SceneTree


func _initialize() -> void:
	print("=== CodeVis GDScript Test Suite ===")
	var total: int = 0
	var passed: int = 0

	var test_script_paths: Array[String] = [
		"res://tests/test_scene_graph_loading.gd",
		"res://tests/test_containment_rendering.gd",
		"res://tests/test_dependency_rendering.gd",
		"res://tests/test_size_encoding.gd",
		"res://tests/test_camera_controls.gd",
	]

	for script_path: String in test_script_paths:
		var script: GDScript = load(script_path)
		if script == null:
			print("ERROR: could not load %s" % script_path)
			continue

		var instance: RefCounted = script.new()
		var file_name: String = script_path.get_file()

		for method: Dictionary in instance.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var ok: bool = instance.call(method_name)
			if ok:
				print("  PASS  %s::%s" % [file_name, method_name])
				passed += 1
			else:
				print("  FAIL  %s::%s" % [file_name, method_name])

		print("---")

	print("%d / %d tests passed." % [passed, total])

	if total > 0 and passed == total:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("SOME TESTS FAILED")
		quit(1)
