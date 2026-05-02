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
##   Port Primitive — small sphere markers anchored to a Container's membrane
##     representing public function interface points.  Visible at NEAR zoom only.
##     Spec §Requirement: Port Primitive.
##
##   Tint Primitive — categorical background colors for Container nodes encoding
##     one dimension of categorical data (e.g. domain ownership).  A palette of
##     6 desaturated colors is pre-defined.  Spec §Requirement: Tint Primitive.
##
## Usage: call attach_primitives(node_data, anchor) after the base volume has
## been created.  The function inspects the node_data dict and attaches the
## appropriate child nodes to the anchor.
## Call render_ports(symbols, anchor, node_size, lod_entries) to add Port markers.
## Call get_tint(index) to retrieve a categorical fill color for a Container.

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


# ===========================================================================
# Tint Primitive
# ===========================================================================

## Categorical color palette for the Tint Primitive.
##
## Desaturated colors allow simultaneous use alongside other primitives
## without visual interference.  Limited to 6 entries per the spec:
##   "palette is limited to 4-6 categorical colors (preattentive discrimination limit)"
## Spec §Requirement: Tint Primitive / §Scenario: Domain tinting.
const TINT_PALETTE: Array[Color] = [
	Color(0.38, 0.58, 0.82, 1.0),  # muted blue   — domain 0
	Color(0.38, 0.72, 0.52, 1.0),  # muted green  — domain 1
	Color(0.82, 0.62, 0.32, 1.0),  # muted amber  — domain 2
	Color(0.68, 0.38, 0.68, 1.0),  # muted purple — domain 3
	Color(0.72, 0.42, 0.42, 1.0),  # muted red    — domain 4
	Color(0.38, 0.72, 0.72, 1.0),  # muted teal   — domain 5
]


## Return the categorical Tint color for a Container at position *index*.
##
## The index wraps around the palette when there are more bounded contexts
## than palette entries.  The returned Color's alpha is always 1.0 — the
## caller (main.gd) overlays the permeability alpha before assigning to the
## material so that Tint and membrane permeability use independent channels.
##
## Spec §Requirement: Tint Primitive:
##   "each context has a distinct desaturated fill color"
##   "palette is limited to 4-6 categorical colors"
##   "only ONE categorical dimension is encoded via Tint at a time"
func get_tint(index: int) -> Color:
	return TINT_PALETTE[index % TINT_PALETTE.size()]


# ===========================================================================
# Port Primitive
# ===========================================================================

## Radius of each Port marker sphere in scene units.
## Small enough to sit on the Container membrane without obscuring the label.
const PORT_RADIUS: float = 0.12

## Offset added to the Container half-size so ports sit on the membrane face.
const PORT_EDGE_OFFSET: float = 0.06

## Base color for all Port markers: light grey to stand out against Container fill.
## Spec §Port Primitive — "a small visual element anchored to a Container's membrane"
const PORT_COLOR: Color = Color(0.88, 0.88, 0.88, 0.92)

## Label3D pixel_size for Port labels — slightly smaller than node labels.
const PORT_LABEL_PIXEL_SIZE: float = 0.008


## Render Port markers on a Container's membrane for each public function.
##
## For every symbol with visibility="public" and kind="function", a small sphere
## is placed on the front face of the Container box and labeled with the function
## name.  All port visuals (sphere + label anchor) are appended to *lod_entries*
## with node_type="port" so that the LOD manager hides them at FAR and MEDIUM
## zoom levels and reveals them only at NEAR.
##
## Spec §Requirement: Port Primitive / §Scenario: Port placement:
##   "4 Ports appear on its membrane"
##   "each Port is labeled with the function name"
## Spec §Scenario: Port visibility at zoom levels:
##   "WHEN the zoom level is far THEN Ports are hidden"
##   "as the human zooms in, Ports fade in on the membrane"
##
## Parameters:
##   symbols:     Array of SymbolInfo dicts (from scene graph node["symbols"])
##   anchor:      Container Node3D anchor to attach Port markers to
##   node_size:   The node's 'size' field — used to compute membrane position
##   lod_entries: LOD entry array — port visuals are appended with type "port"
func render_ports(
	symbols: Array,
	anchor: Node3D,
	node_size: float,
	lod_entries: Array,
) -> void:
	# Collect public functions only — private symbols are NOT ports.
	# Spec §Scenario: Port placement: ports represent public interface points.
	var public_fns: Array = []
	for sym: Dictionary in symbols:
		if sym.get("visibility", "") == "public" and sym.get("kind", "") == "function":
			public_fns.append(sym)

	if public_fns.is_empty():
		return

	var n: int = public_fns.size()
	# Space ports evenly across the front face of the Container box.
	# The Container box spans [-node_size, +node_size] on X (size = full width).
	var total_span: float = node_size * 1.6  # 80% of the box width
	var spacing: float = total_span / float(max(n, 1))
	var start_x: float = -(total_span * 0.5) + spacing * 0.5

	# Y: near the top of the Container surface (bounded_context height ≈ size * 0.2)
	var port_y: float = node_size * 0.12 + PORT_RADIUS

	# Z: the front face of the box is at +node_size/2; add a small offset so
	# the sphere visually sits on the membrane rather than inside it.
	var port_z: float = node_size * 0.5 + PORT_EDGE_OFFSET

	for i: int in range(n):
		var sym: Dictionary = public_fns[i]
		var fn_name: String = str(sym.get("name", "fn_%d" % i))

		# --- Port sphere mesh -----------------------------------------------
		var port_mesh := SphereMesh.new()
		port_mesh.radius = PORT_RADIUS
		port_mesh.height = PORT_RADIUS * 2.0
		port_mesh.radial_segments = 8
		port_mesh.rings = 4

		var port_mat := StandardMaterial3D.new()
		port_mat.albedo_color = PORT_COLOR
		port_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		port_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var port_instance := MeshInstance3D.new()
		port_instance.name = "Port_" + fn_name
		port_instance.mesh = port_mesh
		port_instance.material_override = port_mat
		port_instance.position = Vector3(
			start_x + float(i) * spacing,
			port_y,
			port_z,
		)
		anchor.add_child(port_instance)

		# --- Port label -------------------------------------------------------
		# Label3D sits above the sphere so the function name is readable.
		var port_label := Label3D.new()
		port_label.name = "PortLabel_" + fn_name
		port_label.text = fn_name
		port_label.pixel_size = PORT_LABEL_PIXEL_SIZE
		port_label.position = port_instance.position + Vector3(0.0, PORT_RADIUS + 0.08, 0.0)
		port_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		port_label.no_depth_test = true
		anchor.add_child(port_label)

		# Register both visuals as "port" type so LOD manager shows them only at NEAR.
		# Spec §Scenario: Port visibility at zoom levels —
		#   "WHEN the zoom level is far THEN Ports are hidden"
		#   "as the human zooms in, Ports fade in on the membrane"
		lod_entries.append({"anchor": port_instance, "node_type": "port"})
		lod_entries.append({"anchor": port_label, "node_type": "port"})
