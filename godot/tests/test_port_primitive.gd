## Behavioral tests for the Port Primitive renderer.
##
## Spec: visual-primitives.spec.md § Requirement: Port Primitive
## "a small visual element anchored to a Container's membrane, representing
##  an interface point (public function, API endpoint, event emitter)"
##
## Covers all three spec scenarios:
##
## Scenario: Port placement
##   GIVEN a module with 4 public functions
##   WHEN the Container is rendered
##   THEN 4 Ports appear on its membrane
##   AND each Port is labeled with the function name
##   AND Edges connect to Ports, not directly to the Container body
##
## Scenario: Port direction
##   GIVEN a function that accepts parameters and returns a value
##   WHEN it is rendered as a Port
##   THEN input Ports (parameters/dependencies) are visually distinct from
##        output Ports (return values/emitted events)
##
## Scenario: Port visibility at zoom levels
##   GIVEN a Container viewed from far away
##   WHEN the zoom level is far
##   THEN Ports are hidden (the Container appears as a solid region)
##   AND as the human zooms in, Ports fade in on the membrane
##   AND this follows the LOD Shell behavior
##
## Tests use non-zero parent positions (spec requirement: "Relative to parent"
## positions require tests where parent is at NON-ZERO world position).

extends RefCounted

const Main = preload("res://scripts/main.gd")
const LodManager = preload("res://scripts/lod_manager.gd")
const PortPrimitive = preload("res://scripts/port_primitive.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

## Module with 4 public functions — all with return values (output ports).
## Parent context is at NON-ZERO world position to test relative positioning.
func _make_four_public_functions_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "billing.ctx",
				"name": "BillingContext",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 5.0, "y": 0.0, "z": 3.0},  # NON-ZERO world position
				"size": 8.0,
				"symbols": [],
			},
			{
				"id": "billing.ctx.order_svc",
				"name": "OrderService",
				"type": "module",
				"parent": "billing.ctx",
				"position": {"x": 1.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				# 4 public symbols — each should produce a Port on the membrane.
				"symbols": [
					{"name": "create_order", "visibility": "public", "params": [], "return_type": "Order"},
					{"name": "cancel_order", "visibility": "public", "params": [{"name": "order_id", "type": "str"}], "return_type": "bool"},
					{"name": "get_order",    "visibility": "public", "params": [{"name": "order_id", "type": "str"}], "return_type": "Order"},
					{"name": "list_orders",  "visibility": "public", "params": [], "return_type": "List[Order]"},
				],
			},
		],
		"edges": [],
		"metadata": {},
	}


## Module with only private symbols — should produce ZERO Ports.
func _make_no_public_symbols_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "auth.ctx",
				"name": "AuthContext",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 5.0,
				"symbols": [],
			},
			{
				"id": "auth.ctx.validator",
				"name": "Validator",
				"type": "module",
				"parent": "auth.ctx",
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				# Private symbols only — no ports should appear.
				"symbols": [
					{"name": "_validate_token", "visibility": "private", "params": [{"name": "token", "type": "str"}], "return_type": "bool"},
					{"name": "_hash_password", "visibility": "private", "params": [{"name": "pw", "type": "str"}], "return_type": "str"},
				],
			},
		],
		"edges": [],
		"metadata": {},
	}


## Fixture with one input-only port (params, no return) and one output port (has return).
## Used to test port direction visual distinction.
func _make_direction_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "data.ctx",
				"name": "DataContext",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
				"symbols": [],
			},
			{
				"id": "data.ctx.pipeline",
				"name": "Pipeline",
				"type": "module",
				"parent": "data.ctx",
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.5,
				"symbols": [
					# Input-only port: accepts parameters, produces nothing (no return type).
					{"name": "ingest_data", "visibility": "public", "params": [{"name": "payload", "type": "bytes"}], "return_type": ""},
					# Output port: produces a return value.
					{"name": "get_result",  "visibility": "public", "params": [], "return_type": "Result"},
				],
			},
		],
		"edges": [],
		"metadata": {},
	}


## Fixture for edge-wiring test: edge from functionA to functionB (a public function).
## After build_from_graph, the edge endpoint for functionB should be at the port
## world position (on the membrane), NOT at functionB's interior position.
func _make_edge_wiring_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "svc.ctx",
				"name": "ServiceContext",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 10.0,
				"symbols": [],
			},
			{
				"id": "svc.ctx.caller_mod",
				"name": "CallerModule",
				"type": "module",
				"parent": "svc.ctx",
				"position": {"x": -3.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				"symbols": [],
			},
			{
				# Caller function — inside caller_mod. No port (no public symbols on parent).
				"id": "svc.ctx.caller_mod.call_out",
				"name": "call_out",
				"type": "function",
				"parent": "svc.ctx.caller_mod",
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 0.5,
				"symbols": [],
				"badges": [],
			},
			{
				"id": "svc.ctx.target_mod",
				"name": "TargetModule",
				"type": "module",
				"parent": "svc.ctx",
				"position": {"x": 3.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				# has a public function "my_service" — a Port will be created for it.
				"symbols": [
					{"name": "my_service", "visibility": "public", "params": [{"name": "req", "type": "Request"}], "return_type": "Response"},
				],
			},
			{
				# Target function node — child of target_mod.
				# After Port creation, its world position should be overridden to the
				# port membrane position, not its declared interior offset.
				"id": "svc.ctx.target_mod.my_service",
				"name": "my_service",
				"type": "function",
				"parent": "svc.ctx.target_mod",
				"position": {"x": 0.5, "y": 0.0, "z": 0.0},  # interior offset
				"size": 0.5,
				"symbols": [],
				"badges": [],
			},
		],
		"edges": [
			{
				"source": "svc.ctx.caller_mod.call_out",
				"target": "svc.ctx.target_mod.my_service",
				"type": "direct_call",
				"weight": 1,
				"ubiquitous": false,
			},
		],
		"metadata": {},
	}


## Fixture for LOD test: one module with public functions (will produce ports).
func _make_lod_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "lod.ctx",
				"name": "LodContext",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
				"symbols": [],
			},
			{
				"id": "lod.ctx.lod_mod",
				"name": "LodModule",
				"type": "module",
				"parent": "lod.ctx",
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 2.0,
				"symbols": [
					{"name": "lod_func", "visibility": "public", "params": [], "return_type": "str"},
				],
			},
		],
		"edges": [],
		"metadata": {},
	}


# ---------------------------------------------------------------------------
# Helper: find all Port_ children in a scene tree (recursive).
# ---------------------------------------------------------------------------

func _collect_ports(node: Node3D) -> Array:
	var ports: Array = []
	for child: Node in node.get_children():
		if child.name.begins_with("Port_"):
			ports.append(child)
		if child is Node3D:
			ports.append_array(_collect_ports(child as Node3D))
	return ports


# ---------------------------------------------------------------------------
# Scenario: Port placement — 4 public functions → 4 Ports on membrane
# ---------------------------------------------------------------------------

## Given a module with 4 public functions, 4 Port nodes appear as children.
func test_four_public_functions_produce_four_ports() -> void:
	var main := Main.new()
	main.build_from_graph(_make_four_public_functions_fixture())

	var module_anchor: Node3D = main.get_anchors().get("billing.ctx.order_svc")
	_check(module_anchor != null, "Module anchor must exist for billing.ctx.order_svc")
	if module_anchor == null:
		return

	# Count Port_ children of the module anchor.
	var port_children: Array = []
	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			port_children.append(child)

	_check(
		port_children.size() == 4,
		"Expected exactly 4 Port children on module membrane, got %d" % port_children.size()
	)

	main.free()


## Each Port label matches its public function name.
func test_port_labels_match_function_names() -> void:
	var main := Main.new()
	main.build_from_graph(_make_four_public_functions_fixture())

	var module_anchor: Node3D = main.get_anchors().get("billing.ctx.order_svc")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	var expected_names: PackedStringArray = ["create_order", "cancel_order", "get_order", "list_orders"]
	var found_names: PackedStringArray = []

	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			for sub: Node in child.get_children():
				if sub is Label3D:
					found_names.append((sub as Label3D).text)

	_check(
		found_names.size() == 4,
		"Expected 4 port labels, got %d" % found_names.size()
	)
	for expected: String in expected_names:
		_check(
			expected in found_names,
			"Port label '%s' not found in port children" % expected
		)

	main.free()


## Ports are positioned ON the membrane (at the outer boundary of the container).
## The spec says anchored to the membrane — x local position must equal sz * 0.5.
## This test uses a NON-ZERO parent world position (context at x=5, z=3).
func test_ports_are_on_membrane_not_interior() -> void:
	var main := Main.new()
	main.build_from_graph(_make_four_public_functions_fixture())

	var module_anchor: Node3D = main.get_anchors().get("billing.ctx.order_svc")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	# The module has sz = 3.0. Membrane is at local x = sz * 0.5 = 1.5.
	var membrane_x: float = 3.0 * 0.5  # = 1.5

	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			var port: Node3D = child as Node3D
			# Port local x must equal membrane_x (direct equality — not proximity).
			# Guideline: "Relative to parent" positions require direct equality check.
			_check(
				port.position.x == membrane_x,
				"Port '%s' x=%.3f must equal membrane_x=%.3f (local offset)" % [child.name, port.position.x, membrane_x]
			)

	main.free()


## Modules with ONLY private symbols produce zero Port nodes.
func test_no_ports_for_private_symbols_only() -> void:
	var main := Main.new()
	main.build_from_graph(_make_no_public_symbols_fixture())

	var module_anchor: Node3D = main.get_anchors().get("auth.ctx.validator")
	_check(module_anchor != null, "Module anchor must exist for auth.ctx.validator")
	if module_anchor == null:
		return

	var port_count: int = 0
	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			port_count += 1

	_check(
		port_count == 0,
		"Private-only module must have zero ports, got %d" % port_count
	)

	main.free()


# ---------------------------------------------------------------------------
# Scenario: Port direction — input vs output ports are visually distinct
# ---------------------------------------------------------------------------

## Input-only port has INPUT_PORT_COLOR (teal); output port has OUTPUT_PORT_COLOR (amber).
## The colour difference makes input and output ports visually distinct.
func test_input_port_color_differs_from_output_port_color() -> void:
	var main := Main.new()
	main.build_from_graph(_make_direction_fixture())

	var module_anchor: Node3D = main.get_anchors().get("data.ctx.pipeline")
	_check(module_anchor != null, "Module anchor must exist for data.ctx.pipeline")
	if module_anchor == null:
		return

	var ingest_port: Node3D = null
	var result_port: Node3D = null

	for child: Node in module_anchor.get_children():
		if child.name == "Port_ingest_data":
			ingest_port = child as Node3D
		elif child.name == "Port_get_result":
			result_port = child as Node3D

	_check(ingest_port != null, "Port_ingest_data must exist (input-only: params, no return)")
	_check(result_port != null, "Port_get_result must exist (output: has return value)")

	if ingest_port == null or result_port == null:
		return

	# Check metadata tags set by port_primitive.gd.
	var ingest_is_input: bool = bool(ingest_port.get_meta("is_input_only", false))
	var result_is_input: bool = bool(result_port.get_meta("is_input_only", false))

	_check(
		ingest_is_input == true,
		"ingest_data (params, no return) must be tagged is_input_only=true, got %s" % str(ingest_is_input)
	)
	_check(
		result_is_input == false,
		"get_result (no params, has return) must be tagged is_input_only=false, got %s" % str(result_is_input)
	)

	# Colours must differ between the two port types.
	var ingest_color: Color = ingest_port.get_meta("port_color", Color.BLACK)
	var result_color: Color = result_port.get_meta("port_color", Color.BLACK)
	_check(
		ingest_color != result_color,
		"Input and output port colors must be distinct; got same color %s" % str(ingest_color)
	)

	main.free()


## Input port is specifically the INPUT_PORT_COLOR teal.
func test_input_port_uses_input_color() -> void:
	var main := Main.new()
	main.build_from_graph(_make_direction_fixture())

	var module_anchor: Node3D = main.get_anchors().get("data.ctx.pipeline")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	var ingest_port: Node3D = null
	for child: Node in module_anchor.get_children():
		if child.name == "Port_ingest_data":
			ingest_port = child as Node3D

	_check(ingest_port != null, "Port_ingest_data must exist")
	if ingest_port == null:
		return

	var port_color: Color = ingest_port.get_meta("port_color", Color.BLACK)
	_check(
		port_color == PortPrimitive.INPUT_PORT_COLOR,
		"Input-only port must use INPUT_PORT_COLOR; got %s" % str(port_color)
	)

	main.free()


## Output port is specifically the OUTPUT_PORT_COLOR amber.
func test_output_port_uses_output_color() -> void:
	var main := Main.new()
	main.build_from_graph(_make_direction_fixture())

	var module_anchor: Node3D = main.get_anchors().get("data.ctx.pipeline")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	var result_port: Node3D = null
	for child: Node in module_anchor.get_children():
		if child.name == "Port_get_result":
			result_port = child as Node3D

	_check(result_port != null, "Port_get_result must exist")
	if result_port == null:
		return

	var port_color: Color = result_port.get_meta("port_color", Color.BLACK)
	_check(
		port_color == PortPrimitive.OUTPUT_PORT_COLOR,
		"Output port must use OUTPUT_PORT_COLOR; got %s" % str(port_color)
	)

	main.free()


# ---------------------------------------------------------------------------
# Scenario: Port visibility at zoom levels — hidden at FAR, visible at NEAR
# ---------------------------------------------------------------------------

## At FAR LOD, ports are hidden (Container appears as a solid region).
## Spec: "Ports are hidden (the Container appears as a solid region)" at far zoom.
func test_ports_hidden_at_far_lod() -> void:
	var main := Main.new()
	main.build_from_graph(_make_lod_fixture())

	var module_anchor: Node3D = main.get_anchors().get("lod.ctx.lod_mod")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	# Find the port child.
	var port_node: Node3D = null
	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			port_node = child as Node3D

	_check(port_node != null, "lod_func port must exist on lod_mod")
	if port_node == null:
		return

	# Apply FAR LOD via LodManager (distance > FAR_THRESHOLD = 80.0).
	var lod := LodManager.new()
	var node_entries: Array = []
	# The main.gd registers the port in _lod_node_entries. Collect all entries.
	# We simulate by creating a node_entries array directly with the port.
	node_entries.append({"anchor": port_node, "node_type": "port"})
	lod.update_lod(node_entries, [], LodManager.FAR_THRESHOLD + 1.0)

	# At FAR, port must be hidden.
	_check(
		port_node.visible == false,
		"Port must be HIDDEN at FAR LOD (distance > FAR_THRESHOLD)"
	)

	main.free()


## At NEAR LOD, ports become visible on the membrane.
## Spec: "as the human zooms in, Ports fade in on the membrane"
func test_ports_visible_at_near_lod() -> void:
	var main := Main.new()
	main.build_from_graph(_make_lod_fixture())

	var module_anchor: Node3D = main.get_anchors().get("lod.ctx.lod_mod")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	var port_node: Node3D = null
	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			port_node = child as Node3D

	_check(port_node != null, "lod_func port must exist")
	if port_node == null:
		return

	# First apply FAR to hide, then NEAR to show.
	var lod := LodManager.new()
	var node_entries: Array = [{"anchor": port_node, "node_type": "port"}]

	# Apply FAR — ports should be hidden.
	lod.update_lod(node_entries, [], LodManager.FAR_THRESHOLD + 1.0)
	_check(port_node.visible == false, "Port should be hidden at FAR before switching to NEAR")

	# Apply NEAR — ports should now be visible.
	lod.update_lod(node_entries, [], LodManager.NEAR_THRESHOLD - 1.0)
	_check(
		port_node.visible == true,
		"Port must be VISIBLE at NEAR LOD (distance < NEAR_THRESHOLD)"
	)

	main.free()


## At MEDIUM LOD, ports remain hidden (only bounded_context and module are shown).
## Spec: Ports follow LOD Shell behavior — hidden at far, visible at near.
func test_ports_hidden_at_medium_lod() -> void:
	var main := Main.new()
	main.build_from_graph(_make_lod_fixture())

	var module_anchor: Node3D = main.get_anchors().get("lod.ctx.lod_mod")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	var port_node: Node3D = null
	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			port_node = child as Node3D

	_check(port_node != null, "Port must exist")
	if port_node == null:
		return

	var lod := LodManager.new()
	var medium_dist: float = (LodManager.FAR_THRESHOLD + LodManager.NEAR_THRESHOLD) / 2.0
	lod.update_lod([{"anchor": port_node, "node_type": "port"}], [], medium_dist)

	_check(
		port_node.visible == false,
		"Port must be HIDDEN at MEDIUM LOD"
	)

	main.free()


# ---------------------------------------------------------------------------
# Scenario: Edges connect to Ports, not directly to the Container body
# ---------------------------------------------------------------------------

## After build_from_graph, the world position of a function node that has a
## corresponding port is overridden to the port's membrane world position.
## This causes edges that target the function to terminate at the port.
##
## The fixture places target_mod at local offset (3, 0, 0) within the context at (0,0,0).
## target_mod world pos = (3.0, 0.0, 0.0). sz = 2.0 → membrane x = 1.0.
## Port world pos = (3.0 + 1.0, sz*0.3, z_offset) = (4.0, 0.6, z_offset).
## The z_offset for 1 port at z_start + z_step * 1 = -sz*0.4 + sz*0.8/2 = 0.0.
## So port world pos = (4.0, 0.6, 0.0).
##
## The function node's original interior world pos would be:
##   target_mod_world(3,0,0) + function_local(0.5,0,0) = (3.5, 0.0, 0.0).
## After port creation, world_positions["svc.ctx.target_mod.my_service"] = (4.0, 0.6, 0.0).
func test_edge_target_overridden_to_port_world_position() -> void:
	var main := Main.new()
	main.build_from_graph(_make_edge_wiring_fixture())

	var world_positions: Dictionary = main.get_world_positions()

	# The function node's world position should be overridden to the port position.
	_check(
		world_positions.has("svc.ctx.target_mod.my_service"),
		"World positions must include the target function node ID"
	)
	if not world_positions.has("svc.ctx.target_mod.my_service"):
		main.free()
		return

	var fn_world: Vector3 = world_positions["svc.ctx.target_mod.my_service"]

	# target_mod is at world (3.0, 0.0, 0.0). sz = 2.0. Membrane x = sz * 0.5 = 1.0.
	# Port local pos = (1.0, 0.6, 0.0) (sz*0.3 = 0.6; only 1 port so z=0.0 by centering).
	# Port world pos = (3.0 + 1.0, 0.6, 0.0) = (4.0, 0.6, 0.0).
	var expected_port_x: float = 3.0 + 2.0 * 0.5  # = 4.0

	# The port x must be greater than the module center x (3.0) — it is ON the membrane.
	_check(
		fn_world.x > 3.0,
		"Function world pos x (%.3f) must be > module center x 3.0 (port is on membrane)" % fn_world.x
	)
	# The port x must equal the membrane position: module_world_x + sz * 0.5.
	_check(
		fn_world.x == expected_port_x,
		"Function world pos x (%.3f) must equal membrane position %.3f" % [fn_world.x, expected_port_x]
	)

	main.free()


## Edges that target a function node with a port terminate at the port's
## world position, not at the Container body centre.
func test_function_world_pos_not_equal_to_container_center() -> void:
	var main := Main.new()
	main.build_from_graph(_make_edge_wiring_fixture())

	var world_positions: Dictionary = main.get_world_positions()

	# Container center for target_mod.
	_check(world_positions.has("svc.ctx.target_mod"), "target_mod world pos must exist")
	_check(world_positions.has("svc.ctx.target_mod.my_service"), "Function world pos must exist")

	if not world_positions.has("svc.ctx.target_mod") or not world_positions.has("svc.ctx.target_mod.my_service"):
		main.free()
		return

	var container_center: Vector3 = world_positions["svc.ctx.target_mod"]
	var fn_world: Vector3 = world_positions["svc.ctx.target_mod.my_service"]

	_check(
		not fn_world.is_equal_approx(container_center),
		"Function world pos (%.2f, %.2f, %.2f) must NOT equal container center (%.2f, %.2f, %.2f)" % [
			fn_world.x, fn_world.y, fn_world.z,
			container_center.x, container_center.y, container_center.z
		]
	)

	main.free()


# ---------------------------------------------------------------------------
# Port structure tests — mesh and label children
# ---------------------------------------------------------------------------

## Each Port anchor has a PortMesh child (MeshInstance3D with SphereMesh).
func test_port_anchor_has_mesh_child() -> void:
	var main := Main.new()
	main.build_from_graph(_make_four_public_functions_fixture())

	var module_anchor: Node3D = main.get_anchors().get("billing.ctx.order_svc")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	var port_found: bool = false
	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			port_found = true
			var has_mesh: bool = false
			for sub: Node in child.get_children():
				if sub.name == "PortMesh" and sub is MeshInstance3D:
					var mi: MeshInstance3D = sub as MeshInstance3D
					has_mesh = mi.mesh is SphereMesh
			_check(has_mesh, "Port '%s' must have a PortMesh MeshInstance3D with SphereMesh" % child.name)

	_check(port_found, "At least one Port_ child must exist")
	main.free()


## Each Port anchor has a Label3D child (for the function name).
func test_port_anchor_has_label3d_child() -> void:
	var main := Main.new()
	main.build_from_graph(_make_four_public_functions_fixture())

	var module_anchor: Node3D = main.get_anchors().get("billing.ctx.order_svc")
	_check(module_anchor != null, "Module anchor must exist")
	if module_anchor == null:
		return

	var port_found: bool = false
	for child: Node in module_anchor.get_children():
		if child.name.begins_with("Port_"):
			port_found = true
			var has_label: bool = false
			for sub: Node in child.get_children():
				if sub is Label3D:
					has_label = true
					var lbl: Label3D = sub as Label3D
					_check(
						lbl.pixel_size > 0.0,
						"Port label must have pixel_size > 0 for readability"
					)
					_check(
						lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
						"Port label must have billboard = BILLBOARD_ENABLED"
					)
			_check(has_label, "Port '%s' must have a Label3D child" % child.name)

	_check(port_found, "At least one Port_ child must exist")
	main.free()
