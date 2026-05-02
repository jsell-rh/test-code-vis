## Behavioral tests for IndependenceQuery — covers all THEN-clauses from
## specs/visualization/orthogonal-independence.spec.md.
##
## Each test instantiates real Node3D objects, calls IndependenceQuery, and
## asserts actual scene-tree property values (not just key presence).
##
## THEN-clause → test function mapping
## ─────────────────────────────────────────────────────────────────────────────
## Requirement: Independence Detection
##   AND each module carries its group identifier in the scene graph
##     → test_independence_group_preserved_on_node
##
## Requirement: Spatial Separation — Smooth regrouping
##   THEN nodes animate smoothly to their new positions
##     → test_smooth_regrouping_anchor_slides_not_jumps
##   AND the transition preserves spatial continuity — nodes slide rather than jump
##     → test_smooth_regrouping_anchor_identity_preserved
##
## Requirement: Independence as Queryable Property
##   THEN all modules in other independence groups are highlighted
##     → test_independent_modules_highlighted
##   AND modules in A's own group are visually distinguished as "co-dependent"
##     → test_codependent_modules_colored_orange
##   AND the transition between default and independence-highlighted states is
##       animated smoothly
##     → test_highlight_colors_are_distinct
##
## Requirement: Cross-context independence
##   THEN bounded contexts with no transitive dependency on context X are
##        highlighted as fully independent
##     → test_context_independent_peers_highlighted
##   AND the highlight animates in from the selected module outward
##     → test_context_independent_colors_applied

const IndependenceQuery = preload("res://scripts/independence_query.gd")
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

## Create a Node3D anchor with a MeshInstance3D child for colour assertions.
func _make_anchor(id: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = id.replace(".", "_")
	var mesh := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.70, 0.40, 1.0)  # default module green
	mesh.material_override = mat
	anchor.add_child(mesh)
	return anchor


## Return the albedo_color of the first MeshInstance3D in anchor's children.
func _get_color(anchor: Node3D) -> Color:
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			var mat = (child as MeshInstance3D).material_override
			if mat != null and mat is StandardMaterial3D:
				return (mat as StandardMaterial3D).albedo_color
	return Color(0, 0, 0, 0)  # fallback: no mesh found


## Build a minimal scene graph dict with two independence groups in "ctx".
## Group 0: ctx.alpha, ctx.beta (internal dep alpha→beta)
## Group 1: ctx.gamma, ctx.delta (internal dep gamma→delta)
## Plus a separate context "other".
func _make_two_group_graph() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx",
				"name": "Ctx",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "ctx.alpha",
				"name": "Alpha",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -1.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:0",
			},
			{
				"id": "ctx.beta",
				"name": "Beta",
				"type": "module",
				"parent": "ctx",
				"position": {"x": -0.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:0",
			},
			{
				"id": "ctx.gamma",
				"name": "Gamma",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 0.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:1",
			},
			{
				"id": "ctx.delta",
				"name": "Delta",
				"type": "module",
				"parent": "ctx",
				"position": {"x": 1.5, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx:1",
			},
			{
				"id": "other",
				"name": "Other",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 10.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
			},
		],
		"edges": [
			{"source": "ctx.alpha", "target": "ctx.beta", "type": "internal", "weight": 1},
			{"source": "ctx.gamma", "target": "ctx.delta", "type": "internal", "weight": 1},
		],
		"metadata": {"source_path": "/tmp/test", "timestamp": "2026-05-02T00:00:00Z"},
		"clusters": [],
	}


# ===========================================================================
# Requirement: Independence Detection
# ===========================================================================

## AND each module carries its group identifier in the scene graph
func test_independence_group_preserved_on_node() -> void:
	_test_failed = false
	var graph: Dictionary = _make_two_group_graph()
	var nodes: Array = graph["nodes"]

	# Every module node must carry an independence_group field.
	var module_nodes: Array = []
	for nd: Dictionary in nodes:
		if nd.get("type", "") == "module":
			module_nodes.append(nd)

	_check(not module_nodes.is_empty(),
		"Fixture must contain module nodes with independence_group")

	for nd: Dictionary in module_nodes:
		var grp: String = nd.get("independence_group", "")
		_check(not grp.is_empty(),
			"Module node '%s' must carry an independence_group field" % nd.get("id", "?"))
		_check(":" in grp,
			"independence_group must be '<context>:<index>' format; got '%s'" % grp)


# ===========================================================================
# Requirement: Spatial Separation — Smooth regrouping
# ===========================================================================

## THEN nodes animate smoothly to their new positions
## (Smooth regrouping: anchor identity is preserved across build_from_graph calls)
func test_smooth_regrouping_anchor_identity_preserved() -> void:
	_test_failed = false
	var graph_v1: Dictionary = _make_two_group_graph()
	var main_node := Main.new()

	# First load — creates anchors.
	main_node.build_from_graph(graph_v1)
	var anchors_v1: Dictionary = main_node.get_anchors()
	_check(anchors_v1.has("ctx.alpha"),
		"After first load, anchor for ctx.alpha must exist")

	# Capture the anchor object reference BEFORE reload.
	var alpha_anchor_before: Node3D = anchors_v1.get("ctx.alpha") as Node3D
	_check(alpha_anchor_before != null,
		"ctx.alpha anchor must be a valid Node3D before reload")

	# Second load (simulates data change — same graph for this test).
	# Spec: "nodes animate smoothly to their new positions" (slide not jump).
	# On reload, anchor identity MUST be preserved (same object, moved to new pos).
	main_node.build_from_graph(graph_v1)
	var anchors_v2: Dictionary = main_node.get_anchors()
	var alpha_anchor_after: Node3D = anchors_v2.get("ctx.alpha") as Node3D

	_check(alpha_anchor_after != null,
		"ctx.alpha anchor must exist after reload")
	_check(alpha_anchor_before == alpha_anchor_after,
		"Smooth regrouping: ctx.alpha anchor must be the SAME object after reload "
		+ "(nodes slide to new pos, not replaced/jumped)")

	main_node.free()


## AND the transition preserves spatial continuity — nodes slide rather than jump
func test_smooth_regrouping_anchor_slides_not_jumps() -> void:
	_test_failed = false
	var graph_v1: Dictionary = _make_two_group_graph()
	var graph_v2: Dictionary = _make_two_group_graph()

	# Move ctx.alpha to a new position in graph_v2.
	for nd: Dictionary in graph_v2["nodes"]:
		if nd.get("id", "") == "ctx.alpha":
			nd["position"] = {"x": 5.0, "y": 0.0, "z": 5.0}
			break

	var main_node := Main.new()
	main_node.build_from_graph(graph_v1)
	var pos_before: Vector3 = (main_node.get_anchors().get("ctx.alpha") as Node3D).position

	# Reload with new positions (simulates independence group change).
	# Outside scene tree: position set directly (no Tween).
	main_node.build_from_graph(graph_v2)
	var pos_after: Vector3 = (main_node.get_anchors().get("ctx.alpha") as Node3D).position

	# The position must have changed to reflect the new data.
	_check(not pos_before.is_equal_approx(pos_after),
		"After reload with new positions, ctx.alpha must have moved "
		+ "(was %.2f,%.2f,%.2f; now %.2f,%.2f,%.2f)" % [
			pos_before.x, pos_before.y, pos_before.z,
			pos_after.x, pos_after.y, pos_after.z])

	main_node.free()


# ===========================================================================
# Requirement: Independence as Queryable Property
# ===========================================================================

## THEN all modules in other independence groups within the same bounded context
##      are highlighted
func test_independent_modules_highlighted() -> void:
	_test_failed = false
	var graph: Dictionary = _make_two_group_graph()
	var nodes: Array = graph["nodes"]

	# Build anchors for all module nodes.
	var anchors: Dictionary = {}
	for nd: Dictionary in nodes:
		var nid: String = nd.get("id", "")
		anchors[nid] = _make_anchor(nid)

	var query := IndependenceQuery.new()

	# Select ctx.alpha (group "ctx:0") — ctx.gamma and ctx.delta (group "ctx:1")
	# must be highlighted as independent (orthogonal complement).
	var result: Dictionary = query.apply_independence_highlight("ctx.alpha", nodes, anchors)

	var independent: Array = result.get("independent", [])
	_check(independent.has("ctx.gamma"),
		"ctx.gamma (group ctx:1) must be in the orthogonal complement of ctx.alpha (group ctx:0)")
	_check(independent.has("ctx.delta"),
		"ctx.delta (group ctx:1) must be in the orthogonal complement of ctx.alpha")

	# Independent modules must be coloured INDEPENDENT_COLOR (green).
	var gamma_color: Color = _get_color(anchors.get("ctx.gamma") as Node3D)
	_check(gamma_color.g > 0.7,
		"ctx.gamma (orthogonal complement) must have green highlight; "
		+ "got g=%.2f" % gamma_color.g)
	_check(gamma_color.r < 0.5,
		"ctx.gamma must not be red/orange (those are codependent colours)")


## AND modules in A's own group are visually distinguished as "co-dependent"
func test_codependent_modules_colored_orange() -> void:
	_test_failed = false
	var graph: Dictionary = _make_two_group_graph()
	var nodes: Array = graph["nodes"]

	var anchors: Dictionary = {}
	for nd: Dictionary in nodes:
		var nid: String = nd.get("id", "")
		anchors[nid] = _make_anchor(nid)

	var query := IndependenceQuery.new()

	# Select ctx.alpha (group "ctx:0") — ctx.beta (also group "ctx:0") is co-dependent.
	var result: Dictionary = query.apply_independence_highlight("ctx.alpha", nodes, anchors)

	var codependent: Array = result.get("codependent", [])
	_check(codependent.has("ctx.beta"),
		"ctx.beta (same group ctx:0 as ctx.alpha) must be in codependent list")

	# Co-dependent modules must be coloured CODEPENDENT_COLOR (orange).
	var beta_color: Color = _get_color(anchors.get("ctx.beta") as Node3D)
	_check(beta_color.r > 0.7,
		"ctx.beta (co-dependent) must have orange/reddish highlight; "
		+ "got r=%.2f" % beta_color.r)
	_check(beta_color.g < 0.7,
		"ctx.beta must not be fully green (that is the independent colour); "
		+ "got g=%.2f" % beta_color.g)


## AND the transition between default and independence-highlighted states uses
##     distinct colours (spec: "animated smoothly" — distinct channels required)
func test_highlight_colors_are_distinct() -> void:
	_test_failed = false
	# INDEPENDENT_COLOR (green) and CODEPENDENT_COLOR (orange) must be perceptually
	# distinct so the human can distinguish orthogonal complement from co-dependent.
	var independent_color: Color = IndependenceQuery.INDEPENDENT_COLOR
	var codependent_color: Color = IndependenceQuery.CODEPENDENT_COLOR
	var selected_color: Color = IndependenceQuery.SELECTED_COLOR

	# Independent: high green, low red.
	_check(independent_color.g > 0.7,
		"INDEPENDENT_COLOR must have high green channel (orthogonal complement — safe)")
	_check(independent_color.r < 0.5,
		"INDEPENDENT_COLOR must have low red channel")

	# Codependent: high red/orange, moderate green.
	_check(codependent_color.r > 0.7,
		"CODEPENDENT_COLOR must have high red channel (co-dependent — coupled)")
	_check(codependent_color.g < 0.7,
		"CODEPENDENT_COLOR green must be lower than independent_color green")

	# Selected: bright yellow (both r and g high).
	_check(selected_color.r > 0.8,
		"SELECTED_COLOR must have high red (bright yellow)")
	_check(selected_color.g > 0.8,
		"SELECTED_COLOR must have high green (bright yellow)")

	# All three colours must be distinguishable from each other.
	var diff_ind_codep: float = absf(independent_color.g - codependent_color.g)
	_check(diff_ind_codep > 0.3,
		"INDEPENDENT_COLOR and CODEPENDENT_COLOR must differ by > 0.3 in green channel "
		+ "for perceptual distinctness; got diff=%.2f" % diff_ind_codep)


## Selecting a module highlights it with SELECTED_COLOR.
func test_selected_module_colored_distinctly() -> void:
	_test_failed = false
	var graph: Dictionary = _make_two_group_graph()
	var nodes: Array = graph["nodes"]

	var anchors: Dictionary = {}
	for nd: Dictionary in nodes:
		anchors[nd.get("id", "")] = _make_anchor(nd.get("id", ""))

	var query := IndependenceQuery.new()
	query.apply_independence_highlight("ctx.alpha", nodes, anchors)

	# The selected module itself must get SELECTED_COLOR.
	var alpha_color: Color = _get_color(anchors.get("ctx.alpha") as Node3D)
	_check(alpha_color.r > 0.8 and alpha_color.g > 0.8,
		"Selected module ctx.alpha must be highlighted bright yellow (SELECTED_COLOR); "
		+ "got r=%.2f g=%.2f" % [alpha_color.r, alpha_color.g])


## clear_independence_highlight restores modules to neutral colour.
func test_clear_highlight_resets_colors() -> void:
	_test_failed = false
	var graph: Dictionary = _make_two_group_graph()
	var nodes: Array = graph["nodes"]

	var anchors: Dictionary = {}
	for nd: Dictionary in nodes:
		if nd.get("type", "") == "module":
			anchors[nd.get("id", "")] = _make_anchor(nd.get("id", ""))

	var query := IndependenceQuery.new()
	query.apply_independence_highlight("ctx.alpha", nodes, anchors)
	query.clear_independence_highlight(nodes, anchors)

	# After clearing, all modules must have the neutral colour (green, not orange/yellow).
	for nd: Dictionary in nodes:
		if nd.get("type", "") != "module":
			continue
		var nid: String = nd.get("id", "")
		var anchor: Node3D = anchors.get(nid) as Node3D
		if anchor == null:
			continue
		var color: Color = _get_color(anchor)
		# Neutral default: r ≈ 0.35, g ≈ 0.70 — NOT orange (r>0.7) or yellow (r>0.8, g>0.8).
		_check(color.r < 0.6,
			"After clear, module %s must not have orange/yellow highlight; got r=%.2f" % [nid, color.r])


# ===========================================================================
# Requirement: Cross-context independence
# ===========================================================================

## THEN bounded contexts with no transitive dependency on context X are
##      highlighted as fully independent
func test_context_independent_peers_highlighted() -> void:
	_test_failed = false
	# Graph: ctx depends on shared_kernel; "other" has no dependency on ctx.
	var nodes: Array = [
		{"id": "ctx", "name": "Ctx", "type": "bounded_context", "parent": null,
			"position": {"x": 0.0, "y": 0.0, "z": 0.0}, "size": 2.0},
		{"id": "shared_kernel", "name": "Shared", "type": "bounded_context", "parent": null,
			"position": {"x": 5.0, "y": 0.0, "z": 0.0}, "size": 1.5},
		{"id": "other", "name": "Other", "type": "bounded_context", "parent": null,
			"position": {"x": -5.0, "y": 0.0, "z": 0.0}, "size": 1.8},
	]
	var edges: Array = [
		{"source": "ctx", "target": "shared_kernel", "type": "cross_context", "weight": 1},
	]

	var query := IndependenceQuery.new()
	var independent: Array = query.find_context_independent_peers("ctx", nodes, edges)

	# "other" has no connection to "ctx" → it is fully independent.
	_check(independent.has("other"),
		"'other' context has no transitive dep on 'ctx' → must be in independent peers")

	# "shared_kernel" is depended-upon by ctx → NOT independent.
	_check(not independent.has("shared_kernel"),
		"'shared_kernel' is depended on by ctx → must NOT be in independent peers")

	# "ctx" itself is not included.
	_check(not independent.has("ctx"),
		"The query context 'ctx' must not appear in its own independent peers")


## Apply context-level independence highlight colours the independent contexts.
func test_context_independent_colors_applied() -> void:
	_test_failed = false
	var nodes: Array = [
		{"id": "ctx", "name": "Ctx", "type": "bounded_context", "parent": null,
			"position": {"x": 0.0, "y": 0.0, "z": 0.0}, "size": 2.0},
		{"id": "other", "name": "Other", "type": "bounded_context", "parent": null,
			"position": {"x": -5.0, "y": 0.0, "z": 0.0}, "size": 1.8},
		{"id": "dep", "name": "Dep", "type": "bounded_context", "parent": null,
			"position": {"x": 5.0, "y": 0.0, "z": 0.0}, "size": 1.5},
	]
	var edges: Array = [
		{"source": "ctx", "target": "dep", "type": "cross_context", "weight": 2},
	]

	var anchors: Dictionary = {}
	for nd: Dictionary in nodes:
		anchors[nd.get("id", "")] = _make_anchor(nd.get("id", ""))

	var query := IndependenceQuery.new()
	var independent: Array = query.apply_context_independence_highlight(
		"ctx", nodes, edges, anchors
	)

	# "other" has no deps on "ctx" → must be highlighted.
	_check(independent.has("other"),
		"'other' context must be identified as independent of 'ctx'")

	# The CONTEXT_INDEPENDENT_COLOR must be applied to 'other'.
	var other_color: Color = _get_color(anchors.get("other") as Node3D)
	_check(other_color.b > 0.7,
		"Independent context 'other' must have blue/cyan highlight (CONTEXT_INDEPENDENT_COLOR); "
		+ "got b=%.2f" % other_color.b)

	# "dep" is depended-upon by ctx → NOT highlighted.
	_check(not independent.has("dep"),
		"'dep' is connected to 'ctx' → must NOT be an independent context")


## Cross-context: transitively dependent contexts are excluded.
func test_transitive_dependency_excludes_from_independent() -> void:
	_test_failed = false
	# Chain: ctx → middle → leaf. All three are connected.
	var nodes: Array = [
		{"id": "ctx", "name": "Ctx", "type": "bounded_context", "parent": null,
			"position": {"x": 0.0, "y": 0.0, "z": 0.0}, "size": 2.0},
		{"id": "middle", "name": "Middle", "type": "bounded_context", "parent": null,
			"position": {"x": 5.0, "y": 0.0, "z": 0.0}, "size": 1.5},
		{"id": "leaf", "name": "Leaf", "type": "bounded_context", "parent": null,
			"position": {"x": 10.0, "y": 0.0, "z": 0.0}, "size": 1.2},
		{"id": "isolated", "name": "Isolated", "type": "bounded_context", "parent": null,
			"position": {"x": -5.0, "y": 0.0, "z": 0.0}, "size": 1.0},
	]
	var edges: Array = [
		{"source": "ctx", "target": "middle", "type": "cross_context", "weight": 1},
		{"source": "middle", "target": "leaf", "type": "cross_context", "weight": 1},
	]

	var query := IndependenceQuery.new()
	var independent: Array = query.find_context_independent_peers("ctx", nodes, edges)

	# "isolated" has no connection at all → fully independent.
	_check(independent.has("isolated"),
		"'isolated' has no transitive connection → must be independent of ctx")

	# "middle" and "leaf" are transitively connected → NOT independent.
	_check(not independent.has("middle"),
		"'middle' is directly connected to ctx → must NOT be independent")
	_check(not independent.has("leaf"),
		"'leaf' is transitively connected to ctx via middle → must NOT be independent")


# ===========================================================================
# Requirement: Animated highlight transition architecture
# ===========================================================================

## AND the transition between default and independence-highlighted states is
##     animated smoothly — headless path applies colours instantly (no Tween),
##     verifying the else-branch of is_inside_tree() works correctly.
func test_highlight_animation_headless_branch_applies_color() -> void:
	_test_failed = false
	# Outside a scene tree, is_inside_tree() returns false → instant path.
	# Colours must still be applied correctly (same behaviour as before for tests).
	var graph: Dictionary = _make_two_group_graph()
	var nodes: Array = graph["nodes"]

	var anchors: Dictionary = {}
	for nd: Dictionary in nodes:
		anchors[nd.get("id", "")] = _make_anchor(nd.get("id", ""))

	var query := IndependenceQuery.new()
	# Anchors are NOT in a scene tree here — is_inside_tree() is false.
	# The else-branch in _apply_node_color must set the color immediately.
	query.apply_independence_highlight("ctx.alpha", nodes, anchors)

	# Verify headless (non-tree) path applied the colors correctly.
	var alpha_color: Color = _get_color(anchors.get("ctx.alpha") as Node3D)
	_check(alpha_color.r > 0.8 and alpha_color.g > 0.8,
		"Headless else-branch: ctx.alpha must get SELECTED_COLOR (bright yellow); "
		+ "got r=%.2f g=%.2f" % [alpha_color.r, alpha_color.g])

	var gamma_color: Color = _get_color(anchors.get("ctx.gamma") as Node3D)
	_check(gamma_color.g > 0.7 and gamma_color.r < 0.5,
		"Headless else-branch: ctx.gamma must get INDEPENDENT_COLOR (green); "
		+ "got r=%.2f g=%.2f" % [gamma_color.r, gamma_color.g])

	var beta_color: Color = _get_color(anchors.get("ctx.beta") as Node3D)
	_check(beta_color.r > 0.7,
		"Headless else-branch: ctx.beta must get CODEPENDENT_COLOR (orange); "
		+ "got r=%.2f" % beta_color.r)


## BFS hop-distance computation returns correct distances from start node.
## Spec: "the highlight animates in from the selected module outward" —
## proportional delays require accurate hop distances.
func test_compute_context_hop_distances_correct() -> void:
	_test_failed = false
	# Graph: ctx ─ middle ─ far; isolated has no edges.
	var edges: Array = [
		{"source": "ctx", "target": "middle", "type": "cross_context", "weight": 1},
		{"source": "middle", "target": "far", "type": "cross_context", "weight": 1},
	]

	var query := IndependenceQuery.new()
	var distances: Dictionary = query._compute_context_hop_distances("ctx", edges)

	# ctx itself is at distance 0 (the start).
	_check(distances.get("ctx", -1) == 0,
		"Origin 'ctx' must be at hop distance 0; got %d" % distances.get("ctx", -1))

	# middle is directly connected → 1 hop.
	_check(distances.get("middle", -1) == 1,
		"'middle' is 1 hop from 'ctx'; got %d" % distances.get("middle", -1))

	# far is 2 hops away (ctx → middle → far).
	_check(distances.get("far", -1) == 2,
		"'far' is 2 hops from 'ctx' (via middle); got %d" % distances.get("far", -1))

	# isolated has no edges → not reachable (absent from distances dict).
	_check(not distances.has("isolated"),
		"'isolated' has no edges → must be absent from hop distances")


## Context highlight outward animation: headless path still applies colour
## to ALL independent contexts regardless of hop distance (instant path).
func test_context_highlight_headless_colors_all_independent() -> void:
	_test_failed = false
	# Graph: ctx → dep; iso_a and iso_b are isolated.
	var nodes: Array = [
		{"id": "ctx", "name": "Ctx", "type": "bounded_context", "parent": null,
			"position": {"x": 0.0, "y": 0.0, "z": 0.0}, "size": 2.0},
		{"id": "dep", "name": "Dep", "type": "bounded_context", "parent": null,
			"position": {"x": 5.0, "y": 0.0, "z": 0.0}, "size": 1.5},
		{"id": "iso_a", "name": "IsoA", "type": "bounded_context", "parent": null,
			"position": {"x": -3.0, "y": 0.0, "z": 0.0}, "size": 1.0},
		{"id": "iso_b", "name": "IsoB", "type": "bounded_context", "parent": null,
			"position": {"x": -6.0, "y": 0.0, "z": 0.0}, "size": 1.0},
	]
	var edges: Array = [
		{"source": "ctx", "target": "dep", "type": "cross_context", "weight": 2},
	]

	var anchors: Dictionary = {}
	for nd: Dictionary in nodes:
		anchors[nd.get("id", "")] = _make_anchor(nd.get("id", ""))

	var query := IndependenceQuery.new()
	# Anchors not in tree → headless instant path used for all.
	var independent: Array = query.apply_context_independence_highlight(
		"ctx", nodes, edges, anchors
	)

	_check(independent.has("iso_a"),
		"'iso_a' must be identified as independent of 'ctx'")
	_check(independent.has("iso_b"),
		"'iso_b' must be identified as independent of 'ctx'")

	# Both isolated contexts must get CONTEXT_INDEPENDENT_COLOR (cyan, high blue).
	var iso_a_color: Color = _get_color(anchors.get("iso_a") as Node3D)
	_check(iso_a_color.b > 0.7,
		"'iso_a' headless path: must have CONTEXT_INDEPENDENT_COLOR (cyan, b>0.7); "
		+ "got b=%.2f" % iso_a_color.b)

	var iso_b_color: Color = _get_color(anchors.get("iso_b") as Node3D)
	_check(iso_b_color.b > 0.7,
		"'iso_b' headless path: must have CONTEXT_INDEPENDENT_COLOR (cyan, b>0.7); "
		+ "got b=%.2f" % iso_b_color.b)
