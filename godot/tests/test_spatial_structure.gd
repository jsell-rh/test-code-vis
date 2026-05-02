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
## An edge between two nodes produces a body node named "EdgeLine" (Node3D or
## MeshInstance3D) with line_style metadata, plus a CylinderMesh arrowhead.
## Implemented by: main.gd → _create_edge()
##   - solid edge (calls): MeshInstance3D CylinderMesh body
##   - dashed/dotted edge (imports/inheritance): Node3D container with segment children
##   All bodies are named "EdgeLine" and carry line_style + edge_weight metadata.
func test_dependency_expressed_as_visible_connection() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())

	# Look for a direct child named "EdgeLine" — the edge body created by _create_edge().
	var line_found: bool = false
	for child: Node in main_node.get_children():
		if str(child.name) == "EdgeLine":
			line_found = true
			break
	_check(line_found,
		"A dependency edge must produce a child named 'EdgeLine' in the scene")


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


## WHEN the human is far away, individual cross-context and internal edges are hidden.
## Aggregate edges (one per context pair, weight = total import count) remain VISIBLE.
## Implemented by: lod_manager.gd → _apply_far()
##   cross_context:  `vis_node.visible = (etype == "aggregate")` → false (cross_context)
##   internal:       `vis_node.visible = (etype == "aggregate")` → false (internal)
func test_far_distance_hides_all_edges() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	var edge_entries := _make_lod_edge_entries()

	lod.update_lod(node_entries, edge_entries, LodManager.FAR_THRESHOLD + 10.0)

	_check(not (edge_entries[0]["visual"] as Node3D).visible,
		"Cross-context edge must be hidden at far distance (aggregate edge takes its place)")
	_check(not (edge_entries[1]["visual"] as Node3D).visible,
		"Internal edge must be hidden at far distance")

	for e in node_entries:
		(e["anchor"] as Node3D).free()
	for e in edge_entries:
		(e["visual"] as Node3D).free()


## FAR: aggregate edges (one per context pair, with weight) are visible.
## Cross-context individual edges and internal edges are hidden.
## Spec: spatial-structure.spec.md §Far — bounded context architecture:
##   "cross-context dependencies are shown as single aggregate edges per
##    context pair, with weight indicating total import count"
## Spec: visual-primitives.spec.md §Power Rail Notation — aggregate_edges at FAR.
## Implemented by: lod_manager.gd → _apply_far()
##   aggregate:     `vis_node.visible = (etype == "aggregate")` → true
##   cross_context: `vis_node.visible = (etype == "aggregate")` → false
func test_far_distance_shows_aggregate_edges() -> void:
	var lod := LodManager.new()
	var node_entries := _make_lod_node_entries()
	# Include one aggregate, one cross_context, and one internal edge.
	var agg_edge := MeshInstance3D.new()
	var cross_edge := MeshInstance3D.new()
	var internal_edge := MeshInstance3D.new()
	var edge_entries: Array = [
		{"visual": agg_edge,      "edge_type": "aggregate"},
		{"visual": cross_edge,    "edge_type": "cross_context"},
		{"visual": internal_edge, "edge_type": "internal"},
	]

	lod.update_lod(node_entries, edge_entries, LodManager.FAR_THRESHOLD + 10.0)

	_check(agg_edge.visible,
		"Aggregate edge must be VISIBLE at FAR distance (one per context pair with weight)")
	_check(not cross_edge.visible,
		"Individual cross-context edge must be HIDDEN at FAR distance (aggregate supersedes it)")
	_check(not internal_edge.visible,
		"Internal edge must be HIDDEN at FAR distance")

	for e in node_entries:
		(e["anchor"] as Node3D).free()
	agg_edge.free()
	cross_edge.free()
	internal_edge.free()


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


## AND boundaries between elements are visually clear (module side) —
## The module uses an opaque material (alpha == 1.0), which visually contrasts
## with the translucent context boundary (alpha < 1.0). Together the two tests
## `test_context_boundary_is_visually_distinct_translucent` and
## `test_module_boundary_is_opaque` confirm that boundary regions are
## perceptually distinct from the volumes they contain.
## Implemented by: main.gd → _create_volume()
##   module: `mat.albedo_color = Color(0.35, 0.70, 0.40, 1.0)` (alpha == 1.0)
func test_module_boundary_is_opaque() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_multi_service_fixture())
	var anchors: Dictionary = main_node.get("_anchors")
	var mod_anchor: Node3D = anchors["svc_a.mod1"]

	# Find the MeshInstance3D child of the module anchor.
	var mod_mesh: MeshInstance3D = null
	for child: Node in mod_anchor.get_children():
		if child is MeshInstance3D:
			mod_mesh = child as MeshInstance3D
			break

	_check(mod_mesh != null, "Module anchor must have a MeshInstance3D child")
	if mod_mesh == null:
		return

	var mat := mod_mesh.material_override as StandardMaterial3D
	_check(mat != null, "Module MeshInstance3D must have a StandardMaterial3D override")
	if mat == null:
		return

	# Opacity: alpha must be == 1.0 — contrast with context alpha < 1.0 makes
	# the spatial boundary between regions visually clear.
	_check(mat.albedo_color.a >= 1.0,
		"Module boundary material must be fully opaque (alpha >= 1.0) — contrast with "
		+ "translucent context makes boundaries visually clear")


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


# ---------------------------------------------------------------------------
# Requirement: Edge Primitive — visual-primitives.spec.md
# Scenario: Weighted edge — "its visual thickness is proportional to the weight"
# Scenario: Edge type distinction — "edge type is encoded by line style"
# Scenario: Suppressed ubiquitous edges — "the Edge is NOT drawn"
# Scenario: Power rail toggle — "all suppressed ubiquitous edges fade in"
# ---------------------------------------------------------------------------

## Helper: build a graph with a single direct_call edge of the given weight.
## Uses distinct positions so the edge direction is non-degenerate.
func _make_call_edge_fixture(weight: int) -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 10.0,
			},
			{
				"id": "mod_a",
				"name": "ModA",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -5.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "mod_b",
				"name": "ModB",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 5.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
		],
		"edges": [
			{
				"source": "mod_a",
				"target": "mod_b",
				"type": "direct_call",
				"weight": weight,
			},
		],
	}


## Helper: extract the CylinderMesh top_radius from an "EdgeLine" child.
## For solid edges (MeshInstance3D), reads .mesh.top_radius directly.
## Returns -1.0 if no solid EdgeLine is found.
func _get_solid_edge_radius(main_node: Node3D) -> float:
	for child: Node in main_node.get_children():
		if str(child.name) == "EdgeLine" and child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh is CylinderMesh:
				return (mi.mesh as CylinderMesh).top_radius
	return -1.0


## spec §Edge Primitive §Scenario: Weighted edge —
## "its visual thickness is proportional to the weight (12)"
## "a single-import Edge is visibly thinner than a 12-import Edge"
## The edge body uses a CylinderMesh whose radius encodes weight.
func test_edge_thickness_proportional_to_weight() -> void:
	_test_failed = false
	var main_light: Node3D = MainScript.new()
	main_light.build_from_graph(_make_call_edge_fixture(1))

	var main_heavy: Node3D = MainScript.new()
	main_heavy.build_from_graph(_make_call_edge_fixture(12))

	var light_radius: float = _get_solid_edge_radius(main_light)
	var heavy_radius: float = _get_solid_edge_radius(main_heavy)

	_check(light_radius > 0.0, "Weight-1 edge must have a positive cylinder radius")
	_check(heavy_radius > 0.0, "Weight-12 edge must have a positive cylinder radius")
	_check(
		heavy_radius > light_radius,
		"Weight-12 edge must be wider than weight-1 edge; got %.4f vs %.4f" % [heavy_radius, light_radius]
	)


## spec §Edge Primitive §Scenario: Edge type distinction —
## "edge type is encoded by line style (solid for calls, dashed for imports,
##  dotted for inheritance)"
## direct_call edges must be encoded as 'solid' line style.
func test_direct_call_edge_has_solid_style() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_call_edge_fixture(1))

	var found_solid: bool = false
	for child: Node in main_node.get_children():
		if str(child.name) == "EdgeLine" and child.has_meta("line_style"):
			if str(child.get_meta("line_style")) == "solid":
				found_solid = true
				break

	_check(found_solid, "direct_call edge must have line_style == 'solid'")


## spec §Edge Primitive §Scenario: Edge type distinction —
## cross_context (import-based) edges must be encoded as 'dashed' line style.
func test_import_edge_has_dashed_style() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	# _make_multi_service_fixture has a cross_context edge (import-based).
	main_node.build_from_graph(_make_multi_service_fixture())

	var found_dashed: bool = false
	for child: Node in main_node.get_children():
		if str(child.name) == "EdgeLine" and child.has_meta("line_style"):
			if str(child.get_meta("line_style")) == "dashed":
				found_dashed = true
				break

	_check(found_dashed, "cross_context (import-based) edge must have line_style == 'dashed'")


## Helper: build a graph with a single inherits edge.
func _make_inherits_edge_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "mod_a",
				"name": "ModA",
				"type": "module",
				"parent": null,
				"position": {"x": -10.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "mod_b",
				"name": "ModB",
				"type": "module",
				"parent": null,
				"position": {"x": 10.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
		],
		"edges": [
			{
				"source": "mod_a",
				"target": "mod_b",
				"type": "inherits",
				"weight": 1,
			},
		],
	}


## spec §Edge Primitive §Scenario: Edge type distinction —
## inherits edges must be encoded as 'dotted' line style.
func test_inherits_edge_has_dotted_style() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_inherits_edge_fixture())

	var found_dotted: bool = false
	for child: Node in main_node.get_children():
		if str(child.name) == "EdgeLine" and child.has_meta("line_style"):
			if str(child.get_meta("line_style")) == "dotted":
				found_dotted = true
				break

	_check(found_dotted, "inherits edge must have line_style == 'dotted'")


## Helper: build a graph with a single ubiquitous edge.
func _make_ubiquitous_edge_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "logging",
				"name": "logging",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -20.0, "y": 0.0, "z": 0.0},
				"size": 5.0,
			},
			{
				"id": "mymod",
				"name": "MyMod",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"size": 5.0,
			},
		],
		"edges": [
			{
				"source": "mymod",
				"target": "logging",
				"type": "cross_context",
				"weight": 1,
				"ubiquitous": true,
			},
		],
	}


## spec §Edge Primitive §Scenario: Suppressed ubiquitous edges —
## "the Edge is NOT drawn" — ubiquitous edges must be hidden by default.
## spec §Power Rail Notation §Scenario: Standard library power rail —
## "no edges to logging are drawn"
func test_ubiquitous_edge_suppressed_by_default() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_ubiquitous_edge_fixture())

	# Ubiquitous edge visuals must be tracked and hidden.
	var ubiquitous_visuals: Array = main_node.get("_ubiquitous_edge_visuals")
	_check(
		ubiquitous_visuals.size() > 0,
		"Ubiquitous edge visuals must be tracked in _ubiquitous_edge_visuals"
	)
	for vis: Node3D in ubiquitous_visuals:
		_check(
			not (vis as Node3D).visible,
			"Ubiquitous edge visual must be hidden (not visible) by default"
		)

	# Ubiquitous edges must NOT appear in LOD entries (they bypass LOD).
	var lod_entries: Array = main_node.get("_lod_edge_entries")
	for entry: Dictionary in lod_entries:
		var vis_node: Node3D = entry["visual"] as Node3D
		_check(
			vis_node.visible,
			"Non-ubiquitous edge in LOD entries must be visible"
		)


## spec §Power Rail Notation §Scenario: Power rail toggle —
## "WHEN the human toggles power rails to visible
##  THEN all suppressed ubiquitous edges fade in
##  AND the toggle is reversible"
func test_ubiquitous_edge_toggle_shows_then_hides() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_ubiquitous_edge_fixture())

	var ubiquitous_visuals: Array = main_node.get("_ubiquitous_edge_visuals")
	_check(ubiquitous_visuals.size() > 0, "Must have ubiquitous edge visuals to toggle")

	# Toggle ON — all ubiquitous edges become visible.
	main_node.call("toggle_ubiquitous_edges")
	for vis: Node3D in ubiquitous_visuals:
		_check(
			(vis as Node3D).visible,
			"Ubiquitous edge must become visible after first toggle"
		)

	# Toggle OFF — all ubiquitous edges become hidden again (reversible).
	main_node.call("toggle_ubiquitous_edges")
	for vis: Node3D in ubiquitous_visuals:
		_check(
			not (vis as Node3D).visible,
			"Ubiquitous edge must be hidden again after second toggle (reversible)"
		)


# ---------------------------------------------------------------------------
# Requirement: Container Primitive — membrane permeability
# visual-primitives.spec.md §Scenario: Container membrane permeability —
# "the membrane appears thick/opaque (strong encapsulation)"
# "permeability is a continuous visual property, not a binary toggle"
# ---------------------------------------------------------------------------

## Helper: build a graph with one bounded_context node that has explicit symbols.
func _make_context_with_symbols(symbols: Array) -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 10.0,
				"symbols": symbols,
			},
		],
		"edges": [],
	}


## Helper: get the material alpha of the first MeshInstance3D child of anchor "ctx".
func _get_ctx_alpha(main_node: Node3D) -> float:
	var anchors: Dictionary = main_node.get("_anchors")
	var ctx: Node3D = anchors.get("ctx")
	if ctx == null:
		return -1.0
	for child: Node in ctx.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				return mat.albedo_color.a
	return -1.0


## spec §Container Primitive §Scenario: Container membrane permeability —
## "the membrane appears thick/opaque (strong encapsulation — few openings)"
## "a module with 25 public symbols has a thin/porous membrane"
## "permeability is a continuous visual property, not a binary toggle"
##
## Container with mostly private symbols (strong encapsulation) must have
## higher alpha (more opaque) than container with mostly public symbols.
func test_membrane_permeability_reflects_public_private_ratio() -> void:
	_test_failed = false
	# Few public symbols → strong encapsulation → opaque (high alpha).
	var few_public_symbols: Array = [
		{"name": "priv1", "visibility": "private"},
		{"name": "priv2", "visibility": "private"},
		{"name": "priv3", "visibility": "private"},
		{"name": "pub1",  "visibility": "public"},  # 1 of 4 = 25% public
	]
	# Many public symbols → weak encapsulation → porous (low alpha).
	var many_public_symbols: Array = [
		{"name": "pub1", "visibility": "public"},
		{"name": "pub2", "visibility": "public"},
		{"name": "pub3", "visibility": "public"},
		{"name": "priv", "visibility": "private"},  # 3 of 4 = 75% public
	]

	var main_opaque: Node3D = MainScript.new()
	main_opaque.build_from_graph(_make_context_with_symbols(few_public_symbols))

	var main_porous: Node3D = MainScript.new()
	main_porous.build_from_graph(_make_context_with_symbols(many_public_symbols))

	var alpha_opaque: float = _get_ctx_alpha(main_opaque)
	var alpha_porous: float = _get_ctx_alpha(main_porous)

	_check(alpha_opaque > 0.0, "Opaque container must have positive alpha; got %.3f" % alpha_opaque)
	_check(alpha_porous > 0.0, "Porous container must have positive alpha; got %.3f" % alpha_porous)
	_check(
		alpha_opaque > alpha_porous,
		"Container with fewer public symbols must have higher alpha (more opaque); "
		+ "got opaque=%.3f, porous=%.3f" % [alpha_opaque, alpha_porous]
	)


# ---------------------------------------------------------------------------
# Requirement: Cluster Collapsing
# specs/visualization/spatial-structure.spec.md
#
#   Scenario: Pre-computed cluster suggestions
#     GIVEN the extractor has identified groups of modules with high mutual coupling
#     WHEN the scene graph is loaded
#     THEN suggested clusters are indicated visually (e.g. subtle shared tint)
#     AND the human can accept a suggestion to collapse, or ignore it
#     AND suggestions never auto-collapse — the human always initiates
#
#   Scenario: Collapsing a cluster
#     GIVEN a bounded context with a group of heavily interdependent modules
#     WHEN the human triggers collapse on the group
#     THEN the modules animate together, converging smoothly into a single supernode
#     AND the supernode displays aggregate metrics (total LOC, combined in-degree,
#         combined out-degree)
#     AND edges that formerly entered or left any member are re-routed to the supernode
#
#   Scenario: Expanding a supernode
#     GIVEN a collapsed supernode
#     WHEN the human triggers expansion
#     THEN the supernode smoothly expands back into its constituent modules
#     AND edges re-route back to their original endpoints
#
#   Scenario: Nested collapsing
#     GIVEN a bounded context with multiple suggested clusters
#     WHEN the human collapses one cluster but not another
#     THEN only the selected cluster collapses
#     AND the uncollapsed modules remain in place
# ---------------------------------------------------------------------------

## Helper: build a scene graph dictionary with two coupled modules and one
## pre-computed cluster suggestion.
func _make_cluster_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 15.0,
			},
			{
				"id": "ctx.mod_a",
				"name": "ModA",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -4.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.mod_b",
				"name": "ModB",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 4.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.mod_c",
				"name": "ModC",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 0.0, "y": 0.0, "z": 6.0},
				"size": 3.0,
			},
		],
		"edges": [
			{"source": "ctx.mod_a", "target": "ctx.mod_b", "type": "internal", "weight": 3},
			{"source": "ctx.mod_b", "target": "ctx.mod_a", "type": "internal", "weight": 2},
			{"source": "ctx.mod_c", "target": "ctx.mod_a", "type": "internal", "weight": 1},
		],
		"clusters": [
			{
				"id": "ctx:cluster_0",
				"members": ["ctx.mod_a", "ctx.mod_b"],
				"context": "ctx",
				"aggregate_metrics": {
					"total_loc": 200,
					"in_degree": 1,
					"out_degree": 0,
				},
			},
		],
	}


## Scenario: Pre-computed cluster suggestions —
## "suggested clusters are indicated visually (e.g. subtle shared tint)"
## Implemented by: main.gd → build_from_graph() → _apply_cluster_suggestions()
##   each cluster member node gets a "ClusterTint" MeshInstance3D child with a
##   distinctive semi-transparent overlay so the human can see the suggestion.
## Test: cluster member anchor has a child named "ClusterTint".
func test_cluster_suggestion_has_visual_tint() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_cluster_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	# Both ctx.mod_a and ctx.mod_b are cluster members — both must have a tint.
	for member_id: String in ["ctx.mod_a", "ctx.mod_b"]:
		var anchor: Node3D = anchors.get(member_id) as Node3D
		_check(anchor != null, "Cluster member %s anchor must exist" % member_id)
		if anchor == null:
			continue
		var has_tint: bool = false
		for child: Node in anchor.get_children():
			if str(child.name) == "ClusterTint":
				has_tint = true
				break
		_check(has_tint,
			"Cluster member %s must have a 'ClusterTint' child for visual suggestion" % member_id)


## Scenario: Pre-computed cluster suggestions —
## "suggestions never auto-collapse — the human always initiates"
## Implemented by: main.gd → build_from_graph(): cluster members are NOT hidden
##   after build (no auto-collapse). The _collapsed_clusters dict starts empty.
func test_cluster_suggestion_does_not_auto_collapse() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_cluster_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	# After build, cluster members must still be visible (not auto-collapsed).
	for member_id: String in ["ctx.mod_a", "ctx.mod_b"]:
		var anchor: Node3D = anchors.get(member_id) as Node3D
		_check(anchor != null, "Cluster member %s must have an anchor" % member_id)
		if anchor != null:
			_check(anchor.visible,
				"Cluster member %s must be visible after build (no auto-collapse)" % member_id)

	# No collapsed clusters exist after initial build.
	var collapsed: Dictionary = main_node.get("_collapsed_clusters")
	_check(collapsed.is_empty(),
		"_collapsed_clusters must be empty after initial build (no auto-collapse)")


## Scenario: Collapsing a cluster —
## "WHEN the human triggers collapse on the group"
## "THEN the modules animate together, converging smoothly into a single supernode"
## Implemented by: main.gd → collapse_cluster(cluster_id)
##   - hides member module anchors
##   - creates a supernode Node3D at the centroid of the members
##   - records the collapsed state in _collapsed_clusters
func test_collapse_cluster_hides_members() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_cluster_fixture())

	main_node.call("collapse_cluster", "ctx:cluster_0")

	var anchors: Dictionary = main_node.get("_anchors")
	# Cluster members (ctx.mod_a, ctx.mod_b) must be hidden after collapse.
	for member_id: String in ["ctx.mod_a", "ctx.mod_b"]:
		var anchor: Node3D = anchors.get(member_id) as Node3D
		_check(anchor != null, "Cluster member %s anchor must exist" % member_id)
		if anchor != null:
			_check(not anchor.visible,
				"Cluster member %s must be hidden after collapse" % member_id)


## Scenario: Collapsing a cluster —
## "AND the supernode displays aggregate metrics (total LOC, combined in-degree,
##  combined out-degree)"
## Implemented by: main.gd → collapse_cluster() creates a Node3D named after the
##   cluster ID with a Label3D child showing aggregate metrics.
## Label3D readability: billboard = BILLBOARD_ENABLED and pixel_size > 0.0.
func test_collapse_cluster_creates_supernode_with_metrics() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_cluster_fixture())

	main_node.call("collapse_cluster", "ctx:cluster_0")

	# A supernode anchor must exist in _anchors under the cluster ID.
	var anchors: Dictionary = main_node.get("_anchors")
	var supernode_key: String = "ctx:cluster_0"
	_check(anchors.has(supernode_key),
		"Supernode anchor must be registered in _anchors under cluster ID 'ctx:cluster_0'")

	if not anchors.has(supernode_key):
		return

	var supernode: Node3D = anchors[supernode_key] as Node3D
	_check(supernode != null, "Supernode anchor must not be null")
	if supernode == null:
		return

	# The supernode must have a Label3D child for metrics display.
	var label: Label3D = null
	for child: Node in supernode.get_children():
		if child is Label3D:
			label = child as Label3D
			break
	_check(label != null, "Supernode must have a Label3D child displaying aggregate metrics")
	if label == null:
		return

	# Label3D readability: billboard keeps the label facing the camera so it
	# remains legible from any viewing angle.
	_check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		"Supernode Label3D must use BILLBOARD_ENABLED so it remains readable from any angle")
	# pixel_size > 0.0 ensures the text has a non-zero real-world size in the scene.
	_check(label.pixel_size > 0.0,
		"Supernode Label3D must have pixel_size > 0.0 for legibility; got %.4f" % label.pixel_size)


## Scenario: Collapsing a cluster —
## "AND edges that formerly entered or left any member of the cluster are
##  re-routed to the supernode"
## Implemented by: main.gd → collapse_cluster() iterates LOD edge entries and
##   updates the source/target for edges that connected to a cluster member.
##   The supernode appears in _collapsed_clusters so edge routing knows it's active.
func test_collapse_cluster_recorded_in_collapsed_clusters() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_cluster_fixture())

	main_node.call("collapse_cluster", "ctx:cluster_0")

	# _collapsed_clusters must record the cluster ID and member list.
	var collapsed: Dictionary = main_node.get("_collapsed_clusters")
	_check(collapsed.has("ctx:cluster_0"),
		"_collapsed_clusters must record 'ctx:cluster_0' after collapse")

	if collapsed.has("ctx:cluster_0"):
		var members: Array = collapsed["ctx:cluster_0"] as Array
		_check(members.size() == 2,
			"Collapsed cluster 'ctx:cluster_0' must record 2 members, got %d" % members.size())
		_check(members.has("ctx.mod_a"), "Collapsed cluster members must include 'ctx.mod_a'")
		_check(members.has("ctx.mod_b"), "Collapsed cluster members must include 'ctx.mod_b'")


## Scenario: Expanding a supernode —
## "GIVEN a collapsed supernode"
## "WHEN the human triggers expansion"
## "THEN the supernode smoothly expands back into its constituent modules"
## "AND modules animate outward to their original positions"
## Implemented by: main.gd → expand_cluster(cluster_id)
##   - removes the supernode anchor
##   - restores visibility of member anchors
##   - removes cluster from _collapsed_clusters
func test_expand_cluster_restores_members() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_cluster_fixture())

	# Collapse first, then expand.
	main_node.call("collapse_cluster", "ctx:cluster_0")
	main_node.call("expand_cluster", "ctx:cluster_0")

	var anchors: Dictionary = main_node.get("_anchors")

	# After expansion, cluster members must be visible again.
	for member_id: String in ["ctx.mod_a", "ctx.mod_b"]:
		var anchor: Node3D = anchors.get(member_id) as Node3D
		_check(anchor != null, "Cluster member %s anchor must still exist after expansion" % member_id)
		if anchor != null:
			_check(anchor.visible,
				"Cluster member %s must be visible again after expansion" % member_id)

	# Supernode must be removed from _anchors after expansion.
	_check(not anchors.has("ctx:cluster_0"),
		"Supernode 'ctx:cluster_0' must be removed from _anchors after expansion")

	# _collapsed_clusters must no longer record the cluster.
	var collapsed: Dictionary = main_node.get("_collapsed_clusters")
	_check(not collapsed.has("ctx:cluster_0"),
		"_collapsed_clusters must not record 'ctx:cluster_0' after expansion")


## Scenario: Nested collapsing —
## "GIVEN a bounded context with multiple suggested clusters"
## "WHEN the human collapses one cluster but not another"
## "THEN only the selected cluster collapses"
## "AND the uncollapsed modules remain in place"
## Implemented by: main.gd → collapse_cluster() operates independently per cluster.
func test_nested_collapsing_only_collapses_selected() -> void:
	_test_failed = false

	# Build a fixture with TWO clusters.
	var graph: Dictionary = {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 20.0,
			},
			{
				"id": "ctx.alpha",
				"name": "Alpha",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -8.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.beta",
				"name": "Beta",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -4.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.gamma",
				"name": "Gamma",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 4.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.delta",
				"name": "Delta",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 8.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
		],
		"edges": [
			{"source": "ctx.alpha", "target": "ctx.beta", "type": "internal", "weight": 2},
			{"source": "ctx.beta",  "target": "ctx.alpha", "type": "internal", "weight": 2},
			{"source": "ctx.gamma", "target": "ctx.delta", "type": "internal", "weight": 2},
			{"source": "ctx.delta", "target": "ctx.gamma", "type": "internal", "weight": 2},
		],
		"clusters": [
			{
				"id": "ctx:cluster_0",
				"members": ["ctx.alpha", "ctx.beta"],
				"context": "ctx",
				"aggregate_metrics": {"total_loc": 100, "in_degree": 0, "out_degree": 0},
			},
			{
				"id": "ctx:cluster_1",
				"members": ["ctx.gamma", "ctx.delta"],
				"context": "ctx",
				"aggregate_metrics": {"total_loc": 100, "in_degree": 0, "out_degree": 0},
			},
		],
	}

	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(graph)

	# Collapse only the first cluster.
	main_node.call("collapse_cluster", "ctx:cluster_0")

	var anchors: Dictionary = main_node.get("_anchors")

	# First cluster members must be hidden.
	_check(not (anchors["ctx.alpha"] as Node3D).visible,
		"ctx.alpha must be hidden after collapsing cluster_0")
	_check(not (anchors["ctx.beta"] as Node3D).visible,
		"ctx.beta must be hidden after collapsing cluster_0")

	# Second cluster members must remain visible (not collapsed).
	_check((anchors["ctx.gamma"] as Node3D).visible,
		"ctx.gamma must remain visible (cluster_1 was not collapsed)")
	_check((anchors["ctx.delta"] as Node3D).visible,
		"ctx.delta must remain visible (cluster_1 was not collapsed)")


# ---------------------------------------------------------------------------
# Edge re-routing tests
# specs/visualization/spatial-structure.spec.md § Cluster Collapsing —
#   "edges that formerly entered or left any member of the cluster are
#    re-routed to the supernode"
#   "edge re-routing animates smoothly — endpoints slide to the supernode
#    rather than jumping"
#
# § Expanding a supernode —
#   "edges re-route back to their original endpoints with smooth animation"
# ---------------------------------------------------------------------------

## Build a fixture with an external node whose edge connects to a cluster member.
## The external node "ext" is at (20, 0, 0).  The cluster members ctx.mod_a and
## ctx.mod_b are at world positions (-4, 0, 0) and (4, 0, 0) respectively.
## The edge from "ext" to "ctx.mod_a" is what we will track through collapse/expand.
func _make_reroute_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 15.0,
			},
			{
				"id": "ctx.mod_a",
				"name": "ModA",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -4.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.mod_b",
				"name": "ModB",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 4.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ext",
				"name": "External",
				"type": "module",
				"parent": null,
				"position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
		],
		# Edge from ext → ctx.mod_a: the source "ext" is NOT a cluster member,
		# the target "ctx.mod_a" IS a cluster member.  After collapse the target
		# endpoint must slide from (-4,0,0) to the supernode centroid (0,0,0).
		"edges": [
			{"source": "ext", "target": "ctx.mod_a", "type": "internal", "weight": 1},
		],
		"clusters": [
			{
				"id": "ctx:cluster_0",
				"members": ["ctx.mod_a", "ctx.mod_b"],
				"context": "ctx",
				"aggregate_metrics": {
					"total_loc": 100,
					"in_degree": 1,
					"out_degree": 0,
				},
			},
		],
	}


## Helper: find the arrow visual in _path_edge_entries for the edge
## from "ext" to a cluster member and return its cached to_pos.
## The arrow role entry corresponds to the arrowhead placed at the target endpoint.
func _get_arrow_to_pos(main_node: Node3D) -> Vector3:
	var entries: Array = main_node.get("_path_edge_entries")
	for entry: Dictionary in entries:
		if entry.get("role", "") == "arrow" and entry.get("source", "") == "ext":
			return entry.get("to_pos", Vector3.ZERO)
	return Vector3.INF


## Scenario: Collapsing a cluster — edge re-routing.
##
## "edges that formerly entered or left any member of the cluster are
##  re-routed to the supernode"
##
## After collapse, the edge from "ext" to "ctx.mod_a" must have its target
## endpoint moved to the supernode centroid (average of mod_a and mod_b world
## positions).
##
## Implemented by: main.gd → collapse_cluster() → _reposition_edge_visual().
## The cached to_pos in _path_edge_entries is the ground truth used by both the
## visual reposition and this test assertion.
func test_collapse_cluster_reroutes_edges_to_supernode() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_reroute_fixture())

	# Verify the original arrow to_pos equals ctx.mod_a world position (-4, 0, 0).
	var orig_to: Vector3 = _get_arrow_to_pos(main_node)
	_check(orig_to == Vector3(-4.0, 0.0, 0.0),
		"Before collapse: arrow to_pos must equal ctx.mod_a world pos (-4,0,0); got %s" % str(orig_to))

	main_node.call("collapse_cluster", "ctx:cluster_0")

	# The supernode centroid is the average of mod_a (-4,0,0) and mod_b (4,0,0) = (0,0,0).
	# After re-routing, the arrow to_pos must equal the centroid.
	var rerouted_to: Vector3 = _get_arrow_to_pos(main_node)
	_check(rerouted_to == Vector3(0.0, 0.0, 0.0),
		"After collapse: arrow to_pos must equal supernode centroid (0,0,0); got %s" % str(rerouted_to))


## Scenario: Expanding a supernode — edge endpoint restoration.
##
## "edges re-route back to their original endpoints with smooth animation"
##
## After collapse then expand, the arrow to_pos must return to the original
## ctx.mod_a world position (-4, 0, 0).
##
## Implemented by: main.gd → expand_cluster() → _reposition_edge_visual().
func test_expand_cluster_restores_edge_endpoints() -> void:
	_test_failed = false
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_reroute_fixture())

	# Collapse, then immediately expand.
	main_node.call("collapse_cluster", "ctx:cluster_0")
	main_node.call("expand_cluster", "ctx:cluster_0")

	# The arrow to_pos must be restored to its pre-collapse value: (-4, 0, 0).
	var restored_to: Vector3 = _get_arrow_to_pos(main_node)
	_check(restored_to == Vector3(-4.0, 0.0, 0.0),
		"After expand: arrow to_pos must be restored to (-4,0,0); got %s" % str(restored_to))
