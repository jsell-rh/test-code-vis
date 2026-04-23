extends Camera3D

## Orbit camera controller for CodeVis.
##
## Middle-mouse drag  → orbit around focal pivot
## Scroll wheel       → zoom in / out
## Right-mouse drag   → pan the pivot point

@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 2.0
@export var pan_speed: float = 0.04
@export var min_distance: float = 2.0
@export var max_distance: float = 500.0

## Spherical-coordinate state around _pivot.
## _theta: polar angle from the Y-axis (0 = straight above, PI/2 = side-on).
## _phi:   azimuth around the Y-axis.
var _pivot: Vector3 = Vector3.ZERO
var _distance: float = 40.0
var _theta: float = 0.15  # slight tilt from top-down for depth perception
var _phi: float = 0.0

var _orbiting: bool = false
var _panning: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	_update_transform()


## Reposition the pivot and distance so the whole graph fits in view.
func set_pivot(pivot: Vector3, distance: float) -> void:
	_pivot = pivot
	_distance = clamp(distance, min_distance, max_distance)
	_update_transform()


## Return the current distance from the camera to the pivot.
## Used by main.gd to query LOD level each frame.
func get_distance() -> float:
	return _distance


# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_motion(event as InputEventMouseMotion)


func _handle_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			_orbiting = event.pressed
			_last_mouse = event.position
		MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
			_last_mouse = event.position
		MOUSE_BUTTON_WHEEL_UP:
			_distance = max(min_distance, _distance - zoom_speed * (_distance * 0.05 + 1.0))
			_update_transform()
		MOUSE_BUTTON_WHEEL_DOWN:
			_distance = min(max_distance, _distance + zoom_speed * (_distance * 0.05 + 1.0))
			_update_transform()


func _handle_motion(event: InputEventMouseMotion) -> void:
	var delta: Vector2 = event.position - _last_mouse
	_last_mouse = event.position

	if _orbiting:
		_phi -= delta.x * orbit_speed
		# Clamp theta so the camera never flips past the poles.
		_theta = clamp(_theta - delta.y * orbit_speed, 0.01, PI - 0.01)
		_update_transform()

	elif _panning:
		# Move the pivot in the camera's local XZ plane.
		var right: Vector3 = -global_transform.basis.x
		var forward: Vector3 = Vector3(
			global_transform.basis.z.x,
			0.0,
			global_transform.basis.z.z
		).normalized()
		var pan_amount: float = pan_speed * (_distance * 0.05 + 1.0)
		_pivot += right * delta.x * pan_amount
		_pivot += forward * delta.y * pan_amount
		_update_transform()


# ---------------------------------------------------------------------------
# Transform computation
# ---------------------------------------------------------------------------

func _update_transform() -> void:
	var x: float = _distance * sin(_theta) * cos(_phi)
	var y: float = _distance * cos(_theta)
	var z: float = _distance * sin(_theta) * sin(_phi)
	global_position = _pivot + Vector3(x, y, z)
	look_at(_pivot, Vector3.UP)
