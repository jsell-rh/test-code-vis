## Integration tests for Requirement: godot-application.spec.md (task-013)
##
## Covers ALL MUST-requirements from specs/prototype/godot-application.spec.md
## with behavioral assertions on scene-tree properties and dependency injection
## to bypass @onready null-guards (per onready-null-guard guideline).
##
## Coverage table:
##   Req 1: JSON Scene Graph Loading    → test_reads_json_and_builds_volumes,
##                                        test_edge_connections_created,
##                                        test_positions_set_from_json
##   Req 2: Containment Rendering       → test_bounded_context_is_translucent_volume,
##                                        test_modules_are_opaque_and_inside_context
##   Req 3: Dependency Rendering        → test_cross_context_line_created,
##                                        test_direction_cone_at_target
##   Req 4: Size Encoding               → test_size_proportional_to_metric
##   Req 5: Camera Controls             → test_camera_frames_entire_system (injection),
##                                        test_initial_theta_near_top_down,
##                                        test_scroll_zoom_changes_distance,
##                                        test_orbit_changes_phi_and_theta
##   Req 6: Godot 4.6                   → test_project_declares_godot_46,
##                                        test_fileaccess_get_as_text_works
extends RefCounted

const MainScript := preload("res://scripts/main.gd")
const CameraScript := preload("res://scripts/camera_controller.gd")


## Fixture: two bounded contexts separated by 20 units, each with one module.
## Used for requirements 1-3 integration tests.
func _make_two_context_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "graph_ctx",
				"name": "graph",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 12.0,
			},
			{
				"id": "shared_kernel",
				"name": "shared_kernel",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"size": 8.0,
			},
			{
				"id": "graph_domain",
				"name": "domain",
				"type": "module",
				"parent": "graph_ctx",
				"position": {"x": 2.0, "y": 0.0, "z": 0.0},
				"size": 4.0,
			},
			{
				"id": "sk_core",
				"name": "core",
				"type": "module",
				"parent": "shared_kernel",
				"position": {"x": -2.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
		],
		"edges": [
			{"source": "graph_ctx", "target": "shared_kernel", "type": "cross_context"},
		],
	}


## Fixture: two modules with different size metrics (large vs small).
func _make_size_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "tiny_mod",
				"name": "tiny",
				"type": "module",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "huge_mod",
				"name": "huge",
				"type": "module",
				"parent": null,
				"position": {"x": 30.0, "y": 0.0, "z": 0.0},
				"size": 10.0,
			},
		],
		"edges": [],
	}


# ---------------------------------------------------------------------------
# Requirement 1: JSON Scene Graph Loading
# ---------------------------------------------------------------------------

## THEN generates 3D volumes for each node —
## build_from_graph() must create an anchor in _anchors for every node id.
func test_reads_json_and_builds_volumes() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_two_context_fixture())
	return (
		main_node._anchors.has("graph_ctx")
		and main_node._anchors.has("shared_kernel")
		and main_node._anchors.has("graph_domain")
		and main_node._anchors.has("sk_core")
	)


## AND generates connections for each edge —
## at least one ImmediateMesh MeshInstance3D must be a child of the main node.
func test_edge_connections_created() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_two_context_fixture())
	for child: Node in main_node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is ImmediateMesh:
			return true
	return false


## AND positions elements according to the layout data —
## graph_ctx local position must match JSON {x:0, y:0, z:0};
## shared_kernel must match {x:20, y:0, z:0}.
func test_positions_set_from_json() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_two_context_fixture())
	var ctx_anchor: Node3D = main_node._anchors.get("graph_ctx")
	var sk_anchor: Node3D = main_node._anchors.get("shared_kernel")
	if ctx_anchor == null or sk_anchor == null:
		return false
	var ctx_ok: bool = ctx_anchor.position.is_equal_approx(Vector3(0.0, 0.0, 0.0))
	var sk_ok: bool = sk_anchor.position.is_equal_approx(Vector3(20.0, 0.0, 0.0))
	return ctx_ok and sk_ok


# ---------------------------------------------------------------------------
# Requirement 2: Containment Rendering
# ---------------------------------------------------------------------------

## THEN the bounded context appears as a larger translucent volume —
## bounded_context material must use TRANSPARENCY_ALPHA and alpha < 1.
func test_bounded_context_is_translucent_volume() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_two_context_fixture())
	var anchor: Node3D = main_node._anchors.get("graph_ctx")
	if anchor == null:
		return false
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null:
				return false
			return (
				mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				and mat.albedo_color.a < 1.0
			)
	return false


## AND child modules appear as opaque volumes inside the context —
## module material alpha must be 1.0 (fully opaque),
## AND module anchor must be a child of the context anchor.
func test_modules_are_opaque_and_inside_context() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_two_context_fixture())
	var ctx_anchor: Node3D = main_node._anchors.get("graph_ctx")
	var mod_anchor: Node3D = main_node._anchors.get("graph_domain")
	if ctx_anchor == null or mod_anchor == null:
		return false
	# Module must be parented inside context (visual nesting in scene tree).
	if mod_anchor.get_parent() != ctx_anchor:
		return false
	# Module material must be fully opaque.
	for child: Node in mod_anchor.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null:
				return false
			return mat.albedo_color.a >= 1.0
	return false


# ---------------------------------------------------------------------------
# Requirement 3: Dependency Rendering
# ---------------------------------------------------------------------------

## THEN a line connects the two context volumes —
## an ImmediateMesh edge line must exist as a child of the main node.
func test_cross_context_line_created() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_two_context_fixture())
	for child: Node in main_node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is ImmediateMesh:
			return true
	return false


## AND the line's direction is visually indicated —
## a CylinderMesh cone (top_radius == 0) must exist near the target position.
## graph_ctx (0,0,0) → shared_kernel (20,0,0): cone should be within 2 units of target.
func test_direction_cone_at_target() -> bool:
	# source (0,0,0) → target (20,0,0) → cone positioned near (20,0,0) ✓
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_two_context_fixture())
	var target_pos := Vector3(20.0, 0.0, 0.0)
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if not (mi.mesh is CylinderMesh):
				continue
			var cone := mi.mesh as CylinderMesh
			if cone.top_radius == 0.0:
				# Cone must be near the target (within 2 units).
				return mi.position.distance_to(target_pos) < 2.0
	return false


# ---------------------------------------------------------------------------
# Requirement 4: Size Encoding
# ---------------------------------------------------------------------------

## THEN the module with more code appears as a larger volume —
## huge_mod (size=10) BoxMesh.size.x must be greater than tiny_mod (size=2).
## AND the relative sizes are proportional to the metric (ratio = 5.0).
func test_size_proportional_to_metric() -> bool:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_size_fixture())
	var tiny_anchor: Node3D = main_node._anchors.get("tiny_mod")
	var huge_anchor: Node3D = main_node._anchors.get("huge_mod")
	if tiny_anchor == null or huge_anchor == null:
		return false
	var tiny_mesh: BoxMesh = null
	var huge_mesh: BoxMesh = null
	for child: Node in tiny_anchor.get_children():
		if child is MeshInstance3D:
			tiny_mesh = (child as MeshInstance3D).mesh as BoxMesh
	for child: Node in huge_anchor.get_children():
		if child is MeshInstance3D:
			huge_mesh = (child as MeshInstance3D).mesh as BoxMesh
	if tiny_mesh == null or huge_mesh == null:
		return false
	# huge_mod size=10, tiny_mod size=2 → expected ratio = 5.0
	var expected_ratio: float = 10.0 / 2.0
	var actual_ratio: float = huge_mesh.size.x / tiny_mesh.size.x
	return huge_mesh.size.x > tiny_mesh.size.x and abs(actual_ratio - expected_ratio) < 0.001


# ---------------------------------------------------------------------------
# Requirement 5: Camera Controls — top-down overview (dependency injection)
# ---------------------------------------------------------------------------

## THEN the camera defaults to a top-down view showing the entire system —
## This THEN-clause requires _frame_camera() to run with a real camera.
## Per onready-null-guard guideline: inject a CameraScript to bypass the
## `if _camera == null: return` guard so the THEN-clause is actually exercised.
##
## Expected behaviour after build_from_graph():
##   - camera._pivot ≈ centre of all node world positions
##   - camera._distance > 0 (camera is not at the origin)
##   - camera._theta is small (< PI/4 = 45°) → predominantly top-down
func test_camera_frames_entire_system() -> bool:
	var main_node: Node3D = MainScript.new()
	# Inject a real CameraScript so _frame_camera() can call set_pivot().
	var cam := CameraScript.new()
	main_node.set("_camera", cam)

	# Two contexts at x=0 and x=20: centre should be near x=10.
	main_node.build_from_graph(_make_two_context_fixture())

	# _frame_camera() computes world-position centre and calls cam.set_pivot().
	# Centre of nodes at x∈{0, 20} → centre.x ≈ 10; y=0; z=0.
	var pivot_x_near_centre: bool = abs(cam._pivot.x - 10.0) < 5.0
	# Camera must be positioned at a positive distance from the pivot.
	var distance_positive: bool = cam._distance > 0.0
	# Initial theta: CameraScript initialises _theta = 0.15 (top-down tilt).
	var theta_top_down: bool = cam._theta < PI / 4.0
	return pivot_x_near_centre and distance_positive and theta_top_down


## WHEN the user scrolls toward a bounded context THEN the camera moves closer —
## scroll-up (WHEEL_UP) must decrease _target_distance.
func test_scroll_zoom_changes_distance() -> bool:
	var cam := CameraScript.new()
	var initial_target: float = cam._target_distance

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	up.pressed = true
	cam._handle_button(up)

	return cam._target_distance < initial_target


## WHEN the user uses mouse controls to orbit THEN the camera rotates —
## right-mouse drag (horizontal) must change _phi;
## right-mouse drag (vertical) must change _theta.
func test_orbit_changes_phi_and_theta() -> bool:
	var cam := CameraScript.new()
	var initial_phi: float = cam._phi
	var initial_theta: float = cam._theta

	# Begin orbiting.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Drag diagonally: right 30px, up 20px → phi changes AND theta changes.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(130.0, 80.0)
	cam._handle_motion(motion)

	# drag right 30px → delta.x = +30 → _phi -= 30 * orbit_speed → _phi decreases ✓
	var phi_changed: bool = cam._phi != initial_phi
	# drag up 20px → delta.y = -20 → _theta -= -20 * orbit_speed → _theta increases ✓
	var theta_changed: bool = cam._theta != initial_theta
	return phi_changed and theta_changed


## AND orientation remains intuitive (up stays up) —
## theta is always clamped to [0.01, PI − 0.01] so the camera never flips.
func test_orbit_theta_clamped_prevents_pole_flip() -> bool:
	var cam := CameraScript.new()

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	cam._handle_button(press)

	# Extreme downward drag: delta.y = +10000 → tries to make theta → -infinity.
	# drag down 10000px → delta.y = +10000 → _theta -= 10000 * 0.005 = -50 → clamp to 0.01 ✓
	var down := InputEventMouseMotion.new()
	down.position = Vector2(100.0, 10100.0)
	cam._handle_motion(down)

	# Extreme upward drag: delta.y = -10000 → tries to make theta → +infinity.
	# drag up 10000px → delta.y = -10000 → _theta -= -10000 * 0.005 = +50 → clamp to PI-0.01 ✓
	var up := InputEventMouseMotion.new()
	up.position = Vector2(100.0, 100.0)
	cam._handle_motion(up)

	return cam._theta >= 0.01 and cam._theta <= PI - 0.01


# ---------------------------------------------------------------------------
# Requirement 6: Godot 4.6
# ---------------------------------------------------------------------------

## THEN it uses Godot 4.6.x — project.godot must declare the "4.6" feature tag.
## Uses FileAccess.open() + get_as_text() (valid Godot 4.6 API).
func test_project_declares_godot_46() -> bool:
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	# Must contain both the features key and the "4.6" value.
	return content.contains("config/features") and content.contains('"4.6"')


## AND all API calls are valid for the Godot 4.6 API —
## main.gd must use FileAccess.open() + get_as_text() and must NOT use
## the deprecated Godot 3 File.new() or read_as_text().
func test_main_uses_godot46_fileaccess_api() -> bool:
	var file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	var uses_godot4: bool = content.contains("FileAccess.open(") and content.contains("get_as_text()")
	var no_deprecated: bool = not content.contains("File.new()") and not content.contains("read_as_text()")
	return uses_godot4 and no_deprecated


## AND all scripts use GDScript — every file in res://scripts/ must end in ".gd".
func test_all_scripts_are_gdscript() -> bool:
	var dir := DirAccess.open("res://scripts")
	if dir == null:
		return false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var found_any := false
	while file_name != "":
		if not dir.current_is_dir():
			# Skip Godot-generated metadata files.
			var is_meta: bool = file_name.ends_with(".uid") or file_name.ends_with(".import")
			if not is_meta:
				found_any = true
				if not file_name.ends_with(".gd"):
					dir.list_dir_end()
					return false
		file_name = dir.get_next()
	dir.list_dir_end()
	return found_any
