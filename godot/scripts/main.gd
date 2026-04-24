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
## Level-of-detail (LOD) is applied every frame via LodManager:
##   far distance  → only bounded_context nodes visible
##   medium distance → bounded_context + module nodes visible
##   near distance  → all nodes and edges visible (finest detail)
##
## The JSON file path is configurable via the exported variable.

const SceneGraphLoader = preload("res://scripts/scene_graph_loader.gd")
const LodManager = preload("res://scripts/lod_manager.gd")
const FlowOverlay = preload("res://scripts/flow_overlay.gd")
const LlmViewGenerator = preload("res://scripts/llm_view_generator.gd")
const SceneInterpreter = preload("res://scripts/scene_interpreter.gd")
const UnderstandingOverlay = preload("res://scripts/understanding_overlay.gd")

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

## Entries for path overlay: Array of {visual: Node3D, source: String, target: String}
var _path_edge_entries: Array = []

## Path overlay controller — manages on-demand path and traffic highlighting.
var _flow: FlowOverlay = FlowOverlay.new()

## Path definitions loaded from the scene graph (optional field).
var _flows: Array = []

## Aggregate traffic patterns loaded from the scene graph (optional field).
var _aggregate: Dictionary = {}

## Index of the currently active path (-1 = none).
var _active_path_index: int = -1

## Moldable-views pipeline: SceneInterpreter consumes view specs from LlmViewGenerator.
var _scene_interpreter: SceneInterpreter = SceneInterpreter.new()

## Understanding overlay controller — activates alignment, quality, and impact overlays.
var _understanding_overlay: UnderstandingOverlay = UnderstandingOverlay.new()

## Question input UI — LineEdit for natural-language questions.
var _question_input: LineEdit

## Submit button for the question input UI.
var _ask_button: Button

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

	# Add natural-language question input UI for moldable-views interaction.
	_add_question_ui()

## Build the 3D scene from a parsed scene-graph dictionary.
## Called from _ready() at startup and from tests directly.
func build_from_graph(graph: Dictionary) -> void:
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

	# Load optional path and aggregate traffic definitions.
	_flows = graph.get("flows", [])
	_aggregate = graph.get("aggregate", {})

	# Wire path overlay with the node anchors and edge visuals.
	_flow.setup(_anchors, _path_edge_entries)

	# Reposition camera to frame the whole graph.
	_frame_camera()

	# Apply initial LOD pass so visibility is correct before any _process tick.
	_update_lod()


# ---------------------------------------------------------------------------
# Per-frame LOD update
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_lod()


## Query the camera's current distance and apply LOD visibility accordingly.
func _update_lod() -> void:
	if _camera == null or not _camera.has_method("get_distance"):
		return
	var dist: float = _camera.call("get_distance")
	_lod.update_lod(_lod_node_entries, _lod_edge_entries, dist)


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
	var is_context: bool = nd["type"] == "bounded_context"

	# Mesh ----------------------------------------------------------------
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()

	var mat := StandardMaterial3D.new()
	if is_context:
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
	# Register line with path overlay (source/target needed for path highlighting).
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
	# Register arrowhead with path overlay.
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
# Path overlay input (on-demand activation)
# ---------------------------------------------------------------------------

## Handle keyboard shortcuts for on-demand path overlay and understanding overlays.
##   F → cycle through path definitions (or clear if one is already shown).
##   G → toggle aggregate traffic pattern overlay.
##   H → apply alignment overlay (Conformance Mode — shows spec vs. realization).
##   J → apply quality overlay  (Evaluation Mode  — shows coupling and centrality).
##   K → apply failure impact overlay (Simulation Mode — shows cascade from first node).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_F:
			_toggle_path_overlay()
		KEY_G:
			_toggle_aggregate_overlay()
		KEY_H:
			_apply_alignment_overlay()
		KEY_J:
			_apply_quality_overlay()
		KEY_K:
			_apply_failure_impact_overlay()


## Cycle to the next path definition, or clear the active overlay.
func _toggle_path_overlay() -> void:
	if _flow.is_path_active():
		_flow.clear_path()
		_active_path_index = -1
	elif not _flows.is_empty():
		_active_path_index = (_active_path_index + 1) % _flows.size()
		var f: Dictionary = _flows[_active_path_index]
		_flow.show_path(f.get("path", []), f.get("entry", ""), f.get("terminus", ""))


## Show aggregate traffic patterns, or clear if already active.
func _toggle_aggregate_overlay() -> void:
	if _flow.is_path_active():
		_flow.clear_path()
	else:
		_flow.show_aggregate(
			_aggregate.get("hot_edges", []),
			_aggregate.get("bottlenecks", [])
		)


# ---------------------------------------------------------------------------
# Moldable-views: natural-language question UI → LLM → view-spec pipeline
# ---------------------------------------------------------------------------

## Add a minimal question input UI (LineEdit + Button) to the scene.
## Placed on a CanvasLayer so it overlays the 3D view regardless of camera.
func _add_question_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hbox.offset_top = -52.0
	hbox.offset_right = 520.0
	canvas.add_child(hbox)

	_question_input = LineEdit.new()
	_question_input.placeholder_text = "Ask a question about the codebase..."
	_question_input.custom_minimum_size = Vector2(420.0, 40.0)
	_question_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_question_input)

	_ask_button = Button.new()
	_ask_button.text = "Ask"
	_ask_button.custom_minimum_size = Vector2(60.0, 40.0)
	hbox.add_child(_ask_button)

	_ask_button.pressed.connect(_on_ask_button_pressed)
	_question_input.text_submitted.connect(_on_question_submitted)


## Relay button press to the question submission handler.
func _on_ask_button_pressed() -> void:
	_on_question_submitted(_question_input.text)


## Moldable-views pipeline entry point.
## Called when the human submits a natural-language question.
##
## Pipeline:
##   1. LlmViewGenerator.build_prompt  — encodes question + graph into an LLM prompt
##   2. LLM call (mocked in prototype)  — returns a view-spec JSON response
##   3. LlmViewGenerator.parse_response — produces a validated view-spec dict
##   4. SceneInterpreter.apply_spec     — applies the spec to the live 3D scene
func _on_question_submitted(question: String) -> void:
	if question.is_empty():
		return

	# Stage 1: build the LLM prompt from the question and the loaded scene graph.
	var prompt: String = LlmViewGenerator.build_prompt(question, _graph)

	# Stage 1 (continued): obtain a view-spec response.
	# In this prototype the LLM call is represented by a neutral mock response;
	# a production integration would replace this with an HTTP request to an LLM endpoint.
	var llm_response: String = _call_llm(prompt)

	# Stage 1 (continued): parse the response into a validated view-spec dictionary.
	var spec: Dictionary = LlmViewGenerator.parse_response(llm_response)

	# Stage 2: apply the view spec to the live 3D scene.
	_scene_interpreter.apply_spec(spec, _anchors, self)


## Invoke the LLM with the given prompt and return its response.
## In this prototype, returns a neutral empty-operations response.
## A production implementation would send an HTTP POST to an LLM endpoint.
func _call_llm(_prompt: String) -> String:
	return '{"operations": []}'


# ---------------------------------------------------------------------------
# Understanding overlays (Conformance / Evaluation / Simulation modes)
# ---------------------------------------------------------------------------

## Apply alignment overlay (H key) — Conformance Mode.
## Colours every node in the scene by its spec_status field so the human can
## see whether the as-built system matches the as-specced design.
func _apply_alignment_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	_understanding_overlay.apply_alignment_overlay(nodes, _anchors)


## Apply quality overlay (J key) — Evaluation Mode.
## Colours nodes by coupling and centrality metrics so the human can evaluate
## the architectural quality of the realized system independently of the spec.
func _apply_quality_overlay() -> void:
	var nodes: Array = _graph.get("nodes", [])
	var edges: Array = _graph.get("edges", [])
	_understanding_overlay.apply_quality_overlay(nodes, edges, _anchors)


## Apply failure impact overlay (K key) — Simulation Mode (failure injection).
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
