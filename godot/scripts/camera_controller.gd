extends Camera3D

## Orbit camera controller for CodeVis.
##
## Left-mouse drag   → pan the pivot point (non-inverted: drag direction matches scene movement)
## Right-mouse drag  → orbit around the point under the cursor when drag began
## Middle-mouse drag → orbit around current pivot (alternate binding)
## Scroll wheel      → zoom toward the point under the cursor (smooth, interpolated)

@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 2.0
@export var pan_speed: float = 0.04
@export var min_distance: float = 2.0
@export var max_distance: float = 500.0
## Controls how quickly zoom/pivot smoothly interpolate toward their targets.
## Higher = snappier; lower = more gradual.
@export var zoom_smooth: float = 12.0

## Spherical-coordinate state around _pivot.
## _theta: polar angle from the Y-axis (0 = straight above, PI/2 = side-on).
## _phi:   azimuth around the Y-axis.
var _pivot: Vector3 = Vector3.ZERO
var _distance: float = 40.0
var _theta: float = 0.15  # slight tilt from top-down for depth perception
var _phi: float = 0.0

## Smooth-zoom targets: _distance/_pivot interpolate toward these each frame.
var _target_distance: float = 40.0
var _target_pivot: Vector3 = Vector3.ZERO

var _orbiting: bool = false
var _panning: bool = false
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target_distance = _distance
	_target_pivot = _pivot
	_update_transform()


func _process(delta: float) -> void:
	# Exponential smoothing toward zoom/pivot targets — produces smooth, non-jerky movement.
	var t: float = 1.0 - pow(0.05, delta * zoom_smooth)
	_distance = lerpf(_distance, _target_distance, t)
	_pivot = _pivot.lerp(_target_pivot, t)
	_update_transform()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Reposition the pivot and distance so the whole graph fits in view.
func set_pivot(pivot: Vector3, distance: float) -> void:
	_pivot = pivot
	_target_pivot = pivot
	_distance = clamp(distance, min_distance, max_distance)
	_target_distance = _distance
	_update_transform()


## Return the current distance from the camera to the pivot.
## Used by main.gd to query LOD level each frame.
func get_distance() -> float:
	return _distance


## Begin orbiting around the given world point.
## Sets _pivot to world_pt and recomputes spherical coordinates so the camera
## does not jump — only the orbit centre changes.
## Callable from tests without a real viewport.
func begin_orbit_at_world_point(world_pt: Vector3) -> void:
	_orbiting = true
	# Current camera world position derived from spherical state (no scene-tree needed).
	var cam_pos: Vector3 = _compute_camera_pos()
	var offset: Vector3 = cam_pos - world_pt
	_pivot = world_pt
	_target_pivot = world_pt
	_distance = clamp(offset.length(), min_distance, max_distance)
	_target_distance = _distance
	if _distance > 0.0001:
		_theta = clamp(acos(clamp(offset.y / _distance, -1.0, 1.0)), 0.01, PI - 0.01)
		_phi = atan2(offset.z, offset.x)
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
			# Left-mouse drag pans the pivot.
			_panning = event.pressed
			_last_mouse = event.position

		MOUSE_BUTTON_MIDDLE:
			# Middle-mouse drag orbits around current pivot (alternate binding).
			_orbiting = event.pressed
			_last_mouse = event.position

		MOUSE_BUTTON_RIGHT:
			_last_mouse = event.position
			if event.pressed:
				# Orbit around the world point currently under the cursor.
				var world_pt: Vector3 = _get_ground_point_under_cursor(event.position)
				begin_orbit_at_world_point(world_pt)
			else:
				_orbiting = false

		MOUSE_BUTTON_WHEEL_UP:
			# Zoom in toward the point under the cursor.
			var world_pt: Vector3 = _get_ground_point_under_cursor(_last_mouse)
			_zoom_toward_point(world_pt, -1)

		MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out away from the point under the cursor.
			var world_pt: Vector3 = _get_ground_point_under_cursor(_last_mouse)
			_zoom_toward_point(world_pt, 1)


func _handle_motion(event: InputEventMouseMotion) -> void:
	var delta: Vector2 = event.position - _last_mouse
	_last_mouse = event.position

	if _orbiting:
		_phi -= delta.x * orbit_speed
		# Clamp theta so the camera never flips past the poles.
		_theta = clamp(_theta - delta.y * orbit_speed, 0.01, PI - 0.01)
		_update_transform()

	elif _panning:
		# Non-inverted pan: drag direction matches scene movement direction.
		# Use transform.basis (local) which look_at_from_position sets correctly even
		# when the node is not in the scene tree (headless / unit-test context).
		var basis: Basis = transform.basis
		var right: Vector3 = basis.x
		var backward: Vector3 = Vector3(
			basis.z.x,
			0.0,
			basis.z.z
		).normalized()
		var pan_amount: float = pan_speed * (_distance * 0.05 + 1.0)
		# Drag right → pivot moves right; drag up (negative delta.y) → pivot moves forward.
		_target_pivot += right * delta.x * pan_amount
		_target_pivot -= backward * delta.y * pan_amount
		# Apply immediately for responsive, proportional-to-drag feel (no latency on pan).
		_pivot = _target_pivot
		_update_transform()


# ---------------------------------------------------------------------------
# Zoom toward cursor
# ---------------------------------------------------------------------------

## Zoom in (direction < 0) or out (direction > 0) toward/away from world_pt.
## Only _target_distance/_target_pivot are mutated; _distance/_pivot interpolate
## in _process(), producing smooth animation.
func _zoom_toward_point(world_pt: Vector3, direction: int) -> void:
	var old_dist: float = _target_distance
	if direction < 0:
		_target_distance = maxf(min_distance, _target_distance - zoom_speed * (_target_distance * 0.05 + 1.0))
	else:
		_target_distance = minf(max_distance, _target_distance + zoom_speed * (_target_distance * 0.05 + 1.0))
	# Shift pivot toward/away from the cursor's world point by the same ratio as the zoom.
	var zoom_ratio: float = _target_distance / old_dist
	_target_pivot = world_pt + (_target_pivot - world_pt) * zoom_ratio


# ---------------------------------------------------------------------------
# Raycasting helpers
# ---------------------------------------------------------------------------

## Return the world point on the horizontal plane y = _pivot.y under mouse_pos.
## Falls back to _target_pivot if not in scene tree or if ray is nearly horizontal.
func _get_ground_point_under_cursor(mouse_pos: Vector2) -> Vector3:
	if not is_inside_tree():
		return _target_pivot
	var ray_origin: Vector3 = project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = project_ray_normal(mouse_pos)
	if absf(ray_dir.y) < 0.0001:
		return _target_pivot
	var t: float = (_pivot.y - ray_origin.y) / ray_dir.y
	if t < 0.0:
		return _target_pivot  # intersection behind camera
	return ray_origin + ray_dir * t


# ---------------------------------------------------------------------------
# Transform computation
# ---------------------------------------------------------------------------

## Compute camera world position from spherical coordinates (no scene tree needed).
func _compute_camera_pos() -> Vector3:
	var x: float = _distance * sin(_theta) * cos(_phi)
	var y: float = _distance * cos(_theta)
	var z: float = _distance * sin(_theta) * sin(_phi)
	return _pivot + Vector3(x, y, z)


func _update_transform() -> void:
	var cam_pos: Vector3 = _compute_camera_pos()
	if is_inside_tree():
		global_position = cam_pos
		look_at(_pivot, Vector3.UP)
	else:
		# Headless / unit-test context: set transform directly without scene-tree globals.
		position = cam_pos
		look_at_from_position(cam_pos, _pivot, Vector3.UP)
