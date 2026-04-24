## Tests for Requirement: Desktop Platform
##
## Spec scenario: Running the prototype (nfr.spec.md)
##   GIVEN a Linux desktop (Fedora 42)
##   WHEN the user launches the Godot application
##   THEN it runs natively without browser, container, or VM dependencies
##
## Covered by asserting OS.has_feature("web") returns false (not a browser app)
## and OS.has_feature("pc") returns true (is a desktop/PC application).
extends RefCounted

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


## THEN it runs natively without browser dependencies —
## OS.has_feature("web") must be false; we are a native desktop app, not a browser
## app exported to HTML5/WebAssembly.
func test_not_web_platform() -> void:
	_check(not OS.has_feature("web"),
		"prototype must run as native desktop app, not in a web browser (web feature must be absent)")


## THEN it runs natively without browser, container, or VM dependencies —
## OS.has_feature("pc") must be true; the application targets a PC/desktop platform.
func test_is_pc_desktop_platform() -> void:
	_check(OS.has_feature("pc"),
		"prototype must run as a PC/desktop application (OS.has_feature('pc') must be true)")
