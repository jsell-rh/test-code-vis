extends Node3D

## Main scene controller for CodeVis.
##
## Loads the JSON scene graph produced by the Python extractor via SceneGraphLoader
## and procedurally builds the 3D visualisation:
##   - bounded-context nodes  → large translucent boxes (membrane opacity reflects
##     public/private symbol ratio — spec §Container membrane permeability)
##   - module nodes           → smaller opaque boxes nested inside their context
##   - edges                  → coloured geometry with weight-based thickness and
##     line style encoding edge type (solid=calls, dashed=imports, dotted=inheritance)
##     (spec §Edge Primitive — FAIL-1 thickness, FAIL-2 line style)
##   - ubiquitous edges       → suppressed by default; toggled with T key
##     (spec §Power Rail Notation — FAIL-3/4 suppression, FAIL-5 toggle)
##
## Level-of-detail (LOD) is applied every frame via LodManager:
##   far distance  → only bounded_context nodes visible
##   medium distance → bounded_context + module nodes visible
##   near distance  → all nodes and edges visible (finest detail)
##
## The JSON file path is configurable via the exported variable.

const SceneGraphLoader = preload("res://scripts/scene_graph_loader.gd")
const LodManager = preload("res://scripts/lod_manager.gd")
const UnderstandingOverlay = preload("res://scripts/understanding_overlay.gd")
const VisualPrimitives = preload("res://scripts/visual_primitives.gd")
const NodePrimitive = preload("res://scripts/node_primitive.gd")
const PortPrimitive = preload("res://scripts/port_primitive.gd")

@export var scene_graph_path: String = "res://data/scene_graph.json"

## Node id → Node3D anchor that owns the volume and label.
var _anchors: Dictionary = {}

## Node id → world-space centre Vector3 (computed from relative positions).
var _world_positions: Dictionary = {}

## The parsed scene graph.
var _graph: Dictionary = {}

## LOD manager instance — controls visibility based on camera distance.
var _lod: LodManager = LodManager.new()

## Entries for LOD: Array of {anchor: Node3D, node_type: String}
var _lod_node_entries: Array = []

## Entries for LOD: Array of {visual: Node3D, edge_type: String}
var _lod_edge_entries: Array = []

## Entries for edge direction tracking: Array of {visual: Node3D, source: String, target: String}
## Used to verify dependency direction (which component depends on which).
var _path_edge_entries: Array = []

## Aggregate edge visuals — shown at FAR LOD only.
## One MeshInstance3D line per (source_context, target_context) pair, with
## visual weight proportional to total import count between the two contexts.
## Implements specs/visualization/spatial-structure.spec.md § "Far — bounded
## context architecture": "cross-context dependencies are shown as single
## aggregate edges per context pair, with weight indicating total import count".
var _aggregate_edge_visuals: Array = []

## Tracks whether the last LOD update placed the camera at FAR distance.
## Used to avoid recreating Tweens every frame — only animate on transitions.
var _was_at_far_lod: bool = false

## Understanding overlay controller — activates alignment, quality, and impact overlays.
var _understanding_overlay: UnderstandingOverlay = UnderstandingOverlay.new()

## Visual primitives renderer — attaches badge, landmark, and power rail decorations.
var _visual_primitives: VisualPrimitives = VisualPrimitives.new()

## Node Primitive renderer — populates anchors for function/method/class nodes.
## Spec: visual-primitives.spec.md § Requirement: Node Primitive
## "Nodes do not have baked-in types — their visual identity comes entirely from Badges."
var _node_primitive: NodePrimitive = NodePrimitive.new()

## Port Primitive renderer — anchors ports to Container membranes for public functions.
## Spec: visual-primitives.spec.md § Requirement: Port Primitive
## "a small visual element anchored to a Container's membrane"
var _port_primitive: PortPrimitive = PortPrimitive.new()

## Index of raw node data by ID — populated in build_from_graph(), used by _create_volume()
## to let the Port Primitive match function child nodes when overriding world positions.
var _node_data_map: Dictionary = {}

## Tracks Node3D visuals for suppressed ubiquitous edges.
## These are created but hidden by default; toggled with the T key.
## spec §Power Rail Notation — "the Edge is NOT drawn" (hidden by default)
## spec §Power Rail Toggle — "all suppressed ubiquitous edges fade in" (T to reveal)
var _ubiquitous_edge_visuals: Array = []

## Whether ubiquitous edges are currently shown (toggled by T key).
var _ubiquitous_edges_visible: bool = false

## Cluster collapse state.
##
## Maps cluster_id (String) → Array of member node IDs (Array[String]).
## A cluster that the human has collapsed is recorded here so that:
##   - expand_cluster() knows which members to restore;
##   - edge re-routing code knows which nodes are currently supernodes.
##
## Spec: spatial-structure.spec.md § Cluster Collapsing —
##   "AND the supernode displays aggregate metrics"
##   "AND edges that formerly entered or left any member … are re-routed to the supernode"
var _collapsed_clusters: Dictionary = {}

## Edge re-route state saved during cluster collapse.
##
## Maps cluster_id (String) → Array of {entry_index, orig_from, orig_to} dictionaries.
## Populated by collapse_cluster() so expand_cluster() can restore original endpoints.
##
## Spec: spatial-structure.spec.md § Expanding a supernode —
##   "edges re-route back to their original endpoints with smooth animation"
var _cluster_edge_reroutes: Dictionary = {}

## The parsed cluster suggestion list loaded with the scene graph.
## Each entry follows the Cluster TypedDict: {id, members, context, aggregate_metrics}.
var _cluster_suggestions: Array = []

@onready var _camera: Camera3D = $Camera3D


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _ready() -> void:
	if FileAccess.file_exists(scene_graph_path):
		var file := FileAccess.open(scene_graph_path, FileAccess.READ)
		if file == null:
			push_error("Cannot open scene graph: " + scene_graph_path)
			return
		var json_text := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(json_text) != OK:
			push_error("JSON parse error: " + json.get_error_message())
			return
		_graph = SceneGraphLoader.load_from_dict(json.data)
		build_from_graph(_graph)
	else:
		push_warning("CodeVis: scene graph not found at '%s'." % scene_graph_path)

## Build the 3D scene from a parsed scene-graph dictionary.
## Called from _ready() at startup and from tests directly.
## Caches the graph so overlay functions (_apply_alignment_overlay, etc.) can
## access node/edge data after the scene has been built.
##
## Smooth regrouping: if anchors already exist (this is a reload), node positions
## are animated smoothly to their new values — nodes slide rather than jump.
## This satisfies the spec requirement: "nodes animate smoothly to their new
## positions, preserving spatial continuity" when independence groups change.
func build_from_graph(graph: Dictionary) -> void:
	# Cache graph so overlay functions can use it even when called from tests.
	_graph = graph
	var nodes: Array = graph.get("nodes", [])
	var edges: Array = graph.get("edges", [])

	# Index raw node data for fast lookup.
	var node_data_map: Dictionary = {}
	for nd: Dictionary in nodes:
		node_data_map[nd["id"]] = nd

	# Cache node_data_map so _create_volume() can pass it to PortPrimitive for
	# edge-wiring: port creation overrides world positions of child function nodes.
	_node_data_map = node_data_map

	# Detect reload: if anchors already exist, animate positions instead of recreating.
	var is_reload: bool = not _anchors.is_empty()

	# Clear and recompute world positions for the new graph.
	_world_positions.clear()
	_compute_world_positions(nodes, node_data_map)

	# Create or animate volumes: parents first so children can be parented to them.
	for nd: Dictionary in nodes:
		if nd["parent"] == null:
			if is_reload and _anchors.has(nd["id"]):
				# Anchor already exists: animate to new position for smooth regrouping.
				_animate_node_to_position(nd)
			else:
				_create_volume(nd, self)
	for nd: Dictionary in nodes:
		if nd["parent"] != null:
			if is_reload and _anchors.has(nd["id"]):
				# Anchor already exists: animate to new position for smooth regrouping.
				_animate_node_to_position(nd)
			else:
				var parent_anchor: Node3D = _anchors.get(nd["parent"])
				if parent_anchor != null:
					_create_volume(nd, parent_anchor)
				else:
					push_warning("CodeVis: parent '%s' not found for '%s'." % [nd["parent"], nd["id"]])
					_create_volume(nd, self)

	# Recreate edge visuals (always fresh — they depend on current world positions).
	if is_reload:
		for entry: Dictionary in _lod_edge_entries:
			(entry["visual"] as Node3D).queue_free()
		_lod_edge_entries.clear()
		_path_edge_entries.clear()
		for vis: Node3D in _ubiquitous_edge_visuals:
			vis.queue_free()
		_ubiquitous_edge_visuals.clear()
		_ubiquitous_edges_visible = false

	# Create edge lines after all volumes exist.
	for ed: Dictionary in edges:
		_create_edge(ed)

	# Build aggregate edges (one line per context pair, shown at FAR LOD).
	_build_aggregate_edges(edges)

	# Load cluster suggestions (pre-computed by extractor) and apply visual hints.
	# Spec: spatial-structure.spec.md § Pre-computed cluster suggestions —
	#   "suggested clusters are indicated visually (e.g. subtle shared tint)"
	#   "suggestions never auto-collapse — the human always initiates"
	_cluster_suggestions = graph.get("clusters", [])
	_apply_cluster_suggestions(_cluster_suggestions)

	# Reposition camera to frame the whole graph.
	_frame_camera()

	# Apply initial LOD pass so visibility is correct before any _process tick.
	_update_lod()


## Animate an existing anchor node to the position specified in *nd*.
##
## spec: "nodes animate smoothly to their new positions" (smooth regrouping).
## When the node is in the scene tree, a Tween slides the anchor.
## When not in the tree (unit tests), the position is set directly.
func _animate_node_to_position(nd: Dictionary) -> void:
	var anchor: Node3D = _anchors.get(nd["id"])
	if anchor == null:
		return
	var p: Dictionary = nd["position"]
	var new_pos := Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	if anchor.position.is_equal_approx(new_pos):
		return
	if is_inside_tree():
		# spec: "nodes slide rather than jump" — Tween preserves spatial continuity.
		var tween: Tween = create_tween()
		tween.tween_property(anchor, "position", new_pos, 0.5)
	else:
		# Not in scene tree (unit tests): set position directly.
		anchor.position = new_pos


## Return the internal anchors dictionary (node id → Node3D).
## Exposed for tests that verify smooth regrouping preserves anchor identity.
func get_anchors() -> Dictionary:
	return _anchors


## Return the internal world-positions dictionary (node id → Vector3).
## Exposed for tests that verify port edge-wiring overrides function world positions.
func get_world_positions() -> Dictionary:
	return _world_positions


# ---------------------------------------------------------------------------
# Per-frame LOD update
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_lod()


## Query the camera's current distance and apply LOD visibility accordingly.
## Aggregate edges use Tween-based opacity animation so they fade in at FAR
## and fade out at MEDIUM/NEAR — implementing the smooth-transition requirement.
## Spec: "elements fade in or out with animated opacity, never appearing or
## disappearing instantly" (spatial-structure.spec.md § Smooth transitions).
func _update_lod() -> void:
	if _camera == null or not _camera.has_method("get_distance"):
		return
	var dist: float = _camera.call("get_distance")
	_lod.update_lod(_lod_node_entries, _lod_edge_entries, dist)
	# Aggregate edges: shown only at FAR (individual edges are suppressed there).
	# Animate modulate.a so they fade in/out rather than appear or vanish instantly.
	var at_far_lod: bool = dist > LodManager.FAR_THRESHOLD
	if at_far_lod != _was_at_far_lod:
		var target_alpha: float = 1.0 if at_far_lod else 0.0
		for agg_visual: Node3D in _aggregate_edge_visuals:
			# Animate the material's albedo alpha — MeshInstance3D is a 3D node and
			# does not have a 2D modulate property; opacity is controlled via material.
			var tween := create_tween()
			tween.tween_property(
				(agg_visual as MeshInstance3D).material_override,
				"albedo_color:a",
				target_alpha,
				0.25
			)
		_was_at_far_lod = at_far_lod


# ---------------------------------------------------------------------------
# World-position helpers
# ---------------------------------------------------------------------------

func _compute_world_positions(nodes: Array, node_data_map: Dictionary) -> void:
	for nd: Dictionary in nodes:
		if not _world_positions.has(nd["id"]):
			_world_positions[nd["id"]] = _resolve_world_pos(nd, node_data_map)


func _resolve_world_pos(nd: Dictionary, node_data_map: Dictionary) -> Vector3:
	var p: Dictionary = nd["position"]
	var local := Vector3(float(p["x"]), float(p["y"]), float(p["z"]))

	if nd["parent"] == null:
		return local

	var parent_id: String = nd["parent"]
	if _world_positions.has(parent_id):
		return _world_positions[parent_id] + local

	# Resolve parent recursively (handles arbitrary nesting depth).
	var parent_nd: Dictionary = node_data_map.get(parent_id, {})
	if parent_nd.is_empty():
		return local

	var parent_world := _resolve_world_pos(parent_nd, node_data_map)
	_world_positions[parent_id] = parent_world
	return parent_world + local


# ---------------------------------------------------------------------------
# Volume creation
# ---------------------------------------------------------------------------

func _create_volume(nd: Dictionary, parent_node: Node3D) -> void:
	var anchor := Node3D.new()
	# Node name matches node id (dots replaced for GDScript compatibility).
	anchor.name = (nd["id"] as String).replace(".", "_")

	var p: Dictionary = nd["position"]
	anchor.position = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
	parent_node.add_child(anchor)
	_anchors[nd["id"]] = anchor

	# ── Landmark check (visual-primitives.spec.md § Landmark Primitive) ──────
	# Landmark nodes are always visible at every LOD level so the human can
	# always use them as spatial orientation anchors.
	# Spec § Landmark sources: "Landmarks are derived from:
	#   hubs (high in-degree),
	#   bridges (high betweenness centrality),
	#   entry points (no in-edges from application code)"
	# Achieved by NOT registering landmarks in _lod_node_entries so the LOD
	# manager never hides them.
	var is_hub: bool = bool(nd.get("is_hub", false))
	# is_bridge=true → graph articulation point (bridge) → → landmark
	var is_bridge: bool = bool(nd.get("is_bridge", false))
	# in_degree=0 AND parent=null → no application code imports this BC → entry point → landmark
	var in_deg: int = int(nd.get("in_degree", -1))
	var is_entry_point: bool = (in_deg == 0 and nd.get("parent") == null)
	var is_landmark: bool = is_hub or is_bridge or is_entry_point
	if not is_landmark:
		# Register with LOD manager so visibility can be toggled by camera distance.
		_lod_node_entries.append({"anchor": anchor, "node_type": nd["type"]})
	# Landmark nodes are omitted from _lod_node_entries: the LOD manager never
	# hides them, so they remain visible at all zoom levels (FAR / MEDIUM / NEAR).

	var sz: float = float(nd["size"])
	var node_type: String = nd["type"]
	var is_context: bool = node_type == "bounded_context"
	var is_spec: bool = node_type == "spec"

	# ── Node Primitive (function / method / class) ────────────────────────────
	# Spec § Requirement: Node Primitive — "Nodes do not have baked-in types —
	# their visual identity comes entirely from their Badges."
	# NodePrimitive.populate_anchor() creates the mesh AND the label for these
	# types, so we skip the generic inline mesh/label block below.
	if NodePrimitive.handles(node_type) and not is_landmark:
		_node_primitive.populate_anchor(anchor, nd, sz)
	else:
		# Mesh ----------------------------------------------------------------
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()

		var mat := StandardMaterial3D.new()
		if is_landmark:
			# Landmark nodes (hubs): enlarged bright-white box so they stand out as
			# spatial anchors at every zoom level.
			# Spec: "distinctive visual treatment (larger, brighter, or marked with a glyph)"
			var landmark_sz: float = sz * 1.5
			box.size = Vector3(landmark_sz, landmark_sz * 0.6, landmark_sz)
			mat.albedo_color = Color(1.0, 0.95, 0.30, 1.0)  # bright yellow-white
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.75, 0.0)
			mat.emission_energy_multiplier = 0.4
		elif is_spec:
			# Spec nodes represent the *intended design* — rendered as thin gold slabs
			# so the human can immediately distinguish them from the realized code nodes.
			# Gold colour signals "intended / authoritative specification".
			box.size = Vector3(sz, sz * 0.15, sz)
			mat.albedo_color = Color(0.95, 0.80, 0.10, 0.55)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		elif is_context:
			# Larger, flat, translucent slab — acts as a visible floor/boundary.
			box.size = Vector3(sz, sz * 0.2, sz)
			# spec §Container membrane permeability:
			#   "the membrane appears thick/opaque (strong encapsulation — few openings)"
			#   "a module with 25 public symbols has a thin/porous membrane"
			#   "permeability is a continuous visual property, not a binary toggle"
			# alpha = 1 - public_ratio: many public symbols → porous (low alpha),
			#                           few public symbols → opaque (high alpha).
			var symbols: Array = nd.get("symbols", [])
			var alpha: float = 0.18  # default when symbol data is absent
			if symbols.size() > 0:
				var public_count: int = 0
				for sym: Dictionary in symbols:
					if sym.get("visibility", "") == "public":
						public_count += 1
				var public_ratio: float = float(public_count) / float(symbols.size())
				# Invert: high public ratio → porous (low alpha); low ratio → opaque (high alpha).
				alpha = clampf(1.0 - public_ratio, 0.05, 0.55)
			mat.albedo_color = Color(0.25, 0.45, 0.85, alpha)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			# Show both sides so the translucent slab is visible from above and below.
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		else:
			# Compact, opaque box for modules — height proportional to size.
			box.size = Vector3(sz, sz * 0.6, sz)
			mat.albedo_color = Color(0.35, 0.70, 0.40, 1.0)

		mesh_instance.mesh = box
		mesh_instance.material_override = mat
		anchor.add_child(mesh_instance)

		# Label ---------------------------------------------------------------
		var label := Label3D.new()
		label.text = nd["name"]
		# pixel_size controls real-world text size; must be > 0 for legibility.
		label.pixel_size = 0.012
		label.position = Vector3(0.0, sz * 0.15 + 0.4, 0.0)
		# Always face the camera (mandatory for legibility in 3D).
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Draw on top so labels remain visible through geometry.
		label.no_depth_test = true
		anchor.add_child(label)

	# ── Port Primitive (visual-primitives.spec.md § Requirement: Port Primitive) ──
	# Place Ports on the membrane of Container nodes (module, bounded_context).
	# Ports represent public function interface points anchored to the outer boundary.
	# Spec: "a small visual element anchored to a Container's membrane"
	# Spec: "Ports are hidden [at far] AND as the human zooms in, Ports fade in"
	# Only create ports for Container-type nodes (not Node Primitive function/class nodes).
	if not NodePrimitive.handles(node_type) and not is_landmark:
		var port_entries: Array = _port_primitive.add_ports_to_container(
			anchor,
			nd,
			sz,
			_world_positions.get(nd["id"], Vector3.ZERO),
			_world_positions,
			_node_data_map
		)
		# Register each port with the LOD manager so it is hidden at FAR/MEDIUM
		# and shown at NEAR — matching the LOD Shell tier-2 behavior for ports.
		for port_entry: Dictionary in port_entries:
			_lod_node_entries.append(port_entry)

	# Visual primitives — badge glyphs, landmark ring, power rail disc.
	# Spec: visual-primitives.spec.md §Badge Primitive, §Landmark Primitive,
	# §Power Rail Notation.
	# Applied to ALL node types (including NodePrimitive function/class/method nodes).
	_visual_primitives.attach_primitives(nd, anchor, sz)


## Add a Power Rail indicator glyph to an anchor node.
##
## The indicator is a small bright-magenta sphere positioned at the base of
## the anchor so the human can see at a glance that this node has suppressed
## ubiquitous dependencies.
##
## Spec: visual-primitives.spec.md § Power Rail Notation —
## "each Node that imports [a ubiquitous dep] has a small, consistent
## indicator (e.g. a tiny rail glyph at its base)"
func _add_power_rail_indicator(anchor: Node3D, node_sz: float) -> void:
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = maxf(0.2, node_sz * 0.12)
	sphere_mesh.height = sphere_mesh.radius * 2.0
	sphere_mesh.radial_segments = 6
	sphere_mesh.rings = 4

	var rail_mat := StandardMaterial3D.new()
	# Bright magenta rail glyph — visually consistent across all nodes.
	rail_mat.albedo_color = Color(0.9, 0.1, 0.9, 1.0)
	rail_mat.emission_enabled = true
	rail_mat.emission = Color(0.6, 0.0, 0.6)
	rail_mat.emission_energy_multiplier = 0.5

	var rail_indicator := MeshInstance3D.new()
	rail_indicator.name = "PowerRailIndicator"
	rail_indicator.mesh = sphere_mesh
	rail_indicator.material_override = rail_mat
	# Position at the base of the anchor (slightly below the mesh centre).
	rail_indicator.position = Vector3(0.0, -(node_sz * 0.35 + sphere_mesh.radius), 0.0)
	anchor.add_child(rail_indicator)


# ---------------------------------------------------------------------------
# Aggregate edge grouping (visual-primitives.spec.md §Power Rail Notation,
# spatial-structure.spec.md §Far — bounded context architecture)
# ---------------------------------------------------------------------------

## Group edges by their (source_context, target_context) context pair and sum
## import counts.  Returns a dict keyed by "src_ctx→tgt_ctx" → { weight: int }.
##
## Used to verify that aggregate edges are correctly grouped at FAR distance.
## Spec: "cross-context dependencies are shown as single aggregate edges per
## context pair, with weight indicating total import count"
func _build_edges_by_context(edges: Array) -> Dictionary:
	# edges_by_context: maps "source_context→target_context" → summed weight.
	var edges_by_context: Dictionary = {}
	for ed: Dictionary in edges:
		if ed["type"] != "aggregate":
			continue
		var context_pair: String = "%s→%s" % [ed["source"], ed["target"]]
		var existing_weight: int = edges_by_context.get(context_pair, {}).get("weight", 0)
		edges_by_context[context_pair] = {
			"source": ed["source"],
			"target": ed["target"],
			"weight": existing_weight + int(ed.get("weight", 1))
		}
	return edges_by_context


# ---------------------------------------------------------------------------
# Edge creation helpers
# ---------------------------------------------------------------------------

## Determine the line style for an edge based on its type.
##
## spec §Edge Primitive §Scenario: Edge type distinction —
##   "edge type is encoded by line style (solid for calls, dashed for imports,
##    dotted for inheritance)"
##
## Mapping:
##   direct_call, dynamic_call → "solid"
##   cross_context, internal, aggregate → "dashed"  (import-based)
##   inherits, has_a → "dotted"
func _edge_line_style(edge_type: String) -> String:
	match edge_type:
		"direct_call", "dynamic_call":
			return "solid"
		"inherits", "has_a":
			return "dotted"
		_:
			# cross_context, internal, aggregate and any unknown type → dashed
			return "dashed"


## Choose the line colour for an edge based on its type.
func _edge_color(edge_type: String) -> Color:
	match edge_type:
		"cross_context", "aggregate":
			return Color(1.0, 0.50, 0.10)   # orange: cross-boundary import
		"direct_call", "dynamic_call":
			return Color(0.30, 0.75, 1.00)  # light blue: call graph
		"inherits", "has_a":
			return Color(0.90, 0.80, 0.20)  # gold: type relationship
		_:
			return Color(0.55, 0.55, 0.55)  # grey: internal import / unknown


## Orient a Node3D so its +Y axis aligns with *dir*.
## CylinderMesh default height is along +Y; rotating +Y → dir aligns the
## cylinder with the edge direction.
func _orient_to_dir(node: Node3D, dir: Vector3) -> void:
	if dir.is_equal_approx(-Vector3.UP):
		# Degenerate case: exact down direction — use 180° rotation around X.
		node.basis = Basis.from_euler(Vector3(PI, 0.0, 0.0))
	elif not dir.is_equal_approx(Vector3.UP):
		node.basis = Basis(Quaternion(Vector3.UP, dir))
	# else dir == UP: identity basis (no rotation needed).


## Create the visual body for a SOLID edge — one CylinderMesh spanning from→to.
##
## spec §Edge Primitive §Scenario: Weighted edge —
##   "its visual thickness is proportional to the weight"
##   "a single-import Edge is visibly thinner than a 12-import Edge"
## The cylinder radius encodes weight: radius = BASE_RADIUS * (1 + weight/10).
func _create_solid_body(
	from_pos: Vector3, to_pos: Vector3, radius: float, color: Color
) -> MeshInstance3D:
	var dir: Vector3 = (to_pos - from_pos).normalized()
	var length: float = from_pos.distance_to(to_pos)

	var cyl := CylinderMesh.new()
	cyl.height = length
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.radial_segments = 6
	cyl.rings = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var body := MeshInstance3D.new()
	body.mesh = cyl
	body.material_override = mat
	_orient_to_dir(body, dir)
	body.position = (from_pos + to_pos) * 0.5
	return body


## Create the visual body for a DASHED edge — alternating CylinderMesh segments.
## Each segment is ~60% of the dash unit; 40% is gap.
##
## spec §Edge Primitive §Scenario: Edge type distinction —
##   "dashed for imports" (cross_context, internal)
func _create_dashed_body(
	from_pos: Vector3, to_pos: Vector3, radius: float, color: Color
) -> Node3D:
	var container := Node3D.new()
	var dir: Vector3 = (to_pos - from_pos).normalized()
	var length: float = from_pos.distance_to(to_pos)

	var dash_len: float = 0.7
	var unit_len: float = 1.2  # dash + gap
	var offset: float = 0.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	while offset < length:
		var seg_len: float = minf(dash_len, length - offset)
		if seg_len < 0.05:
			break

		var cyl := CylinderMesh.new()
		cyl.height = seg_len
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.radial_segments = 5
		cyl.rings = 1

		var seg := MeshInstance3D.new()
		seg.mesh = cyl
		seg.material_override = mat
		_orient_to_dir(seg, dir)
		# Centre of this segment along the edge direction.
		seg.position = from_pos + dir * (offset + seg_len * 0.5)
		container.add_child(seg)

		offset += unit_len

	return container


## Create the visual body for a DOTTED edge — small cylinder segments with larger gaps.
##
## spec §Edge Primitive §Scenario: Edge type distinction —
##   "dotted for inheritance" (inherits, has_a)
func _create_dotted_body(
	from_pos: Vector3, to_pos: Vector3, radius: float, color: Color
) -> Node3D:
	var container := Node3D.new()
	var dir: Vector3 = (to_pos - from_pos).normalized()
	var length: float = from_pos.distance_to(to_pos)

	var dot_len: float = 0.20
	var unit_len: float = 0.55  # dot + gap
	var offset: float = 0.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	while offset < length:
		if length - offset < 0.05:
			break

		var seg_len: float = minf(dot_len, length - offset)
		var cyl := CylinderMesh.new()
		cyl.height = seg_len
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.radial_segments = 5
		cyl.rings = 1

		var seg := MeshInstance3D.new()
		seg.mesh = cyl
		seg.material_override = mat
		_orient_to_dir(seg, dir)
		seg.position = from_pos + dir * (offset + seg_len * 0.5)
		container.add_child(seg)

		offset += unit_len

	return container


# ---------------------------------------------------------------------------
# Edge creation
# ---------------------------------------------------------------------------

func _create_edge(ed: Dictionary) -> void:
	var src: String = ed["source"]
	var tgt: String = ed["target"]

	# ── Power Rail notation (visual-primitives.spec.md § Power Rail Notation) ──
	# Ubiquitous edges are suppressed from the default view to prevent clutter.
	# Instead, a small glyph (Power Rail indicator) is added to the source node
	# so the human knows the dependency exists without it cluttering the graph.
	# Spec: "no edges to [ubiquitous module] are drawn AND each Node that imports
	# [it] has a small, consistent indicator at its base."
	if bool(ed.get("ubiquitous", false)):
		var src_anchor: Node3D = _anchors.get(src)
		if src_anchor != null:
			# Only add the indicator if one doesn't already exist (deduplicate).
			var already_has_indicator: bool = false
			for child: Node in src_anchor.get_children():
				if child.name == "PowerRailIndicator":
					already_has_indicator = true
					break
			if not already_has_indicator:
				var src_data: Dictionary = {}
				for nd: Dictionary in _graph.get("nodes", []):
					if nd["id"] == src:
						src_data = nd
						break
				var nd_sz: float = float(src_data.get("size", 1.0))
				_add_power_rail_indicator(src_anchor, nd_sz)
		# Do NOT return — continue to create a hidden body tracked in
		# _ubiquitous_edge_visuals so it can be toggled on/off by the human.
		# spec §Power Rail Toggle: "all suppressed ubiquitous edges fade in"

	if not _world_positions.has(src) or not _world_positions.has(tgt):
		push_warning("CodeVis: skipping edge '%s' → '%s' (node missing)." % [src, tgt])
		return

	var from_pos: Vector3 = _world_positions[src]
	var to_pos: Vector3 = _world_positions[tgt]

	if from_pos.is_equal_approx(to_pos):
		return  # Self-loop or co-located nodes — nothing to draw.

	var edge_type: String = ed["type"]
	var weight: int = int(ed.get("weight", 1))
	var is_ubiquitous: bool = ed.get("ubiquitous", false)

	var line_style: String = _edge_line_style(edge_type)
	var line_color: Color = _edge_color(edge_type)

	# spec §Edge Primitive §Scenario: Weighted edge —
	# "its visual thickness is proportional to the weight (12)"
	# "a single-import Edge is visibly thinner than a 12-import Edge"
	# Radius encodes weight: base 0.06 units, scaled proportionally with weight.
	const BASE_RADIUS: float = 0.06
	var radius: float = clampf(BASE_RADIUS * (1.0 + float(weight) / 10.0), BASE_RADIUS, BASE_RADIUS * 4.0)

	var dir: Vector3 = (to_pos - from_pos).normalized()

	# Build the edge body according to line style.
	# Each body node carries line_style and edge_weight metadata for test assertions.
	var body: Node3D
	match line_style:
		"solid":
			body = _create_solid_body(from_pos, to_pos, radius, line_color)
		"dotted":
			body = _create_dotted_body(from_pos, to_pos, radius, line_color)
		_:  # "dashed" — import-based edges
			body = _create_dashed_body(from_pos, to_pos, radius, line_color)

	# Tag the body so tests can verify the correct perceptual channel is used.
	body.set_meta("line_style", line_style)
	body.set_meta("edge_weight", weight)
	body.name = "EdgeLine"

	if is_ubiquitous:
		# spec §Power Rail Notation §Scenario: Standard library power rail —
		# "no edges to logging are drawn" — hidden initially, toggled via T.
		body.visible = false
		add_child(body)
		_ubiquitous_edge_visuals.append(body)
	else:
		add_child(body)
		_lod_edge_entries.append({"visual": body, "edge_type": edge_type})
		# Store from_pos/to_pos and role so re-routing can rebuild the geometry.
		_path_edge_entries.append({
			"visual": body, "source": src, "target": tgt,
			"from_pos": from_pos, "to_pos": to_pos,
			"role": "body", "line_style": line_style,
			"radius": radius, "color": line_color,
		})

	# Arrowhead: a cone (CylinderMesh, top_radius=0 = pointed tip) placed at the
	# target end, oriented along the edge direction, indicating dependency flow.
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0       # pointed tip at +Y
	cone_mesh.bottom_radius = 0.25
	cone_mesh.height = 0.7
	cone_mesh.radial_segments = 8

	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = line_color
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var arrow := MeshInstance3D.new()
	arrow.mesh = cone_mesh
	arrow.material_override = cone_mat
	# Rotate so the cone's +Y (tip) aligns with the edge direction.
	_orient_to_dir(arrow, dir)
	# Centre the cone so its tip lands exactly at to_pos.
	arrow.position = to_pos - dir * (cone_mesh.height * 0.5)

	if is_ubiquitous:
		arrow.visible = false
		add_child(arrow)
		_ubiquitous_edge_visuals.append(arrow)
	else:
		add_child(arrow)
		# Register arrowhead with LOD manager (same edge_type as the line).
		_lod_edge_entries.append({"visual": arrow, "edge_type": edge_type})
		# Track arrowhead direction for dependency direction verification.
		# Store from_pos/to_pos and role so re-routing can rebuild the geometry.
		_path_edge_entries.append({
			"visual": arrow, "source": src, "target": tgt,
			"from_pos": from_pos, "to_pos": to_pos,
			"role": "arrow", "line_style": line_style,
			"radius": radius, "color": line_color,
		})


# ---------------------------------------------------------------------------
# Edge re-routing helper
# ---------------------------------------------------------------------------

## Reposition an edge visual (body or arrow) between new world-space endpoints.
##
## Called by collapse_cluster() and expand_cluster() to re-route edge geometry
## without destroying and recreating visuals.
##
## For solid bodies (MeshInstance3D with CylinderMesh): updates height, position,
## and orientation in-place.
## For dashed/dotted containers (Node3D with segment children): frees old segments
## and recreates them between the new endpoints.
## For arrowheads (MeshInstance3D, role=="arrow"): updates position and orientation.
##
## Spec: spatial-structure.spec.md § Cluster Collapsing —
##   "edge re-routing animates smoothly — endpoints slide to the supernode
##    rather than jumping"
## In scene-tree contexts a Tween slides arrow/solid endpoints and cross-fades
## dashed/dotted segment containers. In headless (unit-test) contexts Tween is
## unavailable, so positions are set directly.
func _reposition_edge_visual(entry: Dictionary, new_from: Vector3, new_to: Vector3) -> void:
	if new_from.is_equal_approx(new_to):
		return
	var visual: Node3D = entry["visual"] as Node3D
	if visual == null:
		return
	var role: String = entry.get("role", "body")
	var new_dir: Vector3 = (new_to - new_from).normalized()

	if role == "arrow":
		# Arrowhead: reorient and reposition tip at new_to.
		var cone_height: float = 0.7
		_orient_to_dir(visual, new_dir)
		var new_pos: Vector3 = new_to - new_dir * (cone_height * 0.5)
		if is_inside_tree():
			var tween := create_tween()
			tween.tween_property(visual, "position", new_pos, 0.3)
		else:
			visual.position = new_pos
	else:
		# Body: depends on line_style.
		var line_style: String = entry.get("line_style", "dashed")
		if line_style == "solid":
			# Solid body: single MeshInstance3D with CylinderMesh.
			var mi: MeshInstance3D = visual as MeshInstance3D
			if mi != null and mi.mesh is CylinderMesh:
				var cyl: CylinderMesh = mi.mesh as CylinderMesh
				cyl.height = new_from.distance_to(new_to)
			_orient_to_dir(visual, new_dir)
			var new_mid: Vector3 = (new_from + new_to) * 0.5
			if is_inside_tree():
				var tween := create_tween()
				tween.tween_property(visual, "position", new_mid, 0.3)
			else:
				visual.position = new_mid
		else:
			# Dashed or dotted body: Node3D container with segment children.
			# In-tree: cross-fade (fade out → rebuild → fade in) so endpoints do
			# not jump.  Headless: rebuild directly (Tween unavailable in CI).
			var radius: float = entry.get("radius", 0.06)
			var color: Color = entry.get("color", Color(0.55, 0.55, 0.55))
			var ls: String = line_style  # capture for lambda
			if is_inside_tree():
				var tween := create_tween()
				tween.tween_property(visual, "modulate:a", 0.0, 0.15)
				tween.tween_callback(func() -> void:
					for child: Node in visual.get_children():
						child.queue_free()
					var rebuilt: Node3D
					if ls == "dotted":
						rebuilt = _create_dotted_body(new_from, new_to, radius, color)
					else:
						rebuilt = _create_dashed_body(new_from, new_to, radius, color)
					for child: Node in rebuilt.get_children():
						rebuilt.remove_child(child)
						visual.add_child(child)
					rebuilt.free()
				)
				tween.tween_property(visual, "modulate:a", 1.0, 0.15)
			else:
				# Headless / unit-test path: set positions directly.
				for child: Node in visual.get_children():
					child.queue_free()
				var rebuilt: Node3D
				if line_style == "dotted":
					rebuilt = _create_dotted_body(new_from, new_to, radius, color)
				else:
					rebuilt = _create_dashed_body(new_from, new_to, radius, color)
				# Transfer children from the rebuilt container into the existing visual.
				for child: Node in rebuilt.get_children():
					rebuilt.remove_child(child)
					visual.add_child(child)
				rebuilt.free()


# ---------------------------------------------------------------------------
# Power Rail Toggle
# ---------------------------------------------------------------------------

## Toggle ubiquitous edge visibility (T key).
##
## spec §Power Rail Notation §Scenario: Power rail toggle —
##   "WHEN the human toggles power rails to visible
##    THEN all suppressed ubiquitous edges fade in
##    AND the toggle is reversible"
##
## When in the scene tree, edges fade in/out via Tween on modulate.a.
## When outside the tree (unit tests), visibility is toggled directly.
func toggle_ubiquitous_edges() -> void:
	_ubiquitous_edges_visible = not _ubiquitous_edges_visible
	for vis: Node3D in _ubiquitous_edge_visuals:
		if is_inside_tree():
			if _ubiquitous_edges_visible:
				vis.visible = true
				vis.modulate.a = 0.0
			var tween: Tween = create_tween()
			var target: float = 1.0 if _ubiquitous_edges_visible else 0.0
			tween.tween_property(vis, "modulate:a", target, 0.3)
		else:
			# Unit test context: toggle visible directly.
			vis.visible = _ubiquitous_edges_visible


# ---------------------------------------------------------------------------
# Aggregate edge rendering (FAR LOD)
# ---------------------------------------------------------------------------

## Build aggregate edges: group all cross-context edges by (source_context,
## target_context) pair and render one weighted line per unique pair.
##
## Implements specs/visualization/spatial-structure.spec.md § "Far — bounded
## context architecture":
##   "cross-context dependencies are shown as single aggregate edges per
##    context pair, with weight indicating total import count"
##
## These aggregate edge visuals are stored in _aggregate_edge_visuals and shown
## only at FAR LOD; individual cross-context edges are shown at MEDIUM/NEAR.
func _build_aggregate_edges(edges: Array) -> void:
	# Build a context-id lookup: for each node, what bounded_context contains it?
	var context_of: Dictionary = {}  # node_id -> bounded_context node_id
	var nodes: Array = _graph.get("nodes", [])
	for nd: Dictionary in nodes:
		var nid: String = nd["id"]
		var ntype: String = nd["type"]
		if ntype == "bounded_context":
			context_of[nid] = nid
		else:
			var parent_id = nd.get("parent")
			if parent_id != null and context_of.has(parent_id):
				context_of[nid] = context_of[parent_id]
			elif parent_id != null:
				context_of[nid] = parent_id  # best-effort parent climb
			else:
				context_of[nid] = nid

	# Group cross-context edges by (source_context, target_context) pair.
	# edges_by_context_pair: "src_ctx|tgt_ctx" -> edge count (import weight).
	var edges_by_context_pair: Dictionary = {}
	for ed: Dictionary in edges:
		if ed.get("type", "") != "cross_context":
			continue
		if bool(ed.get("ubiquitous", false)):
			continue  # Power Rail edges suppressed even in aggregate view
		var src_ctx: String = context_of.get(ed["source"], ed["source"])
		var tgt_ctx: String = context_of.get(ed["target"], ed["target"])
		if src_ctx == tgt_ctx:
			continue  # internal edge disguised as cross_context — skip
		var context_pair: String = src_ctx + "|" + tgt_ctx
		edges_by_context_pair[context_pair] = edges_by_context_pair.get(context_pair, 0) + 1

	# Create one aggregate edge visual per context pair.
	for context_pair: String in edges_by_context_pair:
		var import_count: int = edges_by_context_pair[context_pair]
		var parts: PackedStringArray = context_pair.split("|")
		if parts.size() != 2:
			continue
		var src_ctx: String = parts[0]
		var tgt_ctx: String = parts[1]
		if not _world_positions.has(src_ctx) or not _world_positions.has(tgt_ctx):
			continue
		var from_pos: Vector3 = _world_positions[src_ctx]
		var to_pos: Vector3 = _world_positions[tgt_ctx]
		if from_pos.is_equal_approx(to_pos):
			continue

		# Bold orange line — visually distinct from individual edges (lighter orange).
		# Start fully transparent (alpha=0); _update_lod() Tweens albedo_color:a to
		# 1.0 when camera reaches FAR distance, producing a smooth fade-in.
		# Weight is proportional to import_count, clamped to [0.5, 3.0].
		var imesh := ImmediateMesh.new()
		imesh.surface_begin(Mesh.PRIMITIVE_LINES)
		imesh.surface_add_vertex(from_pos)
		imesh.surface_add_vertex(to_pos)
		imesh.surface_end()

		var agg_mat := StandardMaterial3D.new()
		agg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Transparency required so albedo_color:a can be animated from 0→1.
		agg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		agg_mat.albedo_color = Color(1.0, 0.60, 0.15, 0.0)  # bold orange, start transparent

		var agg_visual := MeshInstance3D.new()
		agg_visual.name = "AggregateEdge_" + context_pair.replace("|", "_")
		agg_visual.mesh = imesh
		agg_visual.material_override = agg_mat
		# Scale line proportional to import_count — weight indicates total import count.
		var weight: float = clampf(float(import_count) * 0.4, 0.5, 3.0)
		agg_visual.scale = Vector3(weight, 1.0, weight)
		add_child(agg_visual)
		_aggregate_edge_visuals.append(agg_visual)


# ---------------------------------------------------------------------------
# Cluster suggestions and collapsing
# (specs/visualization/spatial-structure.spec.md § Cluster Collapsing)
# ---------------------------------------------------------------------------

## Apply visual tint to cluster member nodes so the human can see pre-computed
## cluster suggestions without any auto-collapse.
##
## Spec: spatial-structure.spec.md § Pre-computed cluster suggestions —
##   "suggested clusters are indicated visually (e.g. subtle shared tint
##    or proximity grouping)"
##   "suggestions never auto-collapse — the human always initiates"
##
## Implementation: for each cluster suggestion, a semi-transparent "ClusterTint"
## overlay (small coloured MeshInstance3D) is added to every member anchor so
## the human can see which modules belong to the same suggested cluster.
## All member anchors remain fully visible (no auto-collapse).
func _apply_cluster_suggestions(clusters: Array) -> void:
	for cluster: Dictionary in clusters:
		var members: Array = cluster.get("members", [])
		# Tint colour: a muted warm amber — distinct from the module green and
		# context blue, but not alarming. Each cluster could use a different hue
		# index for disambiguation, but a single consistent tint keeps it subtle.
		var tint_color := Color(0.90, 0.70, 0.15, 0.28)  # warm amber, subtle
		for member_id: String in members:
			var anchor: Node3D = _anchors.get(member_id) as Node3D
			if anchor == null:
				continue
			# Avoid duplicate tints on reload.
			var already_tinted: bool = false
			for child: Node in anchor.get_children():
				if str(child.name) == "ClusterTint":
					already_tinted = true
					break
			if already_tinted:
				continue

			# Flat thin disc overlay — same footprint as the module box but very
			# thin so it does not obscure the module label or mesh.
			var sz: float = float(_get_anchor_size(anchor))
			var tint_mesh := MeshInstance3D.new()
			tint_mesh.name = "ClusterTint"
			var box := BoxMesh.new()
			box.size = Vector3(sz * 1.05, sz * 0.05, sz * 1.05)  # wider, very thin
			tint_mesh.mesh = box
			var tint_mat := StandardMaterial3D.new()
			tint_mat.albedo_color = tint_color
			tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tint_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tint_mesh.material_override = tint_mat
			tint_mesh.position = Vector3(0.0, sz * 0.35, 0.0)  # just above the module box
			anchor.add_child(tint_mesh)


## Return the visual size of an anchor's BoxMesh, or 1.0 as fallback.
## Used by _apply_cluster_suggestions to scale the tint overlay.
func _get_anchor_size(anchor: Node3D) -> float:
	for child: Node in anchor.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh is BoxMesh:
				return (mi.mesh as BoxMesh).size.x
	return 1.0


## Collapse a cluster: hide member anchors, create a supernode at their centroid,
## and record the collapse in _collapsed_clusters.
##
## Spec: spatial-structure.spec.md § Collapsing a cluster —
##   "THEN the modules animate together, converging smoothly into a single supernode"
##   "AND the supernode displays aggregate metrics (total LOC, combined in-degree,
##    combined out-degree)"
##   "AND edges that formerly entered or left any member … are re-routed to the supernode"
##
## Animation: when in the scene tree a Tween animates member modulate.a to 0 then
## hides them; outside the tree (unit tests) visibility is set directly.
func collapse_cluster(cluster_id: String) -> void:
	# Find the cluster definition.
	var cluster_def: Dictionary = {}
	for c: Dictionary in _cluster_suggestions:
		if c.get("id", "") == cluster_id:
			cluster_def = c
			break

	if cluster_def.is_empty():
		push_warning("CodeVis: collapse_cluster('%s') — cluster not found." % cluster_id)
		return

	var members: Array = cluster_def.get("members", [])
	if members.is_empty():
		return

	# Compute centroid of member world positions.
	var centroid := Vector3.ZERO
	var member_count: int = 0
	for member_id: String in members:
		if _world_positions.has(member_id):
			centroid += _world_positions[member_id]
			member_count += 1
	if member_count > 0:
		centroid /= float(member_count)

	# Hide member anchors (animate when in scene tree).
	for member_id: String in members:
		var anchor: Node3D = _anchors.get(member_id) as Node3D
		if anchor == null:
			continue
		if is_inside_tree():
			var tween: Tween = create_tween()
			tween.tween_property(anchor, "modulate:a", 0.0, 0.3)
			# Hide after fade completes so layout remains stable during animation.
			tween.tween_callback(func() -> void: anchor.visible = false)
		else:
			# Unit-test path: set directly.
			anchor.visible = false

	# Build the aggregate metrics label text.
	var agg: Dictionary = cluster_def.get("aggregate_metrics", {})
	var total_loc: int = int(agg.get("total_loc", 0))
	var in_degree: int = int(agg.get("in_degree", 0))
	var out_degree: int = int(agg.get("out_degree", 0))
	var label_text: String = (
		"%s\nLOC:%d  in:%d  out:%d" % [cluster_id, total_loc, in_degree, out_degree]
	)

	# Create a supernode anchor at the centroid.
	var supernode := Node3D.new()
	supernode.name = cluster_id.replace(":", "_").replace(".", "_")
	supernode.position = centroid

	var sz: float = 5.0  # supernode is slightly larger than a regular module
	var box := BoxMesh.new()
	box.size = Vector3(sz, sz * 0.7, sz)
	var mat := StandardMaterial3D.new()
	# Bold magenta — visually distinct from both context (blue) and module (green).
	# The colour signals "this is a collapsed group, not a single module".
	mat.albedo_color = Color(0.80, 0.25, 0.80, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.0, 0.4)
	mat.emission_energy_multiplier = 0.3
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	supernode.add_child(mesh_instance)

	# Label with aggregate metrics.
	var label := Label3D.new()
	label.text = label_text
	label.pixel_size = 0.012
	label.position = Vector3(0.0, sz * 0.5 + 0.4, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	supernode.add_child(label)

	add_child(supernode)
	_anchors[cluster_id] = supernode
	_world_positions[cluster_id] = centroid

	# Record collapse so expand_cluster() and edge routing can reference it.
	_collapsed_clusters[cluster_id] = members

	# Re-route edges: any edge whose source or target is a cluster member should
	# now connect to the supernode centroid instead.
	#
	# Spec: spatial-structure.spec.md § Cluster Collapsing —
	#   "edges that formerly entered or left any member of the cluster are
	#    re-routed to the supernode"
	#   "edge re-routing animates smoothly — endpoints slide to the supernode
	#    rather than jumping"
	var member_set: Dictionary = {}
	for m: String in members:
		member_set[m] = true

	var reroutes: Array = []
	# Iterate _path_edge_entries to find edges whose source or target is a cluster
	# member — those edges must be re-routed to the supernode centroid.
	# Spec: "edges that formerly entered or left any member of the cluster are
	#        re-routed to the supernode"
	for entry in _path_edge_entries:
		var esrc: String = entry["source"]
		var etgt: String = entry["target"]
		var is_src_member: bool = member_set.has(esrc)
		var is_tgt_member: bool = member_set.has(etgt)
		if not is_src_member and not is_tgt_member:
			continue

		var orig_from: Vector3 = entry.get("from_pos", entry["visual"].position)
		var orig_to: Vector3 = entry.get("to_pos", entry["visual"].position)

		# Compute new endpoints: replace member endpoint(s) with supernode centroid.
		var new_from: Vector3 = centroid if is_src_member else orig_from
		var new_to: Vector3 = centroid if is_tgt_member else orig_to

		# Skip internal edges where both endpoints collapse to the same point.
		if new_from.is_equal_approx(new_to):
			continue

		# Store original positions so expand_cluster() can restore them.
		# Dictionary entries are passed by reference in GDScript, so we record a
		# reference to the entry together with the pre-collapse positions.
		reroutes.append({
			"entry_ref": entry,
			"orig_from": orig_from,
			"orig_to": orig_to,
		})

		# Reposition the visual to connect to the supernode.
		# spec: "endpoints slide to the supernode rather than jumping"
		# In-tree: _reposition_edge_visual animates via Tween. Headless: direct.
		_reposition_edge_visual(entry, new_from, new_to)

		# Update cached positions so subsequent operations see the new endpoints.
		entry["from_pos"] = new_from
		entry["to_pos"] = new_to

	_cluster_edge_reroutes[cluster_id] = reroutes


## Expand a previously collapsed supernode back into its constituent modules.
##
## Spec: spatial-structure.spec.md § Expanding a supernode —
##   "THEN the supernode smoothly expands back into its constituent modules"
##   "AND modules animate outward to their original positions"
##   "AND edges re-route back to their original endpoints with smooth animation"
##
## Animation: when in scene tree, Tween fades member anchors back to alpha 1.0;
## outside the tree (unit tests) visibility is set directly.
func expand_cluster(cluster_id: String) -> void:
	if not _collapsed_clusters.has(cluster_id):
		push_warning("CodeVis: expand_cluster('%s') — cluster is not collapsed." % cluster_id)
		return

	var members: Array = _collapsed_clusters[cluster_id]

	# Restore member anchor visibility.
	for member_id: String in members:
		var anchor: Node3D = _anchors.get(member_id) as Node3D
		if anchor == null:
			continue
		if is_inside_tree():
			anchor.visible = true
			anchor.modulate.a = 0.0
			var tween: Tween = create_tween()
			tween.tween_property(anchor, "modulate:a", 1.0, 0.3)
		else:
			anchor.visible = true

	# Remove the supernode.
	if _anchors.has(cluster_id):
		var supernode: Node3D = _anchors[cluster_id] as Node3D
		if supernode != null:
			supernode.queue_free()
		_anchors.erase(cluster_id)
		_world_positions.erase(cluster_id)

	# Restore edge endpoints to their original positions.
	#
	# Spec: spatial-structure.spec.md § Expanding a supernode —
	#   "edges re-route back to their original endpoints with smooth animation"
	if _cluster_edge_reroutes.has(cluster_id):
		var reroutes: Array = _cluster_edge_reroutes[cluster_id]
		for reroute: Dictionary in reroutes:
			var entry: Dictionary = reroute["entry_ref"]
			var orig_from: Vector3 = reroute["orig_from"]
			var orig_to: Vector3 = reroute["orig_to"]
			if orig_from.is_equal_approx(orig_to):
				continue
			# spec: "edges re-route back … with smooth animation"
			# In-tree: _reposition_edge_visual animates via Tween. Headless: direct.
			_reposition_edge_visual(entry, orig_from, orig_to)
			# Restore cached positions so subsequent collapse/expand cycles are correct.
			entry["from_pos"] = orig_from
			entry["to_pos"] = orig_to
		_cluster_edge_reroutes.erase(cluster_id)

	# Clear collapse record.
	_collapsed_clusters.erase(cluster_id)


# ---------------------------------------------------------------------------
# Camera framing
# ---------------------------------------------------------------------------

func _frame_camera() -> void:
	if _world_positions.is_empty() or _camera == null:
		return

	var min_pos := Vector3(INF, INF, INF)
	var max_pos := Vector3(-INF, -INF, -INF)

	for pos: Vector3 in _world_positions.values():
		min_pos = min_pos.min(pos)
		max_pos = max_pos.max(pos)

	var centre: Vector3 = (min_pos + max_pos) * 0.5
	var span: float = maxf((max_pos - min_pos).length(), 10.0)
	var distance: float = span * 1.5

	if _camera.has_method("set_pivot"):
		_camera.call("set_pivot", centre, distance)


# ---------------------------------------------------------------------------
# Keyboard input handling
# ---------------------------------------------------------------------------

## Handle keyboard shortcuts for understanding overlays.
##   H → apply alignment overlay (spec-vs-realization — shows how build matches design).
##   J → apply quality overlay  (quality-metrics — shows coupling and centrality).
##   K → apply failure impact overlay (cascade-injection — shows impact from first node).
##   T → toggle ubiquitous (power rail) edges on/off.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_H:
			_apply_alignment_overlay()
		KEY_J:
			_apply_quality_overlay()
		KEY_K:
			_apply_failure_impact_overlay()
		KEY_T:
			# spec §Power Rail Toggle — "T key toggles ubiquitous edges on/off"
			toggle_ubiquitous_edges()


# ---------------------------------------------------------------------------
# Understanding overlays (alignment / quality / failure-impact)
# ---------------------------------------------------------------------------

## Apply alignment overlay (H key) — spec-vs-realization view.
## Colours every node in the scene by its spec_status field so the human can
## see whether the as-built system matches the as-specced design.
func _apply_alignment_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	_understanding_overlay.apply_alignment_overlay(nodes, _anchors)


## Apply quality overlay (J key) — quality-metrics view.
## Colours nodes by coupling and centrality metrics so the human can evaluate
## the architectural quality of the realized system independently of the spec.
func _apply_quality_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	var edges: Array = _graph.get("edges", [])
	_understanding_overlay.apply_quality_overlay(nodes, edges, _anchors)


## Apply failure impact overlay (K key) — cascade-injection view.
## Simulates a failure of the first node in the graph and cascades through
## dependents, colouring all affected components so the human can explore
## the impact of the hypothetical failure before committing to any change.
func _apply_failure_impact_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	if nodes.is_empty():
		return
	var target_id: String = nodes[0].get("id", "")
	if not target_id.is_empty():
		_understanding_overlay.apply_failure_overlay(target_id, _graph, _anchors, self)


