## Tests for Requirement: Camera Controls
##
## Spec scenarios:
##   Top-down overview:
##     GIVEN the scene is loaded
##     WHEN the application starts
##     THEN the camera defaults to a top-down view showing the entire system
##
##   Zooming in:
##     GIVEN the top-down view
##     WHEN the user scrolls toward a bounded context
##     THEN the camera moves closer
##     AND internal structure becomes visible as the camera approaches
##     AND labels scale to remain readable
##
##   Orbiting:
##     GIVEN any camera position
##     WHEN the user uses mouse controls to orbit
##     THEN the camera rotates around the current focal point
##     AND orientation remains intuitive (up stays up)
##
## Implementation under test: godot/scripts/camera_controller.gd
##
## State variables (_theta, _phi, _distance, _pivot) are GDScript instance
## variables and are directly readable for assertion.
extends RefCounted

const CameraScript := preload("res://scripts/camera_controller.gd")


## THEN the camera defaults to a top-down view —
## _theta (polar angle from Y-up) must be small: 0 = straight above, PI/2 = side-on.
## The initial value 0.15 rad ≈ 8.6° satisfies "predominantly top-down" (< 45° = PI/4).
func test_initial_theta_is_near_top_down() -> bool:
	var cam = CameraScript.new()
	var result: bool = cam._theta < PI / 4.0
	cam.free()
	return result


## The initial _distance must be positive (camera is not at the origin/pivot).
func test_initial_distance_is_positive() -> bool:
	var cam = CameraScript.new()
	var result: bool = cam._distance > 0.0
	cam.free()
	return result


## WHEN the user scrolls up THEN the camera moves closer —
## MOUSE_BUTTON_WHEEL_UP must decrease _distance.
func test_scroll_up_decreases_distance() -> bool:
	var cam = CameraScript.new()
	var initial_distance: float = cam._distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam._handle_button(event)

	var result: bool = cam._distance < initial_distance
	cam.free()
	return result


## WHEN the user scrolls down THEN the camera moves farther —
## MOUSE_BUTTON_WHEEL_DOWN must increase _distance.
func test_scroll_down_increases_distance() -> bool:
	var cam = CameraScript.new()
	var initial_distance: float = cam._distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	cam._handle_button(event)

	var result: bool = cam._distance > initial_distance
	cam.free()
	return result


## WHEN the user middle-mouse drags horizontally THEN the camera orbits —
## a horizontal drag must change the azimuth angle _phi.
func test_orbit_horizontal_drag_changes_phi() -> bool:
	var cam = CameraScript.new()
	var initial_phi: float = cam._phi

	# Press middle mouse to begin orbiting.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Move 50 pixels to the right.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150.0, 100.0)
	cam._handle_motion(motion)

	# _phi should have changed by -50 * orbit_speed
	var result: bool = cam._phi != initial_phi
	cam.free()
	return result


## WHEN the user middle-mouse drags vertically THEN the polar angle changes —
## a vertical drag must change _theta (camera altitude).
func test_orbit_vertical_drag_changes_theta() -> bool:
	var cam = CameraScript.new()
	var initial_theta: float = cam._theta

	# Press middle mouse to begin orbiting.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Move 20 pixels upward (decreasing screen Y moves camera toward top-down).
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 80.0)
	cam._handle_motion(motion)

	var result: bool = cam._theta != initial_theta
	cam.free()
	return result


## AND orientation remains intuitive — set_pivot() must update the internal
## pivot and distance so the camera tracks the scene centre after framing.
func test_set_pivot_updates_state() -> bool:
	var cam = CameraScript.new()
	var new_pivot := Vector3(5.0, 0.0, 5.0)
	var new_distance: float = 100.0
	cam.set_pivot(new_pivot, new_distance)
	var result: bool = cam._pivot == new_pivot and cam._distance == new_distance
	cam.free()
	return result


## Zoom is clamped to [min_distance, max_distance] —
## repeated scroll-up should never push _distance below min_distance.
func test_zoom_clamped_at_minimum() -> bool:
	var cam = CameraScript.new()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	# Scroll in 200 times — must not go below min_distance.
	for _i: int in range(200):
		cam._handle_button(event)
	var result: bool = cam._distance >= cam.min_distance
	cam.free()
	return result


## AND orientation remains intuitive (up stays up) —
## theta is clamped so the camera never flips past the vertical poles.
## Driving a huge downward drag without clamping would push theta past PI,
## causing the camera to invert; clamping to [0.01, PI-0.01] prevents this.
func test_orbit_theta_clamped_prevents_flip() -> bool:
	var cam = CameraScript.new()
	# Begin orbiting.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)
	# Drag a huge distance downward — without clamping this would push theta past PI.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 1000000.0)
	cam._handle_motion(motion)
	# theta must stay at or below PI-0.01 (clamped), preventing camera inversion.
	var result: bool = cam._theta <= PI - 0.01
	cam.free()
	return result
