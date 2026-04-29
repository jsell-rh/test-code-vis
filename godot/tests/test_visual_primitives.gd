## Behavioral tests: Visual Primitives (Landmark and Power Rail)
##
## Implements THEN clauses from specs/core/visual-primitives.spec.md:
##
##   Landmark Primitive:
##     GIVEN a module with is_hub=true (highest in-degree)
##     WHEN it is identified as a Landmark
##     THEN it is visible at every zoom level (even at FAR)
##     AND it has a distinctive visual treatment (larger, brighter)
##
##   Power Rail Notation:
##     GIVEN an edge with ubiquitous=true (target is a ubiquitous dependency)
##     WHEN the default view is rendered
##     THEN the edge is NOT drawn
##     AND a small indicator on the source node acknowledges the dependency

extends RefCounted

const Main = preload("res://scripts/main.gd")
const LodManager = preload("res://scripts/lod_manager.gd")

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

	# Count individual (non-aggregate) ImmediateMesh edge lines in the scene root.
	# The fixture has 2 edges: svc_a→svc_b (normal) and svc_a→ubiq_dep (ubiquitous).
	# Only the normal edge should produce an individual line; aggregate edges (named
	# "AggregateEdge_*") are a separate FAR-LOD construct and not counted here.
	var line_count: int = 0
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is ImmediateMesh and not (child.name as String).begins_with("AggregateEdge"):
				line_count += 1

	# Exactly 1 individual line should exist (for the normal cross_context edge).
	# The ubiquitous edge should NOT create an individual line.
	_check(
		line_count == 1,
		"Only 1 individual edge line should be drawn (ubiquitous edge is suppressed); got %d" % line_count
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

	# At least one individual (non-aggregate) ImmediateMesh line must exist (from the normal edge).
	var has_line: bool = false
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is ImmediateMesh and not (child.name as String).begins_with("AggregateEdge"):
				has_line = true
				break

	_check(has_line, "Normal (non-ubiquitous) edge svc_a→svc_b must produce a visible line")

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
