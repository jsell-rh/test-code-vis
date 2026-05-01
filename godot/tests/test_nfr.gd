## Behavioral tests for non-functional requirements.
##
## Covers NFR constraints from specs/prototype/nfr.spec.md:
##   - All scripts use GDScript (no C#, no GDNative, no other languages)
##   - FileAccess.open() is exercised by at least one test
##
## Each test_* method is discovered and run by tests/run_tests.gd.

extends RefCounted

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# NFR: All scripts use GDScript
# ---------------------------------------------------------------------------

func test_scripts_dir_contains_only_gdscript() -> void:
	# Spec (nfr.spec.md): "all scripts use GDScript"
	# Iterate every file in res://scripts/ and assert each filename ends in '.gd'.
	var dir := DirAccess.open("res://scripts")
	_check(dir != null, "res://scripts/ must exist and be accessible via DirAccess")
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var found_files := false
	while file_name != "":
		if not dir.current_is_dir():
			found_files = true
			_check(
				file_name.ends_with(".gd"),
				"File '%s' in res://scripts/ must end with '.gd' — only GDScript allowed" % file_name
			)
		file_name = dir.get_next()
	dir.list_dir_end()

	_check(found_files, "res://scripts/ must contain at least one script file")


# ---------------------------------------------------------------------------
# NFR: FileAccess.open() exercised in tests
# ---------------------------------------------------------------------------

func test_fileaccess_reads_project_godot() -> void:
	# Exercises the FileAccess.open() code path in tests.
	# Reads project.godot and asserts it contains the expected config header.
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "FileAccess.open('res://project.godot') must succeed")
	if file == null:
		return

	var content := file.get_as_text()
	file.close()
	_check(
		content.contains("config_version"),
		"project.godot must contain 'config_version' key"
	)
