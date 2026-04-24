## On-demand path overlay for CodeVis.
##
## Highlights specific paths through the structural space and overlays aggregate
## traffic patterns on the persistent structural geography.
## The overlay is NOT active by default — show_path() or show_aggregate()
## must be called explicitly.
##
## Implements the on-demand path overlay spec scenarios:
##   Scenario "Requesting a flow path"    → show_path()
##   Scenario "Flow overlaid on structure" → show_path() (structural nodes stay visible)
##   Scenario "Identifying a bottleneck"  → show_aggregate()
##
## Usage:
##   1. Call setup(anchors, path_edge_entries) once after the scene is built.
##   2. Call show_path(path_nodes, entry_id, terminus_id) to activate a path.
##   3. Call clear_path() to remove the overlay.
##   4. Call show_aggregate(hot_edges, bottleneck_ids) for traffic pattern overlay.
##
## Visual conventions:
##   Entry node:          Color(0.2, 1.0, 0.3, 0.9)  – bright green
##   Mid-path node:       Color(1.0, 1.0, 1.0, 0.9)  – bright white
##   Terminus node:       Color(1.0, 0.2, 0.2, 0.9)  – bright red
##   Off-path node:       Color(0.3, 0.3, 0.3, 0.3)  – dimmed (alpha=0.3)
##   Path edge:           Color(0.0, 0.9, 1.0)        – cyan
##   High-traffic edge:   Color(1.0, 0.5, 0.0)        – orange (traffic >= 500)
##   Medium-traffic edge: Color(1.0, 0.8, 0.0)        – yellow (traffic >= 100)
##   Bottleneck overlay:  Color(1.0, 0.0, 0.0, 0.6)  – red translucent box

## Traffic thresholds for aggregate overlay prominence.
const TRAFFIC_HIGH: int = 500
const TRAFFIC_MEDIUM: int = 100

## Path-node colours.
const ENTRY_COLOR    := Color(0.2, 1.0, 0.3, 0.9)
const TERMINUS_COLOR := Color(1.0, 0.2, 0.2, 0.9)
const ACTIVE_COLOR   := Color(1.0, 1.0, 1.0, 0.9)
const DIMMED_COLOR   := Color(0.3, 0.3, 0.3, 0.3)

## Edge / overlay colours.
const PATH_EDGE_COLOR       := Color(0.0, 0.9, 1.0)
const HIGH_TRAFFIC_COLOR    := Color(1.0, 0.5, 0.0)
const MEDIUM_TRAFFIC_COLOR  := Color(1.0, 0.8, 0.0)
const BOTTLENECK_COLOR      := Color(1.0, 0.0, 0.0, 0.6)

## id → Node3D anchor (set by setup()).
var _anchors: Dictionary = {}

## Array of {visual: Node3D, source: String, target: String} (set by setup()).
var _path_edges: Array = []

## True when a path or aggregate overlay is currently shown.
var _path_active: bool = false

## Saved anchor materials: anchor_node → original material_override.
var _saved_anchor_mats: Dictionary = {}

## Saved edge states: [{visual, orig_visible, orig_mat}].
var _saved_edge_vis: Array = []

## MeshInstance3D nodes added as bottleneck overlays (tracked for cleanup).
var _bottleneck_overlays: Array = []


## Register the scene's anchors and edge visuals for overlay management.
## anchors:         Dictionary mapping node_id (String) → Node3D anchor.
## path_edge_entries: Array of {visual: Node3D, source: String, target: String}.
func setup(anchors: Dictionary, path_edge_entries: Array) -> void:
	_anchors = anchors
	_path_edges = path_edge_entries


## Highlight the given path through the structural space.
## path_nodes: ordered Array[String] of node IDs from entry to terminus.
## entry_id:   first node in the path (rendered green).
## terminus_id: last node in the path (rendered red).
## Mid-path nodes are rendered bright white.
## Off-path nodes are de-emphasised (dimmed material, still visible).
## Edges between consecutive path nodes are highlighted cyan; others hidden.
func show_path(path_nodes: Array, entry_id: String, terminus_id: String) -> void:
	if path_nodes.is_empty():
		return
	_path_active = true

	var in_path: Dictionary = {}
	for nid: String in path_nodes:
		in_path[nid] = true

	# ── Node materials ─────────────────────────────────────────────────────────
	for nid: String in _anchors:
		var anchor: Node3D = _anchors[nid]
		var mesh_inst: MeshInstance3D = _first_mesh(anchor)
		if mesh_inst == null:
			continue
		_saved_anchor_mats[anchor] = mesh_inst.material_override
		var mat := StandardMaterial3D.new()
		if in_path.has(nid):
			if nid == entry_id:
				mat.albedo_color = ENTRY_COLOR
			elif nid == terminus_id:
				mat.albedo_color = TERMINUS_COLOR
			else:
				mat.albedo_color = ACTIVE_COLOR
		else:
			# De-emphasise: dim the colour and reduce opacity so off-path structure
			# remains visible (structural context is preserved, not hidden).
			mat.albedo_color = DIMMED_COLOR
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = mat

	# ── Edge visuals ───────────────────────────────────────────────────────────
	_saved_edge_vis.clear()
	for entry: Dictionary in _path_edges:
		var visual: Node3D = entry["visual"]
		var orig_mat: Material = null
		if visual is MeshInstance3D:
			orig_mat = (visual as MeshInstance3D).material_override
		_saved_edge_vis.append({"visual": visual, "orig_visible": visual.visible, "orig_mat": orig_mat})

		if in_path.has(entry["source"]) and in_path.has(entry["target"]):
			visual.visible = true
			# Highlight path edges with a distinct cyan so the path is traceable.
			if visual is MeshInstance3D:
				var emat := StandardMaterial3D.new()
				emat.albedo_color = PATH_EDGE_COLOR
				emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				(visual as MeshInstance3D).material_override = emat
		else:
			# Hide non-path edges to reduce visual noise.
			visual.visible = false


## Remove all overlays and restore original materials and visibility.
func clear_path() -> void:
	_path_active = false

	for anchor: Node3D in _saved_anchor_mats:
		var mesh_inst: MeshInstance3D = _first_mesh(anchor)
		if mesh_inst != null:
			mesh_inst.material_override = _saved_anchor_mats[anchor]
	_saved_anchor_mats.clear()

	for state: Dictionary in _saved_edge_vis:
		var visual: Node3D = state["visual"]
		visual.visible = state["orig_visible"]
		if visual is MeshInstance3D and state.has("orig_mat"):
			(visual as MeshInstance3D).material_override = state["orig_mat"]
	_saved_edge_vis.clear()

	for overlay: Node3D in _bottleneck_overlays:
		if is_instance_valid(overlay):
			var p: Node = overlay.get_parent()
			if p != null:
				p.remove_child(overlay)
			overlay.free()
	_bottleneck_overlays.clear()


## Overlay aggregate traffic patterns on the structural geography.
## All structural nodes remain fully visible (aggregate adds prominence, not hiding).
## hot_edges:       Array of {source: String, target: String, traffic: int}.
##   traffic >= TRAFFIC_HIGH   → orange (very high prominence).
##   traffic >= TRAFFIC_MEDIUM → yellow (medium prominence).
## bottleneck_ids:  Array[String] of node IDs at constriction points.
##   Each bottleneck anchor receives a red translucent "BottleneckOverlay" child.
func show_aggregate(hot_edges: Array, bottleneck_ids: Array) -> void:
	_path_active = true

	# Build lookup: "source|target" → traffic count.
	var traffic_map: Dictionary = {}
	for he: Dictionary in hot_edges:
		var key := "%s|%s" % [he["source"], he["target"]]
		traffic_map[key] = int(he.get("traffic", 0))

	# Apply prominence colour to hot edges.
	for entry: Dictionary in _path_edges:
		var visual: Node3D = entry["visual"]
		var key := "%s|%s" % [entry["source"], entry["target"]]
		if traffic_map.has(key):
			var t: int = traffic_map[key]
			if visual is MeshInstance3D:
				var emat := StandardMaterial3D.new()
				emat.albedo_color = HIGH_TRAFFIC_COLOR if t >= TRAFFIC_HIGH else MEDIUM_TRAFFIC_COLOR
				emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				(visual as MeshInstance3D).material_override = emat

	# Mark bottleneck nodes with a red translucent overlay box.
	for nid: String in bottleneck_ids:
		if _anchors.has(nid):
			var anchor: Node3D = _anchors[nid]
			var overlay := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			var omat := StandardMaterial3D.new()
			omat.albedo_color = BOTTLENECK_COLOR
			omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			overlay.mesh = box
			overlay.material_override = omat
			overlay.name = "BottleneckOverlay"
			anchor.add_child(overlay)
			_bottleneck_overlays.append(overlay)


## Returns true when a path or aggregate overlay is currently active.
func is_path_active() -> bool:
	return _path_active


## Returns the first MeshInstance3D child of anchor, or null if none found.
func _first_mesh(anchor: Node3D) -> MeshInstance3D:
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null
