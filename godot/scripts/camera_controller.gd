extends Camera3D

## Orbit camera controller for CodeVis.
##
## Left-mouse drag   → pan the pivot point (non-inverted: drag matches view)
## Right-mouse drag  → orbit around the world point under cursor at gesture start
## Scroll wheel      → zoom toward the point under the cursor (smooth)

@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 2.0
@export var pan_speed: float = 0.04
@export var zoom_smoothing: float = 8.0
@export var min_distance: float = 2.0
@export var max_distance: float = 500.0

## Spherical-coordinate state around _pivot.
## _theta: polar angle from the Y-axis (0 = straight above, PI/2 = side-on).
## _phi:   azimuth around the Y-axis.
var _pivot: Vector3 = Vector3.ZERO
var _distance: float = 40.0
var _target_distance: float = 40.0
var _theta: float = 0.15  # slight tilt from top-down for depth perception
var _phi: float = 0.0

var _orbiting: bool = false
var _panning: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target_distance = _distance
	_update_transform()


## Reposition the pivot and distance so the whole graph fits in view.
func set_pivot(pivot: Vector3, distance: float) -> void:
	_pivot = pivot
	_distance = clamp(distance, min_distance, max_distance)
	_target_distance = _distance
	_update_transform()


## Return the current distance from the camera to the pivot.
## Used by main.gd to query LOD level each frame.
func get_distance() -> float:
	return _distance


## Smooth zoom: lerp _distance toward _target_distance each frame.
func _process(delta: float) -> void:
	if not is_equal_approx(_distance, _target_distance):
		var t: float = min(zoom_smoothing * delta, 0.9)
		_distance = lerp(_distance, _target_distance, t)
		if abs(_distance - _target_distance) < 0.001:
			_distance = _target_distance
		_update_transform()


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
		MOUSE_BUTTON_LEFT:
			_panning = event.pressed
			_last_mouse = event.position
		MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
			_last_mouse = event.position
			if event.pressed:
				# Orbit around the world point under cursor at gesture start.
				_set_orbit_pivot(_mouse_to_ground(event.position))
		MOUSE_BUTTON_WHEEL_UP:
			# scroll up → zoom IN → _target_distance decreases → direction must be negative
			_zoom_toward_cursor(_mouse_to_ground(event.position), -zoom_speed)
		MOUSE_BUTTON_WHEEL_DOWN:
			# scroll down → zoom OUT → _target_distance increases → direction must be positive
			_zoom_toward_cursor(_mouse_to_ground(event.position), zoom_speed)


## Zoom _target_distance and shift _pivot so the cursor world-point stays fixed.
func _zoom_toward_cursor(cursor_world: Vector3, direction: float) -> void:
	var old_target: float = _target_distance
	var step: float = direction * (_target_distance * 0.05 + 1.0)
	_target_distance = clamp(_target_distance + step, min_distance, max_distance)
	# Shift pivot toward/away from cursor proportional to zoom fraction.
	if old_target > 0.0:
		var zoom_fraction: float = 1.0 - (_target_distance / old_target)
		# zoom in: direction < 0 -> step < 0 -> target_distance < old_target
		#   -> zoom_fraction = 1 - (smaller/larger) > 0 -> lerp toward cursor -> pivot shifts toward cursor
		# zoom out: direction > 0 -> step > 0 -> target_distance > old_target
		#   -> zoom_fraction = 1 - (larger/smaller) < 0 -> lerp away from cursor -> pivot shifts away
		_pivot = _pivot.lerp(cursor_world, zoom_fraction)
	_update_transform()


## Switch the orbit focal point to world_point while keeping the camera
## position unchanged (recalculate spherical angles from new pivot).
func _set_orbit_pivot(world_point: Vector3) -> void:
	var cam_pos: Vector3 = global_position
	_pivot = world_point
	var offset: Vector3 = cam_pos - _pivot
	var new_dist: float = offset.length()
	if new_dist > 0.001:
		_distance = clamp(new_dist, min_distance, max_distance)
		_target_distance = _distance
		_theta = acos(clamp(offset.y / new_dist, -1.0, 1.0))
		_phi = atan2(offset.z, offset.x)


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
		# Grab model (Google Maps): drag left → content to right appears → pivot moves RIGHT.
		var right: Vector3 = global_transform.basis.x
		var forward: Vector3 = Vector3(
			global_transform.basis.z.x,
			0.0,
			global_transform.basis.z.z
		).normalized()
		var pan_amount: float = pan_speed * (_distance * 0.05 + 1.0)
		# drag left → delta.x = -50 → negate → pivot.x += 50 * pan_amount (moves right) ✓
		_pivot -= right * delta.x * pan_amount
		# drag down → delta.y = +50 → negate → pivot.z -= 50 * pan_amount (moves backward) ✓
		_pivot -= forward * delta.y * pan_amount
		_update_transform()


## Project a screen-space position to the world point on the plane at pivot.y.
## Returns the current pivot when no viewport is available (e.g. headless tests).
func _mouse_to_ground(screen_pos: Vector2) -> Vector3:
	if not is_inside_tree():
		return _pivot
	var ray_origin: Vector3 = project_ray_origin(screen_pos)
	var ray_dir: Vector3 = project_ray_normal(screen_pos)
	if abs(ray_dir.y) < 0.0001:
		return _pivot
	var t: float = (_pivot.y - ray_origin.y) / ray_dir.y
	return ray_origin + ray_dir * t


# ---------------------------------------------------------------------------
# Transform computation
# ---------------------------------------------------------------------------

func _update_transform() -> void:
	var x: float = _distance * sin(_theta) * cos(_phi)
	var y: float = _distance * cos(_theta)
	var z: float = _distance * sin(_theta) * sin(_phi)
	global_position = _pivot + Vector3(x, y, z)
	look_at(_pivot, Vector3.UP)
