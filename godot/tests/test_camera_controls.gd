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
const MainScript := preload("res://scripts/main.gd")


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
## MOUSE_BUTTON_WHEEL_UP must decrease _target_distance (smooth-zoom intent).
## _distance lerps toward _target_distance via _process(); check target here.
func test_scroll_up_decreases_distance() -> bool:
	var cam = CameraScript.new()
	var initial_target: float = cam._target_distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam._handle_button(event)

	return cam._target_distance < initial_target


## WHEN the user scrolls down THEN the camera moves farther —
## MOUSE_BUTTON_WHEEL_DOWN must increase _target_distance.
func test_scroll_down_increases_distance() -> bool:
	var cam = CameraScript.new()
	var initial_target: float = cam._target_distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	cam._handle_button(event)

	return cam._target_distance > initial_target


## WHEN the user right-mouse drags horizontally THEN the camera orbits —
## a horizontal drag must change the azimuth angle _phi.
func test_orbit_horizontal_drag_changes_phi() -> bool:
	# drag right 50px → delta.x = +50 → _phi -= delta.x * orbit_speed → _phi decreases → _phi != initial_phi ✓
	var cam = CameraScript.new()
	var initial_phi: float = cam._phi

	# Press right mouse to begin orbiting.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Move 50 pixels to the right.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150.0, 100.0)
	cam._handle_motion(motion)

	# drag right 50px → delta.x = +50 → _phi -= delta.x * orbit_speed → phi decreases → phi != initial_phi ✓
	return cam._phi != initial_phi


## WHEN the user right-mouse drags vertically THEN the polar angle changes —
## a vertical drag must change _theta (camera altitude).
func test_orbit_vertical_drag_changes_theta() -> bool:
	# drag up 20px → delta.y = -20 → _theta -= delta.y * orbit_speed → _theta += 0.1 → _theta != initial_theta ✓
	var cam = CameraScript.new()
	var initial_theta: float = cam._theta

	# Press right mouse to begin orbiting.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Move 20 pixels upward (decreasing screen Y moves camera toward top-down).
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 80.0)
	cam._handle_motion(motion)

	# drag up 20px (screen Y: 100→80) → delta.y = -20 → _theta -= delta.y * orbit_speed → theta increases → theta != initial_theta ✓
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
## repeated scroll-up should never push _target_distance below min_distance.
## With smooth zoom, _distance lerps toward _target_distance; _target_distance
## is the authoritative clamped value.
func test_zoom_clamped_at_minimum() -> bool:
	var cam = CameraScript.new()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	# Scroll in 200 times — must not go below min_distance.
	for _i: int in range(200):
		cam._handle_button(event)
	return cam._distance >= cam.min_distance and cam._target_distance >= cam.min_distance


## AND orientation remains intuitive (up stays up) — north-pole clamp:
## Extreme DOWNWARD drag (large positive delta.y) tries to drive _theta below 0.01
## (theta = 0 = camera directly above; going below 0 would flip through the north pole).
## drag down 10 000 px → delta.y = +10000 → _theta -= +10000 * orbit_speed → clamp to 0.01 ✓
func test_theta_clamped_at_floor_prevents_north_pole_flip() -> bool:
	var cam = CameraScript.new()

	# Begin orbiting via right-mouse press.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# drag down 10 000 px → delta.y = +10000 → _theta -= 10000 * 0.005 = −50 → clamped to 0.01
	var down_motion := InputEventMouseMotion.new()
	down_motion.position = Vector2(100.0, 10100.0)
	cam._handle_motion(down_motion)

	return cam._theta >= 0.01


## AND orientation remains intuitive (up stays up) — south-pole clamp:
## Extreme UPWARD drag (large negative delta.y) tries to drive _theta above PI − 0.01
## (theta = PI = camera directly below; going past PI would flip through the south pole).
## drag up 10 000 px → delta.y = −10000 → _theta -= (−10000 * orbit_speed) = +50 → clamp to PI − 0.01 ✓
func test_theta_clamped_at_ceiling_prevents_south_pole_flip() -> bool:
	var cam = CameraScript.new()

	# Begin orbiting via right-mouse press.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 10100.0)
	cam._handle_button(press)

	# drag up 10 000 px → delta.y = −10000 → _theta -= (−10000 * 0.005) = +50 → clamped to PI − 0.01
	var up_motion := InputEventMouseMotion.new()
	up_motion.position = Vector2(100.0, 100.0)
	cam._handle_motion(up_motion)

	return cam._theta <= PI - 0.01


## THEN the camera defaults to a top-down view SHOWING THE ENTIRE SYSTEM —
## _frame_camera() in main.gd must position the camera pivot at the scene
## centre and set a distance large enough to encompass all nodes.
##
## This test bypasses the @onready null-guard on _camera (which is always null
## in headless tests because the node is never added to the scene tree) by
## injecting a live CameraScript instance via Node.set() before calling
## build_from_graph(). Without injection _frame_camera() returns immediately
## on the null-guard and the "showing the entire system" THEN-clause has zero
## test coverage.
##
## Fixture: two bounded contexts at world positions x=−30 and x=+30
##   → span = 60 units, expected distance = 60 * 1.5 = 90 > 60
##   → scene centre = (0, 0, 0) (midpoint of both positions)
func test_frame_camera_frames_entire_system_after_build_from_graph() -> bool:
	var main_node: Node3D = MainScript.new()
	var cam = CameraScript.new()
	# Inject camera so _frame_camera()'s null-guard does not short-circuit.
	main_node.set("_camera", cam)

	var fixture := {
		"nodes": [
			{
				"id": "ctx_a",
				"name": "ContextA",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -30.0, "y": 0.0, "z": 0.0},
				"size": 10.0,
			},
			{
				"id": "ctx_b",
				"name": "ContextB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 30.0, "y": 0.0, "z": 0.0},
				"size": 10.0,
			},
		],
		"edges": [],
	}
	main_node.build_from_graph(fixture)

	# Scene centre: midpoint of (-30,0,0) and (30,0,0) = (0,0,0).
	# Distance: span = 60, distance = 60 * 1.5 = 90 > 60 — frames the full scene.
	var pivot_ok: bool = cam._pivot.is_equal_approx(Vector3(0.0, 0.0, 0.0))
	var dist_ok: bool = cam._distance > 60.0
	return pivot_ok and dist_ok
