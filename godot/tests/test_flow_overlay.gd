## Tests for FlowOverlay: on-demand path highlighting through the structural space.
##
## Covers all THEN-clauses from specs/visualization/data-flow.spec.md:
##
##   Scenario "Requesting a flow path":
##     THEN the relevant flow path lights up through the structure
##       → test_path_mid_node_lit_up
##     AND irrelevant structural elements are de-emphasized
##       → test_offpath_nodes_deemphasized, test_offpath_node_transparency_mode
##     AND the flow path is traceable from entry point to terminus
##       → test_entry_node_green, test_terminus_node_red
##
##   Scenario "Flow overlaid on structure":
##     THEN the flow is rendered as a path through the structural space
##       → test_path_edges_visible, test_path_edges_cyan
##     AND the structural context remains visible (not replaced)
##       → test_offpath_nodes_still_in_scene
##     AND the human can follow the path spatially through the system
##       → test_positions_unchanged_when_path_shown
##
##   Scenario "Identifying a bottleneck":
##     THEN high-traffic paths are visually prominent
##       → test_high_traffic_edge_orange, test_medium_traffic_edge_yellow
##     AND bottleneck points (where flow constricts) are identifiable
##       → test_bottleneck_node_has_overlay, test_bottleneck_overlay_red
##
##   Requirement "Flow is On-Demand" (NOT shown by default):
##       → test_flow_not_active_by_default
##
## Additional coverage:
##   clear_path() restores original state:
##       → test_clear_restores_materials, test_clear_restores_edge_visibility,
##          test_is_not_active_after_clear
##   is_path_active() tracks state:
##       → test_is_active_after_show_path, test_aggregate_sets_active,
##          test_aggregate_preserves_edge_visibility

const FlowOverlay = preload("res://scripts/flow_overlay.gd")


# ── Helper: build a Node3D anchor with one MeshInstance3D child ─────────────

func _make_anchor(id: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = id
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.70, 0.40, 1.0)  # structural green
	mesh_inst.material_override = mat
	anchor.add_child(mesh_inst)
	return anchor


# ── Helper: build a plain edge visual MeshInstance3D ────────────────────────

func _make_edge_visual() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.55)
	m.material_override = mat
	return m


# ── Helper: build a full fixture (4 nodes, 3 edges, one FlowOverlay) ────────
# Nodes: entry, mid, terminus, other
# Edges: entry→mid, mid→terminus, other→mid
# Path for most tests: ["entry", "mid", "terminus"]

func _build_fixture() -> Dictionary:
	var root := Node3D.new()
	var entry_anchor   := _make_anchor("entry")
	var mid_anchor     := _make_anchor("mid")
	var terminus_anchor := _make_anchor("terminus")
	var other_anchor   := _make_anchor("other")
	root.add_child(entry_anchor)
	root.add_child(mid_anchor)
	root.add_child(terminus_anchor)
	root.add_child(other_anchor)

	var edge_entry_mid    := _make_edge_visual()
	var edge_mid_terminus := _make_edge_visual()
	var edge_other_mid    := _make_edge_visual()

	var anchors := {
		"entry":    entry_anchor,
		"mid":      mid_anchor,
		"terminus": terminus_anchor,
		"other":    other_anchor,
	}
	var path_edges: Array = [
		{"visual": edge_entry_mid,    "source": "entry",  "target": "mid"},
		{"visual": edge_mid_terminus, "source": "mid",    "target": "terminus"},
		{"visual": edge_other_mid,    "source": "other",  "target": "mid"},
	]

	var overlay := FlowOverlay.new()
	overlay.setup(anchors, path_edges)

	return {
		"overlay":          overlay,
		"anchors":          anchors,
		"path_edges":       path_edges,
		"edge_entry_mid":   edge_entry_mid,
		"edge_mid_terminus": edge_mid_terminus,
		"edge_other_mid":   edge_other_mid,
		"entry":            entry_anchor,
		"mid":              mid_anchor,
		"terminus":         terminus_anchor,
		"other":            other_anchor,
		"root":             root,
	}


# ── Requirement: Flow is On-Demand ──────────────────────────────────────────

## THEN: overlay is NOT active by default (paths must be invoked explicitly).
func test_flow_not_active_by_default() -> bool:
	var overlay := FlowOverlay.new()
	return not overlay.is_path_active()


# ── Scenario: Requesting a flow path ────────────────────────────────────────

## THEN: the relevant flow path lights up — mid-path node has bright white albedo.
func test_path_mid_node_lit_up() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var mesh_inst: MeshInstance3D = (fx["mid"] as Node3D).get_child(0)
	var mat := mesh_inst.material_override as StandardMaterial3D
	if mat == null:
		return false
	var col: Color = mat.albedo_color
	# Bright white: each channel >= 0.9, alpha >= 0.8.
	return col.r >= 0.9 and col.g >= 0.9 and col.b >= 0.9 and col.a >= 0.8


## THEN: flow path traceable — entry node has a distinct green colour.
func test_entry_node_green() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var mesh_inst: MeshInstance3D = (fx["entry"] as Node3D).get_child(0)
	var mat := mesh_inst.material_override as StandardMaterial3D
	if mat == null:
		return false
	var col: Color = mat.albedo_color
	# Green dominant: g > 0.8, r < 0.5, b < 0.5.
	return col.g > 0.8 and col.r < 0.5 and col.b < 0.5


## THEN: flow path traceable — terminus node has a distinct red colour.
func test_terminus_node_red() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var mesh_inst: MeshInstance3D = (fx["terminus"] as Node3D).get_child(0)
	var mat := mesh_inst.material_override as StandardMaterial3D
	if mat == null:
		return false
	var col: Color = mat.albedo_color
	# Red dominant: r > 0.8, g < 0.5, b < 0.5.
	return col.r > 0.8 and col.g < 0.5 and col.b < 0.5


## THEN: irrelevant elements are de-emphasised — off-path node has dimmed colour.
func test_offpath_nodes_deemphasized() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var mesh_inst: MeshInstance3D = (fx["other"] as Node3D).get_child(0)
	var mat := mesh_inst.material_override as StandardMaterial3D
	if mat == null:
		return false
	var col: Color = mat.albedo_color
	# Dimmed: all channels <= 0.4, alpha <= 0.4.
	return col.r <= 0.4 and col.g <= 0.4 and col.b <= 0.4 and col.a <= 0.4


## THEN: off-path node uses TRANSPARENCY_ALPHA so the dim alpha renders correctly.
func test_offpath_node_transparency_mode() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var mesh_inst: MeshInstance3D = (fx["other"] as Node3D).get_child(0)
	var mat := mesh_inst.material_override as StandardMaterial3D
	if mat == null:
		return false
	return mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA


# ── Scenario: Flow overlaid on structure ─────────────────────────────────────

## THEN: structural context remains visible — off-path anchors are still in scene.
func test_offpath_nodes_still_in_scene() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var other: Node3D = fx["other"]
	# Node must have a parent (still in the scene tree) and visible must be true.
	return other.get_parent() != null and other.visible


## THEN: human can follow path spatially — 3D positions are unchanged after show_path.
func test_positions_unchanged_when_path_shown() -> bool:
	var fx := _build_fixture()
	var entry: Node3D = fx["entry"]
	var mid: Node3D   = fx["mid"]
	entry.position = Vector3(1.0, 0.0, 2.0)
	mid.position   = Vector3(3.0, 0.0, 4.0)
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	# Positions must not be modified by the overlay.
	return entry.position.is_equal_approx(Vector3(1.0, 0.0, 2.0)) and \
		   mid.position.is_equal_approx(Vector3(3.0, 0.0, 4.0))


## THEN: flow is rendered as a path — path edges are visible after show_path.
func test_path_edges_visible() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var e1: MeshInstance3D = fx["edge_entry_mid"]
	var e2: MeshInstance3D = fx["edge_mid_terminus"]
	return e1.visible and e2.visible


## THEN: path edges rendered as a path — they are highlighted cyan (distinct from grey structural edges).
func test_path_edges_cyan() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var e1: MeshInstance3D = fx["edge_entry_mid"]
	var mat := e1.material_override as StandardMaterial3D
	if mat == null:
		return false
	var col: Color = mat.albedo_color
	# Cyan: r ~0, g ~0.9, b ~1.0.
	return col.r <= 0.1 and col.g >= 0.8 and col.b >= 0.9


## Off-path edges are hidden to make the active path clear.
func test_offpath_edges_hidden() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_path(
		["entry", "mid", "terminus"], "entry", "terminus"
	)
	var other_edge: MeshInstance3D = fx["edge_other_mid"]
	return not other_edge.visible


# ── clear_path() restores original state ────────────────────────────────────

## After clear_path(), node materials are restored to their originals.
func test_clear_restores_materials() -> bool:
	var fx := _build_fixture()
	var overlay: FlowOverlay = fx["overlay"]
	var mesh_inst: MeshInstance3D = (fx["mid"] as Node3D).get_child(0)
	var original_mat: Material = mesh_inst.material_override
	overlay.show_path(["entry", "mid", "terminus"], "entry", "terminus")
	overlay.clear_path()
	# material_override must be restored to the same reference.
	return mesh_inst.material_override == original_mat


## After clear_path(), hidden edges are made visible again.
func test_clear_restores_edge_visibility() -> bool:
	var fx := _build_fixture()
	var overlay: FlowOverlay = fx["overlay"]
	overlay.show_path(["entry", "mid", "terminus"], "entry", "terminus")
	overlay.clear_path()
	var other_edge: MeshInstance3D = fx["edge_other_mid"]
	return other_edge.visible


## After clear_path(), is_path_active() returns false.
func test_is_not_active_after_clear() -> bool:
	var fx := _build_fixture()
	var overlay: FlowOverlay = fx["overlay"]
	overlay.show_path(["entry", "mid", "terminus"], "entry", "terminus")
	overlay.clear_path()
	return not overlay.is_path_active()


## is_path_active() returns true while a path is shown.
func test_is_active_after_show_path() -> bool:
	var fx := _build_fixture()
	var overlay: FlowOverlay = fx["overlay"]
	overlay.show_path(["entry", "mid", "terminus"], "entry", "terminus")
	return overlay.is_path_active()


# ── Scenario: Identifying a bottleneck ──────────────────────────────────────

## THEN: high-traffic paths are visually prominent — traffic >= 500 → orange edge.
func test_high_traffic_edge_orange() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_aggregate(
		[{"source": "entry", "target": "mid", "traffic": 950}],
		[]
	)
	var edge: MeshInstance3D = fx["edge_entry_mid"]
	var mat := edge.material_override as StandardMaterial3D
	if mat == null:
		return false
	var col: Color = mat.albedo_color
	# Orange: r >= 0.9, g <= 0.6, b <= 0.1.
	return col.r >= 0.9 and col.g <= 0.6 and col.b <= 0.1


## THEN: high-traffic paths — traffic 100–499 → yellow edge (still prominent).
func test_medium_traffic_edge_yellow() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_aggregate(
		[{"source": "entry", "target": "mid", "traffic": 200}],
		[]
	)
	var edge: MeshInstance3D = fx["edge_entry_mid"]
	var mat := edge.material_override as StandardMaterial3D
	if mat == null:
		return false
	var col: Color = mat.albedo_color
	# Yellow: r >= 0.9, g >= 0.7, b <= 0.1.
	return col.r >= 0.9 and col.g >= 0.7 and col.b <= 0.1


## THEN: bottleneck points identifiable — anchor receives a BottleneckOverlay child.
func test_bottleneck_node_has_overlay() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_aggregate([], ["mid"])
	var mid: Node3D = fx["mid"]
	for child: Node in mid.get_children():
		if child.name == "BottleneckOverlay":
			return true
	return false


## THEN: bottleneck overlay is visually red so the constriction point is clear.
func test_bottleneck_overlay_red() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_aggregate([], ["mid"])
	var mid: Node3D = fx["mid"]
	for child: Node in mid.get_children():
		if child.name == "BottleneckOverlay":
			var mesh_inst := child as MeshInstance3D
			if mesh_inst == null:
				return false
			var mat := mesh_inst.material_override as StandardMaterial3D
			if mat == null:
				return false
			var col: Color = mat.albedo_color
			# Red: r >= 0.9, g <= 0.1, b <= 0.1.
			return col.r >= 0.9 and col.g <= 0.1 and col.b <= 0.1
	return false


## show_aggregate() sets is_path_active() to true.
func test_aggregate_sets_active() -> bool:
	var fx := _build_fixture()
	var overlay: FlowOverlay = fx["overlay"]
	overlay.show_aggregate([{"source": "entry", "target": "mid", "traffic": 500}], [])
	return overlay.is_path_active()


## show_aggregate() does NOT hide structural edges (only recolours hot ones).
func test_aggregate_preserves_edge_visibility() -> bool:
	var fx := _build_fixture()
	(fx["overlay"] as FlowOverlay).show_aggregate(
		[{"source": "entry", "target": "mid", "traffic": 950}],
		[]
	)
	# The non-hot edge must remain visible (aggregate doesn't hide anything).
	var other_edge: MeshInstance3D = fx["edge_other_mid"]
	return other_edge.visible
