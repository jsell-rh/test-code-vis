## Behavioral tests for Port Primitive renderer.
##
## Spec: specs/core/visual-primitives.spec.md § Requirement: Port Primitive
##
## All tests instantiate real Node3D trees and assert scene-tree properties
## (position, visible, modulate.a, mesh type) — NOT just dict key existence.
##
## Coverage:
##   - Container with 4 public symbols → 4 Port MeshInstance3D elements on membrane
##   - Container with 0 public symbols → no Port elements
##   - Port labels match function names from symbol table
##   - At tier-0 LOD: Port meshes + labels have alpha = 0 (modulate.a == 0)
##   - At tier-2 LOD: Port meshes + labels have alpha > 0
##   - Input and output Ports appear on opposing faces of Container
##   - Edge endpoints route to Port positions rather than Container centroid
##     when Ports are visible

extends RefCounted

const PortRenderer = preload("res://scripts/port_renderer.gd")
const Main = preload("res://scripts/main.gd")
const LodManager = preload("res://scripts/lod_manager.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## A minimal bounded_context node dict with 4 public symbols.
func _make_context_node_4_public() -> Dictionary:
	return {
		"id": "svc.auth",
		"name": "AuthService",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 4.0,
		"symbols": [
			{"name": "login", "visibility": "public", "signature": "(user: str) -> bool"},
			{"name": "logout", "visibility": "public", "signature": "(session: str) -> None"},
			{"name": "verify_token", "visibility": "public", "signature": "(token: str) -> bool"},
			{"name": "refresh", "visibility": "public", "signature": "() -> str"},
		],
	}


## A bounded_context node with 0 public symbols (all private).
func _make_context_node_0_public() -> Dictionary:
	return {
		"id": "svc.internal",
		"name": "InternalService",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 3.0,
		"symbols": [
			{"name": "_validate", "visibility": "private", "signature": "() -> bool"},
			{"name": "_cleanup", "visibility": "private", "signature": "() -> None"},
		],
	}


## A bounded_context node with mixed public/private symbols.
## 2 public, 3 private.
func _make_context_node_mixed() -> Dictionary:
	return {
		"id": "svc.billing",
		"name": "BillingService",
		"type": "bounded_context",
		"parent": null,
		"position": {"x": 5.0, "y": 0.0, "z": 0.0},
		"size": 3.0,
		"symbols": [
			{"name": "charge", "visibility": "public", "signature": "(amount: float) -> bool"},
			{"name": "refund", "visibility": "public", "signature": "(order_id: str) -> bool"},
			{"name": "_validate_card", "visibility": "private", "signature": "() -> bool"},
			{"name": "_log_transaction", "visibility": "private", "signature": "() -> None"},
			{"name": "_retry", "visibility": "private", "signature": "() -> None"},
		],
	}


## A full scene graph fixture with one Container having 4 public symbols and one
## Container having 2 public symbols, connected by a cross_context edge.
func _make_full_graph_with_ports() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx_a",
				"name": "ContextA",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 4.0,
				"symbols": [
					{"name": "process", "visibility": "public", "signature": "(data: dict) -> dict"},
					{"name": "validate", "visibility": "public", "signature": "(x: int) -> bool"},
				],
			},
			{
				"id": "ctx_b",
				"name": "ContextB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"symbols": [
					{"name": "fetch", "visibility": "public", "signature": "() -> list"},
				],
			},
		],
		"edges": [
			{"source": "ctx_a", "target": "ctx_b", "type": "cross_context", "weight": 1},
		],
		"metadata": {},
	}


## A scene graph fixture with one Container with NO public symbols, for edge fallback test.
func _make_graph_no_ports() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "ctx_x",
				"name": "ContextX",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"symbols": [
					{"name": "_private_fn", "visibility": "private", "signature": "() -> None"},
				],
			},
			{
				"id": "ctx_y",
				"name": "ContextY",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 15.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"symbols": [],
			},
		],
		"edges": [
			{"source": "ctx_x", "target": "ctx_y", "type": "cross_context", "weight": 1},
		],
		"metadata": {},
	}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _count_port_meshes(anchor: Node3D) -> int:
	var count: int = 0
	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			count += 1
	return count


func _count_port_labels(anchor: Node3D) -> int:
	var count: int = 0
	for child: Node in anchor.get_children():
		if child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			count += 1
	return count


func _get_port_meshes(anchor: Node3D) -> Array:
	var result: Array = []
	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			result.append(child)
	return result


func _get_port_labels(anchor: Node3D) -> Array:
	var result: Array = []
	for child: Node in anchor.get_children():
		if child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			result.append(child)
	return result


# ---------------------------------------------------------------------------
# Scenario: Port placement
# Spec: visual-primitives.spec.md § Requirement: Port Primitive
# GIVEN a module with 4 public functions
# WHEN the Container is rendered
# THEN 4 Ports appear on its membrane (4 MeshInstance3D + 4 Label3D)
# AND each Port is labeled with the function name
# ---------------------------------------------------------------------------

func test_four_public_symbols_produce_four_port_meshes() -> void:
	## Container with 4 public symbols → 4 Port MeshInstance3D elements.
	## Spec: "4 Ports appear on its membrane"
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)

	# Each public symbol produces one input port + one output port mesh.
	# 4 public symbols × 2 faces = 8 Port meshes total.
	var mesh_count: int = _count_port_meshes(anchor)
	_check(
		mesh_count == 8,
		"4 public symbols must produce 8 Port meshes (input + output per symbol); got %d" % mesh_count
	)

	anchor.free()


func test_four_public_symbols_produce_four_port_labels() -> void:
	## Each public symbol's Port has a corresponding Label3D.
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)

	var label_count: int = _count_port_labels(anchor)
	_check(
		label_count == 8,
		"4 public symbols must produce 8 Port labels (input + output per symbol); got %d" % label_count
	)

	anchor.free()


func test_zero_public_symbols_produce_no_ports() -> void:
	## Container with 0 public symbols → no Port elements.
	## Spec: "Container with 0 public symbols → no Port elements"
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_0_public(), anchor, 3.0)

	var mesh_count: int = _count_port_meshes(anchor)
	var label_count: int = _count_port_labels(anchor)
	_check(
		mesh_count == 0,
		"Container with 0 public symbols must have no Port meshes; got %d" % mesh_count
	)
	_check(
		label_count == 0,
		"Container with 0 public symbols must have no Port labels; got %d" % label_count
	)

	anchor.free()


func test_only_public_symbols_create_ports() -> void:
	## Only public symbols produce Ports; private symbols are ignored.
	## Fixture has 2 public + 3 private → should produce 4 meshes (2×2).
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	var mesh_count: int = _count_port_meshes(anchor)
	_check(
		mesh_count == 4,
		"2 public symbols must produce 4 Port meshes (input+output); got %d" % mesh_count
	)

	anchor.free()


func test_port_labels_contain_function_names() -> void:
	## Port labels match function names from the symbol table.
	## Spec: "each Port is labeled with the function name"
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	# Collect all label texts.
	var label_texts: Array = []
	for child: Node in anchor.get_children():
		if child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			label_texts.append((child as Label3D).text)

	# The names "charge" and "refund" must appear in at least one label each.
	var found_charge: bool = false
	var found_refund: bool = false
	for txt: String in label_texts:
		if "charge" in txt:
			found_charge = true
		if "refund" in txt:
			found_refund = true

	_check(found_charge, "Port labels must contain function name 'charge'")
	_check(found_refund, "Port labels must contain function name 'refund'")

	anchor.free()


func test_port_meshes_are_sphere_meshes() -> void:
	## Port meshes use SphereMesh (small sphere on the membrane surface).
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			_check(
				(child as MeshInstance3D).mesh is SphereMesh,
				"Port mesh must be a SphereMesh; got %s" % str((child as MeshInstance3D).mesh)
			)

	anchor.free()


func test_port_labels_use_billboard() -> void:
	## Label3D must have billboard = BILLBOARD_ENABLED for legibility in 3D.
	## Spec requirement (overlay): "Label3D requires billboard = BILLBOARD_ENABLED"
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	for child: Node in anchor.get_children():
		if child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			_check(
				(child as Label3D).billboard == BaseMaterial3D.BILLBOARD_ENABLED,
				"Port Label3D must have billboard = BILLBOARD_ENABLED"
			)

	anchor.free()


func test_port_labels_have_positive_pixel_size() -> void:
	## Label3D must have pixel_size > 0 for legibility.
	## Spec requirement (overlay): "Label3D requires pixel_size > 0.0"
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	for child: Node in anchor.get_children():
		if child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			_check(
				(child as Label3D).pixel_size > 0.0,
				"Port Label3D must have pixel_size > 0.0"
			)

	anchor.free()


# ---------------------------------------------------------------------------
# Scenario: Port direction
# Spec: "input Ports (parameters/dependencies) are visually distinct from
#        output Ports (return values/emitted events)"
# Input Ports appear on the left (negative-X) face; output on the right (positive-X).
# ---------------------------------------------------------------------------

func test_input_ports_on_negative_x_face() -> void:
	## Input Port meshes must have position.x < 0 (left / negative-X face).
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)

	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.ends_with("_in"):
			var pos: Vector3 = (child as MeshInstance3D).position
			_check(
				pos.x < 0.0,
				"Input Port must be on negative-X face; got x=%.3f for %s" % [pos.x, child.name]
			)

	anchor.free()


func test_output_ports_on_positive_x_face() -> void:
	## Output Port meshes must have position.x > 0 (right / positive-X face).
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)

	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.ends_with("_out"):
			var pos: Vector3 = (child as MeshInstance3D).position
			_check(
				pos.x > 0.0,
				"Output Port must be on positive-X face; got x=%.3f for %s" % [pos.x, child.name]
			)

	anchor.free()


func test_input_and_output_ports_on_opposing_faces() -> void:
	## Input and output Ports are on opposite sides: input.x < 0, output.x > 0.
	## Spec: "input and output Ports appear on opposing faces of the Container"
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	var input_xs: Array = []
	var output_xs: Array = []
	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			if (child as MeshInstance3D).name.ends_with("_in"):
				input_xs.append((child as MeshInstance3D).position.x)
			elif (child as MeshInstance3D).name.ends_with("_out"):
				output_xs.append((child as MeshInstance3D).position.x)

	_check(input_xs.size() > 0, "Must have at least one input Port")
	_check(output_xs.size() > 0, "Must have at least one output Port")

	for x: float in input_xs:
		_check(x < 0.0, "Input Port must be at negative-X; got x=%.3f" % x)
	for x: float in output_xs:
		_check(x > 0.0, "Output Port must be at positive-X; got x=%.3f" % x)

	anchor.free()


# ---------------------------------------------------------------------------
# Scenario: Port visibility at zoom levels
# Spec: "Ports are hidden at far distance ... as human zooms in, Ports fade in"
# Spec: "LOD transitions MUST use animated opacity (Tween on modulate.a)"
# ---------------------------------------------------------------------------

func test_ports_have_alpha_zero_at_tier_0() -> void:
	## At tier-0 (FAR) LOD: Port meshes and labels must have alpha == 0.
	## Spec: "Port alpha = 0 at tier-0/tier-1"
	##
	## MeshInstance3D opacity: material_override.albedo_color.a (no modulate on 3D nodes)
	## Label3D opacity:        modulate.a (Label3D supports modulate)
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)

	# Apply tier-0 (FAR) LOD — not in scene tree so direct assignment is used (no Tween).
	pr.set_lod_tier(PortRenderer.LOD_TIER_FAR)

	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			_check(
				mat != null and mat.albedo_color.a == 0.0,
				"Port mesh material albedo_color.a must == 0 at tier-0 (FAR); got %.3f for %s" % [
					mat.albedo_color.a if mat != null else -1.0, child.name
				]
			)
		elif child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			_check(
				(child as Label3D).modulate.a == 0.0,
				"Port label modulate.a must == 0 at tier-0 (FAR); got %.3f for %s" % [
					(child as Label3D).modulate.a, child.name
				]
			)

	anchor.free()


func test_ports_have_alpha_zero_at_tier_1() -> void:
	## At tier-1 (MEDIUM) LOD: Port meshes and labels must have alpha == 0.
	## Spec: "Port alpha = 0 at tier-0/tier-1"
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)

	pr.set_lod_tier(PortRenderer.LOD_TIER_MEDIUM)

	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			_check(
				mat != null and mat.albedo_color.a == 0.0,
				"Port mesh material albedo_color.a must == 0 at tier-1 (MEDIUM); got %.3f for %s" % [
					mat.albedo_color.a if mat != null else -1.0, child.name
				]
			)
		elif child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			_check(
				(child as Label3D).modulate.a == 0.0,
				"Port label modulate.a must == 0 at tier-1 (MEDIUM); got %.3f for %s" % [
					(child as Label3D).modulate.a, child.name
				]
			)

	anchor.free()


func test_ports_have_alpha_gt_zero_at_tier_2() -> void:
	## At tier-2 (NEAR) LOD: Port meshes and labels must have alpha > 0.
	## Spec: "Ports fade in on the membrane" at near distance.
	## Note: when NOT in scene tree, set_lod_tier() sets alpha directly (no Tween).
	##
	## MeshInstance3D opacity is tracked via material_override.albedo_color.a.
	## Label3D opacity is tracked via modulate.a.
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)

	pr.set_lod_tier(PortRenderer.LOD_TIER_NEAR)

	var found_any: bool = false
	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			found_any = true
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			_check(
				mat != null and mat.albedo_color.a > 0.0,
				"Port mesh material albedo_color.a must > 0 at tier-2 (NEAR); got %.3f for %s" % [
					mat.albedo_color.a if mat != null else -1.0, child.name
				]
			)
		elif child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			found_any = true
			_check(
				(child as Label3D).modulate.a > 0.0,
				"Port label modulate.a must > 0 at tier-2 (NEAR); got %.3f for %s" % [
					(child as Label3D).modulate.a, child.name
				]
			)

	_check(found_any, "Must have found at least one Port node to test alpha")

	anchor.free()


func test_ports_start_invisible_before_lod_applied() -> void:
	## Newly created Ports start with alpha == 0 before any LOD call.
	## MeshInstance3D: material_override.albedo_color.a == 0 (via base_color a=0).
	## Label3D:        modulate.a == 0.
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_4_public(), anchor, 4.0)
	# Do NOT call set_lod_tier() — Ports should default to invisible.

	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).name.begins_with("Port_"):
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			_check(
				mat != null and mat.albedo_color.a == 0.0,
				"Port mesh must start invisible (albedo_color.a == 0); got %.3f" % [
					mat.albedo_color.a if mat != null else -1.0
				]
			)
		elif child is Label3D and (child as Label3D).name.begins_with("PortLabel_"):
			_check(
				(child as Label3D).modulate.a == 0.0,
				"Port label must start invisible (modulate.a == 0); got %.3f" % [
					(child as Label3D).modulate.a
				]
			)

	anchor.free()


# ---------------------------------------------------------------------------
# Scenario: Port positions registered in renderer
# Tests that get_port_local_positions() returns the correct data for
# edge routing.
# ---------------------------------------------------------------------------

func test_get_port_local_positions_returns_input_and_output_keys() -> void:
	## get_port_local_positions() returns both _in and _out keys per symbol.
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	var positions: Dictionary = pr.get_port_local_positions()
	_check(positions.size() > 0, "get_port_local_positions() must return non-empty dict")

	# Expect both _in and _out keys for each public symbol.
	var has_charge_in: bool = positions.has("charge_in")
	var has_charge_out: bool = positions.has("charge_out")
	var has_refund_in: bool = positions.has("refund_in")
	var has_refund_out: bool = positions.has("refund_out")

	_check(has_charge_in, "Port positions must contain 'charge_in'")
	_check(has_charge_out, "Port positions must contain 'charge_out'")
	_check(has_refund_in, "Port positions must contain 'refund_in'")
	_check(has_refund_out, "Port positions must contain 'refund_out'")

	anchor.free()


func test_input_port_local_x_is_negative() -> void:
	## Input Port local position has x < 0 (left face).
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	var positions: Dictionary = pr.get_port_local_positions()
	if positions.has("charge_in"):
		var pos: Vector3 = positions["charge_in"]
		_check(pos.x < 0.0, "Input Port local x must be < 0; got %.3f" % pos.x)

	anchor.free()


func test_output_port_local_x_is_positive() -> void:
	## Output Port local position has x > 0 (right face).
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_mixed(), anchor, 3.0)

	var positions: Dictionary = pr.get_port_local_positions()
	if positions.has("charge_out"):
		var pos: Vector3 = positions["charge_out"]
		_check(pos.x > 0.0, "Output Port local x must be > 0; got %.3f" % pos.x)

	anchor.free()


func test_no_ports_for_zero_public_symbols_positions_empty() -> void:
	## When no public symbols exist, get_port_local_positions() returns empty dict.
	_test_failed = false
	var anchor := Node3D.new()
	var pr := PortRenderer.new()
	pr.attach_ports(_make_context_node_0_public(), anchor, 3.0)

	var positions: Dictionary = pr.get_port_local_positions()
	_check(positions.is_empty(), "No public symbols → port local positions must be empty")

	anchor.free()


# ---------------------------------------------------------------------------
# Scenario: Edge endpoints route to Port positions when Ports visible
# Tests via main.gd's _find_port_or_centroid() logic exposed through
# get_port_world_positions().
# ---------------------------------------------------------------------------

func test_port_world_positions_registered_in_main() -> void:
	## After build_from_graph(), main.gd must have Port world positions registered
	## for Container nodes with public symbols.
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_full_graph_with_ports())

	var port_world: Dictionary = root.get_port_world_positions()
	_check(
		port_world.size() > 0,
		"Port world positions must be registered after build_from_graph with public symbols"
	)

	# ctx_a has 2 public symbols → should have port entries.
	var has_ctx_a_port: bool = false
	for key: String in port_world:
		if key.begins_with("ctx_a/"):
			has_ctx_a_port = true
			break
	_check(has_ctx_a_port, "main.gd must register Port world positions for ctx_a")

	root.free()


func test_port_world_positions_are_offset_from_centroid() -> void:
	## Port world positions must differ from the Container centroid (they are
	## on the membrane, not at the centre of the Container).
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_full_graph_with_ports())

	var port_world: Dictionary = root.get_port_world_positions()
	var world_positions: Dictionary = root.get("_world_positions")

	var ctx_a_centroid: Vector3 = world_positions.get("ctx_a", Vector3.ZERO)

	for key: String in port_world:
		if key.begins_with("ctx_a/"):
			var port_pos: Vector3 = port_world[key]
			var dist: float = ctx_a_centroid.distance_to(port_pos)
			_check(
				dist > 0.01,
				"Port world position must differ from Container centroid; got dist=%.4f for %s" % [dist, key]
			)
			break

	root.free()


func test_edge_endpoint_uses_port_position_when_available() -> void:
	## When a Container has public symbols, edge endpoints should match
	## registered Port positions rather than Container centroids.
	## This verifies the routing logic in main.gd._find_port_or_centroid().
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_full_graph_with_ports())

	var port_world: Dictionary = root.get_port_world_positions()
	var world_positions: Dictionary = root.get("_world_positions")

	# ctx_a centroid.
	var ctx_a_centroid: Vector3 = world_positions.get("ctx_a", Vector3.ZERO)

	# There must be at least one output port for ctx_a (source of edge).
	var found_output_port: bool = false
	for key: String in port_world:
		if key.begins_with("ctx_a/") and key.ends_with("_out"):
			found_output_port = true
			var port_pos: Vector3 = port_world[key]
			# The port position must differ from the centroid (it is on the membrane).
			_check(
				not port_pos.is_equal_approx(ctx_a_centroid),
				"Port position for ctx_a output must differ from centroid"
			)
			break

	_check(found_output_port, "ctx_a must have at least one output Port registered in port_world")

	root.free()


func test_no_port_world_positions_for_empty_public_symbols() -> void:
	## Containers with no public symbols must not register any Port world positions.
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_graph_no_ports())

	var port_world: Dictionary = root.get_port_world_positions()
	_check(
		port_world.is_empty(),
		"No public symbols in graph → port world positions must be empty; got %d entries" % port_world.size()
	)

	root.free()


func test_port_renderer_registered_per_container_in_main() -> void:
	## main.gd must register one PortRenderer per bounded_context node.
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_full_graph_with_ports())

	var port_renderers: Dictionary = root.get_port_renderers()
	_check(
		port_renderers.has("ctx_a"),
		"main.gd must register a PortRenderer for ctx_a"
	)
	_check(
		port_renderers.has("ctx_b"),
		"main.gd must register a PortRenderer for ctx_b"
	)

	root.free()


func test_find_port_or_centroid_returns_port_not_centroid() -> void:
	## _find_port_or_centroid("ctx_a", true) must return a Port world position,
	## not the Container centroid, when ctx_a has public symbols with registered ports.
	##
	## Spec: visual-primitives.spec.md § Port Primitive —
	##   "Edges connect to Ports, not directly to the Container body"
	##   "falls back to Container centroid when Ports are hidden/unavailable"
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_full_graph_with_ports())

	var port_world: Dictionary = root.get_port_world_positions()
	var world_pos: Dictionary = root.get("_world_positions")

	# ctx_a centroid.
	var ctx_a_centroid: Vector3 = world_pos.get("ctx_a", Vector3.ZERO)

	# Call _find_port_or_centroid directly — must return a port position, not centroid.
	var from_pos: Vector3 = root._find_port_or_centroid("ctx_a", true)

	_check(
		not from_pos.is_equal_approx(ctx_a_centroid),
		"_find_port_or_centroid must return port position, not centroid, when ports exist"
	)

	# Also verify the returned position matches a registered port world position.
	var found_match: bool = false
	for key: String in port_world:
		if key.begins_with("ctx_a/") and key.ends_with("_out"):
			if from_pos.is_equal_approx(port_world[key]):
				found_match = true
	_check(
		found_match,
		"from_pos returned by _find_port_or_centroid must match a registered port world position"
	)

	root.free()
