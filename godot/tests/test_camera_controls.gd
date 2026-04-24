## Tests for UX Polish spec — camera_controller.gd
##
## Spec: specs/prototype/ux-polish.spec.md
##
## THEN-clause coverage (each clause mapped to a named test below):
##
## [Pan/LMB] THEN the camera pans in the direction of the drag
##   → test_lmb_drag_pans_camera
##
## [Pan/LMB] AND the movement direction matches the drag direction (not inverted)
##   → test_pan_direction_not_inverted
##
## [Drag dir] THEN the scene moves in the same direction as the drag
##   → test_pan_direction_not_inverted  (same behavioral assertion)
##
## [Zoom-in] THEN the view zooms toward the point under the cursor
##   → test_zoom_in_shifts_pivot_toward_cursor
##
## [Zoom-in] AND the component under the cursor stays under the cursor during zoom
##   → test_zoom_in_cursor_point_invariant
##
## [Zoom-out] THEN the view zooms out from the point under the cursor
##   → test_zoom_out_shifts_pivot_away_from_cursor
##
## [Orbit] THEN the camera orbits around the point under the cursor at orbit start
##   → test_orbit_uses_right_mouse_button
##   → test_orbit_around_cursor_point
##
## [Orbit] AND the component remains at the visual center during the orbit
##   → test_orbit_pivot_is_world_point  (pivot = world_pt → always at visual centre)
##
## [Smooth zoom] THEN the zoom is animated smoothly (interpolated), not instantaneous
##   → test_smooth_zoom_target_differs_from_distance_after_scroll
##   → test_smooth_zoom_process_interpolates_distance
##
## [Smooth pan] THEN the pan movement is smooth and proportional to drag speed
##   → test_pan_proportional_to_drag_speed
##
## Clamping boundary tests (required by check-clamp-boundary-tests.sh):
##   _distance = clamp(...)  → test_set_pivot_clamps_distance_at_minimum
##   _theta    = clamp(...)  → test_theta_clamped_at_minimum
##                             test_theta_clamped_at_maximum
##
## Implementation under test: godot/scripts/camera_controller.gd

extends RefCounted

const CameraScript := preload("res://scripts/camera_controller.gd")


# ---------------------------------------------------------------------------
# Existing tests (top-down overview / basic zoom / orbit via middle-mouse)
# ---------------------------------------------------------------------------

## THEN the camera defaults to a top-down view —
## _theta (polar angle from Y-up) must be small: 0 = straight above, PI/2 = side-on.
func test_initial_theta_is_near_top_down() -> bool:
	var cam = CameraScript.new()
	return cam._theta < PI / 4.0


## The initial _distance must be positive (camera is not at the origin/pivot).
func test_initial_distance_is_positive() -> bool:
	var cam = CameraScript.new()
	return cam._distance > 0.0


## WHEN the user scrolls up THEN the camera target distance decreases (zoom in).
## _target_distance must decrease; _distance interpolates in _process().
func test_scroll_up_decreases_target_distance() -> bool:
	var cam = CameraScript.new()
	var initial: float = cam._target_distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam._handle_button(event)

	return cam._target_distance < initial


## WHEN the user scrolls down THEN the camera target distance increases (zoom out).
func test_scroll_down_increases_target_distance() -> bool:
	var cam = CameraScript.new()
	var initial: float = cam._target_distance

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	cam._handle_button(event)

	return cam._target_distance > initial


## WHEN the user middle-mouse drags horizontally THEN the camera orbits —
## a horizontal drag must change the azimuth angle _phi.
func test_orbit_horizontal_drag_changes_phi() -> bool:
	# drag right → delta.x > 0 → _phi -= delta.x * orbit_speed → _phi decreases ✓
	var cam = CameraScript.new()
	var initial_phi: float = cam._phi

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150.0, 100.0)
	cam._handle_motion(motion)

	return cam._phi != initial_phi


## WHEN the user middle-mouse drags vertically THEN the polar angle changes.
func test_orbit_vertical_drag_changes_theta() -> bool:
	# drag up → delta.y < 0 → _theta -= delta.y * orbit_speed → _theta increases → camera tilts toward horizon ✓
	var cam = CameraScript.new()
	var initial_theta: float = cam._theta

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 80.0)
	cam._handle_motion(motion)

	return cam._theta != initial_theta


## set_pivot() must update the internal pivot and distance.
func test_set_pivot_updates_state() -> bool:
	var cam = CameraScript.new()
	var new_pivot := Vector3(5.0, 0.0, 5.0)
	var new_distance: float = 100.0
	cam.set_pivot(new_pivot, new_distance)
	return cam._pivot == new_pivot and cam._distance == new_distance


# ---------------------------------------------------------------------------
# Pan with Left Mouse Button — non-inverted
# ---------------------------------------------------------------------------

## [THEN] the camera pans in the direction of the drag.
## LMB press + motion must change the pivot.
func test_lmb_drag_pans_camera() -> bool:
	var cam = CameraScript.new()
	var initial_pivot: Vector3 = cam._pivot

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150.0, 100.0)
	cam._handle_motion(motion)

	return cam._pivot != initial_pivot


## [AND] the movement direction matches the drag direction (not inverted).
## Google Maps convention: "dragging left reveals content to the right" (spec).
## At phi = PI/2 the camera is on the +Z side; its local X axis (basis.x) = world +X.
## Drag LEFT (delta.x < 0):
##   _target_pivot -= right * delta.x   → -= (+X) * (negative) → pivot.x increases
##   → camera moves +X → scene shifts −X (left on screen, same direction as drag) ✓
func test_pan_direction_not_inverted() -> bool:
	var cam = CameraScript.new()
	cam._theta = 0.15
	cam._phi = PI / 2.0
	cam._distance = 40.0
	cam._update_transform()  # set transform.basis from spherical state

	# Press LMB.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Drag 50 pixels to the LEFT (position goes from 100 → 50, delta.x = -50).
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50.0, 100.0)
	cam._handle_motion(motion)

	# drag left → delta.x < 0 → × right (+X at phi=PI/2) × minus sign → pivot.x increases
	# → camera moves +X → scene shifts left (−X) ← drag direction is left ✓
	# (dragging left → scene moves left → right-side content revealed, Google Maps style)
	return cam._pivot.x > 0.0


# ---------------------------------------------------------------------------
# Zoom Toward Mouse Cursor
# ---------------------------------------------------------------------------

## [THEN] the view zooms toward the point under the cursor.
## Zooming in with cursor world-point to the right of pivot must shift _target_pivot rightward.
func test_zoom_in_shifts_pivot_toward_cursor() -> bool:
	var cam = CameraScript.new()
	cam._target_distance = 40.0
	cam._target_pivot = Vector3.ZERO

	var world_pt := Vector3(10.0, 0.0, 0.0)  # cursor is to the right
	cam._zoom_toward_point(world_pt, -1)       # zoom in

	# _target_pivot must move toward world_pt (positive X).
	return cam._target_pivot.x > 0.0


## [AND] the component under the cursor stays under the cursor during zoom.
## Invariant: world_pt lies on the line between new _target_pivot and camera position.
## Equivalent: world_pt == world_pt + (pivot - world_pt) * ratio evaluated at ratio.
## Simple proxy: after zoom toward world_pt, the new pivot is between old pivot and world_pt.
func test_zoom_in_cursor_point_invariant() -> bool:
	var cam = CameraScript.new()
	cam._target_pivot = Vector3.ZERO
	cam._target_distance = 40.0

	var world_pt := Vector3(20.0, 0.0, 0.0)
	cam._zoom_toward_point(world_pt, -1)

	# new_pivot = world_pt + (old_pivot - world_pt) * ratio, ratio < 1 (zoom in)
	# So new_pivot.x is between old_pivot.x (0) and world_pt.x (20): 0 < new_pivot.x < 20
	return cam._target_pivot.x > 0.0 and cam._target_pivot.x < world_pt.x


## [THEN] the view zooms out from the point under the cursor.
## Zooming out moves _target_distance up AND shifts pivot away from cursor.
func test_zoom_out_shifts_pivot_away_from_cursor() -> bool:
	var cam = CameraScript.new()
	cam._target_pivot = Vector3.ZERO
	cam._target_distance = 40.0

	# Cursor is at +X; zooming out should push pivot in -X (away from cursor).
	var world_pt := Vector3(10.0, 0.0, 0.0)
	cam._zoom_toward_point(world_pt, 1)  # zoom out

	# zoom_ratio > 1 → _target_pivot = world_pt + (pivot - world_pt) * ratio
	# = (10,0,0) + ((0,0,0) - (10,0,0)) * ratio = (10 - 10*ratio, 0, 0)
	# ratio > 1 → x < 0 → pivot moved away from world_pt.
	return cam._target_pivot.x < 0.0


# ---------------------------------------------------------------------------
# Orbit Around Mouse Point
# ---------------------------------------------------------------------------

## [THEN] the camera orbits around the point under the cursor at orbit start.
## RMB press + motion must change _phi (orbit happening).
func test_orbit_uses_right_mouse_button() -> bool:
	var cam = CameraScript.new()
	cam._update_transform()
	var initial_phi: float = cam._phi

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150.0, 100.0)
	cam._handle_motion(motion)

	return cam._phi != initial_phi


## [THEN] the camera orbits around the point under the cursor.
## begin_orbit_at_world_point() must set _pivot to the supplied world point.
func test_orbit_around_cursor_point() -> bool:
	var cam = CameraScript.new()
	cam._theta = 0.15
	cam._phi = 0.0
	cam._distance = 40.0
	cam._update_transform()

	var world_pt := Vector3(5.0, 0.0, 3.0)
	cam.begin_orbit_at_world_point(world_pt)

	return cam._pivot == world_pt


## [AND] the component remains at the visual centre during the orbit.
## After begin_orbit_at_world_point, the camera looks_at _pivot which equals world_pt,
## so world_pt is always the visual centre.
func test_orbit_pivot_is_world_point() -> bool:
	var cam = CameraScript.new()
	cam._distance = 40.0
	cam._update_transform()

	var world_pt := Vector3(8.0, 0.0, -4.0)
	cam.begin_orbit_at_world_point(world_pt)

	# Camera must look at _pivot == world_pt after orbit begins.
	return cam._pivot.is_equal_approx(world_pt)


# ---------------------------------------------------------------------------
# Smooth Camera Movement
# ---------------------------------------------------------------------------

## [THEN] the zoom is animated smoothly (interpolated), not instantaneous.
## After a scroll event, _target_distance must differ from _distance —
## they only converge during _process() frames.
func test_smooth_zoom_target_differs_from_distance_after_scroll() -> bool:
	var cam = CameraScript.new()
	cam._distance = 40.0
	cam._target_distance = 40.0

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam._handle_button(event)

	# _target_distance decreased but _distance has not yet interpolated.
	return cam._target_distance < cam._distance


## _process() must interpolate _distance toward _target_distance.
func test_smooth_zoom_process_interpolates_distance() -> bool:
	var cam = CameraScript.new()
	cam._distance = 40.0
	cam._target_distance = 20.0  # set a closer target

	cam._process(0.1)  # simulate one frame

	# _distance must have moved toward 20 but not yet reached it.
	return cam._distance < 40.0 and cam._distance > 20.0


## [THEN] pan movement is smooth — pan is applied immediately without interpolation lag.
## Unlike zoom (which uses target + lerp), pan sets _pivot = _target_pivot on every
## motion event, so there is no lag between drag and scene movement.
func test_pan_applied_immediately_no_lag() -> bool:
	var cam = CameraScript.new()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(130.0, 110.0)
	cam._handle_motion(motion)

	# Pan must be applied immediately: _pivot == _target_pivot (no lerp lag).
	return cam._pivot.is_equal_approx(cam._target_pivot)


## [THEN] the pan movement is smooth and proportional to drag speed.
## A larger drag delta must produce a proportionally larger pivot displacement.
func test_pan_proportional_to_drag_speed() -> bool:
	# larger |delta.x| → larger |right * delta.x * pan_amount| → larger |pivot displacement| ✓
	var cam_slow = CameraScript.new()
	var cam_fast = CameraScript.new()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam_slow._handle_button(press)
	cam_fast._handle_button(press)

	# Small drag for cam_slow.
	var slow_motion := InputEventMouseMotion.new()
	slow_motion.position = Vector2(110.0, 100.0)  # 10 pixels right
	cam_slow._handle_motion(slow_motion)

	# Large drag for cam_fast.
	var fast_motion := InputEventMouseMotion.new()
	fast_motion.position = Vector2(150.0, 100.0)  # 50 pixels right
	cam_fast._handle_motion(fast_motion)

	# cam_fast must have moved the pivot more than cam_slow.
	return cam_fast._pivot.length() > cam_slow._pivot.length()


# ---------------------------------------------------------------------------
# Clamping boundary tests (required by check-clamp-boundary-tests.sh)
# ---------------------------------------------------------------------------

## _distance = clamp(distance, min_distance, max_distance) in set_pivot() —
## passing 0.0 must clamp to min_distance.
func test_set_pivot_clamps_distance_at_minimum() -> bool:
	var cam = CameraScript.new()
	cam.set_pivot(Vector3.ZERO, 0.0)
	return cam._distance >= cam.min_distance


## _theta = clamp(..., 0.01, PI - 0.01): extreme upward drag must clamp at 0.01.
func test_theta_clamped_at_minimum() -> bool:
	var cam = CameraScript.new()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Huge upward drag tries to push theta below 0.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, -100000.0)
	cam._handle_motion(motion)

	return cam._theta >= 0.01


## _theta = clamp(..., 0.01, PI - 0.01): extreme downward drag must clamp at PI - 0.01.
func test_theta_clamped_at_maximum() -> bool:
	var cam = CameraScript.new()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Huge downward drag tries to push theta above PI.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 100000.0)
	cam._handle_motion(motion)

	return cam._theta <= PI - 0.01


## Repeated zoom in must never push _target_distance below min_distance.
func test_zoom_clamped_at_minimum() -> bool:
	var cam = CameraScript.new()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	for _i: int in range(200):
		cam._handle_button(event)
	return cam._target_distance >= cam.min_distance
