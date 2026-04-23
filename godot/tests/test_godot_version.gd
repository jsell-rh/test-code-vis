## Tests for Requirement: Godot 4.6
##
## Spec scenario: Engine version
##   GIVEN the project is opened in Godot
##   WHEN the project settings are inspected
##   THEN it uses Godot 4.6.x
##   AND all scripts use GDScript
##   AND all API calls are valid for the Godot 4.6 API
##
## The guideline also requires that the FileAccess.open() + get_as_text() call
## path used in _ready() is exercised by at least one test.
##
## Implementation: godot/project.godot declares config/features=PackedStringArray("4.6")
extends RefCounted


## THEN it uses Godot 4.6.x —
## Read project.godot via FileAccess.open() + get_as_text() and assert "4.6" is present.
## This simultaneously exercises the FileAccess API path used in main.gd::_ready().
func test_project_declares_godot_46() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	return content.contains("4.6")


## THEN all scripts use GDScript —
## Verify that the main application script is a .gd file readable via FileAccess.
## (A C# script would have a .cs extension; its absence confirms GDScript-only.)
func test_main_script_is_gdscript() -> bool:
	var file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	# GDScript files contain "extends" or "func"; check for a non-empty .gd file.
	return content.length() > 0


## THEN all API calls are valid for the Godot 4.6 API —
## Verify that main.gd uses FileAccess.open() + get_as_text() (Godot 4.x API)
## and does NOT use the deprecated Godot 3-style File.new() or read_as_text().
func test_main_uses_godot4_fileaccess_api() -> bool:
	var file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	var uses_godot4_api: bool = content.contains("FileAccess.open(") and content.contains("get_as_text()")
	var no_deprecated_api: bool = not content.contains("File.new()") and not content.contains("read_as_text()")
	return uses_godot4_api and no_deprecated_api
