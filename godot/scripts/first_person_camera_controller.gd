## FirstPersonCameraController — FPS-style navigation for CodeVis.
##
## Attached to the Main scene as a child Node.  Active only when
## CameraMode.is_first_person == true.  Driven exclusively by GDScript;
## no StaticBody3D, physics shapes, or external libraries.
##
## Controls (active in first-person mode):
##   Mouse move    → look (yaw / pitch)
##   W / S         → forward / backward (horizontal XZ plane)
##   A / D         → strafe left / right
##   Space / Shift → ascend / descend (world Y)
##   Scroll wheel  → increase / decrease MOVE_SPEED
##   Tab           → toggle back to orbital mode
##   Escape        → exit to orbital mode (always releases mouse)
##
## Covers: specs/visualization/spatial-structure.spec.md
## Requirement: 3D Interactive Navigation — first-person exploration scenario.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Mouse rotation sensitivity in radians per pixel.
const MOUSE_SENSITIVITY: float = 0.002

## Default movement speed in units per second.
const MOVE_SPEED_DEFAULT: float = 5.0

## Minimum movement speed (scroll wheel lower bound), units per second.
const MOVE_SPEED_MIN: float = 0.5

## Maximum movement speed (scroll wheel upper bound), units per second.
const MOVE_SPEED_MAX: float = 50.0

## Speed increment per scroll-wheel notch, units per second.
const SPEED_STEP: float = 1.0

## Pitch clamp: ±85 degrees to prevent camera flip.
const PITCH_LIMIT: float = 85.0 * PI / 180.0  # ≈ 1.4835 rad


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Yaw angle (rotation around world Y axis, radians).
## Positive yaw rotates camera counter-clockwise when viewed from above.
var _yaw: float = 0.0

## Pitch angle (rotation around local X axis, radians).
## Positive pitch tilts the camera downward; clamped to ±PITCH_LIMIT.
var _pitch: float = 0.0

## Current movement speed in units per second.
var _move_speed: float = MOVE_SPEED_DEFAULT

## Whether first-person mode is currently active.
var _is_active: bool = false

## Reference to the scene's Camera3D node.  Set by main.gd in _ready().
var _camera: Camera3D = null

## HUD label showing the current mode hint (orbital vs FPS controls).
var _hud_label: Label = null

## HUD label showing current speed when in FPS mode.
var _speed_label: Label = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Connect to CameraMode singleton if available (absent in headless unit tests).
	if Engine.has_singleton("CameraMode"):
		Engine.get_singleton("CameraMode").mode_changed.connect(_on_mode_changed)
	_create_hud()


# ---------------------------------------------------------------------------
# CameraMode signal handler
# ---------------------------------------------------------------------------

## Called when CameraMode emits mode_changed.
func _on_mode_changed(fp: bool) -> void:
	_is_active = fp
	if fp:
		# Entering first-person: read camera's current rotation so the view
		# does not jump.  Preserve world position — only yaw/pitch are read.
		if _camera != null:
			_yaw = _camera.rotation.y
			_pitch = _camera.rotation.x
		# Capture mouse pointer so mouse-look works.
		if is_inside_tree():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# Exiting first-person: restore visible mouse pointer.
		if is_inside_tree():
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_hud()


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event as InputEventKey)
	elif _is_active and event is InputEventMouseMotion:
		_handle_mouse_look(event as InputEventMouseMotion)
	elif _is_active and event is InputEventMouseButton:
		_handle_scroll(event as InputEventMouseButton)


## Handle Tab (mode toggle) and Escape (force-exit to orbital).
func _handle_key(event: InputEventKey) -> void:
	if not event.pressed:
		return
	match event.keycode:
		KEY_TAB:
			_toggle_mode()
		KEY_ESCAPE:
			if _is_active:
				_exit_to_orbital()


## Toggle between orbital and first-person navigation modes.
func _toggle_mode() -> void:
	if not Engine.has_singleton("CameraMode"):
		return
	var cm: Node = Engine.get_singleton("CameraMode")
	if cm.is_first_person:
		cm.enter_orbital()
	else:
		cm.enter_first_person()


## Exit to orbital mode immediately; always releases mouse pointer.
func _exit_to_orbital() -> void:
	if not Engine.has_singleton("CameraMode"):
		return
	Engine.get_singleton("CameraMode").enter_orbital()


## Update yaw and pitch from mouse motion.  Mouse is captured in FPS mode so
## event.relative gives raw pixel delta relative to the last frame.
func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	# drag right → event.relative.x > 0 → _yaw decreases
	# → camera rotation.y decreases → camera turns clockwise → looks right ✓
	_yaw -= event.relative.x * MOUSE_SENSITIVITY

	# drag down → event.relative.y > 0 → _pitch increases
	# → camera rotation.x increases → camera tilts downward ✓
	_pitch += event.relative.y * MOUSE_SENSITIVITY
	_pitch = clamp(_pitch, -PITCH_LIMIT, PITCH_LIMIT)

	_apply_look_rotation()


## Write _yaw / _pitch to the camera rotation.
## Apply yaw first (world Y), then pitch (local X).  No roll.
func _apply_look_rotation() -> void:
	if _camera == null:
		return
	_camera.rotation.y = _yaw
	_camera.rotation.x = _pitch


## Adjust movement speed via scroll wheel.
func _handle_scroll(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			# scroll up → increase speed
			_move_speed = clamp(_move_speed + SPEED_STEP, MOVE_SPEED_MIN, MOVE_SPEED_MAX)
		MOUSE_BUTTON_WHEEL_DOWN:
			# scroll down → decrease speed
			_move_speed = clamp(_move_speed - SPEED_STEP, MOVE_SPEED_MIN, MOVE_SPEED_MAX)
	_update_hud()


# ---------------------------------------------------------------------------
# Per-frame movement
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _is_active or _camera == null:
		return

	var direction := Vector3.ZERO

	# Horizontal forward vector: project camera look direction onto XZ plane.
	# When _yaw = 0 the camera faces -Z (Godot default), so forward = -Z.
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw)).normalized()

	# Strafe right vector: forward × world-up gives the right direction.
	var right := forward.cross(Vector3.UP).normalized()

	if Input.is_key_pressed(KEY_W):
		direction += forward   # W → move forward along horizontal look direction
	if Input.is_key_pressed(KEY_S):
		direction -= forward   # S → move backward
	if Input.is_key_pressed(KEY_A):
		direction -= right     # A → strafe left (opposite to right vector)
	if Input.is_key_pressed(KEY_D):
		direction += right     # D → strafe right
	if Input.is_key_pressed(KEY_SPACE):
		direction += Vector3.UP    # Space → ascend along world Y
	if Input.is_key_pressed(KEY_SHIFT):
		direction -= Vector3.UP    # Shift → descend along world Y

	if direction.length_squared() > 0.0:
		direction = direction.normalized()

	_camera.global_position += direction * _move_speed * delta
	_update_speed_label()


# ---------------------------------------------------------------------------
# HUD (mode hint + speed indicator)
# ---------------------------------------------------------------------------

## Create 2D overlay labels for mode hint and speed display.
## Only executed when inside the scene tree (no-op in headless unit tests).
func _create_hud() -> void:
	if not is_inside_tree():
		return

	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	# Mode hint label — bottom-left corner.
	_hud_label = Label.new()
	_hud_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hud_label.offset_bottom = -8.0
	_hud_label.offset_left = 8.0
	canvas.add_child(_hud_label)

	# Speed label — top-right corner.
	_speed_label = Label.new()
	_speed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_speed_label.offset_top = 8.0
	_speed_label.offset_right = -8.0
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	canvas.add_child(_speed_label)

	_update_hud()


## Update the mode hint and speed labels to reflect current state.
func _update_hud() -> void:
	if _hud_label == null:
		return
	if _is_active:
		_hud_label.text = "[Tab] Orbital | WASD Move | Mouse Look | Scroll Speed | Esc Exit"
	else:
		_hud_label.text = "[Tab] First Person"
	_update_speed_label()


## Refresh the speed label (shown only in FPS mode).
func _update_speed_label() -> void:
	if _speed_label == null:
		return
	if _is_active:
		_speed_label.text = "⚡ %.1f u/s" % _move_speed
	else:
		_speed_label.text = ""
