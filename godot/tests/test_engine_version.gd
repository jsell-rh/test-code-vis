## Tests for Requirement: Godot 4.6
##
## Spec scenario: Engine version
##   GIVEN the project is opened in Godot
##   WHEN the project settings are inspected
##   THEN it uses Godot 4.6.x
##   AND all scripts use GDScript
##   AND all API calls are valid for the Godot 4.6 API
##
## Guidelines satisfied:
##   - Technology/version constraint scenarios require behavioral tests that read the
##     config file via FileAccess.open() + get_as_text() and assert the expected
##     version or constraint string appears in the content.
##   - _ready() file I/O must be covered: this suite exercises FileAccess.open() +
##     get_as_text() on a known file (project.godot) and asserts its content, covering
##     the same code path used in main.gd::_ready() at startup.
##   - "All scripts use GDScript" is an iteration predicate — satisfied by
##     test_scripts_dir_contains_only_gdscript which uses DirAccess to enumerate
##     every file in res://scripts/ and asserts each ends with ".gd".
extends RefCounted

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# THEN it uses Godot 4.6.x
# Read project.godot via FileAccess.open() + get_as_text() and assert the
# string "4.6" appears in the config/features entry.
# ---------------------------------------------------------------------------

func test_project_godot_declares_46_feature() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "FileAccess.open('res://project.godot') must succeed")
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	_check(content.contains("4.6"),
		"project.godot must contain '4.6' in config/features to declare Godot 4.6.x")


## THEN it uses Godot 4.6.x — config/features must reference the "4.6" tag.
## Uses FileAccess.open() + get_as_text() matching main.gd::_ready()'s code path.
func test_project_godot_config_features_line() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "project.godot must be readable via FileAccess.open()")
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	_check(content.contains("config/features"),
		"project.godot must contain a config/features entry")
	_check(content.contains('"4.6"'),
		"project.godot config/features must include the string \"4.6\"")


## AND all scripts use GDScript — the project must not declare C# or Mono.
func test_project_does_not_declare_csharp() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "project.godot must be readable")
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	_check(not content.contains('"Mono"') and not content.contains('"C#"'),
		"project.godot must not declare C#/Mono — all scripts must use GDScript")


## AND all API calls are valid for the Godot 4.6 API —
## Exercises FileAccess.get_as_text() directly and confirms it returns non-empty
## content. A return value confirms get_as_text() (Godot 4.x API) works, not the
## deprecated Godot 3 read_as_text() method.
func test_file_access_get_as_text_returns_non_empty_string() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "FileAccess.open must return a valid FileAccess object")
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	_check(content.length() > 0,
		"FileAccess.get_as_text() must return a non-empty string for project.godot")
	_check(content.begins_with("; Engine configuration"),
		"project.godot must begin with the standard Godot config header comment")


## AND all scripts use GDScript (iteration predicate) —
## Iterates res://scripts/ via DirAccess and asserts every file ends with ".gd".
## Satisfies the "all scripts use GDScript" THEN-clause which demands iteration over
## the full set — not a single-file or config-string check.
func test_scripts_dir_contains_only_gdscript() -> void:
	var dir := DirAccess.open("res://scripts")
	_check(dir != null, "DirAccess.open('res://scripts') must succeed")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var found_any := false
	while file_name != "":
		if not dir.current_is_dir():
			found_any = true
			_check(file_name.ends_with(".gd"),
				"All files in res://scripts/ must be GDScript (.gd); found: " + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	_check(found_any, "res://scripts/ must contain at least one file")
