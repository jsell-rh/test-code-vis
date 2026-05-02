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
