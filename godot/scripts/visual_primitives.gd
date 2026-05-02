extends RefCounted

## Visual Primitives Renderer for code-vis.
##
## Implements the composition layer of the visual-primitives specification:
##   specs/core/visual-primitives.spec.md
##
## This module handles rendering of four primitive types that are layered
## on top of the base Container/Node/Edge rendered by main.gd:
##
##   Badge Primitive — small glyph docked to a node indicating a cross-cutting
##     aspect (pure, io, async, stateful, error_handling, test, entry_point,
##     deprecated).  Spec §Requirement: Badge Primitive.
##
##   Landmark Primitive — distinctive visual treatment (brighter, larger ring)
##     for structurally significant nodes that persist at all zoom levels.
##     Spec §Requirement: Landmark Primitive.
##
##   Power Rail Notation — a small base glyph on nodes that import ubiquitous
##     dependencies.  The rail indicates the dependency exists without drawing
##     the edge.  Spec §Requirement: Power Rail Notation.
##
##   Port Primitive — small visual elements anchored to a Container's membrane,
##     representing interface points (public functions, API endpoints).
##     Ports appear only at NEAR zoom level (LOD tier 2) and are hidden at
##     FAR and MEDIUM distances.  Spec §Requirement: Port Primitive.
##
## Usage: call attach_primitives(node_data, anchor) after the base volume has
## been created.  The function inspects the node_data dict and attaches the
## appropriate child nodes to the anchor.
##
## For Port Primitive: call render_ports(node_data, anchor, node_size) which
## returns an Array of port Node3D anchors.  The caller (main.gd) registers
## them with the LOD manager using node_type="port" so they are hidden at FAR
## and MEDIUM zoom levels and appear only at NEAR.

# ---------------------------------------------------------------------------
# Badge colours
# ---------------------------------------------------------------------------

## Map from badge type string → display colour.
## Colours are desaturated so they remain legible on both dark and light
## backgrounds.  Spec §Scenario: Badge vocabulary — at minimum: pure, io,
## async, stateful, error_handling, test, entry_point, deprecated.
const BADGE_COLORS: Dictionary = {
	"pure": Color(0.30, 0.80, 0.30),       # soft green: no side effects
	"io": Color(0.90, 0.55, 0.10),         # amber: I/O involvement
	"async": Color(0.20, 0.60, 0.90),      # blue: asynchronous
	"stateful": Color(0.80, 0.30, 0.80),   # purple: mutable state
	"error_handling": Color(0.90, 0.20, 0.20),  # red: error paths
	"test": Color(0.60, 0.90, 0.60),       # pale green: test code
	"entry_point": Color(1.00, 0.90, 0.10), # gold: entry point
	"deprecated": Color(0.50, 0.50, 0.50), # grey: deprecated
}

## Radius of each badge sphere in scene units.
const BADGE_RADIUS: float = 0.18

## Spacing between consecutive badges (centre-to-centre) in scene units.
const BADGE_SPACING: float = 0.45

## Y-offset of badges above the node's volume top surface.
const BADGE_Y_OFFSET: float = 0.30

# ---------------------------------------------------------------------------
# Landmark constants
# ---------------------------------------------------------------------------

## Torus ring that marks landmark nodes — a thin ring around the base of the
## volume.  Landmarks persist at all zoom levels and serve as orientation
## anchors.  Spec §Scenario: Hub as landmark.
const LANDMARK_RING_OUTER_RADIUS: float = 1.2
const LANDMARK_RING_INNER_RADIUS_RATIO: float = 0.85
## Landmark ring colour: golden to signify structural importance.
const LANDMARK_COLOR: Color = Color(1.00, 0.85, 0.10, 0.90)
## Scale multiplier applied to the node anchor when it is a landmark.
## A landmark node appears 20% larger than a non-landmark of the same LOC.
const LANDMARK_SCALE: float = 1.20

# ---------------------------------------------------------------------------
# Power rail constants
# ---------------------------------------------------------------------------

## Small flat disc rendered at the base of nodes that have at least one
## ubiquitous dependency.  Its presence signals "power rail in effect" —
## the dependency exists but is not drawn as an edge.
## Spec §Scenario: Standard library power rail.
const POWER_RAIL_RADIUS: float = 0.35
const POWER_RAIL_HEIGHT: float = 0.06
## Consistent position: slightly below the node base so it frames the
## volume from underneath.
const POWER_RAIL_Y_OFFSET: float = -0.10
## Power rail colour: dim white — subtle enough not to compete with structure.
const POWER_RAIL_COLOR: Color = Color(0.85, 0.85, 0.85, 0.70)

# ---------------------------------------------------------------------------
# Port constants
# ---------------------------------------------------------------------------

## Port Primitive — small spheres anchored to the Container membrane surface.
## Spec §Requirement: Port Primitive.
## Spec §Scenario: Port placement — "4 Ports appear on its membrane, each Port
##   is labeled with the function name".
## Spec §Scenario: Port visibility at zoom levels — "Ports are hidden at far,
##   fade in on the membrane as the human zooms in".
##
## Port sphere radius in scene units.
const PORT_RADIUS: float = 0.15
## Port colour for public functions that accept parameters (interface entry points).
## Cyan: "accepts input" / "receives calls" — input port colour.
const PORT_INPUT_COLOR: Color = Color(0.20, 0.80, 0.90, 0.95)
## Port colour for public functions with no parameters (pure queries / factories).
## Amber: "emits output" / "called for result" — output port colour.
const PORT_OUTPUT_COLOR: Color = Color(0.90, 0.65, 0.10, 0.95)
## Ports sit on the membrane (XZ edge of the Container box) at Y=0 (ground plane).
## The Y-position offset above the base plane.
const PORT_Y_LEVEL: float = 0.0
## Label pixel size — must be > 0.0 for legibility (billboard text).
const PORT_LABEL_PIXEL_SIZE: float = 0.006
## Maximum number of Ports rendered per Container.  Above this the membrane
## becomes visually cluttered.  Excess public symbols are silently skipped.
const PORT_MAX: int = 12


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Attach visual primitive decorations to *anchor* based on *node_data*.
##
## Inspects the following keys in node_data:
##   badges: Array[String]  — badge type strings to render
##   is_landmark: bool      — whether to apply landmark treatment
##   has_ubiquitous_dep: bool — whether to show power rail
##
## Parameters:
##   node_data: Dictionary — the raw node dict from the scene graph
##   anchor: Node3D        — the scene-tree node to attach decorations to
##   node_size: float      — the node's 'size' field (used to position badges)
func attach_primitives(
	node_data: Dictionary, anchor: Node3D, node_size: float
) -> void:
	# Landmark visual treatment: scale up and add a ring.
	if node_data.get("is_landmark", false):
		_apply_landmark(anchor, node_size)

	# Badge glyphs: one sphere per badge type, arranged along the top.
	var badges: Array = node_data.get("badges", [])
	if not badges.is_empty():
		_render_badges(badges, anchor, node_size)

	# Power rail indicator: flat disc at the base.
	if node_data.get("has_ubiquitous_dep", false):
		_render_power_rail(anchor, node_size)


## Render Port primitives on the Container membrane for each public symbol.
##
## Spec §Requirement: Port Primitive — "a small visual element anchored to a
##   Container's membrane, representing an interface point (public function,
##   API endpoint, event emitter)."
## Spec §Scenario: Port placement — "4 Ports appear on its membrane, each
##   Port is labeled with the function name."
## Spec §Scenario: Port direction — "input Ports (parameters/dependencies)
##   are visually distinct from output Ports (return values/emitted events)."
## Spec §Scenario: Port visibility at zoom levels — "Ports are hidden at far,
##   fade in on the membrane as the human zooms in (LOD Shell behaviour)."
##
## Only public symbols of kind "function" become Ports.  Private symbols and
## non-callable symbols are NOT rendered as Ports.
##
## Ports are arranged in a ring around the perimeter of the Container at the
## membrane edge (distance = node_size / 2).
##
## Parameters:
##   node_data:  Dictionary — the raw node dict from the scene graph
##   anchor:     Node3D     — the Container anchor to parent ports to
##   node_size:  float      — the Container's 'size' field (determines orbit radius)
##
## Returns: Array of port Node3D anchors.  Caller MUST register each with the
##   LOD manager (node_type="port") so they are hidden at FAR and MEDIUM
##   distances and visible only at NEAR.
func render_ports(
	node_data: Dictionary, anchor: Node3D, node_size: float
) -> Array:
	var symbols: Array = node_data.get("symbols", [])
	if symbols.is_empty():
		return []

	# Collect only public function symbols — these become Ports.
	var public_funcs: Array = []
	for sym: Dictionary in symbols:
		if sym.get("visibility", "") == "public" and sym.get("kind", "") == "function":
			public_funcs.append(sym)
		if public_funcs.size() >= PORT_MAX:
			break

	if public_funcs.is_empty():
		return []

	# Place ports in a ring around the perimeter (XZ circle) of the Container.
	# Orbit radius = half the Container's footprint size, placing ports on the membrane.
	var orbit_r: float = node_size * 0.5
	var n: int = public_funcs.size()
	var port_nodes: Array = []

	for i: int in range(n):
		var sym: Dictionary = public_funcs[i]
		var sym_name: String = str(sym.get("name", "?"))
		# signature is a String like "(param1, param2) -> RetType" or "()" if absent.
		var signature: String = str(sym.get("signature", ""))

		# Has parameters? → input port (cyan). No params → output port (amber).
		# "()" means no parameters — pure query / factory.
		# input port: function accepts something (has parameters beyond self)
		# output port: function takes no meaningful input — emits a result
		var has_params: bool = signature != "()" and signature != ""
		var port_color: Color = PORT_INPUT_COLOR if has_params else PORT_OUTPUT_COLOR

		# Equidistant angle around the full circle.
		var angle: float = TAU * float(i) / float(n)
		# Port is placed on the membrane edge: orbit_r from centre in XZ plane.
		var px: float = cos(angle) * orbit_r
		var pz: float = sin(angle) * orbit_r

		# Port anchor — Node3D parented to the Container anchor.
		var port_anchor := Node3D.new()
		port_anchor.name = "Port_" + sym_name
		port_anchor.position = Vector3(px, PORT_Y_LEVEL, pz)
		anchor.add_child(port_anchor)

		# Port sphere mesh — small sphere to mark the interface point.
		var sphere := SphereMesh.new()
		sphere.radius = PORT_RADIUS
		sphere.height = PORT_RADIUS * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4

		var port_mat := StandardMaterial3D.new()
		port_mat.albedo_color = port_color
		port_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var port_mesh := MeshInstance3D.new()
		port_mesh.name = "PortMesh"
		port_mesh.mesh = sphere
		port_mesh.material_override = port_mat
		port_anchor.add_child(port_mesh)

		# Port label — shows the function name; billboard so it always faces camera.
		var label := Label3D.new()
		label.name = "PortLabel"
		label.text = sym_name
		label.pixel_size = PORT_LABEL_PIXEL_SIZE
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		# Offset label slightly outward and upward from the sphere.
		label.position = Vector3(0.0, PORT_RADIUS * 2.5, 0.0)
		port_anchor.add_child(label)

		port_nodes.append(port_anchor)

	return port_nodes


# ---------------------------------------------------------------------------
# Badge rendering
# ---------------------------------------------------------------------------

## Render badge spheres above the node volume.
##
## Badges are arranged in a row along the X-axis, centred on the node,
## at a fixed Y-offset above the node's top surface.
##
## Spec §Scenario: Multiple badges — all Badges are visible, arranged in a
## consistent order.
## Spec §Scenario: Badge vocabulary — at minimum: pure, io, async, stateful,
## error_handling, test, entry_point, deprecated.
func _render_badges(
	badges: Array, anchor: Node3D, node_size: float
) -> void:
	var n: int = badges.size()
	var total_width: float = (n - 1) * BADGE_SPACING
	var start_x: float = -total_width * 0.5
	# Badges sit above the node top; node box height ≈ size * 0.6 (module) or
	# size * 0.2 (context).  Use the larger offset to clear both types.
	var badge_y: float = node_size * 0.35 + BADGE_Y_OFFSET

	for i: int in range(n):
		var badge_type: String = str(badges[i])
		var color: Color = BADGE_COLORS.get(badge_type, Color(0.7, 0.7, 0.7))

		var badge_mesh := SphereMesh.new()
		badge_mesh.radius = BADGE_RADIUS
		badge_mesh.height = BADGE_RADIUS * 2.0
		badge_mesh.radial_segments = 8
		badge_mesh.rings = 4

		var badge_mat := StandardMaterial3D.new()
		badge_mat.albedo_color = color
		badge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		var badge_instance := MeshInstance3D.new()
		badge_instance.name = "Badge_" + badge_type
		badge_instance.mesh = badge_mesh
		badge_instance.material_override = badge_mat
		badge_instance.position = Vector3(
			start_x + float(i) * BADGE_SPACING,
			badge_y,
			0.0
		)
		anchor.add_child(badge_instance)


# ---------------------------------------------------------------------------
# Landmark rendering
# ---------------------------------------------------------------------------

## Apply landmark visual treatment to *anchor*.
##
## A landmark node is distinguished by:
##   1. A scale multiplier (LANDMARK_SCALE) applied to the anchor so the
##      entire node appears larger than a non-landmark peer.
##   2. A golden torus ring placed at the node's base.  The ring is always
##      visible, acting as a persistent orientation anchor at all LOD levels.
##
## Spec §Scenario: Hub as landmark — larger, brighter, or marked with a glyph.
## Spec §Scenario: Landmark sources — hubs (high in-degree), bridges
## (high betweenness centrality).
func _apply_landmark(anchor: Node3D, node_size: float) -> void:
	# Scale the entire anchor up uniformly so it stands out from peers.
	anchor.scale = Vector3.ONE * LANDMARK_SCALE

	# Torus ring: built from a TorusMesh (Godot 4 has this natively).
	var torus := TorusMesh.new()
	torus.outer_radius = node_size * LANDMARK_RING_OUTER_RADIUS
	torus.inner_radius = (
		node_size * LANDMARK_RING_OUTER_RADIUS * LANDMARK_RING_INNER_RADIUS_RATIO
	)
	torus.rings = 16
	torus.ring_segments = 8

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = LANDMARK_COLOR
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring_instance := MeshInstance3D.new()
	ring_instance.name = "LandmarkRing"
	ring_instance.mesh = torus
	ring_instance.material_override = ring_mat
	# Place ring flat on the ground plane (Y=0) around the node base.
	ring_instance.position = Vector3(0.0, 0.0, 0.0)
	anchor.add_child(ring_instance)


# ---------------------------------------------------------------------------
# Power Rail rendering
# ---------------------------------------------------------------------------

## Render a power rail indicator disc at the base of *anchor*.
##
## The disc is a thin flat cylinder placed just below the node volume.
## Its presence signals to the human that this node has one or more
## ubiquitous dependencies whose edges are suppressed.
##
## Spec §Scenario: Standard library power rail — each Node that imports
## logging has a small, consistent indicator (e.g. a tiny rail glyph at
## its base).
## Spec §Scenario: Multiple power rails — indicators are visually consistent
## (same glyph, same position).
func _render_power_rail(anchor: Node3D, node_size: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = node_size * POWER_RAIL_RADIUS
	disc.bottom_radius = node_size * POWER_RAIL_RADIUS
	disc.height = POWER_RAIL_HEIGHT
	disc.radial_segments = 16
	disc.rings = 1

	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = POWER_RAIL_COLOR
	rail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var disc_instance := MeshInstance3D.new()
	disc_instance.name = "PowerRailDisc"
	disc_instance.mesh = disc
	disc_instance.material_override = rail_mat
	disc_instance.position = Vector3(0.0, POWER_RAIL_Y_OFFSET, 0.0)
	anchor.add_child(disc_instance)
