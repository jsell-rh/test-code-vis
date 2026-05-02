extends RefCounted

## Port Primitive renderer for code-vis.
##
## Implements the Port primitive from visual-primitives.spec.md
## § Requirement: Port Primitive:
##   "a small visual element anchored to a Container's membrane, representing
##    an interface point (public function, API endpoint, event emitter)"
##
## Ports are placed ON the membrane (outer boundary) of Container nodes
## (module or bounded_context).  Input ports (functions that only accept
## parameters) are visually distinct from output ports (functions that
## produce return values) via distinct colours.
##
## LOD: ports are registered as node_type "port" in the LOD entry array.
## LodManager shows "port" nodes only at NEAR distance — hidden at FAR and
## MEDIUM — implementing the spec scenario: "Ports are hidden [at far] AND as
## the human zooms in, Ports fade in on the membrane."
##
## Edge wiring: when a Port is created for a public function, the function
## node's world position in _world_positions is overridden with the port's
## world-space membrane position.  This causes edges that target the function
## node to terminate at the membrane Port, not at the Container body interior.
## Spec: "Edges connect to Ports, not directly to the Container body."

## Sphere radius for Port mesh glyphs.
const PORT_RADIUS: float = 0.15

## Colour for input ports (functions that only accept parameters — no return value).
## Teal: signals "receiver / consumer".
const INPUT_PORT_COLOR: Color = Color(0.20, 0.80, 0.80, 1.0)

## Colour for output ports (functions that produce a return value).
## Amber: signals "producer / provider".
const OUTPUT_PORT_COLOR: Color = Color(0.90, 0.60, 0.10, 1.0)


## Return true if a symbol is an input-only port (has parameters, no return value).
## Used to decide port colour.
static func is_input_port(sym: Dictionary) -> bool:
	var params: Array = sym.get("params", [])
	var ret: String = sym.get("return_type", "")
	var has_return: bool = (ret != "" and ret != "None" and ret != "null")
	return params.size() > 0 and not has_return


## Return true if a symbol is an output port (has a return value).
## Bidirectional symbols (params + return) are treated as output ports.
static func is_output_port(sym: Dictionary) -> bool:
	var ret: String = sym.get("return_type", "")
	return ret != "" and ret != "None" and ret != "null"


## Add Port primitives to a container anchor for all its public symbols.
##
## Ports are placed on the +X membrane face of the container, spread
## evenly along the Z axis.  Each port's world position is stored in
## world_positions under the matching function/method child node ID so that
## edge creation in main.gd routes edges to the port, not the container body.
##
## Parameters:
##   container_anchor:  Node3D anchor for the container (already in scene).
##   node_data:         Raw node dict (must contain "id", "size", "symbols").
##   sz:                Container's 'size' field as a float.
##   container_world:   Container's world-space centre (from _world_positions).
##   world_positions:   Mutable _world_positions dict from main.gd (updated here).
##   node_data_map:     All node dicts keyed by ID (to find child function nodes).
##
## Returns Array of {anchor: Node3D, node_type: "port"} for LOD registration.
func add_ports_to_container(
	container_anchor: Node3D,
	node_data: Dictionary,
	sz: float,
	container_world: Vector3,
	world_positions: Dictionary,
	node_data_map: Dictionary
) -> Array:
	var lod_entries: Array = []
	var symbols: Array = node_data.get("symbols", [])
	var container_id: String = node_data.get("id", "")

	# Ports represent the public interface — filter to public symbols only.
	var public_syms: Array = []
	for sym: Dictionary in symbols:
		if sym.get("visibility", "") == "public":
			public_syms.append(sym)

	if public_syms.is_empty():
		return lod_entries

	var count: int = public_syms.size()

	# Ports sit on the +X membrane face of the container box.
	# Container box width = sz, so the membrane is at local x = sz * 0.5.
	var membrane_x: float = sz * 0.5

	# Y: on the top surface of the container box.
	# Module box height = sz * 0.6, so half-height = sz * 0.3.
	var port_y: float = sz * 0.30

	# Z: spread ports evenly along [−sz*0.4, +sz*0.4] within the box depth.
	var z_start: float = -sz * 0.4
	var z_range: float = sz * 0.8
	var z_step: float = z_range / float(count + 1)

	for i: int in range(count):
		var sym: Dictionary = public_syms[i]
		var sym_name: String = sym.get("name", "port_%d" % i)

		# Local position: on the membrane (+X face).
		var z_pos: float = z_start + z_step * float(i + 1)
		var local_pos := Vector3(membrane_x, port_y, z_pos)

		# Create a Node3D anchor parented to the container anchor.
		# The anchor IS the port — its local position places it ON the membrane.
		var port_anchor := Node3D.new()
		port_anchor.name = "Port_" + sym_name.replace(".", "_")
		port_anchor.position = local_pos
		container_anchor.add_child(port_anchor)

		# ── Colour encoding (spec §Port direction): input vs output ports ────────
		# Input-only port: function receives values, emits nothing.
		# Output port (default): function produces a return value, or bidirectional.
		var sym_is_input_only: bool = is_input_port(sym)
		var port_color: Color = INPUT_PORT_COLOR if sym_is_input_only else OUTPUT_PORT_COLOR

		# ── Sphere mesh glyph ─────────────────────────────────────────────────────
		var sphere := SphereMesh.new()
		sphere.radius = PORT_RADIUS
		sphere.height = PORT_RADIUS * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4

		var mat := StandardMaterial3D.new()
		mat.albedo_color = port_color
		mat.emission_enabled = true
		mat.emission = port_color * 0.5
		mat.emission_energy_multiplier = 0.3

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "PortMesh"
		mesh_inst.mesh = sphere
		mesh_inst.material_override = mat
		port_anchor.add_child(mesh_inst)

		# ── Label3D with function name ────────────────────────────────────────────
		var label := Label3D.new()
		label.text = sym_name
		# Smaller pixel_size than node labels (ports are smaller elements).
		label.pixel_size = 0.008
		label.position = Vector3(0.5, 0.15, 0.0)
		# Always face the camera for legibility.
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		port_anchor.add_child(label)

		# ── Metadata for test assertions ──────────────────────────────────────────
		port_anchor.set_meta("port_name", sym_name)
		port_anchor.set_meta("is_input_only", sym_is_input_only)
		port_anchor.set_meta("port_color", port_color)

		# Register with LOD as "port" type.
		# LodManager._apply_far / _apply_medium only show "bounded_context", "module",
		# and "spec" types — so "port" entries are hidden at FAR and MEDIUM, and
		# shown at NEAR (via _apply_near which shows everything).
		# Spec §Port Primitive §Port visibility at zoom levels:
		#   "Ports are hidden [at far] AND as the human zooms in, Ports fade in"
		lod_entries.append({"anchor": port_anchor, "node_type": "port"})

		# ── Edge wiring: override world position for matching function child node ──
		# spec §Port Primitive: "Edges connect to Ports, not directly to the Container body"
		#
		# The port's world-space position = container_world + local_pos.
		# Find any child node of this container whose name matches sym_name and
		# whose type is function/method.  Override its world_positions entry so
		# that edge creation uses the membrane position, not the interior position.
		var port_world: Vector3 = container_world + local_pos
		for fn_id: String in node_data_map:
			var fn_nd: Dictionary = node_data_map[fn_id]
			if fn_nd.get("parent", "") == container_id:
				if fn_nd.get("name", "") == sym_name:
					if fn_nd.get("type", "") in ["function", "method"]:
						world_positions[fn_id] = port_world

	return lod_entries
