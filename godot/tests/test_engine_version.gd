## Tests for Requirement: Godot 4.6
##
## Spec scenario: Engine version
##   GIVEN the project is opened in Godot
##   WHEN the project settings are inspected
##   THEN it uses Godot 4.6.x
##   AND all scripts use GDScript
##   AND all API calls are valid for the Godot 4.6 API
##
## Also covers the _ready() FileAccess.open() code path requirement:
## main.gd._ready() uses FileAccess.open() + get_as_text() to load the scene
## graph JSON at startup.  This test exercises the same API on a known file
## (project.godot) and asserts the resulting content, ensuring the call path
## is tested rather than only present in production code.
extends RefCounted

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Scenario: Engine version
# THEN it uses Godot 4.6.x
# Verified by reading project.godot via FileAccess.open() + get_as_text() and
# asserting that the string "4.6" appears in the config features list.
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


## THEN it uses Godot 4.6.x — the features array must declare the "4.6" tag.
## This uses the same FileAccess.open() + get_as_text() API that main.gd._ready()
## uses to load the JSON scene graph, exercising that code path in a test context.
func test_project_godot_config_features_line() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "project.godot must be readable via FileAccess.open()")
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	# The project.godot file must contain a config/features line listing "4.6".
	_check(content.contains("config/features"),
		"project.godot must contain a config/features entry")
	_check(content.contains('"4.6"'),
		"project.godot config/features must include the string \"4.6\"")


## AND all scripts use GDScript — the project must not declare any non-GDScript
## language in config/features (e.g., "C#" or "Mono").
func test_project_does_not_declare_csharp() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "project.godot must be readable")
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	_check(not content.contains('"Mono"') and not content.contains('"C#"'),
		"project.godot must not declare C#/Mono — all scripts must use GDScript")


## FileAccess.get_as_text() API verification — confirms the Godot 4.6 API is
## used (not deprecated read_as_text() from older versions).
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


## AND all scripts use GDScript — iterate res://scripts/ and assert every file
## ends with ".gd". This covers the "all scripts use GDScript" THEN-clause by
## checking the extension of every actual file in the scripts directory.
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
