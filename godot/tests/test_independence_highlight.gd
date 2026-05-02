## Behavioral tests for specs/visualization/orthogonal-independence.spec.md
##
## Requirement: Independence as Queryable Property
##   THEN all modules in other independence groups within the same bounded context
##        are highlighted (INDEPENDENT_PEER_COLOR)
##   AND  modules in A's own group are visually distinguished as "co-dependent"
##        (CODEPENDENT_COLOR)
##   AND  the transition between default and independence-highlighted states is
##        animated smoothly
##
## Requirement: Cross-context independence
##   THEN bounded contexts with no transitive dependency on context X are highlighted
##   AND  the highlight animates in from the selected module outward
##
## Tests instantiate real Node3D trees via Main.build_from_graph() and assert
## scene-tree properties — NOT just dict key existence.

extends RefCounted

const Main = preload("res://scripts/main.gd")

var _test_failed: bool = false
var _runner: Object = null


func _check(condition: bool, msg: String) -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg)


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

## Fixture: one bounded context (ctx_a) with two independence groups, plus
## an independent context (ctx_b) that has no dependency on ctx_a.
##
## ctx_a modules:
##   ctx_a.mod_domain   → independence_group "ctx_a:0" (connected to mod_app)
##   ctx_a.mod_app      → independence_group "ctx_a:0" (connected to mod_domain)
##   ctx_a.mod_isolated → independence_group "ctx_a:1" (no internal deps)
## ctx_b: no dependency on ctx_a → fully independent at context level.
func _make_independence_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx_a",
				"name": "ContextA",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"is_hub": false,
				"in_degree": 0,
			},
			{
				"id": "ctx_b",
				"name": "ContextB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 10.0, "y": 0.0, "z": 0.0},
				"size": 2.5,
				"is_hub": false,
				"in_degree": 0,
			},
			{
				"id": "ctx_a.mod_domain",
				"name": "Domain",
				"type": "module",
				"parent": "ctx_a",
				"position": {"x": -1.0, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx_a:0",
			},
			{
				"id": "ctx_a.mod_app",
				"name": "Application",
				"type": "module",
				"parent": "ctx_a",
				"position": {"x": 1.0, "y": 0.0, "z": 0.0},
				"size": 1.0,
				"independence_group": "ctx_a:0",
			},
			{
				"id": "ctx_a.mod_isolated",
				"name": "Isolated",
				"type": "module",
				"parent": "ctx_a",
				"position": {"x": 0.0, "y": 0.0, "z": 2.0},
				"size": 1.0,
				"independence_group": "ctx_a:1",
			},
		],
		"edges": [
			{
				"source": "ctx_a.mod_app",
				"target": "ctx_a.mod_domain",
				"type": "internal",
			},
		],
		"metadata": {},
		"clusters": [],
	}


## Helper: retrieve the albedo_color from the first MeshInstance3D child of *anchor*.
func _get_mesh_color(anchor: Node3D) -> Color:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat = (child as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				return (mat as StandardMaterial3D).albedo_color
	return Color.TRANSPARENT


# ---------------------------------------------------------------------------
# Requirement: Independence as Queryable Property
# spec: orthogonal-independence.spec.md § Scenario: Selecting a module shows
#       its independent peers
# ---------------------------------------------------------------------------

## GIVEN the human selects module A (ctx_a.mod_app, group ctx_a:0)
## THEN all modules in other independence groups within the same bounded context
##      are highlighted with INDEPENDENT_PEER_COLOR
## spec: "all modules in other independence groups within the same bounded context
##        are highlighted"
func test_other_group_modules_highlighted_as_independent_peers() -> void:
	_test_failed = false
	var main := Main.new()
	main.build_from_graph(_make_independence_fixture())

	# Select ctx_a.mod_app (in group ctx_a:0).
	# ctx_a.mod_isolated is in group ctx_a:1 → orthogonal complement → INDEPENDENT_PEER_COLOR.
	main.highlight_independence("ctx_a.mod_app")

	var isolated_anchor: Node3D = main.get_anchors().get("ctx_a.mod_isolated")
	_check(isolated_anchor != null, "Anchor for ctx_a.mod_isolated must exist after build_from_graph")
	if isolated_anchor != null:
		var color: Color = _get_mesh_color(isolated_anchor)
		_check(
			color.is_equal_approx(Main.INDEPENDENT_PEER_COLOR),
			"ctx_a.mod_isolated (group ctx_a:1) must receive INDEPENDENT_PEER_COLOR "
			+ "when ctx_a.mod_app (group ctx_a:0) is selected; "
			+ "got (%.2f,%.2f,%.2f)" % [color.r, color.g, color.b]
		)

	main.free()


## GIVEN the human selects module A (ctx_a.mod_app, group ctx_a:0)
## AND modules in A's own group are visually distinguished as "co-dependent"
## spec: "modules in A's own group are visually distinguished as co-dependent"
func test_own_group_modules_highlighted_as_codependent() -> void:
	_test_failed = false
	var main := Main.new()
	main.build_from_graph(_make_independence_fixture())

	# Select ctx_a.mod_app (in group ctx_a:0).
	# ctx_a.mod_domain is also in group ctx_a:0 → co-dependent → CODEPENDENT_COLOR.
	main.highlight_independence("ctx_a.mod_app")

	var domain_anchor: Node3D = main.get_anchors().get("ctx_a.mod_domain")
	_check(domain_anchor != null, "Anchor for ctx_a.mod_domain must exist after build_from_graph")
	if domain_anchor != null:
		var color: Color = _get_mesh_color(domain_anchor)
		_check(
			color.is_equal_approx(Main.CODEPENDENT_COLOR),
			"ctx_a.mod_domain (same group ctx_a:0 as selection) must receive CODEPENDENT_COLOR; "
			+ "got (%.2f,%.2f,%.2f)" % [color.r, color.g, color.b]
		)

	main.free()


## The co-dependent color and independent peer color MUST be visually distinct.
## spec: modules "distinguished as co-dependent" implies a different visual treatment
## from the "highlighted" (independent peer) state.
func test_codependent_and_independent_colors_are_visually_distinct() -> void:
	_test_failed = false
	_check(
		not Main.CODEPENDENT_COLOR.is_equal_approx(Main.INDEPENDENT_PEER_COLOR),
		"CODEPENDENT_COLOR and INDEPENDENT_PEER_COLOR must be distinct colors "
		+ "so co-dependent and independent peers are visually distinguishable"
	)


## clear_independence_highlight() restores the original mesh colors.
## spec: "the transition between default and independence-highlighted states is
##        animated smoothly" (both directions: apply and clear)
func test_clear_independence_highlight_restores_original_colors() -> void:
	_test_failed = false
	var main := Main.new()
	main.build_from_graph(_make_independence_fixture())

	var isolated_anchor: Node3D = main.get_anchors().get("ctx_a.mod_isolated")
	_check(isolated_anchor != null, "Anchor for ctx_a.mod_isolated must exist")
	if isolated_anchor == null:
		main.free()
		return

	# Record the default color before any highlighting.
	var original_color: Color = _get_mesh_color(isolated_anchor)

	# Apply highlight and then clear it.
	main.highlight_independence("ctx_a.mod_app")
	main.clear_independence_highlight()

	# After clearing, the color must be restored to its pre-highlight value.
	var restored_color: Color = _get_mesh_color(isolated_anchor)
	_check(
		restored_color.is_equal_approx(original_color),
		"clear_independence_highlight must restore original color; "
		+ "expected (%.2f,%.2f,%.2f), got (%.2f,%.2f,%.2f)" % [
			original_color.r, original_color.g, original_color.b,
			restored_color.r, restored_color.g, restored_color.b,
		]
	)

	main.free()


## Highlighting changes the module color from its default state.
## spec: "the transition between default and independence-highlighted states is
##        animated smoothly" — verified by confirming the color actually changes.
func test_highlight_changes_module_color_from_default() -> void:
	_test_failed = false
	var main := Main.new()
	main.build_from_graph(_make_independence_fixture())

	var isolated_anchor: Node3D = main.get_anchors().get("ctx_a.mod_isolated")
	_check(isolated_anchor != null, "Anchor for ctx_a.mod_isolated must exist")
	if isolated_anchor == null:
		main.free()
		return

	var default_color: Color = _get_mesh_color(isolated_anchor)
	main.highlight_independence("ctx_a.mod_app")
	var highlighted_color: Color = _get_mesh_color(isolated_anchor)

	_check(
		not highlighted_color.is_equal_approx(default_color),
		"Independence highlight must change the module color from its default value — "
		+ "the highlighted state must be visually distinct from the default state"
	)

	main.free()


## Selecting the isolated module (group ctx_a:1) makes group 0 the independent peer.
## spec scenario: "Selecting a module shows its independent peers" — symmetry check.
func test_highlight_independence_covers_selected_nodes_complement() -> void:
	_test_failed = false
	var main := Main.new()
	main.build_from_graph(_make_independence_fixture())

	# Select ctx_a.mod_isolated (group ctx_a:1).
	# ctx_a.mod_domain and ctx_a.mod_app (group ctx_a:0) become independent peers.
	main.highlight_independence("ctx_a.mod_isolated")

	var domain_anchor: Node3D = main.get_anchors().get("ctx_a.mod_domain")
	var app_anchor: Node3D = main.get_anchors().get("ctx_a.mod_app")
	_check(domain_anchor != null, "ctx_a.mod_domain anchor must exist")
	_check(app_anchor != null, "ctx_a.mod_app anchor must exist")

	if domain_anchor != null:
		var color: Color = _get_mesh_color(domain_anchor)
		_check(
			color.is_equal_approx(Main.INDEPENDENT_PEER_COLOR),
			"ctx_a.mod_domain (group ctx_a:0) must be INDEPENDENT_PEER_COLOR "
			+ "when ctx_a.mod_isolated (group ctx_a:1) is selected"
		)

	if app_anchor != null:
		var color: Color = _get_mesh_color(app_anchor)
		_check(
			color.is_equal_approx(Main.INDEPENDENT_PEER_COLOR),
			"ctx_a.mod_app (group ctx_a:0) must be INDEPENDENT_PEER_COLOR "
			+ "when ctx_a.mod_isolated (group ctx_a:1) is selected"
		)

	main.free()


# ---------------------------------------------------------------------------
# Requirement: Cross-context independence
# spec: orthogonal-independence.spec.md § Scenario: Cross-context independence
# ---------------------------------------------------------------------------

## GIVEN the human selects module A in context X (ctx_a)
## WHEN independence is displayed at the context level
## THEN bounded contexts with no transitive dependency on context X are highlighted
## spec: "_compute_context_independence returns correct independent contexts"
func test_compute_context_independence_finds_isolated_contexts() -> void:
	_test_failed = false
	var main := Main.new()
	# Fixture: ctx_a and ctx_b have no edges between them → both are independent.
	main.build_from_graph(_make_independence_fixture())

	var independent: Array = main._compute_context_independence("ctx_a")
	_check(
		independent.size() > 0,
		"ctx_b has no transitive dependency on ctx_a — must appear in the independent set; "
		+ "got empty set"
	)
	_check(
		"ctx_b" in independent,
		"ctx_b must be in ctx_a's independent context set; got: " + str(independent)
	)
	_check(
		not ("ctx_a" in independent),
		"ctx_a must NOT appear in its own independent context set"
	)

	main.free()


## GIVEN ctx_c depends on ctx_a (transitive dependency)
## THEN ctx_c is NOT in the independent set for ctx_a
## spec: "bounded contexts with no transitive dependency on context X are highlighted"
## (contexts WITH a transitive dependency are NOT highlighted)
func test_dependent_context_is_not_independent() -> void:
	_test_failed = false
	var main := Main.new()

	# Extend the base fixture with ctx_c that has a cross_context edge to ctx_a.
	var fixture: Dictionary = _make_independence_fixture()
	fixture["nodes"].append({
		"id": "ctx_c",
		"name": "ContextC",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 10.0},
		"size": 2.0,
		"is_hub": false,
		"in_degree": 1,
	})
	fixture["edges"].append({
		"source": "ctx_c",
		"target": "ctx_a",
		"type": "cross_context",
	})
	main.build_from_graph(fixture)

	var independent: Array = main._compute_context_independence("ctx_a")
	_check(
		not ("ctx_c" in independent),
		"ctx_c depends on ctx_a → ctx_c must NOT be in ctx_a's independent context set; "
		+ "got: " + str(independent)
	)

	main.free()


## Highlight a module and verify that the independent BC (ctx_b) receives
## INDEPENDENT_PEER_COLOR through highlight_independence().
## spec: "THEN bounded contexts with no transitive dependency on context X are highlighted"
func test_independent_context_receives_highlight_color() -> void:
	_test_failed = false
	var main := Main.new()
	main.build_from_graph(_make_independence_fixture())

	# ctx_a.mod_app's context is ctx_a. ctx_b has no dependency on ctx_a.
	main.highlight_independence("ctx_a.mod_app")

	var ctx_b_anchor: Node3D = main.get_anchors().get("ctx_b")
	_check(ctx_b_anchor != null, "Anchor for ctx_b must exist after build_from_graph")
	if ctx_b_anchor != null:
		var color: Color = _get_mesh_color(ctx_b_anchor)
		_check(
			color.is_equal_approx(Main.INDEPENDENT_PEER_COLOR),
			"ctx_b (no transitive dependency on ctx_a) must receive INDEPENDENT_PEER_COLOR; "
			+ "got (%.2f,%.2f,%.2f)" % [color.r, color.g, color.b]
		)

	main.free()


## clear_independence_highlight() also restores bounded context colors.
func test_clear_restores_context_highlight() -> void:
	_test_failed = false
	var main := Main.new()
	main.build_from_graph(_make_independence_fixture())

	var ctx_b_anchor: Node3D = main.get_anchors().get("ctx_b")
	_check(ctx_b_anchor != null, "Anchor for ctx_b must exist")
	if ctx_b_anchor == null:
		main.free()
		return

	var original_color: Color = _get_mesh_color(ctx_b_anchor)
	main.highlight_independence("ctx_a.mod_app")
	main.clear_independence_highlight()
	var restored_color: Color = _get_mesh_color(ctx_b_anchor)

	_check(
		restored_color.is_equal_approx(original_color),
		"clear_independence_highlight must restore ctx_b's original color; "
		+ "expected (%.2f,%.2f,%.2f), got (%.2f,%.2f,%.2f)" % [
			original_color.r, original_color.g, original_color.b,
			restored_color.r, restored_color.g, restored_color.b,
		]
	)

	main.free()
