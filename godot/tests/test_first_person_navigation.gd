## Behavioral tests for specs/visualization/spatial-structure.spec.md
## Requirement: 3D Interactive Navigation — first-person exploration.
##
## Task-108: Godot — first-person camera navigation mode.
##
## Scenarios covered:
##
##   CameraMode singleton
##     GIVEN a fresh CameraMode instance
##     THEN is_first_person is false (orbital is the default)
##     WHEN enter_first_person() is called THEN is_first_person is true
##     WHEN enter_orbital() is called THEN is_first_person is false
##     WHEN mode changes THEN mode_changed signal is emitted
##
##   Mouse look — yaw (horizontal)
##     GIVEN the FPS controller is active
##     WHEN the mouse moves right (event.relative.x > 0)
##     THEN _yaw decreases (camera turns right, clockwise from top)
##
##   Mouse look — pitch (vertical)
##     GIVEN the FPS controller is active
##     WHEN the mouse moves down (event.relative.y > 0)
##     THEN _pitch increases (camera tilts downward)
##
##   Pitch clamped at ±85°
##     GIVEN many downward mouse movements
##     THEN _pitch never exceeds PITCH_LIMIT
##     GIVEN many upward mouse movements
##     THEN _pitch never falls below -PITCH_LIMIT
##
##   Speed adjustment via scroll wheel
##     GIVEN the FPS controller is active
##     WHEN scroll-up is applied
##     THEN _move_speed increases (signed: > initial)
##     THEN _move_speed is clamped at MOVE_SPEED_MAX (boundary: <=)
##     WHEN scroll-down is applied
##     THEN _move_speed decreases (signed: < initial)
##     THEN _move_speed is clamped at MOVE_SPEED_MIN (boundary: >=)
##
##   Orbital camera disabled while FPS is active
##     GIVEN orbital camera_controller with _fps_mode set to true
##     WHEN scroll input is sent
##     THEN _target_distance does not change

extends RefCounted

const CameraModeScript := preload("res://autoload/camera_mode.gd")
const FPSController := preload("res://scripts/first_person_camera_controller.gd")
const CameraControllerScript := preload("res://scripts/camera_controller.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Build a fresh CameraMode instance (simulates the autoload singleton).
func _make_camera_mode() -> Object:
	return CameraModeScript.new()


## Build a FPS controller with is_active forced on (bypasses CameraMode check).
func _make_active_fps() -> Object:
	var ctrl: Object = FPSController.new()
	ctrl.set("_is_active", true)
	return ctrl


## Simulate a mouse-motion event with the given relative movement.
func _make_mouse_motion(rel_x: float, rel_y: float) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(rel_x, rel_y)
	return event


## Simulate a mouse-button event (scroll).
func _make_scroll(button_index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	return event


# ---------------------------------------------------------------------------
# Scenario: CameraMode singleton state
# ---------------------------------------------------------------------------

## GIVEN a fresh CameraMode instance THEN is_first_person defaults to false.
## Orbital mode is the application default; FPS must be explicitly entered.
func test_camera_mode_initial_state_is_orbital() -> void:
	var cm: Object = _make_camera_mode()
	_check(cm.get("is_first_person") == false,
		"CameraMode.is_first_person must be false on construction (orbital is default)")


## WHEN enter_first_person() is called THEN is_first_person becomes true.
## Implemented by: camera_mode.gd → enter_first_person()
##   is_first_person = true; emit_signal("mode_changed", true)
func test_camera_mode_enter_first_person_sets_flag() -> void:
	var cm: Object = _make_camera_mode()
	cm.call("enter_first_person")
	_check(cm.get("is_first_person") == true,
		"enter_first_person() must set is_first_person to true")


## WHEN enter_orbital() is called THEN is_first_person becomes false.
## Implemented by: camera_mode.gd → enter_orbital()
##   is_first_person = false; emit_signal("mode_changed", false)
func test_camera_mode_enter_orbital_clears_flag() -> void:
	var cm: Object = _make_camera_mode()
	cm.call("enter_first_person")
	cm.call("enter_orbital")
	_check(cm.get("is_first_person") == false,
		"enter_orbital() must set is_first_person back to false")


## WHEN mode_changed signal is emitted it carries the correct bool value.
## Signal is connected in tests via a lambda (not via engine singleton).
func test_camera_mode_signal_emitted_on_enter_first_person() -> void:
	var cm: Object = _make_camera_mode()
	var received: Array = []
	cm.connect("mode_changed", func(fp: bool) -> void: received.append(fp))
	cm.call("enter_first_person")
	_check(received.size() == 1,
		"mode_changed signal must be emitted exactly once on enter_first_person()")
	_check(received[0] == true,
		"mode_changed signal must carry true when entering first-person mode")


## mode_changed signal carries false when returning to orbital.
func test_camera_mode_signal_emitted_on_enter_orbital() -> void:
	var cm: Object = _make_camera_mode()
	var received: Array = []
	cm.connect("mode_changed", func(fp: bool) -> void: received.append(fp))
	cm.call("enter_first_person")
	cm.call("enter_orbital")
	_check(received.size() == 2,
		"mode_changed must be emitted on both enter_first_person and enter_orbital")
	_check(received[1] == false,
		"mode_changed must carry false when returning to orbital mode")


# ---------------------------------------------------------------------------
# Scenario: Mouse look — yaw (horizontal)
# ---------------------------------------------------------------------------

## WHEN the mouse moves right (relative.x > 0) THEN _yaw decreases.
## Sign derivation:
##   drag right → event.relative.x > 0 → _yaw -= positive → _yaw decreases
##   → camera rotation.y decreases → camera turns clockwise → looks right ✓
## Implemented by: first_person_camera_controller.gd → _handle_mouse_look()
##   _yaw -= event.relative.x * MOUSE_SENSITIVITY
func test_mouse_look_yaw_decreases_on_drag_right() -> void:
	var ctrl: Object = _make_active_fps()
	var initial_yaw: float = ctrl.get("_yaw")
	var event := _make_mouse_motion(100.0, 0.0)  # drag right 100 px
	ctrl.call("_handle_mouse_look", event)
	# drag right → _yaw must decrease (not just change — signed comparison) ✓
	_check(ctrl.get("_yaw") < initial_yaw,
		"Dragging mouse right must decrease _yaw (camera turns right)")


## Dragging left (relative.x < 0) must increase _yaw (camera turns left).
## Sign derivation:
##   drag left → event.relative.x < 0 → _yaw -= negative → _yaw increases
##   → camera rotation.y increases → camera turns counter-clockwise → looks left ✓
func test_mouse_look_yaw_increases_on_drag_left() -> void:
	var ctrl: Object = _make_active_fps()
	var initial_yaw: float = ctrl.get("_yaw")
	var event := _make_mouse_motion(-100.0, 0.0)  # drag left 100 px
	ctrl.call("_handle_mouse_look", event)
	# drag left → _yaw must increase ✓
	_check(ctrl.get("_yaw") > initial_yaw,
		"Dragging mouse left must increase _yaw (camera turns left)")


# ---------------------------------------------------------------------------
# Scenario: Mouse look — pitch (vertical)
# ---------------------------------------------------------------------------

## WHEN the mouse moves down (relative.y > 0) THEN _pitch increases.
## Sign derivation:
##   drag down → event.relative.y > 0 → _pitch += positive → _pitch increases
##   → camera rotation.x increases → camera tilts downward ✓
## Implemented by: first_person_camera_controller.gd → _handle_mouse_look()
##   _pitch += event.relative.y * MOUSE_SENSITIVITY
func test_mouse_look_pitch_increases_on_drag_down() -> void:
	var ctrl: Object = _make_active_fps()
	var initial_pitch: float = ctrl.get("_pitch")
	var event := _make_mouse_motion(0.0, 100.0)  # drag down 100 px
	ctrl.call("_handle_mouse_look", event)
	# drag down → _pitch must increase (signed, not just != initial) ✓
	_check(ctrl.get("_pitch") > initial_pitch,
		"Dragging mouse down must increase _pitch (camera tilts downward)")


## Dragging mouse up (relative.y < 0) must decrease _pitch (camera tilts upward).
## Sign derivation:
##   drag up → event.relative.y < 0 → _pitch += negative → _pitch decreases
##   → camera rotation.x decreases → camera tilts upward ✓
func test_mouse_look_pitch_decreases_on_drag_up() -> void:
	var ctrl: Object = _make_active_fps()
	var initial_pitch: float = ctrl.get("_pitch")
	var event := _make_mouse_motion(0.0, -100.0)  # drag up 100 px
	ctrl.call("_handle_mouse_look", event)
	# drag up → _pitch must decrease ✓
	_check(ctrl.get("_pitch") < initial_pitch,
		"Dragging mouse up must decrease _pitch (camera tilts upward)")


# ---------------------------------------------------------------------------
# Scenario: Pitch clamped at ±85°
# ---------------------------------------------------------------------------

## Applying many downward drags must not push _pitch beyond PITCH_LIMIT.
## Boundary assertion: _pitch <= PITCH_LIMIT at all times.
## Implemented by: first_person_camera_controller.gd
##   _pitch = clamp(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
func test_pitch_clamped_at_maximum() -> void:
	var ctrl: Object = _make_active_fps()
	var pitch_limit: float = ctrl.get("PITCH_LIMIT")
	var event := _make_mouse_motion(0.0, 1000.0)  # huge downward drag
	for _i: int in range(20):
		ctrl.call("_handle_mouse_look", event)
	var final_pitch: float = ctrl.get("_pitch")
	# Boundary check: pitch must never exceed +PITCH_LIMIT (≈ 1.48 rad = 85°) ✓
	_check(final_pitch <= pitch_limit,
		"_pitch must be clamped at +PITCH_LIMIT (85 degrees) to prevent camera flip")


## Applying many upward drags must not push _pitch below -PITCH_LIMIT.
## Boundary assertion: _pitch >= -PITCH_LIMIT at all times.
func test_pitch_clamped_at_minimum() -> void:
	var ctrl: Object = _make_active_fps()
	var pitch_limit: float = ctrl.get("PITCH_LIMIT")
	var event := _make_mouse_motion(0.0, -1000.0)  # huge upward drag
	for _i: int in range(20):
		ctrl.call("_handle_mouse_look", event)
	var final_pitch: float = ctrl.get("_pitch")
	# Boundary check: pitch must never fall below -PITCH_LIMIT (≈ -1.48 rad = -85°) ✓
	_check(final_pitch >= -pitch_limit,
		"_pitch must be clamped at -PITCH_LIMIT (-85 degrees) to prevent camera flip")


# ---------------------------------------------------------------------------
# Scenario: Speed adjustment via scroll wheel
# ---------------------------------------------------------------------------

## Scroll-up increases _move_speed.
## Signed comparison: _move_speed must be strictly greater than initial value.
## Implemented by: first_person_camera_controller.gd → _handle_scroll()
##   _move_speed = clamp(_move_speed + SPEED_STEP, MOVE_SPEED_MIN, MOVE_SPEED_MAX)
func test_scroll_up_increases_move_speed() -> void:
	var ctrl: Object = _make_active_fps()
	var initial_speed: float = ctrl.get("_move_speed")
	var event := _make_scroll(MOUSE_BUTTON_WHEEL_UP)
	ctrl.call("_handle_scroll", event)
	# scroll up → _move_speed must increase (signed, not just change) ✓
	_check(ctrl.get("_move_speed") > initial_speed,
		"Scroll-up must increase _move_speed")


## Scroll-down decreases _move_speed.
## Signed comparison: _move_speed must be strictly less than initial value.
func test_scroll_down_decreases_move_speed() -> void:
	var ctrl: Object = _make_active_fps()
	var initial_speed: float = ctrl.get("_move_speed")
	var event := _make_scroll(MOUSE_BUTTON_WHEEL_DOWN)
	ctrl.call("_handle_scroll", event)
	# scroll down → _move_speed must decrease (signed) ✓
	_check(ctrl.get("_move_speed") < initial_speed,
		"Scroll-down must decrease _move_speed")


## Repeated scroll-up must not push _move_speed above MOVE_SPEED_MAX.
## Boundary assertion: _move_speed <= MOVE_SPEED_MAX.
func test_move_speed_clamped_at_maximum() -> void:
	var ctrl: Object = _make_active_fps()
	var max_speed: float = ctrl.get("MOVE_SPEED_MAX")
	var event := _make_scroll(MOUSE_BUTTON_WHEEL_UP)
	# Scroll up many times — should never exceed maximum.
	for _i: int in range(200):
		ctrl.call("_handle_scroll", event)
	var final_speed: float = ctrl.get("_move_speed")
	# Boundary: _move_speed must be clamped at MOVE_SPEED_MAX ✓
	_check(final_speed <= max_speed,
		"_move_speed must be clamped at MOVE_SPEED_MAX after many scroll-ups")


## Repeated scroll-down must not push _move_speed below MOVE_SPEED_MIN.
## Boundary assertion: _move_speed >= MOVE_SPEED_MIN.
func test_move_speed_clamped_at_minimum() -> void:
	var ctrl: Object = _make_active_fps()
	var min_speed: float = ctrl.get("MOVE_SPEED_MIN")
	var event := _make_scroll(MOUSE_BUTTON_WHEEL_DOWN)
	# Scroll down many times — should never fall below minimum.
	for _i: int in range(200):
		ctrl.call("_handle_scroll", event)
	var final_speed: float = ctrl.get("_move_speed")
	# Boundary: _move_speed must be clamped at MOVE_SPEED_MIN ✓
	_check(final_speed >= min_speed,
		"_move_speed must be clamped at MOVE_SPEED_MIN after many scroll-downs")


# ---------------------------------------------------------------------------
# Scenario: Orbital camera disabled while FPS is active
# ---------------------------------------------------------------------------

## GIVEN orbital camera with _fps_mode = true
## WHEN scroll-up event arrives THEN _target_distance does not change.
## Implemented by: camera_controller.gd → _unhandled_input()
##   early return if _fps_mode is true.
func test_orbital_camera_ignores_scroll_in_fps_mode() -> void:
	var cam: Object = CameraControllerScript.new()
	var initial_target: float = cam.get("_target_distance")
	# Activate FPS mode on the orbital controller.
	cam.set("_fps_mode", true)
	# Send a scroll-up event — should be ignored.
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam.call("_unhandled_input", event)
	_check(cam.get("_target_distance") == initial_target,
		"Orbital camera must not respond to scroll input when _fps_mode is true")


## GIVEN orbital camera with _fps_mode = false
## WHEN scroll-up event arrives THEN _target_distance decreases.
## Verifies the guard only fires in FPS mode (orbital still works normally).
func test_orbital_camera_responds_to_scroll_in_orbital_mode() -> void:
	var cam: Object = CameraControllerScript.new()
	var initial_target: float = cam.get("_target_distance")
	cam.set("_fps_mode", false)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	cam.call("_unhandled_input", event)
	# In orbital mode scroll-up must decrease target distance ✓
	_check(cam.get("_target_distance") < initial_target,
		"Orbital camera must still respond to scroll when _fps_mode is false")


# ---------------------------------------------------------------------------
# Scenario: FPS constants are defined at expected values
# ---------------------------------------------------------------------------

## MOUSE_SENSITIVITY must be 0.002 (radians per pixel) as specified.
func test_fps_mouse_sensitivity_constant() -> void:
	var ctrl: Object = FPSController.new()
	var sens: float = ctrl.get("MOUSE_SENSITIVITY")
	_check(is_equal_approx(sens, 0.002),
		"MOUSE_SENSITIVITY must be 0.002 rad/pixel as specified")


## MOVE_SPEED_DEFAULT must be 5.0 units/s.
func test_fps_move_speed_default_constant() -> void:
	var ctrl: Object = FPSController.new()
	var spd: float = ctrl.get("MOVE_SPEED_DEFAULT")
	_check(is_equal_approx(spd, 5.0),
		"MOVE_SPEED_DEFAULT must be 5.0 units/s as specified")


## Initial _move_speed must equal MOVE_SPEED_DEFAULT.
func test_fps_initial_move_speed_is_default() -> void:
	var ctrl: Object = FPSController.new()
	var spd: float = ctrl.get("_move_speed")
	var def_spd: float = ctrl.get("MOVE_SPEED_DEFAULT")
	_check(is_equal_approx(spd, def_spd),
		"_move_speed must equal MOVE_SPEED_DEFAULT on construction")


## FPS mode is inactive by default (orbital mode is the application default).
func test_fps_inactive_by_default() -> void:
	var ctrl: Object = FPSController.new()
	_check(ctrl.get("_is_active") == false,
		"_is_active must be false on construction — orbital is the default mode")
