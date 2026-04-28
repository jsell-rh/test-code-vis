## CameraMode — global singleton tracking the current camera navigation mode.
##
## Autoload registered as "CameraMode" in project.godot.
## In unit tests the singleton is absent (Engine.has_singleton returns false);
## all consumers guard their calls with Engine.has_singleton("CameraMode").
##
## Covers: specs/visualization/spatial-structure.spec.md
## Requirement: 3D Interactive Navigation — first-person mode toggle.
extends Node

## Current mode: true = first-person FPS, false = orbital top-down (default).
var is_first_person: bool = false

## Emitted whenever the navigation mode changes.
## Consumers: camera_controller.gd (to pause orbital processing),
##            first_person_camera_controller.gd (to activate FPS logic).
signal mode_changed(first_person: bool)


## Switch to first-person (FPS) navigation mode.
## Emits mode_changed(true).
func enter_first_person() -> void:
	is_first_person = true
	emit_signal("mode_changed", true)


## Switch back to orbital (top-down) navigation mode.
## Emits mode_changed(false).
func enter_orbital() -> void:
	is_first_person = false
	emit_signal("mode_changed", false)
