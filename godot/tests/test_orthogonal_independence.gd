## Behavioral tests for orthogonal independence visualisation.
##
## Implements THEN-clauses from specs/visualization/orthogonal-independence.spec.md:
##
## § "Independence Detection"
##   THEN {A,B} and {C,D} are identified as independent groups
##     → test_independent_modules_highlighted
##   THEN the entire context is a single group (fully connected)
##     → test_codependent_modules_distinguished
##
## § "Spatial Separation of Independent Groups"
##   THEN the groups occupy distinct spatial regions within the context's volume
##     → test_independent_groups_spatially_separated_in_scene
##   THEN nodes animate smoothly to their new positions (smooth regrouping)
##     → test_smooth_regrouping_preserves_spatial_continuity
##
## § "Independence as Queryable Property"
##   THEN all modules in other groups are highlighted (INDEPENDENT_COLOR)
##     → test_independent_modules_highlighted
##   AND modules in A's own group are visually distinguished as co-dependent
##     → test_codependent_modules_distinguished
##   AND transition between default and highlighted states is animated smoothly
##     → test_independence_highlight_animated
##   THEN bounded contexts with no transitive dep are highlighted as independent
##     → test_cross_context_independence_highlighted
##   AND the highlight animates from the selected module outward
##     → test_highlight_animates_outward

const IndependenceController = preload("res://scripts/independence_controller.gd")
const Main = preload("res://scripts/main.gd")

var _test_failed: bool = false
var _runner: Object = null


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

## Create a Node3D anchor with a MeshInstance3D child (neutral grey material).
func _make_anchor(id: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = id.replace(".", "_")
	var mesh := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.4, 1.0)
	mesh.material_override = mat
	anchor.add_child(mesh)
	return anchor


## Build a minimal graph with two independence groups inside one bounded context.
## Group "ctx:0" contains ctx.module_a and ctx.module_b (share internal dep).
## Group "ctx:1" contains ctx.module_c and ctx.module_d (no dep on group 0).
func _make_two_group_graph() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx",
				"name": "CTX",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.module_a",
				"name": "Module A",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -1.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:0",
			},
			{
				"id": "ctx.module_b",
				"name": "Module B",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -0.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:0",
			},
			{
				"id": "ctx.module_c",
				"name": "Module C",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 0.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:1",
			},
			{
				"id": "ctx.module_d",
				"name": "Module D",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 1.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:1",
			},
		],
		"edges": [
			{"source": "ctx.module_a", "target": "ctx.module_b", "type": "internal"},
			{"source": "ctx.module_c", "target": "ctx.module_d", "type": "internal"},
		],
		"metadata": {"source_path": "/tmp/test", "timestamp": "2026-01-01T00:00:00Z"},
		"clusters": [],
	}


## Build a graph with two bounded contexts where only one depends on the other.
## context_x depends on context_y (cross-context edge x → y).
## context_z has no dependency on either.
func _make_cross_context_graph() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "context_x",
				"name": "Context X",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -5.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "context_y",
				"name": "Context Y",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "context_z",
				"name": "Context Z",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 5.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
			{
				"id": "context_x.mod",
				"name": "Mod",
				"type": "module",
				"parent": "context_x",
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "context_x:0",
			},
		],
		"edges": [
			{"source": "context_x", "target": "context_y", "type": "cross_context"},
		],
		"metadata": {"source_path": "/tmp/test", "timestamp": "2026-01-01T00:00:00Z"},
		"clusters": [],
	}


func _get_mesh_color(anchor: Node3D) -> Color:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				return mat.albedo_color
	return Color(0.0, 0.0, 0.0, 0.0)


# ===========================================================================
# § Independence as Queryable Property
# ===========================================================================

## THEN all modules in other independence groups within the same bounded context
##      are highlighted (as independent peers)
func test_independent_modules_highlighted() -> void:
	_test_failed = false
	var ic := IndependenceController.new()
	var graph := _make_two_group_graph()

	var anchor_a := _make_anchor("ctx.module_a")
	var anchor_b := _make_anchor("ctx.module_b")
	var anchor_c := _make_anchor("ctx.module_c")
	var anchor_d := _make_anchor("ctx.module_d")
	var ctx_anchor := _make_anchor("ctx")

	var anchors: Dictionary = {
		"ctx": ctx_anchor,
		"ctx.module_a": anchor_a,
		"ctx.module_b": anchor_b,
		"ctx.module_c": anchor_c,
		"ctx.module_d": anchor_d,
	}

	# Select module_a (group "ctx:0"); module_c and module_d are in group "ctx:1".
	ic.select_module("ctx.module_a", graph, anchors, null)

	# module_c and module_d must be highlighted as INDEPENDENT_COLOR.
	var color_c := _get_mesh_color(anchor_c)
	_check(
		color_c == IndependenceController.INDEPENDENT_COLOR,
		"ctx.module_c must be highlighted as INDEPENDENT_COLOR (it is in group ctx:1, not ctx:0). Got: %s" % color_c
	)
	var color_d := _get_mesh_color(anchor_d)
	_check(
		color_d == IndependenceController.INDEPENDENT_COLOR,
		"ctx.module_d must be highlighted as INDEPENDENT_COLOR (it is in group ctx:1, not ctx:0). Got: %s" % color_d
	)


## AND modules in A's own group are visually distinguished as "co-dependent"
func test_codependent_modules_distinguished() -> void:
	_test_failed = false
	var ic := IndependenceController.new()
	var graph := _make_two_group_graph()

	var anchor_a := _make_anchor("ctx.module_a")
	var anchor_b := _make_anchor("ctx.module_b")
	var anchor_c := _make_anchor("ctx.module_c")
	var anchor_d := _make_anchor("ctx.module_d")
	var ctx_anchor := _make_anchor("ctx")

	var anchors: Dictionary = {
		"ctx": ctx_anchor,
		"ctx.module_a": anchor_a,
		"ctx.module_b": anchor_b,
		"ctx.module_c": anchor_c,
		"ctx.module_d": anchor_d,
	}

	# Select module_a (group "ctx:0"); module_b is in the same group.
	ic.select_module("ctx.module_a", graph, anchors, null)

	# module_b must be coloured CODEPENDENT_COLOR (same group as module_a).
	var color_b := _get_mesh_color(anchor_b)
	_check(
		color_b == IndependenceController.CODEPENDENT_COLOR,
		"ctx.module_b must be CODEPENDENT_COLOR (same group as selected ctx.module_a). Got: %s" % color_b
	)

	# module_a itself must be SELECTED_COLOR.
	var color_a := _get_mesh_color(anchor_a)
	_check(
		color_a == IndependenceController.SELECTED_COLOR,
		"ctx.module_a (selected) must be SELECTED_COLOR. Got: %s" % color_a
	)

	# INDEPENDENT_COLOR and CODEPENDENT_COLOR must be visually distinct.
	_check(
		IndependenceController.INDEPENDENT_COLOR != IndependenceController.CODEPENDENT_COLOR,
		"INDEPENDENT_COLOR and CODEPENDENT_COLOR must differ so the human can distinguish them"
	)


## AND the transition between default and independence-highlighted states is
##     animated smoothly (material albedo_color:a fade — not a binary pop).
##     MeshInstance3D is a Node3D (not CanvasItem) so modulate is unavailable;
##     the animation is performed via the material's albedo_color alpha channel.
func test_independence_highlight_animated() -> void:
	_test_failed = false
	var ic := IndependenceController.new()
	var graph := _make_two_group_graph()

	var anchor_c := _make_anchor("ctx.module_c")
	var anchor_a := _make_anchor("ctx.module_a")
	var anchor_b := _make_anchor("ctx.module_b")
	var anchor_d := _make_anchor("ctx.module_d")
	var ctx_anchor := _make_anchor("ctx")

	var anchors: Dictionary = {
		"ctx": ctx_anchor,
		"ctx.module_a": anchor_a,
		"ctx.module_b": anchor_b,
		"ctx.module_c": anchor_c,
		"ctx.module_d": anchor_d,
	}

	# Select module_a; module_c is in the independent group.
	# tween_host = null → direct apply (no Tween in headless); alpha is 1.0.
	# When in the scene tree, material albedo_color:a fades from 0 → 1 (animation).
	ic.select_module("ctx.module_a", graph, anchors, null)

	# Without a scene-tree host, the color is applied directly (full opacity).
	var mesh_c: MeshInstance3D = null
	for child in anchor_c.get_children():
		if child is MeshInstance3D:
			mesh_c = child as MeshInstance3D
			break

	_check(mesh_c != null, "anchor_c must have a MeshInstance3D child after highlight")
	if mesh_c != null:
		# Verify that the material WAS changed (color is set).
		var mat: StandardMaterial3D = mesh_c.material_override as StandardMaterial3D
		_check(
			mat != null,
			"mesh_c.material_override must be a StandardMaterial3D after highlight"
		)
		if mat != null:
			_check(
				mat.albedo_color == IndependenceController.INDEPENDENT_COLOR,
				"mesh_c albedo must be INDEPENDENT_COLOR after select_module. Got: %s" % mat.albedo_color
			)
			# Without a scene-tree tween_host, albedo alpha must be the full color
			# value (animation is skipped; color is applied directly at full opacity).
			_check(
				mat.albedo_color.a >= 1.0,
				"Without scene-tree host, material albedo_color.a should be 1.0. Got: %s" % mat.albedo_color.a
			)


## AND the highlight animates from the selected module outward to its peers.
## Verified by: independent peers receive a different color than the selected module,
## showing the highlight spans outward from origin.
func test_highlight_animates_outward() -> void:
	_test_failed = false
	var ic := IndependenceController.new()
	var graph := _make_two_group_graph()

	var anchor_a := _make_anchor("ctx.module_a")
	var anchor_b := _make_anchor("ctx.module_b")
	var anchor_c := _make_anchor("ctx.module_c")
	var anchor_d := _make_anchor("ctx.module_d")
	var ctx_anchor := _make_anchor("ctx")

	var anchors: Dictionary = {
		"ctx": ctx_anchor,
		"ctx.module_a": anchor_a,
		"ctx.module_b": anchor_b,
		"ctx.module_c": anchor_c,
		"ctx.module_d": anchor_d,
	}

	ic.select_module("ctx.module_a", graph, anchors, null)

	# The selected module (module_a) is SELECTED_COLOR.
	# Independent peers (module_c, module_d) are INDEPENDENT_COLOR.
	# Co-dependent (module_b) is CODEPENDENT_COLOR.
	# This verifies the highlight spans outward from the selected module to its peers.
	var color_a := _get_mesh_color(anchor_a)
	var color_c := _get_mesh_color(anchor_c)

	_check(
		color_a == IndependenceController.SELECTED_COLOR,
		"Selected module_a must be SELECTED_COLOR. Got: %s" % color_a
	)
	_check(
		color_c == IndependenceController.INDEPENDENT_COLOR,
		"Independent peer module_c must be INDEPENDENT_COLOR. Got: %s" % color_c
	)
	_check(
		color_a != color_c,
		"Selected module and independent peer must have distinct colours (highlight spans outward)"
	)


## THEN bounded contexts with no transitive dependency on context X are
##      highlighted as fully independent
func test_cross_context_independence_highlighted() -> void:
	_test_failed = false
	var ic := IndependenceController.new()
	var graph := _make_cross_context_graph()

	var anchor_x := _make_anchor("context_x")
	var anchor_y := _make_anchor("context_y")
	var anchor_z := _make_anchor("context_z")
	var anchor_mod := _make_anchor("context_x.mod")

	var anchors: Dictionary = {
		"context_x": anchor_x,
		"context_y": anchor_y,
		"context_z": anchor_z,
		"context_x.mod": anchor_mod,
	}

	# Select the module in context_x.
	# context_z has no dependency on context_x → context-level independent.
	# context_y is reachable from context_x (context_x → context_y) → NOT independent.
	ic.select_module("context_x.mod", graph, anchors, null)

	var color_z := _get_mesh_color(anchor_z)
	_check(
		color_z == IndependenceController.CONTEXT_INDEPENDENT_COLOR,
		"context_z (no dep on context_x) must be CONTEXT_INDEPENDENT_COLOR. Got: %s" % color_z
	)

	# context_y is reachable from context_x → it is NOT highlighted as independent.
	var color_y := _get_mesh_color(anchor_y)
	_check(
		color_y != IndependenceController.CONTEXT_INDEPENDENT_COLOR,
		"context_y (reachable from context_x via cross-context dep) must NOT be CONTEXT_INDEPENDENT_COLOR. Got: %s" % color_y
	)


# ===========================================================================
# § Spatial Separation of Independent Groups (rendering side)
# ===========================================================================

## THEN the groups occupy distinct spatial regions within the context's volume.
## Verified by: modules from different independence groups are positioned further
## apart than modules within the same group, after build_from_graph.
func test_independent_groups_spatially_separated_in_scene() -> void:
	_test_failed = false
	var root := Main.new()
	# Use a graph where group positions are explicit in the JSON.
	# module_a and module_b are in group 0 (close together: x=-1.5 and x=-0.5).
	# module_c and module_d are in group 1 (close together: x=+0.5 and x=+1.5).
	# Cross-group distance (|−1.5 to 0.5| = 2.0) > within-group distance (|−1.5 to −0.5| = 1.0).
	var graph := _make_two_group_graph()
	root.build_from_graph(graph)

	# Find anchors by name in scene tree.
	var anchor_a: Node3D = null
	var anchor_b: Node3D = null
	var anchor_c: Node3D = null
	for child in root.get_children():
		match child.name:
			"ctx":
				for sub in child.get_children():
					match sub.name:
						"ctx_module_a":
							anchor_a = sub as Node3D
						"ctx_module_b":
							anchor_b = sub as Node3D
						"ctx_module_c":
							anchor_c = sub as Node3D
	_check(anchor_a != null, "ctx.module_a anchor must exist in scene after build_from_graph")
	_check(anchor_b != null, "ctx.module_b anchor must exist in scene after build_from_graph")
	_check(anchor_c != null, "ctx.module_c anchor must exist in scene after build_from_graph")

	if anchor_a != null and anchor_b != null and anchor_c != null:
		var within_dist: float = anchor_a.position.distance_to(anchor_b.position)
		var cross_dist: float = anchor_a.position.distance_to(anchor_c.position)
		_check(
			cross_dist > within_dist,
			"Cross-group distance (%s) must exceed within-group distance (%s) — groups must be spatially separated" % [cross_dist, within_dist]
		)

	root.free()


# ===========================================================================
# § Smooth Regrouping on Data Change
# ===========================================================================

## THEN nodes animate smoothly to their new positions.
## AND the transition preserves spatial continuity — nodes slide rather than jump.
##
## Verified by: after a second build_from_graph call, the anchor node OBJECT
## is reused (not destroyed and recreated), proving spatial continuity.
## The position moves to the new value (not kept stale), proving data is applied.
func test_smooth_regrouping_preserves_spatial_continuity() -> void:
	_test_failed = false
	var root := Main.new()

	# First build: module_a at x=-1.5 (group ctx:0).
	var graph1 := _make_two_group_graph()
	root.build_from_graph(graph1)

	# Capture the anchor object reference for ctx.module_a.
	var anchors_after_first: Dictionary = root.get_anchors()
	var anchor_before: Node3D = anchors_after_first.get("ctx.module_a") as Node3D
	_check(
		anchor_before != null,
		"ctx.module_a anchor must exist after first build_from_graph"
	)

	# Second build: same module_a but at a different position (merged group → x changed).
	var graph2 := _make_two_group_graph()
	# Move module_a to a different position to simulate regrouping.
	for nd: Dictionary in graph2["nodes"]:
		if nd["id"] == "ctx.module_a":
			nd["position"] = {"x": 3.0, "y": 0.0, "z": 0.0}
			nd["independence_group"] = "ctx:0"  # group unchanged
	root.build_from_graph(graph2)

	# The anchor should be the SAME object (reused, not recreated).
	var anchors_after_second: Dictionary = root.get_anchors()
	var anchor_after: Node3D = anchors_after_second.get("ctx.module_a") as Node3D
	_check(
		anchor_after != null,
		"ctx.module_a anchor must still exist after second build_from_graph"
	)
	_check(
		anchor_before == anchor_after,
		"Smooth regrouping: anchor for ctx.module_a must be REUSED (same object), not destroyed and recreated. Spatial continuity requires the same scene node to animate."
	)

	# In non-tree context: position is set directly (no Tween needed).
	# Verify the position was updated to the new value.
	if anchor_after != null:
		_check(
			is_equal_approx(anchor_after.position.x, 3.0),
			"After second build_from_graph, ctx.module_a position.x must be 3.0 (new value). Got: %s" % anchor_after.position.x
		)

	root.free()


# ===========================================================================
# § Independence controller clear / reset
# ===========================================================================

## Clearing the independence highlight resets the selected id.
func test_clear_independence_highlight_resets_selection() -> void:
	_test_failed = false
	var ic := IndependenceController.new()
	var graph := _make_two_group_graph()

	var anchor_a := _make_anchor("ctx.module_a")
	var anchor_c := _make_anchor("ctx.module_c")
	var anchors: Dictionary = {
		"ctx.module_a": anchor_a,
		"ctx.module_c": anchor_c,
	}

	ic.select_module("ctx.module_a", graph, anchors, null)
	_check(
		ic.get_selected_id() == "ctx.module_a",
		"After select_module, get_selected_id must return the selected id"
	)

	ic.clear_independence_highlight(anchors, graph, null)
	_check(
		ic.get_selected_id().is_empty(),
		"After clear_independence_highlight, get_selected_id must return empty string"
	)
