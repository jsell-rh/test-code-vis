## Behavioral tests for specs/visualization/spatial-structure.spec.md
## § "Cluster Collapsing" requirement.
##
## Spec: The human MUST be able to collapse a group of tightly-coupled modules
## into a single supernode, reducing visual complexity without losing structural
## information.
##
## Scenarios covered:
##
##   Scenario: Pre-computed cluster suggestions
##     GIVEN the extractor has identified groups of modules with high mutual coupling
##     WHEN the scene graph is loaded
##     THEN suggested clusters are indicated visually (e.g. subtle shared tint)
##     AND the human can accept a suggestion to collapse, or ignore it
##     AND suggestions never auto-collapse — the human always initiates
##
##   Scenario: Collapsing a cluster
##     GIVEN a bounded context with a group of heavily interdependent modules
##     WHEN the human triggers collapse on the group
##     THEN the modules animate together, converging smoothly into a single supernode
##     AND the supernode displays aggregate metrics (total LOC, combined in/out-degree)
##     AND edges that formerly entered or left any member are re-routed to the supernode
##
##   Scenario: Expanding a supernode
##     GIVEN a collapsed supernode
##     WHEN the human triggers expansion
##     THEN the supernode smoothly expands back into its constituent modules
##     AND modules animate outward to their original positions
##     AND edges re-route back to their original endpoints
##
##   Scenario: Nested collapsing (independence)
##     GIVEN a bounded context with multiple suggested clusters
##     WHEN the human collapses one cluster but not another
##     THEN only the selected cluster collapses
##     AND the uncollapsed modules remain in place

extends RefCounted

const MainScript := preload("res://scripts/main.gd")
const ClusterManager := preload("res://scripts/cluster_manager.gd")

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

## A scene graph fixture with two modules in a cluster.
func _make_graph_with_clusters() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "svc",
				"name": "Service",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 12.0,
			},
			{
				"id": "svc.mod_a",
				"name": "ModuleA",
				"type": "module",
				"parent": "svc",
				"position": {"x": -3.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod_b",
				"name": "ModuleB",
				"type": "module",
				"parent": "svc",
				"position": {"x": 3.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod_c",
				"name": "ModuleC",
				"type": "module",
				"parent": "svc",
				"position": {"x": 0.0, "y": 0.0, "z": 5.0},
				"size": 2.5,
			},
		],
		"edges": [
			{"source": "svc.mod_a", "target": "svc.mod_b", "type": "internal"},
			{"source": "svc.mod_b", "target": "svc.mod_a", "type": "internal"},
		],
		"clusters": [
			{
				"id": "svc:cluster_0",
				"members": ["svc.mod_a", "svc.mod_b"],
				"context": "svc",
				"aggregate_metrics": {
					"total_loc": 250,
					"in_degree": 1,
					"out_degree": 0,
				},
			},
		],
	}


## A fixture with two distinct clusters.
func _make_graph_two_clusters() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "svc",
				"name": "Service",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 15.0,
			},
			{
				"id": "svc.mod_a",
				"name": "ModuleA",
				"type": "module",
				"parent": "svc",
				"position": {"x": -5.0, "y": 0.0, "z": -5.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod_b",
				"name": "ModuleB",
				"type": "module",
				"parent": "svc",
				"position": {"x": -3.0, "y": 0.0, "z": -5.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod_c",
				"name": "ModuleC",
				"type": "module",
				"parent": "svc",
				"position": {"x": 3.0, "y": 0.0, "z": 5.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod_d",
				"name": "ModuleD",
				"type": "module",
				"parent": "svc",
				"position": {"x": 5.0, "y": 0.0, "z": 5.0},
				"size": 3.0,
			},
		],
		"edges": [
			{"source": "svc.mod_a", "target": "svc.mod_b", "type": "internal"},
			{"source": "svc.mod_c", "target": "svc.mod_d", "type": "internal"},
		],
		"clusters": [
			{
				"id": "svc:cluster_0",
				"members": ["svc.mod_a", "svc.mod_b"],
				"context": "svc",
				"aggregate_metrics": {"total_loc": 100, "in_degree": 0, "out_degree": 1},
			},
			{
				"id": "svc:cluster_1",
				"members": ["svc.mod_c", "svc.mod_d"],
				"context": "svc",
				"aggregate_metrics": {"total_loc": 80, "in_degree": 2, "out_degree": 0},
			},
		],
	}


# ---------------------------------------------------------------------------
# Scenario: Pre-computed cluster suggestions
# THEN suggested clusters are indicated visually (subtle shared tint)
# ---------------------------------------------------------------------------

## Cluster hint produces a MeshInstance3D child named "ClusterHint_<id>" on each member.
## Implemented by: cluster_manager.gd → apply_cluster_hints()
##   adds BoxMesh with translucent coloured material to each member anchor
func test_cluster_hint_adds_child_to_member_anchors() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var anchors: Dictionary = main_node.get("_anchors")

	# After build_from_graph, cluster hints should be applied to mod_a and mod_b.
	var mod_a_anchor: Node3D = anchors.get("svc.mod_a")
	var mod_b_anchor: Node3D = anchors.get("svc.mod_b")
	_check(mod_a_anchor != null, "svc.mod_a anchor must exist")
	_check(mod_b_anchor != null, "svc.mod_b anchor must exist")

	if mod_a_anchor == null or mod_b_anchor == null:
		return

	# Look for the cluster hint child (MeshInstance3D named ClusterHint_*).
	var hint_a: bool = false
	for child: Node in mod_a_anchor.get_children():
		if child.name.begins_with("ClusterHint_"):
			hint_a = true
			break
	_check(hint_a, "svc.mod_a must have a ClusterHint_* child after build_from_graph")

	var hint_b: bool = false
	for child: Node in mod_b_anchor.get_children():
		if child.name.begins_with("ClusterHint_"):
			hint_b = true
			break
	_check(hint_b, "svc.mod_b must have a ClusterHint_* child after build_from_graph")


## Module that is NOT in any cluster must NOT receive a cluster hint.
## Spec: "the human can accept a suggestion to collapse, or ignore it"
##       (non-cluster modules are visually unchanged)
func test_non_cluster_member_has_no_cluster_hint() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var anchors: Dictionary = main_node.get("_anchors")

	# svc.mod_c is not in any cluster in the fixture.
	var mod_c_anchor: Node3D = anchors.get("svc.mod_c")
	_check(mod_c_anchor != null, "svc.mod_c anchor must exist")
	if mod_c_anchor == null:
		return

	var has_hint: bool = false
	for child: Node in mod_c_anchor.get_children():
		if child.name.begins_with("ClusterHint_"):
			has_hint = true
			break
	_check(not has_hint,
		"svc.mod_c (not in any cluster) must NOT have a ClusterHint_* child")


## Cluster hint material is translucent (alpha < 1.0).
## Spec: "subtle shared tint" — the hint must not dominate the view.
func test_cluster_hint_material_is_translucent() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var anchors: Dictionary = main_node.get("_anchors")

	var mod_a_anchor: Node3D = anchors.get("svc.mod_a")
	if mod_a_anchor == null:
		return

	var hint_mesh: MeshInstance3D = null
	for child: Node in mod_a_anchor.get_children():
		if child.name.begins_with("ClusterHint_") and child is MeshInstance3D:
			hint_mesh = child as MeshInstance3D
			break
	_check(hint_mesh != null, "ClusterHint child must be a MeshInstance3D")
	if hint_mesh == null:
		return

	var mat := hint_mesh.material_override as StandardMaterial3D
	_check(mat != null, "ClusterHint material must be StandardMaterial3D")
	if mat == null:
		return
	_check(mat.albedo_color.a < 1.0,
		"ClusterHint material must be translucent (alpha < 1.0) — spec: 'subtle shared tint'")


## Suggestions never auto-collapse: members remain visible after build_from_graph.
## Spec: "suggestions never auto-collapse — the human always initiates"
func test_cluster_members_remain_visible_after_hint_applied() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var anchors: Dictionary = main_node.get("_anchors")

	var mod_a_anchor: Node3D = anchors.get("svc.mod_a")
	var mod_b_anchor: Node3D = anchors.get("svc.mod_b")
	if mod_a_anchor == null or mod_b_anchor == null:
		return

	# Members must not be hidden by hint application.
	_check(mod_a_anchor.visible,
		"svc.mod_a must remain visible after cluster hints are applied (no auto-collapse)")
	_check(mod_b_anchor.visible,
		"svc.mod_b must remain visible after cluster hints are applied (no auto-collapse)")


# ---------------------------------------------------------------------------
# Scenario: Collapsing a cluster
# WHEN the human triggers collapse on the group
# THEN the modules animate together, converging into a single supernode
# AND the supernode displays aggregate metrics
# ---------------------------------------------------------------------------

## Collapsing a cluster creates a supernode Node3D in the scene.
## Implemented by: main.gd → collapse_cluster() → cluster_manager.gd → collapse_cluster()
func test_collapse_creates_supernode() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())

	var supernode: Node3D = main_node.call("collapse_cluster", "svc:cluster_0")
	_check(supernode != null,
		"collapse_cluster() must return a non-null supernode Node3D")


## The supernode has a MeshInstance3D child (the visual representation).
## Spec: "modules animate together, converging smoothly into a single supernode"
func test_supernode_has_mesh_instance() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var supernode: Node3D = main_node.call("collapse_cluster", "svc:cluster_0")
	if supernode == null:
		return

	var has_mesh: bool = false
	for child: Node in supernode.get_children():
		if child is MeshInstance3D:
			has_mesh = true
			break
	_check(has_mesh, "Supernode must have a MeshInstance3D child (visual representation)")


## The supernode has a Label3D child displaying aggregate metrics.
## Spec: "the supernode displays aggregate metrics (total LOC, combined in-degree,
##        combined out-degree)"
func test_supernode_label_contains_aggregate_metrics() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var supernode: Node3D = main_node.call("collapse_cluster", "svc:cluster_0")
	if supernode == null:
		return

	var label: Label3D = null
	for child: Node in supernode.get_children():
		if child is Label3D:
			label = child as Label3D
			break
	_check(label != null, "Supernode must have a Label3D child for aggregate metrics")
	if label == null:
		return

	# The label text must reference the aggregate metrics from the fixture:
	# total_loc=250, in_degree=1, out_degree=0.
	var text: String = label.text
	_check(text.contains("250") or text.contains("LOC"),
		"Supernode label must contain total LOC metric (250 in fixture)")


## Supernode Label3D must use billboard mode and positive pixel_size for legibility.
## Spec: labels must be readable at current zoom level.
func test_supernode_label_billboard_and_pixel_size() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var supernode: Node3D = main_node.call("collapse_cluster", "svc:cluster_0")
	if supernode == null:
		return

	var label: Label3D = null
	for child: Node in supernode.get_children():
		if child is Label3D:
			label = child as Label3D
			break
	if label == null:
		return

	# Billboard mode makes the label always face the camera — required for readability.
	_check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		"Supernode Label3D must use BILLBOARD_ENABLED so it faces the camera")
	# pixel_size must be > 0 for the label to be visible at all.
	_check(label.pixel_size > 0.0,
		"Supernode Label3D must have pixel_size > 0.0 for legibility")


## After collapsing, is_cluster_collapsed() returns true.
## Implements the state-tracking requirement (idempotent collapse guard).
func test_collapse_state_is_tracked() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())

	# Before collapse: not collapsed.
	var before: bool = main_node.call("is_cluster_collapsed", "svc:cluster_0")
	_check(not before,
		"is_cluster_collapsed() must return false before collapse is triggered")

	main_node.call("collapse_cluster", "svc:cluster_0")

	# After collapse: collapsed.
	var after: bool = main_node.call("is_cluster_collapsed", "svc:cluster_0")
	_check(after,
		"is_cluster_collapsed() must return true after collapse_cluster() is called")


## Collapsing an unknown cluster_id returns null gracefully.
func test_collapse_unknown_cluster_returns_null() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())
	var result: Node3D = main_node.call("collapse_cluster", "nonexistent:cluster")
	_check(result == null,
		"collapse_cluster() on unknown id must return null without error")


# ---------------------------------------------------------------------------
# Scenario: Expanding a supernode
# GIVEN a collapsed supernode
# WHEN the human triggers expansion
# THEN the supernode smoothly expands back into its constituent modules
# ---------------------------------------------------------------------------

## Expanding a collapsed cluster makes member anchors visible again.
## Spec: "the supernode smoothly expands back into its constituent modules"
func test_expand_restores_member_visibility() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())

	# Collapse first.
	main_node.call("collapse_cluster", "svc:cluster_0")
	var anchors: Dictionary = main_node.get("_anchors")

	# Expand.
	var expanded: bool = main_node.call("expand_cluster", "svc:cluster_0")
	_check(expanded, "expand_cluster() must return true when cluster was collapsed")

	var mod_a_anchor: Node3D = anchors.get("svc.mod_a")
	var mod_b_anchor: Node3D = anchors.get("svc.mod_b")
	if mod_a_anchor == null or mod_b_anchor == null:
		return

	_check(mod_a_anchor.visible,
		"svc.mod_a must be visible again after expand_cluster()")
	_check(mod_b_anchor.visible,
		"svc.mod_b must be visible again after expand_cluster()")


## After expansion, is_cluster_collapsed() returns false.
func test_expand_updates_collapse_state() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())

	main_node.call("collapse_cluster", "svc:cluster_0")
	main_node.call("expand_cluster", "svc:cluster_0")

	var state: bool = main_node.call("is_cluster_collapsed", "svc:cluster_0")
	_check(not state,
		"is_cluster_collapsed() must return false after expand_cluster()")


## Expanding a non-collapsed cluster returns false gracefully.
func test_expand_not_collapsed_returns_false() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_clusters())

	# Do not collapse first — call expand directly.
	var result: bool = main_node.call("expand_cluster", "svc:cluster_0")
	_check(not result,
		"expand_cluster() on a non-collapsed cluster must return false")


# ---------------------------------------------------------------------------
# Scenario: Nested collapsing — independence of clusters
# WHEN the human collapses one cluster but not another
# THEN only the selected cluster collapses
# AND the uncollapsed modules remain in place
# ---------------------------------------------------------------------------

## Collapsing cluster_0 must not affect modules in cluster_1.
## Spec: "when the human collapses one cluster but not another, only the
##        selected cluster collapses"
func test_independent_cluster_collapse() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_two_clusters())
	var anchors: Dictionary = main_node.get("_anchors")

	# Collapse only cluster_0 (svc.mod_a + svc.mod_b).
	main_node.call("collapse_cluster", "svc:cluster_0")

	# cluster_1 members (svc.mod_c + svc.mod_d) must remain visible.
	var mod_c: Node3D = anchors.get("svc.mod_c")
	var mod_d: Node3D = anchors.get("svc.mod_d")
	_check(mod_c != null, "svc.mod_c must exist")
	_check(mod_d != null, "svc.mod_d must exist")
	if mod_c != null:
		_check(mod_c.visible,
			"svc.mod_c (cluster_1 member) must remain visible when cluster_0 is collapsed")
	if mod_d != null:
		_check(mod_d.visible,
			"svc.mod_d (cluster_1 member) must remain visible when cluster_0 is collapsed")

	# cluster_1 must not be marked as collapsed.
	var c1_collapsed: bool = main_node.call("is_cluster_collapsed", "svc:cluster_1")
	_check(not c1_collapsed,
		"cluster_1 must not be collapsed when only cluster_0 was collapsed")


## Both clusters can be collapsed independently without interfering.
func test_two_clusters_collapse_independently() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_two_clusters())

	var sn0: Node3D = main_node.call("collapse_cluster", "svc:cluster_0")
	var sn1: Node3D = main_node.call("collapse_cluster", "svc:cluster_1")

	_check(sn0 != null, "collapse_cluster(svc:cluster_0) must return a supernode")
	_check(sn1 != null, "collapse_cluster(svc:cluster_1) must return a supernode")
	_check(sn0 != sn1, "Each cluster must produce its own distinct supernode")


# ---------------------------------------------------------------------------
# ClusterManager unit tests (standalone, without main.gd)
# ---------------------------------------------------------------------------

## apply_cluster_hints() via ClusterManager directly — members get tint children.
func test_cluster_manager_apply_hints_direct() -> void:
	var cm := ClusterManager.new()
	var anchor_a := Node3D.new()
	var anchor_b := Node3D.new()
	var anchors_map: Dictionary = {
		"mod_a": anchor_a,
		"mod_b": anchor_b,
	}
	var clusters: Array = [
		{
			"id": "ctx:cluster_0",
			"members": ["mod_a", "mod_b"],
			"context": "ctx",
			"aggregate_metrics": {"total_loc": 50, "in_degree": 0, "out_degree": 1},
		},
	]

	cm.apply_cluster_hints(anchors_map, clusters)

	var hint_a: bool = false
	for child: Node in anchor_a.get_children():
		if child.name.begins_with("ClusterHint_"):
			hint_a = true
			break
	_check(hint_a, "ClusterManager.apply_cluster_hints must add ClusterHint_* to mod_a")

	var hint_b: bool = false
	for child: Node in anchor_b.get_children():
		if child.name.begins_with("ClusterHint_"):
			hint_b = true
			break
	_check(hint_b, "ClusterManager.apply_cluster_hints must add ClusterHint_* to mod_b")

	# Cleanup.
	anchor_a.free()
	anchor_b.free()


## apply_cluster_hints() is idempotent — calling twice does not add duplicate hints.
func test_cluster_manager_hints_idempotent() -> void:
	var cm := ClusterManager.new()
	var anchor := Node3D.new()
	var anchors_map: Dictionary = {"mod_x": anchor}
	var clusters: Array = [
		{
			"id": "ctx:cluster_0",
			"members": ["mod_x"],
			"context": "ctx",
			"aggregate_metrics": {"total_loc": 10, "in_degree": 0, "out_degree": 0},
		},
	]

	cm.apply_cluster_hints(anchors_map, clusters)
	cm.apply_cluster_hints(anchors_map, clusters)

	var hint_count: int = 0
	for child: Node in anchor.get_children():
		if child.name.begins_with("ClusterHint_"):
			hint_count += 1
	_check(hint_count == 1,
		"apply_cluster_hints() must be idempotent — hint added only once (got %d)" % hint_count)

	anchor.free()


## is_collapsed() returns false for an unknown cluster.
func test_cluster_manager_is_collapsed_unknown() -> void:
	var cm := ClusterManager.new()
	_check(not cm.is_collapsed("no_such:cluster"),
		"is_collapsed() must return false for an unknown cluster_id")


## collapse_cluster() returns null when no members are present.
func test_cluster_manager_collapse_empty_members() -> void:
	var cm := ClusterManager.new()
	cm.init({}, null)
	var cluster: Dictionary = {
		"id": "ctx:cluster_0",
		"members": [],
		"context": "ctx",
		"aggregate_metrics": {"total_loc": 0, "in_degree": 0, "out_degree": 0},
	}
	var result: Node3D = cm.collapse_cluster("ctx:cluster_0", cluster)
	_check(result == null,
		"collapse_cluster() with empty members list must return null")


# ---------------------------------------------------------------------------
# Fixtures for edge rerouting tests
# ---------------------------------------------------------------------------

## A scene graph with cluster members AND a cross-boundary edge.
## Cluster: svc.mod_a + svc.mod_b (centroid = (0,0,0) in headless).
## External: svc.mod_c — connected to mod_a by a boundary edge.
## Internal: svc.mod_a → svc.mod_b (internal to the cluster).
##
## In headless mode, anchors use local positions:
##   mod_a.position = (-3,0,0), mod_b.position = (3,0,0)
##   centroid (headless) = avg(-3,3)/avg(0)/avg(0) = (0,0,0)
##
## World positions (_world_positions, svc at origin):
##   svc.mod_a = (-3,0,0), svc.mod_b = (3,0,0), svc.mod_c = (0,0,5)
##
## Boundary edge (svc.mod_c → svc.mod_a):
##   from_pos = (0,0,5), to_pos = (-3,0,0)
##   After collapse: to_pos must change to centroid (0,0,0).
func _make_graph_with_crossing_edges() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "svc",
				"name": "Service",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 12.0,
			},
			{
				"id": "svc.mod_a",
				"name": "ModuleA",
				"type": "module",
				"parent": "svc",
				"position": {"x": -3.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod_b",
				"name": "ModuleB",
				"type": "module",
				"parent": "svc",
				"position": {"x": 3.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod_c",
				"name": "ModuleC",
				"type": "module",
				"parent": "svc",
				"position": {"x": 0.0, "y": 0.0, "z": 5.0},
				"size": 2.5,
			},
		],
		"edges": [
			# Internal edge (both cluster members): must be hidden on collapse.
			{"source": "svc.mod_a", "target": "svc.mod_b", "type": "internal"},
			# Boundary edge (external → cluster member): to_pos must move to centroid.
			{"source": "svc.mod_c", "target": "svc.mod_a", "type": "internal"},
		],
		"clusters": [
			{
				"id": "svc:cluster_0",
				"members": ["svc.mod_a", "svc.mod_b"],
				"context": "svc",
				"aggregate_metrics": {
					"total_loc": 250,
					"in_degree": 1,
					"out_degree": 0,
				},
			},
		],
	}


# ---------------------------------------------------------------------------
# Scenario: Collapsing a cluster — edge re-routing
# THEN edges that formerly entered or left any member are re-routed to the supernode
# ---------------------------------------------------------------------------

## Boundary edge endpoint moves to the cluster centroid after collapse.
## Spec: "edges that formerly entered or left any member of the cluster
##        are re-routed to the supernode"
##
## In headless: centroid = avg of mod_a.position(-3,0,0) and mod_b.position(3,0,0) = (0,0,0).
## The boundary edge (svc.mod_c → svc.mod_a) had to_pos = (-3,0,0);
## after collapse it must be (0,0,0) (the supernode centroid).
func test_collapse_reroutes_boundary_edge_to_centroid() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())

	main_node.call("collapse_cluster", "svc:cluster_0")

	# Inspect the _path_edge_entries to verify rerouting.
	var entries: Array = main_node.get("_path_edge_entries")
	var found_rerouted: bool = false
	for entry: Dictionary in entries:
		if (entry.get("source", "") == "svc.mod_c"
				and entry.get("target", "") == "svc.mod_a"
				and entry.get("entry_type", "") == "line"):
			var to_pos: Vector3 = entry.get("to_pos", Vector3(999, 999, 999))
			# Centroid in headless: avg((-3,0,0),(3,0,0)) = (0,0,0)
			_check(
				to_pos.is_equal_approx(Vector3(0.0, 0.0, 0.0)),
				(
					"Boundary edge to_pos must be rerouted to cluster centroid (0,0,0)"
					+ " after collapse, got %s" % str(to_pos)
				)
			)
			found_rerouted = true
			break
	_check(found_rerouted,
		"Must find a 'line' entry for boundary edge svc.mod_c → svc.mod_a in _path_edge_entries")


## Internal edge (both endpoints in cluster) is hidden after collapse.
## Spec: implied by cluster collapsing — internal structure is abstracted away.
func test_collapse_hides_internal_edges_between_cluster_members() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())

	main_node.call("collapse_cluster", "svc:cluster_0")

	# The internal edge (svc.mod_a → svc.mod_b) must not be visible.
	var entries: Array = main_node.get("_path_edge_entries")
	var found_internal: bool = false
	for entry: Dictionary in entries:
		if (entry.get("source", "") == "svc.mod_a"
				and entry.get("target", "") == "svc.mod_b"
				and entry.get("entry_type", "") == "line"):
			var visual: Node3D = entry.get("visual")
			_check(visual != null,
				"Internal edge must have a visual in _path_edge_entries")
			if visual != null:
				_check(not visual.visible,
					"Internal edge visual must be hidden (visible=false) after cluster collapse")
			found_internal = true
			break
	_check(found_internal,
		"Must find a 'line' entry for internal edge svc.mod_a → svc.mod_b in _path_edge_entries")


# ---------------------------------------------------------------------------
# Scenario: Expanding a supernode — edge restoration
# THEN edges re-route back to their original endpoints with smooth animation
# ---------------------------------------------------------------------------

## After expand, boundary edge endpoint is restored to the original node position.
## Spec: "edges re-route back to their original endpoints with smooth animation"
func test_expand_restores_edge_endpoints() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())

	# Record original to_pos before collapse.
	var entries: Array = main_node.get("_path_edge_entries")
	var orig_to_pos: Vector3 = Vector3(999, 999, 999)
	for entry: Dictionary in entries:
		if (entry.get("source", "") == "svc.mod_c"
				and entry.get("target", "") == "svc.mod_a"
				and entry.get("entry_type", "") == "line"):
			orig_to_pos = entry.get("to_pos", Vector3(999, 999, 999))
			break

	# Collapse then expand.
	main_node.call("collapse_cluster", "svc:cluster_0")
	main_node.call("expand_cluster", "svc:cluster_0")

	# Verify the boundary edge endpoint is restored.
	for entry: Dictionary in entries:
		if (entry.get("source", "") == "svc.mod_c"
				and entry.get("target", "") == "svc.mod_a"
				and entry.get("entry_type", "") == "line"):
			var restored_to_pos: Vector3 = entry.get("to_pos", Vector3(999, 999, 999))
			_check(
				restored_to_pos.is_equal_approx(orig_to_pos),
				(
					"Boundary edge to_pos must be restored to original %s after expand, got %s"
					% [str(orig_to_pos), str(restored_to_pos)]
				)
			)
			break


## After expand, internal edge visibility is restored.
## Spec: members and their internal connections return after expansion.
func test_expand_restores_internal_edge_visibility() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())

	# Collapse then expand.
	main_node.call("collapse_cluster", "svc:cluster_0")
	main_node.call("expand_cluster", "svc:cluster_0")

	var entries: Array = main_node.get("_path_edge_entries")
	var found: bool = false
	for entry: Dictionary in entries:
		if (entry.get("source", "") == "svc.mod_a"
				and entry.get("target", "") == "svc.mod_b"
				and entry.get("entry_type", "") == "line"):
			var visual: Node3D = entry.get("visual")
			if visual != null:
				_check(visual.visible,
					"Internal edge must be visible again after expand_cluster()")
			found = true
			break
	_check(found, "Must find the internal-edge line entry in _path_edge_entries")


# ---------------------------------------------------------------------------
# Scenario: Expanding a supernode — member position restoration
# THEN modules animate outward to their original positions
# ---------------------------------------------------------------------------

## expand_cluster() restores member anchors to their original positions.
## Spec: "modules animate outward to their original positions"
##
## In headless mode Tween is not executed (no scene tree), so positions are
## restored immediately to stored original_positions.
## The test manually moves mod_a to simulate the collapsed state, then
## verifies expand_cluster() restores it using the captured original position.
func test_expand_restores_member_positions() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())
	var anchors: Dictionary = main_node.get("_anchors")

	var mod_a: Node3D = anchors.get("svc.mod_a")
	_check(mod_a != null, "svc.mod_a anchor must exist")
	if mod_a == null:
		return

	# Record the original local position before collapse (-3, 0, 0).
	var orig_pos: Vector3 = mod_a.position

	# Collapse (stores original_positions internally).
	main_node.call("collapse_cluster", "svc:cluster_0")

	# Simulate what the Tween would do during collapse: move anchor to centroid.
	# In headless the Tween is not executed, so we move manually.
	mod_a.position = Vector3(0.0, 0.0, 0.0)  # centroid in this fixture

	# Expand — must restore mod_a.position to orig_pos (-3, 0, 0).
	main_node.call("expand_cluster", "svc:cluster_0")

	_check(
		mod_a.position.is_equal_approx(orig_pos),
		(
			"expand_cluster() must restore svc.mod_a.position to original %s, got %s"
			% [str(orig_pos), str(mod_a.position)]
		)
	)


## collapse_cluster() captures original member positions in _collapse_state.
## This ensures expand_cluster() can always restore positions deterministically,
## even when the Tween is not available (headless) or has already completed.
func test_original_positions_captured_before_collapse() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())
	var anchors: Dictionary = main_node.get("_anchors")

	var mod_a: Node3D = anchors.get("svc.mod_a")
	var mod_b: Node3D = anchors.get("svc.mod_b")
	if mod_a == null or mod_b == null:
		return

	var expected_a: Vector3 = mod_a.position  # (-3, 0, 0)
	var expected_b: Vector3 = mod_b.position  # (3, 0, 0)

	main_node.call("collapse_cluster", "svc:cluster_0")

	# Access collapse state via the cluster_manager.
	var cm: Object = main_node.get("_cluster_manager")
	_check(cm != null, "_cluster_manager must exist on main_node")
	if cm == null:
		return

	var collapse_state: Dictionary = cm.get("_collapse_state")
	_check(collapse_state.has("svc:cluster_0"),
		"_collapse_state must contain an entry for svc:cluster_0 after collapse")
	if not collapse_state.has("svc:cluster_0"):
		return

	var state: Dictionary = collapse_state.get("svc:cluster_0")
	var orig_positions: Dictionary = state.get("original_positions", {})

	_check(orig_positions.has("svc.mod_a"),
		"original_positions must contain svc.mod_a")
	_check(orig_positions.has("svc.mod_b"),
		"original_positions must contain svc.mod_b")

	if orig_positions.has("svc.mod_a"):
		_check(
			(orig_positions["svc.mod_a"] as Vector3).is_equal_approx(expected_a),
			(
				"original_positions[svc.mod_a] must be %s, got %s"
				% [str(expected_a), str(orig_positions["svc.mod_a"])]
			)
		)
	if orig_positions.has("svc.mod_b"):
		_check(
			(orig_positions["svc.mod_b"] as Vector3).is_equal_approx(expected_b),
			(
				"original_positions[svc.mod_b] must be %s, got %s"
				% [str(expected_b), str(orig_positions["svc.mod_b"])]
			)
		)


# ---------------------------------------------------------------------------
# C5/E4: Edge endpoint animation — _edge_animations tracking
# ---------------------------------------------------------------------------

## After collapse, _edge_animations is non-empty (boundary edge queued for lerp).
## Spec: "edge re-routing animates smoothly — endpoints slide to the supernode
##        rather than jumping"
## Proof: the animation queue has an entry for the boundary edge immediately
## after collapse_cluster() returns, before _process() fires.
## (In headless mode _process() is never called by the engine, so the queue
##  persists until explicitly drained or ignored.)
func test_collapse_edge_animation_tracked() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())

	main_node.call("collapse_cluster", "svc:cluster_0")

	# Access _edge_animations through the cluster_manager.
	var cm: Object = main_node.get("_cluster_manager")
	_check(cm != null, "_cluster_manager must exist on main_node")
	if cm == null:
		return

	var edge_anims: Dictionary = cm.get("_edge_animations")
	_check(not edge_anims.is_empty(),
		"_edge_animations must be non-empty after collapse — proves animation was queued"
		+ " (C5: endpoints slide rather than jump)")


## After expand, _edge_animations gains an entry for the boundary edge restore.
## Spec: "edges re-route back to their original endpoints with smooth animation"
## (E4 animation tracking)
func test_expand_edge_animation_tracked() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_graph_with_crossing_edges())

	# Collapse first (this queues collapse animations).
	main_node.call("collapse_cluster", "svc:cluster_0")

	# Drain collapse animations by calling _process on the cluster manager.
	var cm: Object = main_node.get("_cluster_manager")
	_check(cm != null, "_cluster_manager must exist on main_node")
	if cm == null:
		return

	# Advance past the collapse animations (duration = ANIM_DURATION = 0.35s).
	cm.call("_process", 1.0)

	# Expand — should queue restore animations.
	main_node.call("expand_cluster", "svc:cluster_0")

	var edge_anims: Dictionary = cm.get("_edge_animations")
	_check(not edge_anims.is_empty(),
		"_edge_animations must be non-empty after expand — proves animation was queued"
		+ " (E4: endpoints slide back to original positions)")
