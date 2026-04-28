extends Node3D

## Main scene controller for CodeVis.
##
## Loads the JSON scene graph produced by the Python extractor via SceneGraphLoader
## and procedurally builds the 3D visualisation:
##   - bounded-context nodes  → large translucent boxes
##   - module nodes           → smaller opaque boxes nested inside their context
##   - edges                  → coloured lines with arrowhead cones
##     (orange = cross-context, grey = internal)
##
## The JSON file path is configurable via the exported variable.

const SceneGraphLoader = preload("res://scripts/scene_graph_loader.gd")
const LodManager = preload("res://scripts/lod_manager.gd")
const UnderstandingOverlay = preload("res://scripts/understanding_overlay.gd")

@export var scene_graph_path: String = "res://data/scene_graph.json"

## Node id → Node3D anchor that owns the volume and label.
var _anchors: Dictionary = {}

## Node id → world-space centre Vector3 (computed from relative positions).
var _world_positions: Dictionary = {}

## LOD manager — toggles node/edge visibility by camera distance.
var _lod: LodManager = LodManager.new()

## Node anchor entries for LOD visibility management.
var _lod_node_entries: Array = []

## Edge MeshInstance3D entries for LOD visibility management.
var _lod_edge_entries: Array = []

## Edge entries with source/target ids for dependency-direction tracking.
var _path_edge_entries: Array = []

## Cached graph for overlay functions that need to re-read nodes/edges.
var _graph: Dictionary = {}

## Understanding overlay helper — handles all node-colour transformations.
var _understanding_overlay: UnderstandingOverlay = UnderstandingOverlay.new()

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
		var graph: Dictionary = SceneGraphLoader.load_from_dict(json.data)
		build_from_graph(graph)
	else:
		push_warning("CodeVis: scene graph not found at '%s'." % scene_graph_path)


## Build the 3D scene from a parsed scene-graph dictionary.
## Called from _ready() at startup and from tests directly.
func build_from_graph(graph: Dictionary) -> void:
	_graph = graph
	var nodes: Array = graph.get("nodes", [])
	var edges: Array = graph.get("edges", [])

	# Index raw node data for fast lookup.
	var node_data_map: Dictionary = {}
	for nd: Dictionary in nodes:
		node_data_map[nd["id"]] = nd

	# Pre-compute every node's world-space centre before creating geometry,
	# so that edge endpoints are available without depending on Godot's
	# deferred global-transform propagation.
	_compute_world_positions(nodes, node_data_map)

	# Create volumes: parents first so children can be parented to them.
	for nd: Dictionary in nodes:
		if nd["parent"] == null:
			_create_volume(nd, self)
	for nd: Dictionary in nodes:
		if nd["parent"] != null:
			var parent_anchor: Node3D = _anchors.get(nd["parent"])
			if parent_anchor != null:
				_create_volume(nd, parent_anchor)
			else:
				push_warning("CodeVis: parent '%s' not found for '%s'." % [nd["parent"], nd["id"]])
				_create_volume(nd, self)

	# Create edge lines after all volumes exist.
	for ed: Dictionary in edges:
		_create_edge(ed)

	# Reposition camera to frame the whole graph.
	_frame_camera()


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
	# Register with LOD manager so visibility can be toggled by camera distance.
	_lod_node_entries.append({"anchor": anchor, "node_type": nd["type"]})

	var sz: float = float(nd["size"])
	var node_type: String = nd["type"]
	var is_context: bool = node_type == "bounded_context"
	var is_spec: bool = node_type == "spec"

	# Mesh ----------------------------------------------------------------
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	var mat := StandardMaterial3D.new()
	if is_spec:
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
		mat.albedo_color = Color(0.25, 0.45, 0.85, 0.18)
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


# ---------------------------------------------------------------------------
# Edge creation
# ---------------------------------------------------------------------------

func _create_edge(ed: Dictionary) -> void:
	var src: String = ed["source"]
	var tgt: String = ed["target"]

	if not _world_positions.has(src) or not _world_positions.has(tgt):
		push_warning("CodeVis: skipping edge '%s' → '%s' (node missing)." % [src, tgt])
		return

	var from_pos: Vector3 = _world_positions[src]
	var to_pos: Vector3 = _world_positions[tgt]

	if from_pos.is_equal_approx(to_pos):
		return  # Self-loop or co-located nodes — nothing to draw.

	var is_cross: bool = ed["type"] == "cross_context"
	var line_color: Color = Color(1.0, 0.50, 0.10) if is_cross else Color(0.55, 0.55, 0.55)

	# Build a line mesh using ImmediateMesh (PRIMITIVE_LINES, two vertices).
	var imesh := ImmediateMesh.new()
	imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	imesh.surface_set_color(line_color)
	imesh.surface_add_vertex(from_pos)
	imesh.surface_set_color(line_color)
	imesh.surface_add_vertex(to_pos)
	imesh.surface_end()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = imesh
	mesh_instance.material_override = mat
	# Edges live at the scene root so their positions are already world-space.
	add_child(mesh_instance)
	# Register line with LOD manager.
	_lod_edge_entries.append({"visual": mesh_instance, "edge_type": ed["type"]})
	# Track edge direction (source/target) so dependency direction can be verified.
	_path_edge_entries.append({"visual": mesh_instance, "source": src, "target": tgt})

	# Arrowhead: a cone (CylinderMesh, top_radius=0 = pointed tip) placed at the
	# target end, oriented along the edge direction, indicating dependency flow.
	var dir: Vector3 = (to_pos - from_pos).normalized()
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
	arrow.basis = Basis(Quaternion(Vector3.UP, dir))
	# Centre the cone so its tip lands exactly at to_pos.
	arrow.position = to_pos - dir * (cone_mesh.height * 0.5)
	add_child(arrow)
	# Register arrowhead with LOD manager (same edge_type as the line).
	_lod_edge_entries.append({"visual": arrow, "edge_type": ed["type"]})
	# Track arrowhead direction for dependency direction verification.
	_path_edge_entries.append({"visual": arrow, "source": src, "target": tgt})


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
# Understanding overlays — delegated to UnderstandingOverlay helper.
# These methods are invoked via keyboard shortcuts (H / J / K) to visualise
# how the realized build relates to the intended design.
# ---------------------------------------------------------------------------

func _apply_alignment_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	_understanding_overlay.apply_alignment_overlay(nodes, _anchors)


func _apply_quality_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	var edges: Array = _graph.get("edges", [])
	_understanding_overlay.apply_quality_overlay(nodes, edges, _anchors)


func _apply_failure_impact_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	if nodes.is_empty():
		return
	var target_id: String = nodes[0].get("id", "")
	if not target_id.is_empty():
		_understanding_overlay.apply_failure_overlay(target_id, _graph, _anchors, self)
