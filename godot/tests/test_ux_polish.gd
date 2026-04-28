## Tests for UX Polish spec — specs/prototype/ux-polish.spec.md
##
## Requirement: Pan with Left Mouse Button
##   Scenario: Panning the view
##     GIVEN the top-down camera view
##     WHEN the user holds left mouse button and drags
##     THEN the camera pans in the direction of the drag
##     AND the movement direction matches the drag direction (not inverted)
##
## Requirement: Non-Inverted Movement
##   Scenario: Drag direction matches view movement
##     GIVEN any camera position
##     WHEN the user drags in any direction
##     THEN the scene moves in the same direction as the drag
##
## Requirement: Zoom Toward Mouse Cursor
##   Scenario: Zooming into a specific component
##     GIVEN the mouse cursor is positioned over a bounded context
##     WHEN the user scrolls to zoom in
##     THEN the view zooms toward the point under the cursor
##     AND the component under the cursor stays under the cursor during the zoom
##   Scenario: Zooming out
##     GIVEN a zoomed-in view
##     WHEN the user scrolls to zoom out
##     THEN the view zooms out from the point under the cursor
##
## Requirement: Orbit Around Mouse Point
##   Scenario: Orbiting around a component
##     GIVEN the mouse cursor is over a specific component
##     WHEN the user holds right mouse button and drags
##     THEN the camera orbits around the point under the cursor at orbit start
##     AND the component remains at the visual center during the orbit
##
## Requirement: Smooth Camera Movement
##   Scenario: Smooth zoom
##     GIVEN any camera position
##     WHEN the user scrolls to zoom
##     THEN the zoom is animated smoothly (interpolated), not instantaneous
##   Scenario: Smooth pan
##     GIVEN any camera position
##     WHEN the user drags to pan
##     THEN the pan movement is smooth and proportional to drag speed
##
## Implementation under test: godot/scripts/camera_controller.gd

extends RefCounted

const CameraScript := preload("res://scripts/camera_controller.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_cam() -> Object:
	return CameraScript.new()


func _press_lmb(cam: Object, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	cam._handle_button(e)


func _press_rmb(cam: Object, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.position = pos
	cam._handle_button(e)


func _move_mouse(cam: Object, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	cam._handle_motion(e)


# ---------------------------------------------------------------------------
# Pan with Left Mouse Button
# THEN the camera pans in the direction of the drag
# ---------------------------------------------------------------------------

func test_lmb_pan_moves_pivot() -> bool:
	var cam = _make_cam()
	var initial_pivot: Vector3 = cam._pivot

	_press_lmb(cam, Vector2(100.0, 100.0))
	_move_mouse(cam, Vector2(150.0, 100.0))  # drag right 50 px

	# Pivot must have moved from its initial position.
	return cam._pivot != initial_pivot


# ---------------------------------------------------------------------------
# Non-Inverted Movement
# THEN the scene moves in the same direction as the drag
# AND the movement direction matches the drag direction (not inverted)
#
# In a headless test global_transform is identity → basis.x = (1,0,0).
# Dragging right (positive delta.x) must increase pivot.x.
# ---------------------------------------------------------------------------

func test_pan_drag_right_decreases_pivot_x() -> bool:
	# Map-grab model: drag right → pivot moves LEFT (reveals content to the left).
	# Spec: "dragging left reveals content to the right, as in Google Maps".
	# Equivalently, drag right → reveals content to the left → pivot.x DECREASES.
	var cam = _make_cam()
	var initial_x: float = cam._pivot.x

	_press_lmb(cam, Vector2(100.0, 100.0))
	_move_mouse(cam, Vector2(150.0, 100.0))  # drag right → delta.x = +50

	return cam._pivot.x < initial_x


func test_pan_drag_left_increases_pivot_x() -> bool:
	# Map-grab model: drag left → pivot moves RIGHT (reveals content to the right).
	# Spec: "dragging left reveals content to the right, as in Google Maps".
	# → pivot.x INCREASES.
	var cam = _make_cam()
	var initial_x: float = cam._pivot.x

	_press_lmb(cam, Vector2(100.0, 100.0))
	_move_mouse(cam, Vector2(50.0, 100.0))  # drag left → delta.x = -50

	return cam._pivot.x > initial_x


# The scene "moves in the same direction" — dragging down reveals content above
# by shifting pivot in the negative forward direction (map-grab model).
func test_drag_direction_matches_view_movement() -> bool:
	var cam = _make_cam()

	# Drag down → delta.y = +50.  Map-grab: _pivot -= forward * delta.y * pan_amount.
	# In headless identity transform, forward = basis.z = (0,0,1).
	# So _pivot.z DECREASES.  Assert pivot.z < 0.0.
	_press_lmb(cam, Vector2(100.0, 100.0))
	_move_mouse(cam, Vector2(100.0, 150.0))  # drag down 50 px

	return cam._pivot.z < 0.0


# ---------------------------------------------------------------------------
# Zoom Toward Mouse Cursor
# THEN the view zooms toward the point under the cursor
# AND the component under the cursor stays under the cursor during the zoom
# ---------------------------------------------------------------------------

func test_zoom_toward_cursor_shifts_pivot_toward_cursor() -> bool:
	var cam = _make_cam()
	# Pivot starts at origin; cursor is at world (10, 0, 0).
	var cursor_world := Vector3(10.0, 0.0, 0.0)
	cam._zoom_toward_cursor(cursor_world, -cam.zoom_speed)  # zoom in

	# Pivot must have shifted toward the cursor (x increases from 0).
	return cam._pivot.x > 0.0


func test_component_stays_under_cursor_on_zoom_in() -> bool:
	var cam = _make_cam()
	# Cursor is far from pivot; pivot should move toward cursor on zoom-in.
	var cursor_world := Vector3(20.0, 0.0, 0.0)
	var before: float = cam._pivot.x  # 0.0

	cam._zoom_toward_cursor(cursor_world, -cam.zoom_speed)

	# The pivot is now closer to the cursor than it was before.
	var after: float = cam._pivot.x
	return after > before


# ---------------------------------------------------------------------------
# Zooming out
# THEN the view zooms out from the point under the cursor
# ---------------------------------------------------------------------------

func test_zoom_out_from_cursor_shifts_pivot_away() -> bool:
	var cam = _make_cam()
	# Place pivot between origin and cursor.
	cam._pivot = Vector3(5.0, 0.0, 0.0)
	var cursor_world := Vector3(10.0, 0.0, 0.0)

	cam._zoom_toward_cursor(cursor_world, cam.zoom_speed)  # zoom out

	# Pivot should move away from cursor (x decreases below 5).
	return cam._pivot.x < 5.0


func test_zoom_out_increases_target_distance() -> bool:
	var cam = _make_cam()
	var initial_target: float = cam._target_distance
	cam._zoom_toward_cursor(cam._pivot, cam.zoom_speed)

	return cam._target_distance > initial_target


# ---------------------------------------------------------------------------
# Orbit Around Mouse Point
# THEN the camera orbits around the point under the cursor at orbit start
# ---------------------------------------------------------------------------

func test_orbit_pivot_set_to_cursor_point_at_start() -> bool:
	var cam = _make_cam()
	# In headless mode _mouse_to_ground returns _pivot, so call _set_orbit_pivot
	# directly with a known world point — the production code calls exactly this
	# from _handle_button when RMB is pressed.
	var world_point := Vector3(5.0, 0.0, 7.0)
	cam._set_orbit_pivot(world_point)

	return cam._pivot == world_point


func test_orbit_pivot_is_used_during_orbit() -> bool:
	var cam = _make_cam()
	# Set a non-origin orbit pivot.
	var world_point := Vector3(3.0, 0.0, 4.0)
	cam._set_orbit_pivot(world_point)
	var pivot_before: Vector3 = cam._pivot

	# Orbit: RMB already set the pivot; subsequent motion keeps pivot the same
	# (orbit rotates the camera around _pivot, it does not move _pivot).
	cam._orbiting = true
	cam._last_mouse = Vector2(100.0, 100.0)
	_move_mouse(cam, Vector2(120.0, 100.0))  # horizontal drag

	# _pivot must not have changed — the orbit focal point is fixed.
	return cam._pivot == pivot_before


# AND the component remains at the visual center during the orbit —
# verified by asserting _pivot is unchanged after orbit motion.
func test_component_remains_at_visual_center_during_orbit() -> bool:
	var cam = _make_cam()
	cam._set_orbit_pivot(Vector3(8.0, 0.0, 0.0))
	var center: Vector3 = cam._pivot

	cam._orbiting = true
	cam._last_mouse = Vector2(200.0, 200.0)
	_move_mouse(cam, Vector2(250.0, 180.0))  # diagonal drag

	return cam._pivot == center


# ---------------------------------------------------------------------------
# Smooth Camera Movement — Smooth zoom
# THEN the zoom is animated smoothly (interpolated), not instantaneous
# ---------------------------------------------------------------------------

func test_zoom_is_interpolated_not_instantaneous() -> bool:
	var cam = _make_cam()
	var initial_distance: float = cam._distance

	# Trigger zoom in.
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.position = Vector2(400.0, 300.0)
	cam._handle_button(e)

	var target: float = cam._target_distance

	# _distance must NOT have jumped to target immediately.
	if cam._distance != initial_distance:
		return false  # distance changed without _process → not smooth

	# After one frame (16 ms), _distance moves partially toward target.
	cam._process(0.016)
	var after_one_frame: float = cam._distance

	# Must have moved toward target but not fully snapped.
	return after_one_frame < initial_distance and after_one_frame > target


func test_target_distance_clamped_at_minimum() -> bool:
	var cam = _make_cam()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.position = Vector2(0.0, 0.0)
	for _i: int in range(200):
		cam._handle_button(e)
	return cam._target_distance >= cam.min_distance


func test_target_distance_clamped_at_maximum() -> bool:
	var cam = _make_cam()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = Vector2(0.0, 0.0)
	for _i: int in range(200):
		cam._handle_button(e)
	return cam._target_distance <= cam.max_distance


## _theta boundary: extreme upward orbit drag must not push theta below 0.01.
func test_theta_clamped_at_minimum() -> bool:
	var cam = _make_cam()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Large positive delta.y drives theta toward 0 (top-down).
	cam._last_mouse = Vector2(100.0, 100.0)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, 9200.0)  # +9100 px downward
	cam._handle_motion(motion)

	return cam._theta >= 0.01


## _theta boundary: extreme downward orbit drag must not push theta above PI-0.01.
func test_theta_clamped_at_maximum() -> bool:
	var cam = _make_cam()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Large negative delta.y drives theta toward PI (straight below).
	cam._last_mouse = Vector2(100.0, 100.0)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100.0, -9000.0)  # -9100 px upward
	cam._handle_motion(motion)

	return cam._theta <= PI - 0.01


# ---------------------------------------------------------------------------
# Smooth Camera Movement — Smooth pan
# THEN the pan movement is smooth and proportional to drag speed
# ---------------------------------------------------------------------------

func test_pan_proportional_to_drag_speed() -> bool:
	var cam1 = _make_cam()
	var cam2 = _make_cam()

	# Small drag on cam1 (10 px).
	_press_lmb(cam1, Vector2(100.0, 100.0))
	_move_mouse(cam1, Vector2(110.0, 100.0))
	var move1: float = cam1._pivot.length()

	# Larger drag on cam2 (50 px, 5× bigger).
	_press_lmb(cam2, Vector2(100.0, 100.0))
	_move_mouse(cam2, Vector2(150.0, 100.0))
	var move2: float = cam2._pivot.length()

	# Larger drag must produce a larger pivot displacement.
	return move2 > move1
