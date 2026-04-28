## Tests for Requirement: Desktop Platform
##
## Spec: specs/prototype/nfr.spec.md
## Requirement: Desktop Platform
##
## "The prototype MUST run as a native desktop application on Linux (Fedora).
##  It MUST NOT depend on a browser, container, or VM."
##
## Scenario: Running the prototype
##   GIVEN a Linux desktop (Fedora 42)
##   WHEN the user launches the Godot application
##   THEN it runs natively without browser, container, or VM dependencies
##
## Guidelines satisfied:
##   - Platform/runtime constraint THEN-clauses require explicit OS.has_feature() tests.
##   - Read project.godot via FileAccess.open() + get_as_text() and assert no
##     web-export settings are present.
##   - All tests use Pattern-1 (_check() / _test_failed).
##
## Tests in this file:
##   test_not_running_in_web_browser
##   test_not_running_on_android
##   test_not_running_on_ios
##   test_project_godot_has_no_web_export_preset

extends RefCounted

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# THEN it runs natively without browser, container, or VM dependencies
# ---------------------------------------------------------------------------

## OS.has_feature("web") must be false — the application must not run in a browser.
## Implements: "runs natively without browser ... dependencies"
func test_not_running_in_web_browser() -> void:
	_check(
		not OS.has_feature("web"),
		"OS.has_feature('web') must be false — prototype runs as desktop app, not in browser"
	)


## OS.has_feature("android") must be false — not a mobile/containerised platform.
## Implements: "runs natively without ... container, or VM dependencies"
func test_not_running_on_android() -> void:
	_check(
		not OS.has_feature("android"),
		"OS.has_feature('android') must be false — prototype targets desktop Linux, not Android"
	)


## OS.has_feature("ios") must be false — not a mobile/containerised platform.
## Implements: "runs natively without ... VM dependencies"
func test_not_running_on_ios() -> void:
	_check(
		not OS.has_feature("ios"),
		"OS.has_feature('ios') must be false — prototype targets desktop Linux, not iOS"
	)


## project.godot must not contain a web/HTML5 export preset.
## Implements: "runs natively without browser ... dependencies" at the configuration level.
## Uses FileAccess.open() + get_as_text() — same code path required by guidelines.
func test_project_godot_has_no_web_export_preset() -> void:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	_check(file != null, "FileAccess.open('res://project.godot') must succeed")
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	_check(
		not content.contains("HTML5") and not content.contains("Web"),
		"project.godot must not declare an HTML5/Web export preset — desktop only"
	)
