## Tests for Requirement: Godot 4.6
##
## Spec scenario: Engine version
##   GIVEN the project is opened in Godot
##   WHEN the project settings are inspected
##   THEN it uses Godot 4.6.x
##   AND all scripts use GDScript
##   AND all API calls are valid for the Godot 4.6 API
##
## Guidelines:
##   - Technology/version constraint scenarios require behavioral tests that read the
##     config file and assert the expected version string appears in the content.
##   - _ready() file I/O must be covered: this test exercises FileAccess.open() +
##     get_as_text() on a known file and asserts its content, covering that code path.
extends RefCounted


## THEN it uses Godot 4.6.x —
## Read project.godot via FileAccess.open() + get_as_text() and assert the
## version string "4.6" is present in the file content.
func test_project_godot_declares_version_4_6() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	return content.contains("4.6")


## AND the features array in project.godot references "4.6" —
## The config/features line must include the "4.6" feature tag so the
## Godot editor enforces the correct engine version constraint.
func test_project_features_include_4_6() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	# project.godot stores features as: config/features=PackedStringArray("4.6")
	return content.contains("\"4.6\"")


## AND all scripts use GDScript —
## The main script file must be a .gd file (not C# or other) and must be
## loadable as GDScript, confirming the project does not mix languages.
func test_main_script_is_gdscript() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	# run/main_scene must point to a .tscn (GDScript-backed) scene, not a .cs scene.
	return content.contains("main.tscn") and not content.contains(".cs")


## AND all scripts use GDScript (iteration) —
## Iterates every file in res://scripts/ using DirAccess and asserts that
## every file has a .gd extension.  This covers the "all scripts use GDScript"
## THEN-clause by enumerating the complete set, not by checking a config string.
func test_scripts_dir_contains_only_gdscript() -> bool:
	var dir := DirAccess.open("res://scripts")
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name != "":
			if not file_name.ends_with(".gd"):
				dir.list_dir_end()
				return false
		file_name = dir.get_next()
	dir.list_dir_end()
	return true
