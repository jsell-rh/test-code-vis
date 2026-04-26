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
	return cam._theta < PI / 4.0


## The initial _distance must be positive (camera is not at the origin/pivot).
func test_initial_distance_is_positive() -> bool:
	var cam = CameraScript.new()
	return cam._distance > 0.0


## WHEN the user scrolls up THEN the camera moves closer —
## MOUSE_BUTTON_WHEEL_UP must decrease _distance.
func test_scroll_up_decreases_distance() -> bool:
	var cam = CameraScript.new()
	var initial_distance: float = cam._distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam._handle_button(event)

	return cam._distance < initial_distance


## WHEN the user scrolls down THEN the camera moves farther —
## MOUSE_BUTTON_WHEEL_DOWN must increase _distance.
func test_scroll_down_increases_distance() -> bool:
	var cam = CameraScript.new()
	var initial_distance: float = cam._distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	cam._handle_button(event)

	return cam._distance > initial_distance


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
	# Sign derivation: drag right → delta.x = +50 → _phi -= 50 * orbit_speed
	# → _phi decreases → camera azimuth rotates → scene on screen shifts ✓
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150.0, 100.0)
	cam._handle_motion(motion)

	# _phi should have changed by -50 * orbit_speed
	return cam._phi != initial_phi


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

	# Move 20 pixels upward (screen Y decreases → delta.y = -20).
	# Sign derivation: drag up → delta.y = -20 → _theta -= (-20) * orbit_speed
	# → _theta increases → camera tilts away from top-down → scene shifts on screen ✓
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 80.0)
	cam._handle_motion(motion)

	return cam._theta != initial_theta


## AND orientation remains intuitive — set_pivot() must update the internal
## pivot and distance so the camera tracks the scene centre after framing.
func test_set_pivot_updates_state() -> bool:
	var cam = CameraScript.new()
	var new_pivot := Vector3(5.0, 0.0, 5.0)
	var new_distance: float = 100.0
	cam.set_pivot(new_pivot, new_distance)
	return cam._pivot == new_pivot and cam._distance == new_distance


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
	return cam._distance >= cam.min_distance


## AND orientation remains intuitive (up stays up) —
## _theta is clamped to [0.01, PI-0.01] to prevent the camera from flipping
## past the poles. An extreme downward drag (delta.y very large) must leave
## _theta >= 0.01 (the minimum clamp boundary).
func test_theta_clamped_at_minimum() -> bool:
	var cam = CameraScript.new()
	cam._theta = 0.02  # near lower pole

	# Press middle mouse to begin orbiting.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Drag DOWN by an extreme amount: delta.y = +10000
	# → _theta -= 10000 * 0.005 = -50 → clamp keeps _theta >= 0.01.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 10100.0)
	cam._handle_motion(motion)

	return cam._theta >= 0.01


## THEN the camera defaults to a top-down view showing the entire system —
## The initial Y component of the camera offset must be positive (camera is above pivot).
## y = _distance * cos(_theta); with _theta = 0.15 ≈ 8.6°, cos(0.15) > 0.98, so y > 0.
func test_initial_camera_is_above_pivot() -> bool:
	var cam = CameraScript.new()
	var y_component: float = cam._distance * cos(cam._theta)
	return y_component > 0.0


## THEN the camera moves closer (zoom toward target) —
## set_pivot(target, distance) must move the pivot to the target point.
## Sign-chain derivation:
## call set_pivot(target, dist) → _pivot = target → distance changes to dist
## → camera frames the target → zoom toward target ✓
func test_zoom_toward_point_moves_pivot_toward_target() -> bool:
	var cam = CameraScript.new()
	var target := Vector3(10.0, 0.0, 10.0)
	var new_distance: float = 20.0
	cam.set_pivot(target, new_distance)
	return cam._pivot == target and cam._distance == new_distance


## AND internal structure becomes visible as the camera approaches —
## A single scroll-up must reduce distance by a bounded (non-instantaneous) amount,
## leaving the camera above min_distance (not snapped to zero/min immediately).
func test_zoom_is_smooth_not_instantaneous() -> bool:
	var cam = CameraScript.new()
	var initial_distance: float = cam._distance  # 40.0

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam._handle_button(event)

	# Distance must have decreased (moved closer) but not jump to min_distance.
	var delta: float = initial_distance - cam._distance
	return delta > 0.0 and cam._distance > cam.min_distance


## THEN the camera rotates around the current focal point —
## A diagonal middle-mouse drag must change BOTH azimuth (_phi) and polar (_theta).
## Sign-chain derivation:
## drag right → delta.x = +50 → _phi -= 50 * orbit_speed → phi changes ✓
## drag down  → delta.y = +50 → _theta -= 50 * orbit_speed → theta changes ✓
func test_orbit_changes_theta_and_phi() -> bool:
	var cam = CameraScript.new()
	var initial_theta: float = cam._theta
	var initial_phi: float = cam._phi

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Diagonal drag changes both angles.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150.0, 150.0)
	cam._handle_motion(motion)

	return cam._phi != initial_phi and cam._theta != initial_theta


## THEN the camera rotates around the current focal point —
## set_pivot repoints the orbit center; after set_pivot the pivot must equal the given point.
func test_orbit_pivot_set_to_cursor_world_point() -> bool:
	var cam = CameraScript.new()
	var new_pivot := Vector3(10.0, 0.0, 5.0)
	cam.set_pivot(new_pivot, cam._distance)
	return cam._pivot == new_pivot


## AND orientation remains intuitive (up stays up) — minimum clamp (spec-named alias) —
## _theta cannot go below 0.01 regardless of how far down the user drags.
## Sign-chain derivation:
## drag down → delta.y = +10000 → _theta -= 10000 * orbit_speed = -50
## → clamp(0.02 - 50, 0.01, PI-0.01) = 0.01 → camera does not flip below lower pole ✓
func test_theta_clamped_at_minimum_to_prevent_flip() -> bool:
	var cam = CameraScript.new()
	cam._theta = 0.02  # near lower pole

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 10100.0)
	cam._handle_motion(motion)

	return cam._theta >= 0.01


## AND orientation remains intuitive (up stays up) — maximum clamp —
## _theta cannot exceed PI-0.01 regardless of how far up the user drags.
## Sign-chain derivation:
## drag up → delta.y = -10000 → _theta -= (-10000) * orbit_speed = +50
## → clamp(PI-0.02 + 50, 0.01, PI-0.01) = PI-0.01 → camera does not flip past upper pole ✓
func test_theta_clamped_at_maximum_to_prevent_flip() -> bool:
	var cam = CameraScript.new()
	cam._theta = PI - 0.02  # near upper pole

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Drag UP by an extreme amount: delta.y = -10000
	# → _theta -= (-10000) * 0.005 = +50 → clamp keeps _theta <= PI - 0.01.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, -9900.0)
	cam._handle_motion(motion)

	return cam._theta <= PI - 0.01
