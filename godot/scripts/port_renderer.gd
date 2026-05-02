extends RefCounted

## Port Primitive Renderer for code-vis.
##
## Implements the Port primitive as specified in:
##   specs/core/visual-primitives.spec.md § Requirement: Port Primitive
##
## A Port is a small labeled visual element anchored to a Container's membrane,
## representing an interface point (public function, API endpoint, event emitter).
##
## Spec: "a Port is a small visual element anchored to a Container's membrane,
##   representing an interface point (public function, API endpoint, event emitter)"
##
## ## Port direction
##
## Input Ports (functions that accept parameters / dependencies):
##   Rendered on the LEFT face (negative-X side) of the Container.
##
## Output Ports (functions that return values / emit events):
##   Rendered on the RIGHT face (positive-X side) of the Container.
##
## For the prototype, one input-side Port and one output-side Port is created
## per public function.  Full per-parameter rendering is a future enhancement.
##
## ## LOD integration
##
## Ports are tier-2 (near) detail.  At tier-0 and tier-1 the Port meshes and
## labels have alpha = 0 (invisible).  At tier-2 they fade in.
##
## Spec: "as the human zooms in, Ports fade in on the membrane"
##
## ## Opacity implementation
##
## MeshInstance3D in Godot 4 does NOT have a modulate property (modulate is a
## CanvasItem / 2D concept).  Mesh opacity is controlled via the material's
## albedo_color.a.  Label3D DOES have a modulate property.
##
## Tween targets:
##   MeshInstance3D  → material_override:albedo_color:a
##   Label3D         → modulate:a
##
## ## Usage
##
## After a Container anchor has been created by main.gd, call:
##
##   var port_renderer := PortRenderer.new()
##   port_renderer.attach_ports(node_data, anchor, container_size)
##
## Then call set_lod_tier() when the camera LOD tier changes.
## Retrieve Port world positions for edge routing via get_port_local_positions().

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Radius of each Port mesh sphere in scene units.
const PORT_MESH_RADIUS: float = 0.12

## Y-offset along the container face where Ports are placed.
## Ports sit slightly above the base of the container volume.
const PORT_Y_OFFSET: float = 0.1

## Spacing between consecutive Ports on the same face (centre-to-centre).
const PORT_SPACING: float = 0.55

## Label pixel_size — must be > 0 for legibility.
const PORT_LABEL_PIXEL_SIZE: float = 0.008

## Color for input Ports (parameters — data flowing IN).
## Cyan-blue to suggest incoming signal.  Alpha starts at 0.0 (hidden).
## Alpha = 1.0 when fully visible at tier-2 LOD.
const INPUT_PORT_COLOR: Color = Color(0.20, 0.70, 1.00, 0.0)   # alpha=0 until tier-2

## Color for output Ports (return values — data flowing OUT).
## Warm orange to suggest outgoing signal.  Alpha starts at 0.0 (hidden).
const OUTPUT_PORT_COLOR: Color = Color(1.00, 0.55, 0.15, 0.0)  # alpha=0 until tier-2

## LOD tier constants.  Mirrors the tier model in LodManager without a
## hard dependency (Port alpha is driven by set_lod_tier() calls from main.gd).
const LOD_TIER_FAR: int = 0    # > FAR_THRESHOLD — Ports invisible
const LOD_TIER_MEDIUM: int = 1  # > NEAR_THRESHOLD — Ports invisible
const LOD_TIER_NEAR: int = 2    # ≤ NEAR_THRESHOLD — Ports visible

## Fade duration in seconds for LOD opacity transitions.
## Matches spatial-structure.spec.md § "Smooth transitions between levels".
const LOD_FADE_DURATION: float = 0.25

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

## All Port MeshInstance3D nodes created by this renderer.
## Used for bulk alpha transitions (material.albedo_color.a).
var _port_meshes: Array = []

## All Port Label3D nodes created by this renderer.
## Used for bulk alpha transitions (modulate.a).
var _port_labels: Array = []

## Current LOD tier (0=far, 1=medium, 2=near).
var _current_lod_tier: int = -1  # -1 = not yet applied

## Map of symbol_name (String) → local Vector3 of the Port's position.
## Stored in LOCAL space relative to the Container anchor so that main.gd can
## add the Container's world position to get the absolute world position.
## Key: symbol name with suffix (e.g. "login_in")  Value: local Vector3
var _port_local_positions: Dictionary = {}

## The anchor Node3D this renderer attached Ports to.
var _anchor: Node3D = null

## The Container size passed to attach_ports().
var _container_size: float = 1.0


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Attach Port visual elements to *anchor* based on *node_data*.
##
## Only public symbols in node_data["symbols"] are rendered as Ports.
## Spec: "a module with 4 public functions — 4 Ports appear on its membrane"
##
## Parameters:
##   node_data:      Dictionary — the raw node dict from the scene graph
##   anchor:         Node3D    — the Container's scene-tree anchor
##   container_size: float     — the node's 'size' field (controls spacing)
func attach_ports(
	node_data: Dictionary, anchor: Node3D, container_size: float
) -> void:
	_anchor = anchor
	_container_size = container_size
	_port_meshes.clear()
	_port_labels.clear()
	_port_local_positions.clear()

	var symbols: Array = node_data.get("symbols", [])
	if symbols.is_empty():
		return  # No symbols → no Ports.

	# Filter to public symbols only.
	var public_symbols: Array = []
	for sym: Dictionary in symbols:
		if sym.get("visibility", "") == "public":
			public_symbols.append(sym)

	if public_symbols.is_empty():
		return  # Spec: Container with 0 public symbols → no Port elements.

	# Distribute Ports evenly on the membrane faces.
	# For the prototype: each public function gets ONE input-side Port (left face)
	# and ONE output-side Port (right face).
	var n: int = public_symbols.size()

	# Half-size of the Container box along X.
	# Container box size = Vector3(sz, sz*0.2, sz) for bounded_context nodes.
	# Ports are placed on the ±X faces at x = ±(sz/2).
	var half_sz: float = container_size * 0.5

	# Distribute ports evenly along Z:  total_spread = (n-1) * PORT_SPACING.
	var total_height: float = float(n - 1) * PORT_SPACING
	var start_z: float = -total_height * 0.5

	for i: int in range(n):
		var sym: Dictionary = public_symbols[i]
		var sym_name: String = sym.get("name", "?")
		var z_offset: float = start_z + float(i) * PORT_SPACING

		# Input Port — left face (negative X).
		# Input ports represent parameters/dependencies (data flowing in).
		var input_pos := Vector3(-half_sz, PORT_Y_OFFSET, z_offset)
		_create_port(sym_name + "_in", input_pos, INPUT_PORT_COLOR, sym_name + "▶", anchor)
		_port_local_positions[sym_name + "_in"] = input_pos

		# Output Port — right face (positive X).
		# Output ports represent return values/emitted events (data flowing out).
		var output_pos := Vector3(half_sz, PORT_Y_OFFSET, z_offset)
		_create_port(sym_name + "_out", output_pos, OUTPUT_PORT_COLOR, "◀" + sym_name, anchor)
		_port_local_positions[sym_name + "_out"] = output_pos

	# New ports start invisible (alpha=0 in material and label modulate).
	# set_lod_tier() is called by main.gd after attach_ports() to apply
	# the current LOD state.


## Return local-space Port positions keyed by "symbol_name_in" / "symbol_name_out".
##
## main.gd adds the Container's world position to these to get absolute positions
## for edge routing.
func get_port_local_positions() -> Dictionary:
	return _port_local_positions


## Apply a LOD tier to all Port nodes, animating their opacity.
##
## tier:
##   LOD_TIER_FAR (0)    → alpha = 0  (Ports invisible at far distance)
##   LOD_TIER_MEDIUM (1) → alpha = 0  (Ports invisible at medium distance)
##   LOD_TIER_NEAR (2)   → alpha = 1  (Ports visible at near distance)
##
## Spec: "Port visibility is LOD-driven: hidden at tier-0/1, fade in at tier-2"
## Spec: "elements fade in or out with animated opacity, never appearing instantly"
##
## Opacity control:
##   MeshInstance3D → material_override.albedo_color.a  (NOT modulate — 3D nodes)
##   Label3D        → modulate.a  (Label3D supports modulate)
func set_lod_tier(tier: int) -> void:
	if tier == _current_lod_tier:
		return  # No change — skip animation.
	_current_lod_tier = tier
	var target_alpha: float = 1.0 if tier == LOD_TIER_NEAR else 0.0

	# MeshInstance3D: opacity via material albedo_color.a.
	# When in scene tree: Tween material_override:albedo_color:a for smooth fade.
	# When NOT in scene tree (unit tests): set directly.
	for mesh_node: MeshInstance3D in _port_meshes:
		var mat: StandardMaterial3D = mesh_node.material_override as StandardMaterial3D
		if mat == null:
			continue
		if mesh_node.is_inside_tree():
			# spec: "LOD transitions MUST use animated opacity (Tween on modulate.a)"
			# For MeshInstance3D the equivalent is animating albedo_color:a.
			mesh_node.create_tween().tween_property(
				mat, "albedo_color:a", target_alpha, LOD_FADE_DURATION
			)
		else:
			# Unit test context: set directly so assertions are immediately effective.
			var c: Color = mat.albedo_color
			c.a = target_alpha
			mat.albedo_color = c

	# Label3D: opacity via modulate.a (Label3D supports modulate unlike other Node3D subclasses).
	for label_node: Label3D in _port_labels:
		if label_node.is_inside_tree():
			label_node.create_tween().tween_property(
				label_node, "modulate:a", target_alpha, LOD_FADE_DURATION
			)
		else:
			label_node.modulate.a = target_alpha


## Return the count of Port MeshInstance3D nodes created.
## Each public symbol produces 2 meshes (input + output Port).
func get_port_count() -> int:
	return _port_meshes.size()


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Create one Port: a small sphere (MeshInstance3D) + a Label3D, both anchored
## to *anchor* at *local_pos*.
##
## port_key:   unique node name for the mesh (e.g. "process_order_in")
## local_pos:  local position relative to the Container anchor
## base_color: base colour with alpha=0 initially (INPUT_PORT_COLOR / OUTPUT_PORT_COLOR)
## label_text: text for the Label3D
## anchor:     the Container Node3D to attach to
func _create_port(
	port_key: String,
	local_pos: Vector3,
	base_color: Color,
	label_text: String,
	anchor: Node3D
) -> void:
	# Port mesh — small sphere on the membrane surface.
	var sphere := SphereMesh.new()
	sphere.radius = PORT_MESH_RADIUS
	sphere.height = PORT_MESH_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4

	# Transparency is required so alpha=0 renders as invisible.
	# alpha starts at 0.0 (hidden at tier-0/1); set_lod_tier() drives it to 1.0.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color  # base_color already has a=0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Port_" + port_key
	mesh_inst.mesh = sphere
	mesh_inst.material_override = mat
	mesh_inst.position = local_pos
	# MeshInstance3D has no .modulate; alpha controlled via mat.albedo_color.a.
	# mat.albedo_color.a is already 0.0 from base_color.
	anchor.add_child(mesh_inst)
	_port_meshes.append(mesh_inst)

	# Port label — shows the function name, always faces the camera.
	var label := Label3D.new()
	label.name = "PortLabel_" + port_key
	label.text = label_text
	# pixel_size > 0 is mandatory for legibility (spec requirement).
	label.pixel_size = PORT_LABEL_PIXEL_SIZE
	# BILLBOARD_ENABLED: label always faces the camera (mandatory for 3D legibility).
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Draw above geometry so labels remain readable through surfaces.
	label.no_depth_test = true
	# Position the label slightly further from the container than the mesh.
	# Input ports (negative X): offset further left; output ports: further right.
	var label_offset: float = PORT_MESH_RADIUS * 2.5
	var label_pos := local_pos
	if local_pos.x < 0.0:
		# Input port: move label further left (more negative X).
		label_pos.x -= label_offset
	else:
		# Output port: move label further right (more positive X).
		label_pos.x += label_offset
	label.position = label_pos
	# Label3D supports modulate; start invisible (alpha=0).
	label.modulate.a = 0.0
	anchor.add_child(label)
	_port_labels.append(label)
