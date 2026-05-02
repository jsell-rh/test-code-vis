## Behavioral tests for specs/core/visual-primitives.spec.md
##
## Spec: Visual Primitives Specification
## Purpose: Verify that the VisualPrimitives renderer correctly attaches
##   Badge, Landmark, Power Rail, and Port visual elements to scene nodes.
##   Also tests Landmark LOD persistence and Power Rail suppression via Main/LodManager,
##   and Port Primitive LOD visibility at NEAR zoom level only.
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
# Requirement: Port Primitive
# Spec: visual-primitives.spec.md § Requirement: Port Primitive
# GIVEN a module with 4 public functions
# WHEN the Container is rendered
# THEN 4 Ports appear on its membrane
# AND each Port is labeled with the function name
# AND Edges connect to Ports, not directly to the Container body
# ---------------------------------------------------------------------------


## Helper: build node_data with the given symbol list.
func _make_node_with_symbols(symbols: Array) -> Dictionary:
	return {
		"id": "ctx.module",
		"name": "Module",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 4.0,
		"symbols": symbols,
	}


## Helper: build a public function symbol entry.
func _make_public_func(name: String, has_params: bool) -> Dictionary:
	var sig: String = "(x: int)" if has_params else "()"
	return {"name": name, "visibility": "public", "kind": "function", "signature": sig}


## Helper: build a private function symbol entry.
func _make_private_func(name: String) -> Dictionary:
	return {"name": name, "visibility": "private", "kind": "function", "signature": "()"}


## Helper: count Port_ anchor children of an anchor node.
func _count_ports(anchor: Node3D) -> int:
	var count: int = 0
	for child in anchor.get_children():
		if str(child.name).begins_with("Port_"):
			count += 1
	return count


## Helper: find a Port_ anchor by function name.
func _find_port(anchor: Node3D, func_name: String) -> Node3D:
	for child in anchor.get_children():
		if str(child.name) == "Port_" + func_name:
			return child as Node3D
	return null


func test_public_functions_become_ports() -> void:
	## Spec §Scenario: Port placement —
	##   "4 Ports appear on its membrane"
	## GIVEN a Container node with 4 public function symbols
	## WHEN render_ports is called
	## THEN 4 Port_ anchor children are created
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_node_with_symbols([
		_make_public_func("process_order", true),
		_make_public_func("validate_order", true),
		_make_public_func("cancel_order", true),
		_make_public_func("get_status", false),
	])

	var ports: Array = _vp.render_ports(node_data, anchor, 4.0)

	_check(ports.size() == 4, "4 public functions must produce 4 port nodes; got %d" % ports.size())
	_check(_count_ports(anchor) == 4, "anchor must have 4 Port_ children; got %d" % _count_ports(anchor))


func test_private_functions_produce_no_ports() -> void:
	## Spec §Scenario: Port placement — Ports represent PUBLIC interface points.
	## GIVEN a Container node with only private function symbols
	## WHEN render_ports is called
	## THEN no Port_ anchor children are created
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_node_with_symbols([
		_make_private_func("_validate_input"),
		_make_private_func("_internal_check"),
	])

	var ports: Array = _vp.render_ports(node_data, anchor, 4.0)

	_check(ports.size() == 0, "Private-only symbols must produce 0 port nodes; got %d" % ports.size())
	_check(_count_ports(anchor) == 0, "anchor must have 0 Port_ children; got %d" % _count_ports(anchor))


func test_port_is_labeled_with_function_name() -> void:
	## Spec §Scenario: Port placement — "each Port is labeled with the function name"
	## GIVEN a Container with a public function named "process_order"
	## WHEN render_ports is called
	## THEN the Port_process_order anchor has a Label3D child with text "process_order"
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_node_with_symbols([
		_make_public_func("process_order", true),
	])

	_vp.render_ports(node_data, anchor, 4.0)

	var port: Node3D = _find_port(anchor, "process_order")
	_check(port != null, "Port_process_order anchor must exist")
	if port == null:
		return

	var found_label: bool = false
	var label_text: String = ""
	for child in port.get_children():
		if child is Label3D:
			found_label = true
			label_text = str((child as Label3D).text)
			break

	_check(found_label, "Port anchor must have a Label3D child")
	_check(label_text == "process_order", "Port label must show function name; got '%s'" % label_text)


func test_port_label_has_billboard_enabled() -> void:
	## Label3D readability: billboard = BILLBOARD_ENABLED and pixel_size > 0.0
	## GIVEN a Container with a public function
	## WHEN render_ports is called
	## THEN the port's Label3D uses billboard mode for camera-facing legibility
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_node_with_symbols([
		_make_public_func("my_func", false),
	])

	_vp.render_ports(node_data, anchor, 4.0)

	var port: Node3D = _find_port(anchor, "my_func")
	_check(port != null, "Port_my_func must exist")
	if port == null:
		return

	for child in port.get_children():
		if child is Label3D:
			var lbl := child as Label3D
			_check(
				lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
				"Port label must have billboard=BILLBOARD_ENABLED"
			)
			_check(lbl.pixel_size > 0.0, "Port label pixel_size must be > 0")
			return

	_check(false, "No Label3D found on port anchor")


func test_port_has_sphere_mesh() -> void:
	## Spec §Scenario: Port placement — Ports are small visual elements.
	## GIVEN a public function Port
	## WHEN render_ports is called
	## THEN the Port has a PortMesh MeshInstance3D child with a SphereMesh
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_node_with_symbols([
		_make_public_func("some_func", true),
	])

	_vp.render_ports(node_data, anchor, 4.0)

	var port: Node3D = _find_port(anchor, "some_func")
	_check(port != null, "Port anchor must exist")
	if port == null:
		return

	var found_sphere: bool = false
	for child in port.get_children():
		if child is MeshInstance3D and str(child.name) == "PortMesh":
			found_sphere = (child as MeshInstance3D).mesh is SphereMesh
			break

	_check(found_sphere, "Port must have a PortMesh MeshInstance3D with a SphereMesh")


func test_ports_on_membrane_perimeter() -> void:
	## Spec §Scenario: Port placement — "Ports appear on its membrane"
	## The membrane edge of a Container of size S is at distance S/2 from centre in XZ.
	## GIVEN a Container of size 4.0
	## WHEN render_ports is called
	## THEN each port is positioned at XZ distance ≈ 2.0 from the anchor origin
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_size: float = 4.0
	var orbit_r: float = node_size * 0.5  # = 2.0
	var node_data: Dictionary = _make_node_with_symbols([
		_make_public_func("func_a", true),
		_make_public_func("func_b", false),
	])

	_vp.render_ports(node_data, anchor, node_size)

	for child in anchor.get_children():
		if not str(child.name).begins_with("Port_"):
			continue
		var port: Node3D = child as Node3D
		var xz_dist: float = Vector2(port.position.x, port.position.z).length()
		_check(
			absf(xz_dist - orbit_r) < 0.01,
			"Port %s must be at XZ distance %.2f from centre; got %.4f" % [
				port.name, orbit_r, xz_dist
			]
		)


func test_port_positions_are_distinct() -> void:
	## GIVEN a Container with 3 public functions
	## WHEN render_ports is called
	## THEN all 3 Port_ anchors are at distinct XZ positions
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_node_with_symbols([
		_make_public_func("func_a", true),
		_make_public_func("func_b", false),
		_make_public_func("func_c", true),
	])

	_vp.render_ports(node_data, anchor, 4.0)

	var positions: Array = []
	for child in anchor.get_children():
		if str(child.name).begins_with("Port_"):
			positions.append(Vector2((child as Node3D).position.x, (child as Node3D).position.z))

	_check(positions.size() == 3, "Must have 3 port positions; got %d" % positions.size())
	for i: int in range(positions.size()):
		for j: int in range(i + 1, positions.size()):
			var dist: float = (positions[i] - positions[j]).length()
			_check(dist > 0.1, "Port positions must be distinct (i=%d, j=%d dist=%.4f)" % [i, j, dist])


func test_input_port_color_differs_from_output_port() -> void:
	## Spec §Scenario: Port direction —
	##   "input Ports (parameters/dependencies) are visually distinct from
	##    output Ports (return values/emitted events)"
	## GIVEN a public function with parameters (input port) and one without (output port)
	## WHEN render_ports is called
	## THEN the PortMesh materials have different albedo colors
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = _make_node_with_symbols([
		_make_public_func("receive_order", true),   # has params → input port
		_make_public_func("get_total", false),       # no params  → output port
	])

	_vp.render_ports(node_data, anchor, 4.0)

	var input_color: Color = Color(0.0, 0.0, 0.0)
	var output_color: Color = Color(0.0, 0.0, 0.0)
	var found_input: bool = false
	var found_output: bool = false

	for child in anchor.get_children():
		if not str(child.name).begins_with("Port_"):
			continue
		for mesh_child in (child as Node3D).get_children():
			if mesh_child is MeshInstance3D and str(mesh_child.name) == "PortMesh":
				var mat: StandardMaterial3D = (mesh_child as MeshInstance3D).material_override as StandardMaterial3D
				if mat == null:
					continue
				if str(child.name) == "Port_receive_order":
					input_color = mat.albedo_color
					found_input = true
				elif str(child.name) == "Port_get_total":
					output_color = mat.albedo_color
					found_output = true

	_check(found_input, "Port_receive_order must exist")
	_check(found_output, "Port_get_total must exist")
	if found_input and found_output:
		_check(
			input_color != output_color,
			"Input port and output port must have different colors"
		)


func test_no_ports_when_no_symbols() -> void:
	## GIVEN a Container node with no symbols key
	## WHEN render_ports is called
	## THEN no Port_ children are created
	_test_failed = false
	var anchor: Node3D = _make_anchor()
	var node_data: Dictionary = {
		"id": "ctx",
		"name": "Ctx",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 4.0,
		# No "symbols" key at all
	}

	var ports: Array = _vp.render_ports(node_data, anchor, 4.0)

	_check(ports.size() == 0, "No symbols → 0 port nodes; got %d" % ports.size())


func test_port_lod_registration_in_main() -> void:
	## Spec §Scenario: Port visibility at zoom levels —
	##   "Ports are hidden (the Container appears as a solid region)"
	##   "as the human zooms in, Ports fade in on the membrane"
	##
	## Integration test: build a scene via main.gd with a bounded_context node
	## that has public symbols.  After build_from_graph, the LOD manager must
	## have port entries registered (node_type="port").  At FAR distance, ports
	## must be hidden; at NEAR distance, ports must be visible.
	_test_failed = false
	var main_node: Node3D = Main.new()
	var graph: Dictionary = {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
				"symbols": [
					{"name": "process_order", "visibility": "public", "kind": "function", "signature": "(order: Order)"},
					{"name": "cancel_order",  "visibility": "public", "kind": "function", "signature": "(id: int)"},
				],
			},
		],
		"edges": [],
	}

	main_node.build_from_graph(graph)

	# Inspect _lod_node_entries to confirm port entries were registered.
	var lod_entries: Array = main_node.get("_lod_node_entries")
	_check(lod_entries != null, "_lod_node_entries must exist on main node")
	if lod_entries == null:
		return

	var port_entries: Array = []
	for entry: Dictionary in lod_entries:
		if entry.get("node_type", "") == "port":
			port_entries.append(entry)

	_check(
		port_entries.size() == 2,
		"2 public functions must produce 2 LOD port entries; got %d" % port_entries.size()
	)


func test_ports_hidden_at_far_lod() -> void:
	## Spec §Scenario: Port visibility at zoom levels —
	##   "Ports are hidden (the Container appears as a solid region)"
	## GIVEN a Container with public symbols rendered via main.gd
	## WHEN the LOD is set to FAR distance
	## THEN all port nodes are not visible
	_test_failed = false
	var main_node: Node3D = Main.new()
	var graph: Dictionary = {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
				"symbols": [
					{"name": "public_func", "visibility": "public", "kind": "function", "signature": "(x: int)"},
				],
			},
		],
		"edges": [],
	}

	main_node.build_from_graph(graph)

	# Apply FAR LOD manually — camera distance > FAR_THRESHOLD (80.0).
	var lod_entries: Array = main_node.get("_lod_node_entries")
	var edge_entries: Array = main_node.get("_lod_edge_entries")
	_check(lod_entries != null, "_lod_node_entries must exist")
	if lod_entries == null:
		return

	var lod: LodManager = LodManager.new()
	lod.update_lod(lod_entries, edge_entries if edge_entries != null else [], 200.0)

	# All port entries must be invisible after FAR LOD.
	for entry: Dictionary in lod_entries:
		if entry.get("node_type", "") == "port":
			var port_node: Node3D = entry["anchor"] as Node3D
			_check(
				not port_node.visible,
				"Port node must be hidden at FAR distance; visible=%s" % str(port_node.visible)
			)


func test_ports_visible_at_near_lod() -> void:
	## Spec §Scenario: Port visibility at zoom levels —
	##   "as the human zooms in, Ports fade in on the membrane"
	## GIVEN a Container with public symbols rendered via main.gd
	## WHEN the LOD is set to NEAR distance
	## THEN all port nodes are visible
	_test_failed = false
	var main_node: Node3D = Main.new()
	var graph: Dictionary = {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
				"symbols": [
					{"name": "public_func", "visibility": "public", "kind": "function", "signature": "(x: int)"},
				],
			},
		],
		"edges": [],
	}

	main_node.build_from_graph(graph)

	# Apply NEAR LOD — camera distance < NEAR_THRESHOLD (20.0).
	var lod_entries: Array = main_node.get("_lod_node_entries")
	var edge_entries: Array = main_node.get("_lod_edge_entries")
	_check(lod_entries != null, "_lod_node_entries must exist")
	if lod_entries == null:
		return

	var lod: LodManager = LodManager.new()
	lod.update_lod(lod_entries, edge_entries if edge_entries != null else [], 5.0)

	# All port entries must be visible after NEAR LOD.
	for entry: Dictionary in lod_entries:
		if entry.get("node_type", "") == "port":
			var port_node: Node3D = entry["anchor"] as Node3D
			_check(
				port_node.visible,
				"Port node must be visible at NEAR distance; visible=%s" % str(port_node.visible)
			)
