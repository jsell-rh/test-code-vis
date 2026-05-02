## Behavioral tests for specs/core/visual-primitives.spec.md
##
## Spec: Visual Primitives Specification
## Purpose: Verify that the VisualPrimitives renderer correctly attaches
##   Badge, Landmark, and Power Rail visual elements to scene nodes.
##   Also tests Landmark LOD persistence and Power Rail suppression via Main/LodManager.
##
## Tests instantiate real Node3D trees and assert scene-tree properties —
## NOT just dict key existence.

extends RefCounted

const Main = preload("res://scripts/main.gd")
const LodManager = preload("res://scripts/lod_manager.gd")
const VisualPrimitives = preload("res://scripts/visual_primitives.gd")

var _vp: VisualPrimitives = VisualPrimitives.new()
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

## A minimal fixture with one hub node (is_hub=true) and one regular module.
## The hub is a bounded_context; the non-hub plain node is a module so that
## the FAR LOD test can verify the module is hidden while the hub stays visible.
## (The LOD manager hides modules at FAR distance but not bounded_contexts.)
func _make_hub_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "hub_svc",
				"name": "HubService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"is_hub": true,
			},
			{
				"id": "ctx_b",
				"name": "ContextB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 10.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				"is_hub": false,
			},
			{
				"id": "ctx_b.plain_mod",
				"name": "PlainModule",
				"type": "module",
				"parent": "ctx_b",
				"position": {"x": 1.0, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"is_hub": false,
			},
		],
		"edges": [],
		"metadata": {},
	}


## A fixture with one ubiquitous edge (ubiquitous=true) and one regular edge.
func _make_power_rail_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "svc_a",
				"name": "ServiceA",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "svc_b",
				"name": "ServiceB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 15.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "ubiq_dep",
				"name": "UbiqDep",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 15.0},
				"size": 1.5,
			},
		],
		"edges": [
			# Normal edge — should be drawn.
			{"source": "svc_a", "target": "svc_b", "type": "cross_context"},
			# Ubiquitous edge — should be suppressed, indicator added.
			{
				"source": "svc_a",
				"target": "ubiq_dep",
				"type": "cross_context",
				"ubiquitous": true,
			},
		],
		"metadata": {},
	}


# ---------------------------------------------------------------------------
# Helper: find a child MeshInstance3D by name in a node's children
# ---------------------------------------------------------------------------

func _find_mesh_child(parent: Node3D) -> MeshInstance3D:
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


func _find_child_by_name(parent: Node3D, target_name: String) -> Node:
	for child: Node in parent.get_children():
		if child.name == target_name:
			return child
	return null


# ---------------------------------------------------------------------------
# Scenario: Landmark Primitive
# GIVEN a module with is_hub=true
# WHEN it is identified as a Landmark
# THEN it has a distinctive visual treatment (larger, brighter)
# AND it is visible at every zoom level
# ---------------------------------------------------------------------------

## THEN it has a distinctive visual treatment — landmark is larger.
## Hub nodes are scaled up (landmark_sz = sz * 1.5) so they stand out.
## Implemented by: main.gd → _create_volume()
##   `var landmark_sz: float = sz * 1.5`
func test_hub_node_has_larger_mesh_than_regular_node() -> void:
	var root := Main.new()
	root.build_from_graph(_make_hub_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var hub_anchor: Node3D = anchors.get("hub_svc")
	var plain_anchor: Node3D = anchors.get("ctx_b")
	_check(hub_anchor != null, "hub_svc anchor must exist after build_from_graph")
	_check(plain_anchor != null, "ctx_b anchor must exist after build_from_graph")
	if hub_anchor == null or plain_anchor == null:
		root.free()
		return

	var hub_mesh := _find_mesh_child(hub_anchor)
	var plain_mesh := _find_mesh_child(plain_anchor)
	_check(hub_mesh != null, "hub_svc must have a MeshInstance3D child")
	_check(plain_mesh != null, "ctx_b must have a MeshInstance3D child")
	if hub_mesh == null or plain_mesh == null:
		root.free()
		return

	# Hub size = sz(3.0) * 1.5 = 4.5; ctx_b size = sz(2.0) (non-hub).
	# Compare mesh bounding box extents: hub should be larger in X.
	var hub_aabb := (hub_mesh.mesh as BoxMesh).size.x
	var plain_aabb := (plain_mesh.mesh as BoxMesh).size.x
	_check(
		hub_aabb > plain_aabb,
		"Hub node mesh must be larger than plain node mesh (Landmark distinctive size)"
	)

	root.free()


## THEN it has a distinctive visual treatment — landmark has a bright colour.
## Hub nodes use a bright yellow material with emission, making them stand out.
## Implemented by: main.gd → _create_volume() when is_landmark:
##   `mat.albedo_color = Color(1.0, 0.95, 0.30, 1.0)`  -- bright yellow
##   `mat.emission_enabled = true`
func test_hub_node_has_bright_emission_material() -> void:
	var root := Main.new()
	root.build_from_graph(_make_hub_fixture())
	var anchors: Dictionary = root.get("_anchors")
	var hub_anchor: Node3D = anchors.get("hub_svc")
	_check(hub_anchor != null, "hub_svc anchor must exist")
	if hub_anchor == null:
		root.free()
		return

	var hub_mesh := _find_mesh_child(hub_anchor)
	_check(hub_mesh != null, "hub_svc must have a MeshInstance3D child")
	if hub_mesh == null:
		root.free()
		return

	var mat := hub_mesh.material_override as StandardMaterial3D
	_check(mat != null, "hub_svc MeshInstance3D must have a StandardMaterial3D override")
	if mat == null:
		root.free()
		return

	# Landmark should have emission enabled.
	_check(mat.emission_enabled, "Landmark hub node must have emission_enabled=true for brightness")
	# Landmark albedo should be bright (sum R+G+B > 2.0 for a bright color).
	var brightness: float = mat.albedo_color.r + mat.albedo_color.g + mat.albedo_color.b
	_check(brightness > 2.0, "Landmark hub node must have a bright albedo color")

	root.free()


## THEN it is visible at every zoom level — hub NOT in LOD entries.
## Hub nodes are excluded from _lod_node_entries so the LOD manager never hides them.
## Spec: "visible at every zoom level, even when surrounding Nodes are hidden by LOD"
## Implemented by: main.gd → _create_volume() when is_landmark:
##   (does NOT call `_lod_node_entries.append(...)`)
func test_hub_node_not_registered_in_lod_entries() -> void:
	var root := Main.new()
	root.build_from_graph(_make_hub_fixture())
	var lod_entries: Array = root.get("_lod_node_entries")

	# Check that "hub_svc" anchor is NOT in any LOD entry.
	var anchors: Dictionary = root.get("_anchors")
	var hub_anchor: Node3D = anchors.get("hub_svc")
	_check(hub_anchor != null, "hub_svc anchor must exist")
	if hub_anchor == null:
		root.free()
		return

	var hub_in_lod: bool = false
	for entry: Dictionary in lod_entries:
		if (entry["anchor"] as Node3D) == hub_anchor:
			hub_in_lod = true
			break
	_check(
		not hub_in_lod,
		"Hub (Landmark) node must NOT be registered in LOD entries — it persists at all zoom levels"
	)

	root.free()


## THEN it is visible at every zoom level — hub visible after FAR LOD applied.
## After applying FAR LOD (which hides non-landmark nodes), hub stays visible.
## Spec: "visible at every zoom level, even when surrounding Nodes are hidden by LOD"
func test_hub_node_visible_after_far_lod_applied() -> void:
	var root := Main.new()
	root.build_from_graph(_make_hub_fixture())

	var lod: LodManager = root.get("_lod")
	var node_entries: Array = root.get("_lod_node_entries")
	var edge_entries: Array = root.get("_lod_edge_entries")

	# Apply FAR LOD — would hide non-landmark nodes.
	lod.update_lod(node_entries, edge_entries, LodManager.FAR_THRESHOLD + 20.0)

	# Hub (landmark) should still be visible — it was never registered in LOD.
	var anchors: Dictionary = root.get("_anchors")
	var hub_anchor: Node3D = anchors.get("hub_svc")
	_check(hub_anchor != null, "hub_svc anchor must exist after build")
	if hub_anchor != null:
		_check(
			hub_anchor.visible,
			"Hub (Landmark) node must remain visible after FAR LOD (persists at all zoom levels)"
		)

	# Module node should be hidden at FAR (modules ARE hidden at FAR, it IS in LOD entries).
	var plain_anchor: Node3D = anchors.get("ctx_b.plain_mod")
	_check(plain_anchor != null, "ctx_b.plain_mod anchor must exist")
	if plain_anchor != null:
		_check(
			not plain_anchor.visible,
			"Module node must be hidden at FAR distance (LOD hides modules)"
		)

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Power Rail Notation
# GIVEN an edge with ubiquitous=true
# WHEN the default view is rendered
# THEN the edge is NOT drawn
# AND a small indicator on the source node acknowledges the dependency
# ---------------------------------------------------------------------------

## THEN the edge is NOT drawn — no ImmediateMesh line created for ubiquitous edge.
## Spec: "no edges to [ubiquitous module] are drawn"
## Implemented by: main.gd → _create_edge() — returns early when ubiquitous=true.
func test_ubiquitous_edge_produces_no_line_mesh() -> void:
	var root := Main.new()
	root.build_from_graph(_make_power_rail_fixture())

	# Count VISIBLE "EdgeLine" children at the scene root.
	# The fixture has 2 edges: svc_a→svc_b (normal) and svc_a→ubiq_dep (ubiquitous).
	# Both create an "EdgeLine" body, but the ubiquitous one is hidden by default.
	# Aggregate edges (named "AggregateEdge_*") are a separate FAR-LOD construct.
	var visible_line_count: int = 0
	for child: Node in root.get_children():
		if child.name == "EdgeLine" and (child as Node3D).visible:
			visible_line_count += 1

	# Exactly 1 VISIBLE edge body should exist (for the normal cross_context edge).
	# The ubiquitous edge body is hidden (tracked in _ubiquitous_edge_visuals).
	_check(
		visible_line_count == 1,
		"Only 1 visible edge body should be drawn (ubiquitous body is hidden); got %d" % visible_line_count
	)

	root.free()


## THEN a small indicator on the source node acknowledges the dependency.
## Spec: "each Node that imports [ubiquitous dep] has a small, consistent indicator"
## Implemented by: main.gd → _create_edge() → _add_power_rail_indicator() when ubiquitous.
func test_ubiquitous_edge_adds_power_rail_indicator_to_source() -> void:
	var root := Main.new()
	root.build_from_graph(_make_power_rail_fixture())

	var anchors: Dictionary = root.get("_anchors")
	var svc_a_anchor: Node3D = anchors.get("svc_a")
	_check(svc_a_anchor != null, "svc_a anchor must exist (it is the source of the ubiquitous edge)")
	if svc_a_anchor == null:
		root.free()
		return

	# The Power Rail indicator is a child named "PowerRailIndicator".
	var indicator: Node = _find_child_by_name(svc_a_anchor, "PowerRailIndicator")
	_check(
		indicator != null,
		"svc_a (source of ubiquitous edge) must have a 'PowerRailIndicator' child node"
	)
	if indicator != null:
		_check(indicator is MeshInstance3D, "PowerRailIndicator must be a MeshInstance3D")

	root.free()


## Non-ubiquitous edge STILL produces a line mesh — normal rendering unchanged.
## Spec: "the human can toggle ubiquitous edges on if needed"
## The normal svc_a→svc_b edge is drawn regardless of the ubiquitous edge.
func test_non_ubiquitous_edge_still_drawn() -> void:
	var root := Main.new()
	root.build_from_graph(_make_power_rail_fixture())

	# At least one visible "EdgeLine" child must exist (from the normal cross_context edge).
	# The implementation uses CylinderMesh-based bodies named "EdgeLine" (not ImmediateMesh),
	# so we check by name and visibility rather than mesh type.
	var has_visible_line: bool = false
	for child: Node in root.get_children():
		if child.name == "EdgeLine" and (child as Node3D).visible:
			has_visible_line = true
			break

	_check(has_visible_line, "Normal (non-ubiquitous) edge svc_a→svc_b must produce a visible edge body")

	root.free()


## Source node without ubiquitous outgoing edges does NOT get a rail indicator.
## Spec: indicator is only added when the node has suppressed dependencies.
func test_non_ubiquitous_source_has_no_rail_indicator() -> void:
	var root := Main.new()
	root.build_from_graph(_make_power_rail_fixture())

	var anchors: Dictionary = root.get("_anchors")
	# svc_b has no ubiquitous outgoing edges — it should not have a rail indicator.
	var svc_b_anchor: Node3D = anchors.get("svc_b")
	_check(svc_b_anchor != null, "svc_b anchor must exist")
	if svc_b_anchor == null:
		root.free()
		return

	var indicator: Node = _find_child_by_name(svc_b_anchor, "PowerRailIndicator")
	_check(
		indicator == null,
		"svc_b (no ubiquitous outgoing edges) must NOT have a PowerRailIndicator"
	)

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Landmark Sources — bridge and entry-point
# Spec: visual-primitives.spec.md § Landmark Primitive / Landmark sources
# "Landmarks are derived from: hubs (high in-degree), bridges (high
#  betweenness centrality), entry points (no in-edges from application code)"
# ---------------------------------------------------------------------------

## A fixture with one bridge node (is_bridge=true) and two regular bounded contexts.
## The bridge node connects them structurally and must be treated as a Landmark.
func _make_bridge_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx_a",
				"name": "ContextA",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -10.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				"is_bridge": true,
				"is_hub": false,
				"in_degree": 1,
			},
			{
				"id": "ctx_b",
				"name": "ContextB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 10.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				"is_bridge": false,
				"is_hub": false,
				"in_degree": 1,
			},
		],
		"edges": [],
		"metadata": {},
	}


## A fixture with one entry-point node (in_degree=0, no parent) and a regular node.
## Entry points have no in-edges from application code; they are Landmarks.
func _make_entry_point_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "main_api",
				"name": "MainAPI",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.5,
				"is_bridge": false,
				"is_hub": false,
				"in_degree": 0,
			},
			{
				"id": "downstream",
				"name": "Downstream",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 15.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				"is_bridge": false,
				"is_hub": false,
				"in_degree": 1,
			},
		],
		"edges": [],
		"metadata": {},
	}


## THEN bridge node is NOT in LOD entries — it persists at all zoom levels.
## Spec: bridge → high betweenness centrality → Landmark → always visible.
## Implemented by: main.gd → _create_volume() when is_bridge=true
func test_bridge_node_not_registered_in_lod_entries() -> void:
	var root := Main.new()
	root.build_from_graph(_make_bridge_fixture())
	var lod_entries: Array = root.get("_lod_node_entries")
	var anchors: Dictionary = root.get("_anchors")

	var bridge_anchor: Node3D = anchors.get("ctx_a")
	_check(bridge_anchor != null, "ctx_a (bridge) anchor must exist after build_from_graph")
	if bridge_anchor == null:
		root.free()
		return

	var bridge_in_lod: bool = false
	for entry: Dictionary in lod_entries:
		if (entry["anchor"] as Node3D) == bridge_anchor:
			bridge_in_lod = true
			break
	_check(
		not bridge_in_lod,
		"Bridge node (is_bridge=true) must NOT be in LOD entries — it is a Landmark (always visible)"
	)

	root.free()


## THEN entry-point node is NOT in LOD entries — it persists at all zoom levels.
## Spec: entry point (no in-edges from application code) → Landmark → always visible.
## Implemented by: main.gd → _create_volume() when in_degree=0 AND parent=null
func test_entry_point_node_not_registered_in_lod_entries() -> void:
	var root := Main.new()
	root.build_from_graph(_make_entry_point_fixture())
	var lod_entries: Array = root.get("_lod_node_entries")
	var anchors: Dictionary = root.get("_anchors")

	var ep_anchor: Node3D = anchors.get("main_api")
	_check(ep_anchor != null, "main_api (entry point) anchor must exist after build_from_graph")
	if ep_anchor == null:
		root.free()
		return

	var ep_in_lod: bool = false
	for entry: Dictionary in lod_entries:
		if (entry["anchor"] as Node3D) == ep_anchor:
			ep_in_lod = true
			break
	_check(
		not ep_in_lod,
		"Entry-point node (in_degree=0, no parent) must NOT be in LOD entries — it is a Landmark"
	)

	root.free()


## Non-bridge, non-hub, non-entry-point nodes remain in LOD entries (can be hidden).
## Ensures the Landmark promotion doesn't inadvertently affect all nodes.
func test_regular_node_still_in_lod_entries() -> void:
	var root := Main.new()
	root.build_from_graph(_make_bridge_fixture())
	var lod_entries: Array = root.get("_lod_node_entries")
	var anchors: Dictionary = root.get("_anchors")

	# ctx_b: is_bridge=false, is_hub=false, in_degree=1 → NOT a landmark → in LOD
	var regular_anchor: Node3D = anchors.get("ctx_b")
	_check(regular_anchor != null, "ctx_b (regular node) anchor must exist")
	if regular_anchor == null:
		root.free()
		return

	var regular_in_lod: bool = false
	for entry: Dictionary in lod_entries:
		if (entry["anchor"] as Node3D) == regular_anchor:
			regular_in_lod = true
			break
	_check(
		regular_in_lod,
		"Regular node (not bridge/hub/entry-point) MUST be in LOD entries (can be hidden by LOD)"
	)

	root.free()


# ---------------------------------------------------------------------------
# task-075 additions: Badge, Landmark, Power Rail via VisualPrimitives
# ---------------------------------------------------------------------------

## Minimal node_data dict for a module node with badges.
func _make_badge_node_data(badge_list: Array) -> Dictionary:
	return {
		"id": "test.module",
		"name": "TestModule",
		"type": "module",
		"parent": "test",
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 2.0,
		"badges": badge_list,
		"is_landmark": false,
		"has_ubiquitous_dep": false,
	}


## Minimal node_data dict for a landmark node.
func _make_landmark_node_data() -> Dictionary:
	return {
		"id": "hub.module",
		"name": "HubModule",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 3.0,
		"badges": [],
		"is_landmark": true,
		"has_ubiquitous_dep": false,
	}


## Minimal node_data dict for a power rail node.
func _make_power_rail_node_data() -> Dictionary:
	return {
		"id": "consumer.module",
		"name": "ConsumerModule",
		"type": "module",
		"parent": "consumer",
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 2.0,
		"badges": [],
		"is_landmark": false,
		"has_ubiquitous_dep": true,
	}


## Create a fresh Node3D anchor for attaching primitives.
func _make_anchor() -> Node3D:
	return Node3D.new()


# ---------------------------------------------------------------------------
# Requirement: Badge Primitive
# Spec: visual-primitives.spec.md § Requirement: Badge Primitive
# THEN the Node displays a small glyph indicating the aspect
# AND the Badge is positioned consistently across all Nodes
# AND all Badges are visible, arranged in a consistent order
# ---------------------------------------------------------------------------


func test_single_badge_creates_mesh_child() -> void:
	## GIVEN a node with one badge
	## WHEN attach_primitives is called
	## THEN a MeshInstance3D child is added to the anchor
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data(["pure"])

	_vp.attach_primitives(node_data, anchor, 2.0)

	# Find any MeshInstance3D child (the badge sphere).
	var found_badge: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Badge_"):
			found_badge = true
			break

	_check(found_badge, "Single badge must add a MeshInstance3D child named 'Badge_pure'")


func test_multiple_badges_all_rendered() -> void:
	## GIVEN a node with three badges (io, async, error_handling)
	## WHEN attach_primitives is called
	## THEN three MeshInstance3D badge children are added
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var badges: Array = ["io", "async", "error_handling"]
	var node_data: Dictionary = _make_badge_node_data(badges)

	_vp.attach_primitives(node_data, anchor, 2.0)

	var badge_count: int = 0
	for child in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Badge_"):
			badge_count += 1

	_check(
		badge_count == 3,
		"Three badges must produce three Badge_ children; got %d" % badge_count
	)


func test_badge_positions_are_distinct() -> void:
	## GIVEN two badges
	## WHEN attach_primitives is called
	## THEN the two badge children have different X positions (consistent order)
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data(["pure", "io"])

	_vp.attach_primitives(node_data, anchor, 2.0)

	var badge_positions: Array = []
	for child in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Badge_"):
			badge_positions.append((child as MeshInstance3D).position)

	_check(badge_positions.size() == 2, "Expected 2 badge positions; got %d" % badge_positions.size())
	if badge_positions.size() == 2:
		var p0: Vector3 = badge_positions[0]
		var p1: Vector3 = badge_positions[1]
		_check(
			abs(p0.x - p1.x) > 0.01,
			"Two badges must have distinct X positions; both at x=%.3f" % p0.x
		)


func test_badge_y_position_above_node() -> void:
	## GIVEN a node with size=2.0 and a 'pure' badge
	## WHEN attach_primitives is called
	## THEN the badge mesh is positioned above Y=0 (above the node base)
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data(["pure"])

	_vp.attach_primitives(node_data, anchor, 2.0)

	var badge_y: float = 0.0
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Badge_"):
			badge_y = (child as MeshInstance3D).position.y
			found = true
			break

	_check(found, "Badge child must exist")
	if found:
		_check(
			badge_y > 0.0,
			"Badge Y position must be above 0.0 (above node base); got %.3f" % badge_y
		)


func test_badge_mesh_is_sphere() -> void:
	## GIVEN a node with a badge
	## WHEN attach_primitives is called
	## THEN the badge MeshInstance3D uses a SphereMesh
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data(["io"])

	_vp.attach_primitives(node_data, anchor, 2.0)

	var found_sphere: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Badge_"):
			var mi: MeshInstance3D = child as MeshInstance3D
			found_sphere = mi.mesh is SphereMesh
			break

	_check(found_sphere, "Badge mesh must be a SphereMesh")


func test_no_badges_no_badge_children() -> void:
	## GIVEN a node with empty badges array
	## WHEN attach_primitives is called
	## THEN no Badge_ children are added
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data([])

	_vp.attach_primitives(node_data, anchor, 2.0)

	for child in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Badge_"):
			_check(false, "No badges → no Badge_ children expected")
			return


func test_badge_vocabulary_pure() -> void:
	## The 'pure' badge type must render without error.
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["pure"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_pure":
			found = true
	_check(found, "'pure' badge must create a Badge_pure child")


func test_badge_vocabulary_io() -> void:
	## The 'io' badge type must render without error.
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["io"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_io":
			found = true
	_check(found, "'io' badge must create a Badge_io child")


func test_badge_vocabulary_async() -> void:
	## The 'async' badge type must render without error.
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["async"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_async":
			found = true
	_check(found, "'async' badge must create a Badge_async child")


func test_badge_vocabulary_test() -> void:
	## The 'test' badge type must render without error.
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["test"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_test":
			found = true
	_check(found, "'test' badge must create a Badge_test child")


func test_badge_vocabulary_stateful() -> void:
	## The 'stateful' badge type must render without error and create a Badge_stateful child.
	## spec §Scenario: Badge vocabulary — "at minimum: ... stateful ..."
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["stateful"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_stateful":
			found = true
	_check(found, "'stateful' badge must create a Badge_stateful child")


func test_badge_vocabulary_deprecated() -> void:
	## The 'deprecated' badge type must render without error and create a Badge_deprecated child.
	## spec §Scenario: Badge vocabulary — "at minimum: ... deprecated"
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["deprecated"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_deprecated":
			found = true
	_check(found, "'deprecated' badge must create a Badge_deprecated child")


func test_badge_vocabulary_error_handling() -> void:
	## The 'error_handling' badge type must render without error and create a Badge_error_handling child.
	## spec §Scenario: Badge vocabulary — "at minimum: ... error_handling ..."
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["error_handling"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_error_handling":
			found = true
	_check(found, "'error_handling' badge must create a Badge_error_handling child")


func test_badge_vocabulary_entry_point() -> void:
	## The 'entry_point' badge type must render without error and create a Badge_entry_point child.
	## spec §Scenario: Badge vocabulary — "at minimum: ... entry_point ..."
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	_vp.attach_primitives(_make_badge_node_data(["entry_point"]), anchor, 1.5)
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "Badge_entry_point":
			found = true
	_check(found, "'entry_point' badge must create a Badge_entry_point child")


# ---------------------------------------------------------------------------
# Requirement: Landmark Primitive
# Spec: visual-primitives.spec.md § Requirement: Landmark Primitive
# THEN it is visible at every zoom level, even when surrounding Nodes are hidden
# AND it has a distinctive visual treatment (larger, brighter, or marked with a glyph)
# ---------------------------------------------------------------------------


func test_landmark_applies_scale_to_anchor() -> void:
	## GIVEN a node with is_landmark=True
	## WHEN attach_primitives is called
	## THEN the anchor scale is greater than Vector3.ONE (larger visual treatment)
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_landmark_node_data()

	_vp.attach_primitives(node_data, anchor, 3.0)

	_check(
		anchor.scale.x > 1.0,
		"Landmark anchor scale.x must be > 1.0; got %.3f" % anchor.scale.x
	)
	_check(
		anchor.scale.y > 1.0,
		"Landmark anchor scale.y must be > 1.0; got %.3f" % anchor.scale.y
	)
	_check(
		anchor.scale.z > 1.0,
		"Landmark anchor scale.z must be > 1.0; got %.3f" % anchor.scale.z
	)


func test_landmark_adds_ring_child() -> void:
	## GIVEN a landmark node
	## WHEN attach_primitives is called
	## THEN a 'LandmarkRing' MeshInstance3D child is added
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_landmark_node_data()

	_vp.attach_primitives(node_data, anchor, 3.0)

	var found_ring: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "LandmarkRing":
			found_ring = true
			break

	_check(found_ring, "Landmark node must have a 'LandmarkRing' MeshInstance3D child")


func test_landmark_ring_uses_torus_mesh() -> void:
	## GIVEN a landmark node
	## WHEN attach_primitives is called
	## THEN the LandmarkRing uses a TorusMesh
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_landmark_node_data()

	_vp.attach_primitives(node_data, anchor, 3.0)

	var found_torus: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "LandmarkRing":
			found_torus = (child as MeshInstance3D).mesh is TorusMesh
			break

	_check(found_torus, "LandmarkRing must use a TorusMesh")


func test_non_landmark_has_no_scale_boost() -> void:
	## GIVEN a node with is_landmark=False
	## WHEN attach_primitives is called
	## THEN the anchor scale remains Vector3.ONE
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data([])  # no landmark flag

	_vp.attach_primitives(node_data, anchor, 2.0)

	_check(
		anchor.scale.is_equal_approx(Vector3.ONE),
		"Non-landmark anchor must remain scale=Vector3.ONE; got %s" % str(anchor.scale)
	)


func test_non_landmark_has_no_ring() -> void:
	## GIVEN a node without is_landmark flag
	## WHEN attach_primitives is called
	## THEN no LandmarkRing child is added
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data([])

	_vp.attach_primitives(node_data, anchor, 2.0)

	for child in anchor.get_children():
		if str(child.name) == "LandmarkRing":
			_check(false, "Non-landmark node must not have a LandmarkRing child")
			return


# ---------------------------------------------------------------------------
# Requirement: Power Rail Notation
# Spec: visual-primitives.spec.md § Requirement: Power Rail Notation
# THEN each Node that imports logging has a small, consistent indicator
# (e.g. a tiny rail glyph at its base)
# ---------------------------------------------------------------------------


func test_power_rail_disc_added_for_ubiquitous_dep() -> void:
	## GIVEN a node with has_ubiquitous_dep=True
	## WHEN attach_primitives is called
	## THEN a 'PowerRailDisc' MeshInstance3D child is added
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_power_rail_node_data()

	_vp.attach_primitives(node_data, anchor, 2.0)

	var found_rail: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "PowerRailDisc":
			found_rail = true
			break

	_check(
		found_rail,
		"Node with has_ubiquitous_dep must have a 'PowerRailDisc' MeshInstance3D child"
	)


func test_power_rail_disc_is_cylinder_mesh() -> void:
	## GIVEN a node with has_ubiquitous_dep=True
	## WHEN attach_primitives is called
	## THEN the PowerRailDisc uses a CylinderMesh (flat disc shape)
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_power_rail_node_data()

	_vp.attach_primitives(node_data, anchor, 2.0)

	var found_cylinder: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "PowerRailDisc":
			found_cylinder = (child as MeshInstance3D).mesh is CylinderMesh
			break

	_check(found_cylinder, "PowerRailDisc must use a CylinderMesh")


func test_power_rail_disc_position_below_or_at_base() -> void:
	## GIVEN a power rail node
	## WHEN attach_primitives is called
	## THEN the disc is at Y ≤ 0 (at or below the node base)
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_power_rail_node_data()

	_vp.attach_primitives(node_data, anchor, 2.0)

	var disc_y: float = 999.0
	var found: bool = false
	for child in anchor.get_children():
		if child is MeshInstance3D and str((child as MeshInstance3D).name) == "PowerRailDisc":
			disc_y = (child as MeshInstance3D).position.y
			found = true
			break

	_check(found, "PowerRailDisc child must exist")
	if found:
		_check(
			disc_y <= 0.0,
			"PowerRailDisc must be at Y ≤ 0 (at node base); got y=%.3f" % disc_y
		)


func test_no_power_rail_when_flag_absent() -> void:
	## GIVEN a node without has_ubiquitous_dep
	## WHEN attach_primitives is called
	## THEN no PowerRailDisc child is added
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_badge_node_data([])  # no ubiquitous dep

	_vp.attach_primitives(node_data, anchor, 2.0)

	for child in anchor.get_children():
		if str(child.name) == "PowerRailDisc":
			_check(false, "Node without has_ubiquitous_dep must not have PowerRailDisc")
			return


func test_multiple_nodes_consistent_rail_position() -> void:
	## Spec §Scenario: Multiple power rails — indicators are visually consistent.
	## GIVEN two nodes both with has_ubiquitous_dep=True
	## WHEN attach_primitives is called on both
	## THEN both PowerRailDisc children are at the same Y position
	_test_failed = false
	var anchor_a: Node3D = _make_anchor()
	var anchor_b: Node3D = _make_anchor()
	var node_data: Dictionary = _make_power_rail_node_data()

	_vp.attach_primitives(node_data, anchor_a, 2.0)
	_vp.attach_primitives(node_data, anchor_b, 2.0)

	var y_a: float = 999.0
	var y_b: float = 998.0
	for child in anchor_a.get_children():
		if str(child.name) == "PowerRailDisc":
			y_a = (child as MeshInstance3D).position.y
	for child in anchor_b.get_children():
		if str(child.name) == "PowerRailDisc":
			y_b = (child as MeshInstance3D).position.y

	_check(
		abs(y_a - y_b) < 0.001,
		"Power rail discs must be at the same Y on all nodes; got %.3f vs %.3f" % [y_a, y_b]
	)


# ---------------------------------------------------------------------------
# Requirement: Landmark + Badge Composability
# Spec: visual-primitives.spec.md § Requirement: Primitives Compose, Not Interfere
# Simultaneous primitives are independently readable.
# ---------------------------------------------------------------------------


func test_landmark_and_badges_compose() -> void:
	## GIVEN a node that is both a landmark and has badges
	## WHEN attach_primitives is called
	## THEN both the LandmarkRing and Badge_ children are present
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = {
		"id": "hub.module",
		"name": "HubModule",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 3.0,
		"badges": ["entry_point"],
		"is_landmark": true,
		"has_ubiquitous_dep": false,
	}

	_vp.attach_primitives(node_data, anchor, 3.0)

	var found_ring: bool = false
	var found_badge: bool = false
	for child in anchor.get_children():
		if str(child.name) == "LandmarkRing":
			found_ring = true
		if str(child.name).begins_with("Badge_"):
			found_badge = true

	_check(found_ring, "Landmark+Badge node must have LandmarkRing")
	_check(found_badge, "Landmark+Badge node must have a Badge_ child")


func test_all_three_primitives_compose() -> void:
	## GIVEN a node with all three: landmark, badges, power rail
	## WHEN attach_primitives is called
	## THEN all three decorations are present independently
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = {
		"id": "super.hub",
		"name": "SuperHub",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 4.0,
		"badges": ["io", "async"],
		"is_landmark": true,
		"has_ubiquitous_dep": true,
	}

	_vp.attach_primitives(node_data, anchor, 4.0)

	var found_ring: bool = false
	var badge_count: int = 0
	var found_rail: bool = false

	for child in anchor.get_children():
		var child_name: String = str(child.name)
		if child_name == "LandmarkRing":
			found_ring = true
		if child_name.begins_with("Badge_"):
			badge_count += 1
		if child_name == "PowerRailDisc":
			found_rail = true

	_check(found_ring, "All-three node must have LandmarkRing")
	_check(badge_count == 2, "All-three node must have 2 badge children; got %d" % badge_count)
	_check(found_rail, "All-three node must have PowerRailDisc")
	_check(
		anchor.scale.x > 1.0,
		"All-three node landmark scale must be > 1.0; got %.3f" % anchor.scale.x
	)


# ---------------------------------------------------------------------------
# Requirement: Route Primitive
# Spec: visual-primitives.spec.md § Requirement: Route Primitive
#
# Scenario: Request path
#   THEN a Route is rendered as a highlighted, labeled path
#   AND the Route has a name
#   AND each segment of the Route is a sequence of Edges
#   AND non-Route elements are de-emphasized
#
# Scenario: Route classification
#   THEN each Route has a distinct visual treatment (color)
#
# Scenario: Route direction
#   THEN the entry point and terminus of the Route are visually distinct
# ---------------------------------------------------------------------------


func _make_route_fixture() -> Dictionary:
	## Fixture: two nodes connected by one edge, wrapped in one route.
	## Entry: "handler" — Terminus: "service"
	return {
		"nodes": [
			{
				"id": "handler",
				"name": "HTTPHandler",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "service",
				"name": "OrderService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 8.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "db",
				"name": "Database",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 16.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
		],
		"edges": [
			# Route edge (part of the happy-path route)
			{"source": "handler", "target": "service", "type": "cross_context"},
			# Non-route edge
			{"source": "service", "target": "db", "type": "cross_context"},
		],
		"routes": [
			{
				"name": "Order Submission",
				"classification": "happy_path",
				"segments": [
					{"source": "handler", "target": "service"},
				],
			},
		],
		"metadata": {},
	}


func _make_multi_route_fixture() -> Dictionary:
	## Fixture: happy_path and error_path routes.
	return {
		"nodes": [
			{
				"id": "entry",
				"name": "Entry",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "happy_svc",
				"name": "HappyService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 8.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "error_svc",
				"name": "ErrorService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 8.0, "y": 0.0, "z": 8.0},
				"size": 2.0,
			},
		],
		"edges": [
			{"source": "entry", "target": "happy_svc", "type": "cross_context"},
			{"source": "entry", "target": "error_svc", "type": "cross_context"},
		],
		"routes": [
			{
				"name": "Happy Path",
				"classification": "happy_path",
				"segments": [{"source": "entry", "target": "happy_svc"}],
			},
			{
				"name": "Error Path",
				"classification": "error_path",
				"segments": [{"source": "entry", "target": "error_svc"}],
			},
		],
		"metadata": {},
	}


func test_route_creates_highlight_overlay_for_route_segments() -> void:
	## GIVEN a scene graph with a route containing one segment (handler → service)
	## WHEN build_from_graph is called
	## THEN a RouteHighlight MeshInstance3D exists as a scene child for that segment
	## Spec §Scenario: Request path — "a Route is rendered as a highlighted, labeled path"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_route_fixture())

	var found_highlight: bool = false
	for child: Node in root.get_children():
		if str(child.name).begins_with("RouteHighlight_"):
			found_highlight = true
			break

	_check(
		found_highlight,
		"Route segment (handler→service) must create a RouteHighlight_ child on the scene root"
	)


func test_route_has_name_label() -> void:
	## GIVEN a route with name "Order Submission"
	## WHEN build_from_graph is called
	## THEN a Label3D child named "RouteLabel_..." exists
	## AND the label has billboard enabled (BILLBOARD_ENABLED) for readability
	## AND the label has pixel_size > 0.0 for legibility in 3D space
	## Spec §Scenario: Request path — "the Route has a name"
	## Guidelines: "Label3D readability: billboard = BILLBOARD_ENABLED and pixel_size > 0.0"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_route_fixture())

	var found_label: bool = false
	for child: Node in root.get_children():
		if str(child.name).begins_with("RouteLabel_"):
			found_label = true
			_check(
				child is Label3D,
				"RouteLabel_ child must be a Label3D; got %s" % child.get_class()
			)
			if child is Label3D:
				var lbl: Label3D = child as Label3D
				_check(
					lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
					"RouteLabel_ billboard must be BILLBOARD_ENABLED for readability"
				)
				_check(
					lbl.pixel_size > 0.0,
					"RouteLabel_ pixel_size must be > 0.0 for legibility; got %.4f" % lbl.pixel_size
				)
			break

	_check(found_label, "Route must create a RouteLabel_ Label3D child for its name")


func test_route_entry_endpoint_marker_exists() -> void:
	## GIVEN a route from handler → service
	## WHEN build_from_graph is called
	## THEN a RouteEntry_ MeshInstance3D exists at the entry node position
	## Spec §Scenario: Route direction — "entry point … visually distinct (landmark-style)"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_route_fixture())

	var found_entry: bool = false
	for child: Node in root.get_children():
		if str(child.name).begins_with("RouteEntry_"):
			found_entry = true
			_check(
				child is MeshInstance3D,
				"RouteEntry_ must be a MeshInstance3D (sphere marker); got %s" % child.get_class()
			)
			break

	_check(found_entry, "Route entry node must have a RouteEntry_ sphere marker")


func test_route_terminus_endpoint_marker_exists() -> void:
	## GIVEN a route from handler → service
	## WHEN build_from_graph is called
	## THEN a RouteTerminus_ MeshInstance3D exists at the terminus node position
	## Spec §Scenario: Route direction — "terminus of the Route visually distinct (landmark-style)"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_route_fixture())

	var found_terminus: bool = false
	for child: Node in root.get_children():
		if str(child.name).begins_with("RouteTerminus_"):
			found_terminus = true
			_check(
				child is MeshInstance3D,
				"RouteTerminus_ must be a MeshInstance3D (sphere marker); got %s" % child.get_class()
			)
			break

	_check(found_terminus, "Route terminus node must have a RouteTerminus_ sphere marker")


func test_routes_active_flag_set_when_routes_present() -> void:
	## GIVEN a scene graph with routes
	## WHEN build_from_graph is called
	## THEN get_routes_active() returns true
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_route_fixture())

	_check(
		root.get_routes_active(),
		"_routes_active must be true when routes are present in the scene graph"
	)


func test_no_routes_flag_false_when_no_routes() -> void:
	## GIVEN a scene graph with no routes
	## WHEN build_from_graph is called
	## THEN get_routes_active() returns false
	_test_failed = false
	var root := Main.new()
	var fixture: Dictionary = _make_hub_fixture()  # no routes key
	root.build_from_graph(fixture)

	_check(
		not root.get_routes_active(),
		"_routes_active must be false when no routes are in the scene graph"
	)


func test_route_classification_happy_path_uses_green_color() -> void:
	## GIVEN a route with classification="happy_path"
	## WHEN build_from_graph is called
	## THEN the RouteHighlight_ MeshInstance3D has a green-dominant albedo color
	## Spec §Scenario: Route classification — "each Route has a distinct visual treatment (color)"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_route_fixture())  # happy_path route

	var found_green: bool = false
	for child: Node in root.get_children():
		if str(child.name).begins_with("RouteHighlight_"):
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi != null and mi.material_override is StandardMaterial3D:
				var color: Color = (mi.material_override as StandardMaterial3D).albedo_color
				# Green channel must exceed red channel (happy_path = bright green).
				if color.g > color.r:
					found_green = true
			break

	_check(
		found_green,
		"happy_path route highlight must have a green-dominant color (g > r)"
	)


func test_route_classification_error_path_uses_red_color() -> void:
	## GIVEN a route with classification="error_path"
	## WHEN build_from_graph is called
	## THEN the error route RouteHighlight_ has a red-dominant albedo color
	## Spec §Scenario: Route classification — "each Route has a distinct visual treatment (color)"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_multi_route_fixture())

	# Walk all RouteHighlight_ children and find the error path one.
	var found_red: bool = false
	for child: Node in root.get_children():
		if str(child.name).begins_with("RouteHighlight_") and str(child.name).contains("Error"):
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi != null and mi.material_override is StandardMaterial3D:
				var color: Color = (mi.material_override as StandardMaterial3D).albedo_color
				# Red channel must exceed green channel (error_path = bright red).
				if color.r > color.g:
					found_red = true

	_check(
		found_red,
		"error_path route highlight must have a red-dominant color (r > g)"
	)


func test_two_routes_produce_distinct_highlight_colors() -> void:
	## GIVEN two routes (happy_path and error_path)
	## WHEN build_from_graph is called
	## THEN the highlight colors of the two routes differ
	## Spec §Scenario: Route classification — "each Route has a distinct visual treatment"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_multi_route_fixture())

	var colors: Array = []
	for child: Node in root.get_children():
		if str(child.name).begins_with("RouteHighlight_"):
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi != null and mi.material_override is StandardMaterial3D:
				var c: Color = (mi.material_override as StandardMaterial3D).albedo_color
				# Normalize alpha to compare only hue/saturation/value.
				var c_no_alpha := Color(c.r, c.g, c.b, 1.0)
				colors.append(c_no_alpha)

	_check(
		colors.size() >= 2,
		"Multi-route fixture must produce at least 2 RouteHighlight_ children; got %d" % colors.size()
	)

	if colors.size() >= 2:
		_check(
			not colors[0].is_equal_approx(colors[1]),
			"Two different route classifications must produce different highlight colors"
		)


func test_route_visuals_array_has_one_entry_per_route() -> void:
	## GIVEN two routes in the scene graph
	## WHEN build_from_graph is called
	## THEN get_route_visuals() returns an array with 2 entries (one per route)
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_multi_route_fixture())

	var rv: Array = root.get_route_visuals()
	_check(
		rv.size() == 2,
		"get_route_visuals() must have one entry per route; expected 2, got %d" % rv.size()
	)
