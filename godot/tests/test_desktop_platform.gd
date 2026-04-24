## Tests for Desktop Platform requirement.
##
## Spec: specs/prototype/nfr.spec.md
## Requirement: Desktop Platform
##   The prototype MUST run as a native desktop application on Linux (Fedora).
##
## Scenario: Running the prototype
##   GIVEN a Linux desktop (Fedora 42)
##   WHEN the user launches the Godot application
##   THEN it runs natively without browser, container, or VM dependencies
##
## THEN-clause coverage:
##   THEN it runs natively without browser, container, or VM dependencies
##     → test_not_running_in_web_context
##     → test_not_running_on_android
##     → test_not_running_on_ios

extends RefCounted


## [THEN] runs natively without browser dependencies.
## OS.has_feature("web") returns false on a native Linux desktop application.
func test_not_running_in_web_context() -> bool:
	return not OS.has_feature("web")


## [THEN] runs natively without mobile (Android) VM/container dependencies.
## OS.has_feature("android") returns false on a native Linux desktop application.
func test_not_running_on_android() -> bool:
	return not OS.has_feature("android")


## [THEN] runs natively without mobile (iOS) dependencies.
## OS.has_feature("ios") returns false on a native Linux desktop application.
func test_not_running_on_ios() -> bool:
	return not OS.has_feature("ios")


## Verify project.godot contains no HTML5/web export configuration.
## Reads the project file and asserts absence of web-export sections.
func test_project_godot_has_no_web_export() -> bool:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	if f == null:
		return false
	var contents: String = f.get_as_text()
	f.close()
	# Web export presets set platform = "Web" or contain [preset.0.options]
	# with "web" or "html5" configuration. Assert neither is present.
	return not contents.to_lower().contains("platform=\"web\"") \
		and not contents.to_lower().contains("platform=\"html5\"")
