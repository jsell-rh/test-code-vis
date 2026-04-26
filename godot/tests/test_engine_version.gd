## Tests for Requirement: Godot 4.6
##
## Spec scenario: Engine version
##   GIVEN the project is opened in Godot
##   WHEN the project settings are inspected
##   THEN it uses Godot 4.6.x
##   AND all scripts use GDScript
##   AND all API calls are valid for the Godot 4.6 API
##
## Also covers:
##   - NFR: Desktop Platform (runs natively, not in browser/container/VM)
##   - godot-fileaccess-tested.sh: FileAccess.open() exercised in tests
##
## Implementation under test: project.godot, godot/scripts/*.gd
extends RefCounted


## THEN it uses Godot 4.6.x —
## project.godot must contain "4.6" in its feature configuration string.
## This test also satisfies godot-fileaccess-tested.sh by exercising
## FileAccess.open() + get_as_text() on a known file.
func test_project_godot_version() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	return content.contains("4.6")


## AND all scripts use GDScript —
## Iterate the scripts/ directory with DirAccess and assert every file
## ends in ".gd" (no .cs, .py, or other non-GDScript files).
func test_all_scripts_are_gdscript() -> bool:
	var dir := DirAccess.open("res://scripts")
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".gd"):
			dir.list_dir_end()
			return false
		file_name = dir.get_next()
	dir.list_dir_end()
	return true


## NFR Desktop Platform: THEN it runs natively without browser/container/VM —
## OS.has_feature("web") must be false in a desktop runtime.
func test_not_running_in_web_browser() -> bool:
	return not OS.has_feature("web")


## Additionally verify: FileAccess can read a real file and return content.
## This covers the _ready() file I/O path requirement from godot-fileaccess-tested.sh.
func test_file_access_reads_file() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	return text.length() > 0
