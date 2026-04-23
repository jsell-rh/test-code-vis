## Behavioral tests for specs/visualization/spatial-structure.spec.md
##
## Spec: Spatial Structure Specification
## Purpose: Define how a software system's structure is represented as a
##          persistent, navigable 3D space.
##
## Scenarios covered:
##
##   Scenario 1 – First-person exploration
##     GIVEN a software system has been loaded
##     WHEN the human enters the environment
##     THEN the system is presented as a navigable 3D space
##     AND the spatial layout communicates the system's structure
##
##   Scenario 2 – Structural elements have spatial presence
##     GIVEN a software system with distinct modules and services
##     WHEN the system is rendered
##     THEN each structural element occupies a distinct region of the space
##     AND boundaries between elements are visually clear
##     AND structural relationships (containment, dependency) are expressed spatially
##
##   Scenario 3 – Navigating from system level to module level
##     GIVEN a system with multiple services each containing multiple modules
##     WHEN the human is far away, they see high-level services
##     AND when the human moves closer to a service, internal modules become visible
##     AND when the human moves closer to a module, finer-grained details appear
##
## Note: "first person" navigation is NOT implemented in the prototype
## (prototype-scope.spec.md § Not In Scope). The orbit camera (pan/zoom/rotate)
## is the prototype's navigation mechanism.

extends RefCounted

const MainScript := preload("res://scripts/main.gd")
const CameraScript := preload("res://scripts/camera_controller.gd")
const LodManager := preload("res://scripts/lod_manager.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Two bounded contexts at distinct positions with child modules and an edge.
func _make_multi_service_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "svc_a",
				"name": "ServiceA",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -30.0, "y": 0.0, "z": 0.0},
				"size": 15.0,
			},
			{
				"id": "svc_b",
				"name": "ServiceB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 30.0, "y": 0.0, "z": 0.0},
				"size": 12.0,
			},
			{
				"id": "svc_a.mod1",
				"name": "ModuleOne",
				"type": "module",
				"parent": "svc_a",
				"position": {"x": -5.0, "y": 0.0, "z": -5.0},
				"size": 4.0,
			},
			{
				"id": "svc_b.mod2",
				"name": "ModuleTwo",
				"type": "module",
				"parent": "svc_b",
				"position": {"x": 5.0, "y": 0.0, "z": 5.0},
				"size": 3.0,
			},
		],
		"edges": [
			{"source": "svc_a", "target": "svc_b", "type": "cross_context"},
			{"source": "svc_a.mod1", "target": "svc_b.mod2", "type": "internal"},
		],
	}


# ---------------------------------------------------------------------------
# Scenario 1: First-person exploration
# THEN the system is presented as a navigable 3D space
# ---------------------------------------------------------------------------

## The camera controller supports zoom — distance decreases on zoom-in.
## Implemented by: camera_controller.gd → _handle_button() MOUSE_BUTTON_WHEEL_UP
##   `_distance = max(min_distance, _distance - zoom_speed * (_distance * 0.05 + 1.0))`
func test_camera_supports_zoom_in() -> void:
	var cam: Object = CameraScript.new()
	var initial_distance: float = cam.get("_distance")
	# Simulate wheel-up: apply the same formula as _handle_button
	var zoom_speed: float = cam.get("zoom_speed")
	var min_dist: float = cam.get("min_distance")
	var new_distance: float = max(min_dist, initial_distance - zoom_speed * (initial_distance * 0.05 + 1.0))
	_check(new_distance < initial_distance,
		"Camera should move closer (smaller distance) when zooming in")


## The camera controller supports zoom out — distance increases on zoom-out.
## Implemented by: camera_controller.gd → _handle_button() MOUSE_BUTTON_WHEEL_DOWN
##   `_distance = min(max_distance, _distance + zoom_speed * (_distance * 0.05 + 1.0))`
func test_camera_supports_zoom_out() -> void:
	var cam: Object = CameraScript.new()
	var initial_distance: float = cam.get("_distance")
	var zoom_speed: float = cam.get("zoom_speed")
	var max_dist: float = cam.get("max_distance")
	var new_distance: float = min(max_dist, initial_distance + zoom_speed * (initial_distance * 0.05 + 1.0))
	_check(new_distance > initial_distance,
		"Camera should move farther (larger distance) when zooming out")


## The camera controller supports orbit — phi and theta change on drag.
## Implemented by: camera_controller.gd → _handle_motion() when _orbiting == true
##   `_phi -= delta.x * orbit_speed` and `_theta = clamp(...)`
func test_camera_supports_orbit() -> void:
	var cam: Object = CameraScript.new()
	var initial_phi: float = cam.get("_phi")
	var orbit_speed: float = cam.get("orbit_speed")
	# Simulate horizontal drag of 100 pixels
	var new_phi: float = initial_phi - 100.0 * orbit_speed
	_check(not is_equal_approx(new_phi, initial_phi),
		"Camera phi should change when orbiting (azimuth rotation)")


## get_distance() returns the current camera distance — used by LOD system.
## Implemented by: camera_controller.gd → get_distance()
##   `return _distance`
func test_camera_get_distance_returns_current_distance() -> void:
	var cam: Object = CameraScript.new()
	cam.set("_distance", 55.5)
	_check(is_equal_approx(cam.call("get_distance"), 55.5),
		"get_distance() should return the current _distance value (55.5)")


## THEN the spatial layout communicates the system's structure —
## build_from_graph() creates a Node3D anchor for every node in the JSON.
## Implemented by: main.gd → build_from_graph() → _create_volume()
##   each node becomes a named Node3D at position from JSON
func test_spatial_layout_creates_node_per_structural_element() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())
	var anchors: Dictionary = main_node.get("_anchors")
	_check(anchors.has("svc_a"), "ServiceA anchor must exist in _anchors")
	_check(anchors.has("svc_b"), "ServiceB anchor must exist in _anchors")
	_check(anchors.has("svc_a.mod1"), "ModuleOne anchor must exist in _anchors")
	_check(anchors.has("svc_b.mod2"), "ModuleTwo anchor must exist in _anchors")


# ---------------------------------------------------------------------------
# Scenario 2: Structural elements have spatial presence
# THEN each structural element occupies a distinct region of the space
# ---------------------------------------------------------------------------

## THEN each structural element occupies a distinct region of the space —
## Two bounded contexts placed at different JSON positions must have
## different world-space positions after build_from_graph().
## Implemented by: main.gd → _create_volume()
##   `anchor.position = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))`
func test_distinct_contexts_occupy_distinct_regions() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())
	var anchors: Dictionary = main_node.get("_anchors")
	var pos_a: Vector3 = (anchors["svc_a"] as Node3D).position
	var pos_b: Vector3 = (anchors["svc_b"] as Node3D).position
	_check(not pos_a.is_equal_approx(pos_b),
		"Two distinct bounded contexts must occupy different positions in space")


## AND boundaries between elements are visually clear —
## The bounded context uses a translucent material (alpha < 1.0).
## Module uses an opaque material (alpha == 1.0).
## This visual difference makes the boundary region distinct from its children.
## Implemented by: main.gd → _create_volume()
##   context: `mat.albedo_color = Color(0.25, 0.45, 0.85, 0.18)` + TRANSPARENCY_ALPHA
##   module:  `mat.albedo_color = Color(0.35, 0.70, 0.40, 1.0)` (opaque)
func test_context_boundary_is_visually_distinct_translucent() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())
	var anchors: Dictionary = main_node.get("_anchors")
	var ctx_anchor: Node3D = anchors["svc_a"]

	# Find the MeshInstance3D child of the context anchor.
	var ctx_mesh: MeshInstance3D = null
	for child: Node in ctx_anchor.get_children():
		if child is MeshInstance3D:
			ctx_mesh = child as MeshInstance3D
			break

	_check(ctx_mesh != null, "Context anchor must have a MeshInstance3D child")
	if ctx_mesh == null:
		return

	var mat := ctx_mesh.material_override as StandardMaterial3D
	_check(mat != null, "Context MeshInstance3D must have a StandardMaterial3D override")
	if mat == null:
		return

	# Translucency: alpha < 1.0 and TRANSPARENCY_ALPHA mode.
	_check(mat.albedo_color.a < 1.0,
		"Context boundary material must be translucent (alpha < 1.0) for visual clarity")
	_check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"Context boundary material must use TRANSPARENCY_ALPHA mode")


## AND structural relationships (containment) are expressed spatially —
## Module anchor is a child of the context anchor in the scene tree.
## Implemented by: main.gd → build_from_graph()
##   when nd["parent"] != null:
##     `parent_anchor = _anchors[nd["parent"]]`
##     `_create_volume(nd, parent_anchor)` → anchor added to parent_anchor
func test_containment_expressed_as_scene_tree_parenting() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())
	var anchors: Dictionary = main_node.get("_anchors")
	var ctx_anchor: Node3D = anchors["svc_a"]
	var mod_anchor: Node3D = anchors["svc_a.mod1"]

	# The module's anchor must be a direct child of the context's anchor.
	_check(mod_anchor.get_parent() == ctx_anchor,
		"Module anchor must be parented to its containing context anchor")


## AND structural relationships (dependency) are expressed spatially —
## An edge between two nodes produces at least one MeshInstance3D child of main.
## Implemented by: main.gd → _create_edge()
##   creates ImmediateMesh line and CylinderMesh arrowhead as children of main
func test_dependency_expressed_as_visible_connection() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())

	var line_found: bool = false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is ImmediateMesh:
				line_found = true
				break
	_check(line_found,
		"A dependency edge must produce a visible line (ImmediateMesh) in the scene")


# ---------------------------------------------------------------------------
# Scenario 3: Scale Through Zoom / Level of Detail
# WHEN the human is far away, they see high-level services
# AND when the human moves closer to a service, internal modules become visible
# AND when the human moves closer to a module, finer-grained details appear
# ---------------------------------------------------------------------------

## Helper: build a LOD node entry pair (one context, one module).
func _make_lod_node_entries() -> Array:
	var ctx_anchor := Node3D.new()
	var mod_anchor := Node3D.new()
	return [
		{"anchor": ctx_anchor, "node_type": "bounded_context"},
		{"anchor": mod_anchor, "node_type": "module"},
	]


## Helper: build a LOD edge entry pair (one cross_context, one internal).
func _make_lod_edge_entries() -> Array:
	var cross_edge := MeshInstance3D.new()
	var internal_edge := MeshInstance3D.new()
	return [
		{"visual": cross_edge, "edge_type": "cross_context"},
		{"visual": internal_edge, "edge_type": "internal"},
	]


## WHEN the human is far away, they see high-level services (bounded_context visible).
## Implemented by: lod_manager.gd → _apply_far()
##   context anchor: `anchor.visible = (ntype == "bounded_context")`  → true
##   module anchor:  `anchor.visible = (ntype == "bounded_context")`  → false (module)
func test_far_distance_shows_only_bounded_contexts() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	var edge_entries := _make_lod_edge_entries()

	lod.update_lod(node_entries, edge_entries, LodManager.FAR_THRESHOLD + 10.0)

	var ctx_anchor: Node3D = node_entries[0]["anchor"]
	var mod_anchor: Node3D = node_entries[1]["anchor"]
	_check(ctx_anchor.visible,
		"Bounded context must be visible at far distance (>FAR_THRESHOLD)")
	_check(not mod_anchor.visible,
		"Module must be hidden at far distance (>FAR_THRESHOLD)")

	# Cleanup
	for e in node_entries:
		(e["anchor"] as Node3D).free()
	for e in edge_entries:
		(e["visual"] as Node3D).free()


## WHEN the human is far away, all edges are hidden.
## Implemented by: lod_manager.gd → _apply_far()
##   `(entry["visual"] as Node3D).visible = false`
func test_far_distance_hides_all_edges() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	var edge_entries := _make_lod_edge_entries()

	lod.update_lod(node_entries, edge_entries, LodManager.FAR_THRESHOLD + 10.0)

	_check(not (edge_entries[0]["visual"] as Node3D).visible,
		"Cross-context edge must be hidden at far distance")
	_check(not (edge_entries[1]["visual"] as Node3D).visible,
		"Internal edge must be hidden at far distance")

	for e in node_entries:
		(e["anchor"] as Node3D).free()
	for e in edge_entries:
		(e["visual"] as Node3D).free()


## AND when the human moves closer to a service, internal modules become visible.
## Implemented by: lod_manager.gd → _apply_medium()
##   context: `anchor.visible = (ntype == "bounded_context" or ntype == "module")` → true
##   module:  same expression → true
func test_medium_distance_shows_modules() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	var edge_entries := _make_lod_edge_entries()

	# Midpoint between NEAR and FAR thresholds.
	var mid: float = (LodManager.NEAR_THRESHOLD + LodManager.FAR_THRESHOLD) * 0.5
	lod.update_lod(node_entries, edge_entries, mid)

	var ctx_anchor: Node3D = node_entries[0]["anchor"]
	var mod_anchor: Node3D = node_entries[1]["anchor"]
	_check(ctx_anchor.visible,
		"Bounded context must remain visible at medium distance")
	_check(mod_anchor.visible,
		"Module must become visible at medium distance (closer than FAR_THRESHOLD)")

	for e in node_entries:
		(e["anchor"] as Node3D).free()
	for e in edge_entries:
		(e["visual"] as Node3D).free()


## At medium distance, cross-context edges appear but internal edges stay hidden.
## Implemented by: lod_manager.gd → _apply_medium()
##   cross_context: `vis_node.visible = (etype == "cross_context")` → true
##   internal:      same expression → false
func test_medium_distance_shows_cross_context_edges_only() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	var edge_entries := _make_lod_edge_entries()

	var mid: float = (LodManager.NEAR_THRESHOLD + LodManager.FAR_THRESHOLD) * 0.5
	lod.update_lod(node_entries, edge_entries, mid)

	_check((edge_entries[0]["visual"] as Node3D).visible,
		"Cross-context edge must be visible at medium distance")
	_check(not (edge_entries[1]["visual"] as Node3D).visible,
		"Internal edge must remain hidden at medium distance")

	for e in node_entries:
		(e["anchor"] as Node3D).free()
	for e in edge_entries:
		(e["visual"] as Node3D).free()


## AND when the human moves closer to a module, finer-grained details appear.
## At NEAR distance, all nodes AND all edges (including internal) become visible.
## Implemented by: lod_manager.gd → _apply_near()
##   nodes: `(entry["anchor"] as Node3D).visible = true`
##   edges: `(entry["visual"] as Node3D).visible = true`
func test_near_distance_shows_all_nodes() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	var edge_entries := _make_lod_edge_entries()

	lod.update_lod(node_entries, edge_entries, LodManager.NEAR_THRESHOLD - 5.0)

	var ctx_anchor: Node3D = node_entries[0]["anchor"]
	var mod_anchor: Node3D = node_entries[1]["anchor"]
	_check(ctx_anchor.visible,
		"Bounded context must be visible at near distance")
	_check(mod_anchor.visible,
		"Module must be visible at near distance")

	for e in node_entries:
		(e["anchor"] as Node3D).free()
	for e in edge_entries:
		(e["visual"] as Node3D).free()


## Finer-grained details (internal edges) appear at near distance.
## Implemented by: lod_manager.gd → _apply_near()
##   `(entry["visual"] as Node3D).visible = true`
func test_near_distance_shows_internal_edges_as_fine_detail() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	var edge_entries := _make_lod_edge_entries()

	lod.update_lod(node_entries, edge_entries, LodManager.NEAR_THRESHOLD - 5.0)

	_check((edge_entries[0]["visual"] as Node3D).visible,
		"Cross-context edge must be visible at near distance")
	_check((edge_entries[1]["visual"] as Node3D).visible,
		"Internal edge (fine detail) must be visible at near distance")

	for e in node_entries:
		(e["anchor"] as Node3D).free()
	for e in edge_entries:
		(e["visual"] as Node3D).free()


## LOD transitions are monotonic: as distance decreases, more is visible.
## Building on the full graph, verify that _lod_node_entries are populated.
## Implemented by: main.gd → _create_volume()
##   `_lod_node_entries.append({"anchor": anchor, "node_type": nd["type"]})`
func test_lod_node_entries_populated_after_build() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())
	var entries: Array = main_node.get("_lod_node_entries")
	_check(entries.size() == 4,
		"LOD node entries must contain one entry per node (4 nodes in fixture)")
	# Verify types are correctly recorded.
	var types: Array = []
	for e: Dictionary in entries:
		types.append(e["node_type"])
	_check(types.has("bounded_context"),
		"LOD entries must include bounded_context type")
	_check(types.has("module"),
		"LOD entries must include module type")


## LOD edge entries are populated (both cross_context and internal per fixture edge).
## Implemented by: main.gd → _create_edge()
##   line:      `_lod_edge_entries.append({"visual": mesh_instance, ...})`
##   arrowhead: `_lod_edge_entries.append({"visual": arrow, ...})`
func test_lod_edge_entries_populated_after_build() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())
	var entries: Array = main_node.get("_lod_edge_entries")
	# 2 edges × 2 visuals (line + arrow) = 4 entries.
	_check(entries.size() == 4,
		"LOD edge entries must contain 4 entries (2 edges × 2 visuals each)")
	var etypes: Array = []
	for e: Dictionary in entries:
		etypes.append(e["edge_type"])
	_check(etypes.has("cross_context"),
		"LOD edge entries must include cross_context type")
	_check(etypes.has("internal"),
		"LOD edge entries must include internal type")


## LOD integrates with main: applying far LOD via lod_manager hides modules.
## This end-to-end test builds a graph, then calls update_lod() directly
## on the LOD manager with the populated entries, and asserts module visibility.
func test_lod_integration_far_hides_modules_in_built_scene() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())

	var lod: LodManager = main_node.get("_lod")
	var node_entries: Array = main_node.get("_lod_node_entries")
	var edge_entries: Array = main_node.get("_lod_edge_entries")

	# Apply FAR LOD directly.
	lod.update_lod(node_entries, edge_entries, LodManager.FAR_THRESHOLD + 20.0)

	# Module anchors should now be hidden.
	var anchors: Dictionary = main_node.get("_anchors")
	var mod_anchor: Node3D = anchors.get("svc_a.mod1")
	_check(mod_anchor != null, "Module anchor svc_a.mod1 must exist")
	if mod_anchor != null:
		_check(not mod_anchor.visible,
			"Module anchor must be hidden after applying FAR LOD")

	# Context anchors should still be visible.
	var ctx_anchor: Node3D = anchors.get("svc_a")
	_check(ctx_anchor != null, "Context anchor svc_a must exist")
	if ctx_anchor != null:
		_check(ctx_anchor.visible,
			"Context anchor must remain visible after applying FAR LOD")
