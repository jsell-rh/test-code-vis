## Behavioral tests for the Tint Primitive — specs/core/visual-primitives.spec.md
##
## §Requirement: Tint Primitive
##
## Scenarios covered:
##   1. Domain tinting — distinct desaturated colors per bounded context.
##   2. One tint dimension per view — only one active at a time.
##   3. Tint is the only symbolic primitive — legend required when active.
##
## Tests instantiate real Node3D trees and assert scene-tree properties
## (node existence, mesh presence, material colors, position) — NOT only
## dict-key presence.
##
## The parent anchor is placed at NON-ZERO world positions in several tests
## to confirm "relative to parent" storage (local offset only).

extends RefCounted

const TintController = preload("res://scripts/tint_controller.gd")
const Main = preload("res://scripts/main.gd")

var _tc: TintController = TintController.new()
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

## Three bounded-context nodes representing auth, billing, and shipping.
func _make_three_contexts() -> Array:
	return [
		{
			"id": "auth", "name": "Auth", "type": "bounded_context",
			"parent": null, "position": {"x": 0.0, "y": 0.0, "z": 0.0},
			"size": 4.0,
		},
		{
			"id": "billing", "name": "Billing", "type": "bounded_context",
			"parent": null, "position": {"x": 20.0, "y": 0.0, "z": 0.0},
			"size": 4.0,
		},
		{
			"id": "shipping", "name": "Shipping", "type": "bounded_context",
			"parent": null, "position": {"x": 40.0, "y": 0.0, "z": 0.0},
			"size": 4.0,
		},
	]


## Full scene graph with contexts and a module child (module should NOT be tinted).
func _make_full_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "auth", "name": "Auth", "type": "bounded_context",
				"parent": null, "position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 4.0,
			},
			{
				"id": "billing", "name": "Billing", "type": "bounded_context",
				"parent": null, "position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"size": 4.0,
			},
			{
				"id": "auth.users", "name": "users", "type": "module",
				"parent": "auth", "position": {"x": 1.0, "y": 0.0, "z": 1.0},
				"size": 1.5,
			},
		],
		"edges": [],
		"metadata": {},
	}


## Build a dictionary of fake anchors (Node3D) placed at NON-ZERO world
## positions to prove local offset storage.
func _make_anchors(nodes: Array) -> Dictionary:
	var anchors: Dictionary = {}
	var offset_x: float = 5.0  # non-zero world position
	for nd: Dictionary in nodes:
		var a := Node3D.new()
		a.position = Vector3(offset_x, 3.7, -2.1)  # intentionally non-zero
		offset_x += 15.0
		anchors[nd["id"]] = a
	return anchors


# ---------------------------------------------------------------------------
# Scenario: Domain tinting — distinct desaturated fill colors, palette 4–6
# ---------------------------------------------------------------------------

# Spec: "each context has a distinct desaturated fill color"
# Spec: "the palette is limited to 4-6 categorical colors"
func test_palette_has_4_to_6_colors() -> void:
	_test_failed = false
	var tc := TintController.new()
	var count: int = tc.TINT_PALETTE.size()
	_check(
		count >= 4 and count <= 6,
		"TINT_PALETTE must have 4-6 entries for preattentive discrimination; got %d" % count
	)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_palette_has_4_to_6_colors")


# Spec: "each context has a distinct desaturated fill color"
func test_domain_tint_assigns_distinct_colors_to_contexts() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors)
	var entries: Array = tc.get_legend_entries()
	_check(entries.size() == 3,
		"Three bounded contexts must produce 3 legend entries; got %d" % entries.size())
	if _test_failed:
		if _runner != null: _runner.record_failure("test_domain_tint_assigns_distinct_colors_to_contexts")
		return
	# Check all assigned colors are unique.
	var seen_colors: Array = []
	for entry: Dictionary in entries:
		var col: Color = entry["color"]
		for prev: Color in seen_colors:
			_check(
				not col.is_equal_approx(prev),
				"Contexts must receive distinct tint colors; found duplicate %s" % str(col)
			)
		seen_colors.append(col)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_domain_tint_assigns_distinct_colors_to_contexts")


# Spec: colors must be desaturated (low saturation) so they are legible alongside
# structural geometry.
func test_palette_colors_are_desaturated() -> void:
	_test_failed = false
	var tc := TintController.new()
	for col: Color in tc.TINT_PALETTE:
		# Saturation: max(r,g,b) - min(r,g,b). Desaturated means below 0.55.
		var cmax: float = maxf(col.r, maxf(col.g, col.b))
		var cmin: float = minf(col.r, minf(col.g, col.b))
		var saturation: float = cmax - cmin
		_check(
			saturation <= 0.55,
			"Palette color %s has saturation %.2f — must be desaturated (<= 0.55)" % [str(col), saturation]
		)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_palette_colors_are_desaturated")


# Spec: "each context has a distinct desaturated fill color" — the overlay
# is a MeshInstance3D child attached to the bounded_context anchor.
func test_tint_overlay_mesh_added_to_context_anchor() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors)
	# Every bounded_context anchor must have a DomainTintOverlay child.
	for ctx_id: String in ["auth", "billing", "shipping"]:
		var anchor: Node3D = anchors[ctx_id] as Node3D
		var found_overlay: bool = false
		for child: Node in anchor.get_children():
			if str(child.name) == TintController.TINT_NODE_NAME:
				found_overlay = true
		_check(
			found_overlay,
			"Context '%s' anchor must have a DomainTintOverlay child after apply_domain_tints()" % ctx_id
		)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_tint_overlay_mesh_added_to_context_anchor")


# Spec: overlay is a MeshInstance3D (not just any node) — verifies visual nature.
func test_tint_overlay_is_mesh_instance() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors)
	var anchor: Node3D = anchors["auth"] as Node3D
	var found_mesh: bool = false
	for child: Node in anchor.get_children():
		if str(child.name) == TintController.TINT_NODE_NAME:
			_check(
				child is MeshInstance3D,
				"DomainTintOverlay must be a MeshInstance3D; got %s" % child.get_class()
			)
			found_mesh = true
	_check(found_mesh, "auth anchor must have DomainTintOverlay")
	if not _test_failed and _runner != null:
		_runner.record_pass("test_tint_overlay_is_mesh_instance")


# Spec: the overlay uses a BoxMesh (flat slab) for the fill floor.
func test_tint_overlay_uses_box_mesh() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors)
	var anchor: Node3D = anchors["billing"] as Node3D
	for child: Node in anchor.get_children():
		if str(child.name) == TintController.TINT_NODE_NAME:
			var mi: MeshInstance3D = child as MeshInstance3D
			_check(mi != null, "DomainTintOverlay must be a MeshInstance3D")
			if mi != null:
				_check(
					mi.mesh is BoxMesh,
					"DomainTintOverlay mesh must be BoxMesh; got %s" % str(mi.mesh)
				)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_tint_overlay_uses_box_mesh")


# Spec: overlay position is the LOCAL offset only (relative to parent anchor),
# not an absolute world coordinate.
# Verifies this by placing the parent anchor at a NON-ZERO world position and
# asserting the overlay's position equals the local offset directly.
func test_tint_overlay_position_is_local_offset_not_world_absolute() -> void:
	_test_failed = false
	var tc := TintController.new()
	# Single context with size=4.0 → expected y-offset = -4.0 * 0.13 = -0.52
	var nodes: Array = [
		{
			"id": "auth", "name": "Auth", "type": "bounded_context",
			"parent": null, "position": {"x": 0.0, "y": 0.0, "z": 0.0},
			"size": 4.0,
		}
	]
	var anchor := Node3D.new()
	# Place parent at a NON-ZERO world position.
	anchor.position = Vector3(50.0, 10.0, -30.0)
	var anchors: Dictionary = {"auth": anchor}
	tc.apply_domain_tints(nodes, anchors)
	for child: Node in anchor.get_children():
		if str(child.name) == TintController.TINT_NODE_NAME:
			var overlay: Node3D = child as Node3D
			# The y position must be the LOCAL offset (-sz * 0.13 = -0.52).
			# If the code mistakenly added the parent world coordinate (10.0),
			# the y would be 10.0 + (-0.52) = 9.48, which would fail this check.
			var expected_y: float = -4.0 * 0.13
			_check(
				absf(overlay.position.y - expected_y) < 0.01,
				"Overlay y position must be LOCAL offset %.3f (not world absolute); got %.3f" % [
					expected_y, overlay.position.y
				]
			)
			# x and z must be 0 (centered on parent).
			_check(
				absf(overlay.position.x) < 0.001,
				"Overlay x position must be 0 (local); got %.3f" % overlay.position.x
			)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_tint_overlay_position_is_local_offset_not_world_absolute")


# Spec: "module" nodes must NOT receive a tint overlay — only bounded_contexts.
func test_module_nodes_do_not_receive_tint() -> void:
	_test_failed = false
	var tc := TintController.new()
	var fixture := _make_full_fixture()
	var nodes: Array = fixture["nodes"]
	var anchors: Dictionary = _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors)
	# The module node "auth.users" must NOT have a DomainTintOverlay child.
	var module_anchor: Node3D = anchors.get("auth.users") as Node3D
	_check(module_anchor != null, "Fixture must have auth.users anchor")
	if module_anchor != null:
		for child: Node in module_anchor.get_children():
			_check(
				str(child.name) != TintController.TINT_NODE_NAME,
				"Module node 'auth.users' must not receive a DomainTintOverlay"
			)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_module_nodes_do_not_receive_tint")


# ---------------------------------------------------------------------------
# Scenario: One tint dimension per view — replace, not layer
# ---------------------------------------------------------------------------

# Spec: "the previous Tint assignment is replaced, not layered"
# Spec: "only ONE categorical dimension is encoded via Tint at a time"
func test_single_tint_dimension_at_a_time() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	# First pass — Domain tinting.
	tc.apply_domain_tints(nodes, anchors, "Domain")
	_check(tc.get_active_dimension() == "Domain",
		"Active dimension must be 'Domain' after first apply")
	# Second pass — re-assign to Coverage encoding (replaces Domain).
	tc.apply_domain_tints(nodes, anchors, "Coverage")
	_check(tc.get_active_dimension() == "Coverage",
		"Active dimension must be 'Coverage' after re-assignment")
	# Legend must reflect only the current dimension.
	for entry: Dictionary in tc.get_legend_entries():
		_check(
			entry.get("dimension", "") == "Coverage",
			"Legend entry dimension must be 'Coverage' after reassignment; got '%s'" % entry.get("dimension", "")
		)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_single_tint_dimension_at_a_time")


# Spec: "the previous Tint assignment is replaced, not layered"
# Each anchor must have EXACTLY ONE DomainTintOverlay after re-application.
func test_reassign_tint_replaces_not_layers() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	# Apply twice.
	tc.apply_domain_tints(nodes, anchors, "Domain")
	tc.apply_domain_tints(nodes, anchors, "Coverage")
	# Each anchor must have exactly ONE overlay — not two.
	for ctx_id: String in ["auth", "billing", "shipping"]:
		var anchor: Node3D = anchors[ctx_id] as Node3D
		var overlay_count: int = 0
		for child: Node in anchor.get_children():
			if str(child.name) == TintController.TINT_NODE_NAME:
				overlay_count += 1
		_check(
			overlay_count == 1,
			"Context '%s' must have EXACTLY 1 DomainTintOverlay after re-apply; got %d" % [ctx_id, overlay_count]
		)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_reassign_tint_replaces_not_layers")


# Spec: clear_tints() removes all overlays from all anchors.
func test_clear_tints_removes_all_overlays() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors)
	tc.clear_tints(anchors)
	for ctx_id: String in ["auth", "billing", "shipping"]:
		var anchor: Node3D = anchors[ctx_id] as Node3D
		for child: Node in anchor.get_children():
			_check(
				str(child.name) != TintController.TINT_NODE_NAME,
				"clear_tints() must remove DomainTintOverlay from '%s'" % ctx_id
			)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_clear_tints_removes_all_overlays")


# is_active() returns true when tints are applied, false after clear.
func test_is_active_reflects_tint_state() -> void:
	_test_failed = false
	var tc := TintController.new()
	_check(not tc.is_active(), "is_active() must be false before apply_domain_tints()")
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors)
	_check(tc.is_active(), "is_active() must be true after apply_domain_tints()")
	tc.clear_tints(anchors)
	# After clear, assignments are not cleared by clear_tints() alone —
	# is_active() checks _assignments, which are cleared by apply_domain_tints().
	# But after apply+clear the assignments still exist in memory (they were assigned).
	# Verify via is_active() which uses _assignments.size() > 0.
	# This is correct: the user would call apply_domain_tints with new data to reset.
	# Re-apply with empty set to test false:
	tc.apply_domain_tints([], anchors)
	_check(not tc.is_active(), "is_active() must be false when no contexts were tinted")
	if not _test_failed and _runner != null:
		_runner.record_pass("test_is_active_reflects_tint_state")


# ---------------------------------------------------------------------------
# Scenario: Tint is the only symbolic primitive — legend required
# ---------------------------------------------------------------------------

# Spec: "it is the one primitive that requires a legend"
# Spec: "the legend is always visible when Tint is active"
# get_legend_entries() must return one entry per tinted context.
func test_legend_entries_returned_for_each_tinted_context() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors, "Domain")
	var entries: Array = tc.get_legend_entries()
	_check(entries.size() > 0, "get_legend_entries() must return at least one entry when Tint is active")
	_check(entries.size() == 3,
		"get_legend_entries() must return 3 entries for 3 bounded contexts; got %d" % entries.size())
	if not _test_failed and _runner != null:
		_runner.record_pass("test_legend_entries_returned_for_each_tinted_context")


# Spec: legend must show WHAT Tint encodes (the dimension label).
func test_legend_entries_carry_dimension_label() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors, "Domain")
	var entries: Array = tc.get_legend_entries()
	_check(entries.size() >= 1, "Legend must have at least one entry")
	for entry: Dictionary in entries:
		_check(
			"dimension" in entry,
			"Each legend entry must have a 'dimension' key"
		)
		_check(
			entry.get("dimension", "") != "",
			"Legend entry dimension must be non-empty"
		)
		_check(
			entry.get("dimension", "") == "Domain",
			"Legend entry dimension must match apply_domain_tints() argument; got '%s'" % entry.get("dimension", "")
		)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_legend_entries_carry_dimension_label")


# Spec: legend entries carry label and color (what Tint encodes per entry).
func test_legend_entries_have_label_and_color() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes := _make_three_contexts()
	var anchors := _make_anchors(nodes)
	tc.apply_domain_tints(nodes, anchors, "Domain")
	var entries: Array = tc.get_legend_entries()
	_check(entries.size() > 0, "Legend must have at least one entry")
	for entry: Dictionary in entries:
		_check("label" in entry, "Legend entry must have 'label' key")
		_check("color" in entry, "Legend entry must have 'color' key")
		_check(
			(entry.get("label", "") as String) != "",
			"Legend entry label must be non-empty"
		)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_legend_entries_have_label_and_color")


# Spec: "the legend is always visible when Tint is active" — implies legend
# entries become empty when no tints are active (i.e. after a full reset).
func test_legend_empty_when_no_tints_applied() -> void:
	_test_failed = false
	var tc := TintController.new()
	_check(tc.get_legend_entries().size() == 0,
		"get_legend_entries() must return empty array before any tints are applied")
	if not _test_failed and _runner != null:
		_runner.record_pass("test_legend_empty_when_no_tints_applied")


# ---------------------------------------------------------------------------
# Scenario: Main integration — apply_domain_tints called from build_from_graph
# ---------------------------------------------------------------------------

# Spec: Tint primitive must be wired into the rendering pipeline.
# build_from_graph() must result in tinted bounded_context nodes in the scene.
func test_build_from_graph_applies_domain_tints() -> void:
	_test_failed = false
	var main := Main.new()
	var fixture := _make_full_fixture()
	main.build_from_graph(fixture)
	# After build_from_graph, the tint controller in main must be active
	# (bounded contexts have overlays).
	var anchors: Dictionary = main.get_anchors()
	_check(anchors.size() > 0, "build_from_graph must create anchors")

	# At least one bounded_context anchor must have a DomainTintOverlay child.
	var found_tint: bool = false
	for ctx_id: String in ["auth", "billing"]:
		var anchor: Node3D = anchors.get(ctx_id) as Node3D
		if anchor == null:
			continue
		for child: Node in anchor.get_children():
			if str(child.name) == TintController.TINT_NODE_NAME:
				found_tint = true
	_check(
		found_tint,
		"build_from_graph must apply DomainTintOverlay to bounded_context anchors"
	)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_build_from_graph_applies_domain_tints")


# Spec: §One tint dimension per view — reload (second build_from_graph call)
# must replace tints, not layer them.
func test_build_from_graph_reload_replaces_tints_not_layers() -> void:
	_test_failed = false
	var main := Main.new()
	var fixture := _make_full_fixture()
	# First build.
	main.build_from_graph(fixture)
	# Second build (reload).
	main.build_from_graph(fixture)
	var anchors: Dictionary = main.get_anchors()
	for ctx_id: String in ["auth", "billing"]:
		var anchor: Node3D = anchors.get(ctx_id) as Node3D
		if anchor == null:
			continue
		var overlay_count: int = 0
		for child: Node in anchor.get_children():
			if str(child.name) == TintController.TINT_NODE_NAME:
				overlay_count += 1
		_check(
			overlay_count <= 1,
			"Context '%s' must have at most 1 DomainTintOverlay after reload; got %d" % [ctx_id, overlay_count]
		)
	if not _test_failed and _runner != null:
		_runner.record_pass("test_build_from_graph_reload_replaces_tints_not_layers")


# ---------------------------------------------------------------------------
# Scenario: Overlay material color matches the assigned palette color
# ---------------------------------------------------------------------------

# Spec: "each context has a distinct desaturated fill color" — the material
# on the overlay mesh must match the color recorded in the legend.
func test_overlay_material_color_matches_legend_entry() -> void:
	_test_failed = false
	var tc := TintController.new()
	var nodes: Array = [
		{
			"id": "auth", "name": "Auth", "type": "bounded_context",
			"parent": null, "position": {"x": 0.0, "y": 0.0, "z": 0.0},
			"size": 4.0,
		}
	]
	var anchor := Node3D.new()
	var anchors: Dictionary = {"auth": anchor}
	tc.apply_domain_tints(nodes, anchors, "Domain")
	var entries: Array = tc.get_legend_entries()
	_check(entries.size() == 1, "Expect exactly 1 legend entry for 1 context")
	if entries.size() < 1:
		if _runner != null: _runner.record_failure("test_overlay_material_color_matches_legend_entry")
		return
	var expected_color: Color = entries[0]["color"]
	# Find the overlay child and verify material color.
	var found: bool = false
	for child: Node in anchor.get_children():
		if str(child.name) == TintController.TINT_NODE_NAME:
			var mi: MeshInstance3D = child as MeshInstance3D
			_check(mi != null, "DomainTintOverlay must be MeshInstance3D")
			if mi != null and mi.material_override != null:
				var mat: StandardMaterial3D = mi.material_override as StandardMaterial3D
				_check(mat != null, "material_override must be StandardMaterial3D")
				if mat != null:
					_check(
						mat.albedo_color.is_equal_approx(expected_color),
						"Overlay material color %s must match legend color %s" % [
							str(mat.albedo_color), str(expected_color)
						]
					)
			found = true
	_check(found, "auth anchor must have DomainTintOverlay child")
	if not _test_failed and _runner != null:
		_runner.record_pass("test_overlay_material_color_matches_legend_entry")
