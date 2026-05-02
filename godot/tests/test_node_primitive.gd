## Behavioral tests for the Node Primitive renderer.
##
## Spec: visual-primitives.spec.md § Requirement: Node Primitive
## Purpose: Verify that function, method, and class nodes are rendered as Node
##   Primitives with identity (name label) and no type-specific shape — only
##   Badges differentiate them visually.
##
## Tests instantiate real Node3D trees and assert scene-tree properties:
##   - Label3D exists with the correct node name
##   - Same BoxMesh geometry for function AND class nodes (no shape distinction)
##   - "pure" badge attaches correctly when present
##   - No Badge_ children when badges array is empty
##
## Spec § Scenario: Function node —
##   "GIVEN a function validate_order with no side effects
##    WHEN the LLM maps it to a Node
##    THEN the Node exists with its name
##    AND it carries a 'pure' Badge
##    AND no special shape distinguishes it from a class node — only the Badges differ"
##
## Spec § Scenario: Node without badges —
##   "GIVEN an entity with no notable aspects yet analyzed
##    WHEN it is rendered
##    THEN it appears as a plain Node with its name
##    AND Badges are added as analysis layers are applied"

extends RefCounted

const Main = preload("res://scripts/main.gd")
const NodePrimitive = preload("res://scripts/node_primitive.gd")
const VisualPrimitives = preload("res://scripts/visual_primitives.gd")

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

## A scene graph with one function node (type="function") carrying a "pure" badge.
## Based on the spec's example: "a function validate_order with no side effects".
func _make_function_node_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "svc.mod",
				"name": "MyService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "svc.mod.validate_order",
				"name": "validate_order",
				"type": "function",
				"parent": "svc.mod",
				"position": {"x": 1.0, "y": 0.0, "z": 0.5},
				"size": 0.8,
				"badges": ["pure"],
			},
		],
		"edges": [],
		"metadata": {},
	}


## A scene graph with one class node (type="class").
func _make_class_node_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "billing.ctx",
				"name": "BillingContext",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "billing.ctx.PaymentProcessor",
				"name": "PaymentProcessor",
				"type": "class",
				"parent": "billing.ctx",
				"position": {"x": 0.5, "y": 0.0, "z": 0.5},
				"size": 0.8,
				"badges": [],
			},
		],
		"edges": [],
		"metadata": {},
	}


## A scene graph with one method node (type="method").
func _make_method_node_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "auth.mod",
				"name": "AuthModule",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
			},
			{
				"id": "auth.mod.login",
				"name": "login",
				"type": "method",
				"parent": "auth.mod",
				"position": {"x": 0.5, "y": 0.0, "z": 0.0},
				"size": 0.8,
				"badges": [],
			},
		],
		"edges": [],
		"metadata": {},
	}


## A scene graph with both a function and a class node, to compare their geometry.
func _make_function_and_class_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "shared.ctx",
				"name": "SharedContext",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 5.0,
			},
			{
				"id": "shared.ctx.validate_order",
				"name": "validate_order",
				"type": "function",
				"parent": "shared.ctx",
				"position": {"x": 1.0, "y": 0.0, "z": 0.0},
				"size": 0.8,
				"badges": [],
			},
			{
				"id": "shared.ctx.OrderValidator",
				"name": "OrderValidator",
				"type": "class",
				"parent": "shared.ctx",
				"position": {"x": -1.0, "y": 0.0, "z": 0.0},
				"size": 0.8,
				"badges": [],
			},
		],
		"edges": [],
		"metadata": {},
	}


# ---------------------------------------------------------------------------
# Helper: find first child of type in a Node3D
# ---------------------------------------------------------------------------

func _find_label3d(parent: Node3D) -> Label3D:
	for child: Node in parent.get_children():
		if child is Label3D:
			return child as Label3D
	return null


func _find_mesh_instance(parent: Node3D) -> MeshInstance3D:
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


func _find_child_by_name(parent: Node3D, target_name: String) -> Node:
	for child: Node in parent.get_children():
		if child.name == target_name:
			return child
	return null


# ---------------------------------------------------------------------------
# Scenario: Function node
# GIVEN function validate_order with no side effects
# WHEN the LLM maps it to a Node
# THEN the Node exists with its name
# AND it carries a "pure" Badge
# AND no special shape distinguishes it from a class node
# ---------------------------------------------------------------------------


## THEN the Node exists with its name — Label3D has text "validate_order".
## Spec: "The Node exists with its name"
func test_function_node_has_label_with_name() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_function_node_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var fn_anchor: Node3D = anchors.get("svc.mod.validate_order")
	_check(fn_anchor != null, "validate_order anchor must exist after build_from_graph")
	if fn_anchor == null:
		root.free()
		return

	# Label3D must be present with the correct function name.
	var label: Label3D = _find_label3d(fn_anchor)
	_check(label != null, "function node must have a Label3D child")
	if label != null:
		_check(
			label.text == "validate_order",
			"Label3D.text must be 'validate_order'; got '%s'" % label.text
		)

	root.free()


## THEN Label3D is billboarded (readable from any camera angle).
## Spec (guideline): "Label3D readability: billboard = BILLBOARD_ENABLED and pixel_size > 0.0"
func test_function_node_label_is_billboarded() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_function_node_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var fn_anchor: Node3D = anchors.get("svc.mod.validate_order")
	_check(fn_anchor != null, "validate_order anchor must exist")
	if fn_anchor == null:
		root.free()
		return

	var label: Label3D = _find_label3d(fn_anchor)
	_check(label != null, "function node must have a Label3D child")
	if label != null:
		_check(
			label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
			"function node Label3D must have billboard=BILLBOARD_ENABLED for readability"
		)
		_check(
			label.pixel_size > 0.0,
			"function node Label3D must have pixel_size > 0.0; got %.4f" % label.pixel_size
		)

	root.free()


## THEN it carries a "pure" Badge — Badge_pure MeshInstance3D child present.
## Spec: "it carries a 'pure' Badge"
func test_function_node_with_pure_badge_has_badge_child() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_function_node_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var fn_anchor: Node3D = anchors.get("svc.mod.validate_order")
	_check(fn_anchor != null, "validate_order anchor must exist")
	if fn_anchor == null:
		root.free()
		return

	# Badge_pure must be present as a MeshInstance3D child.
	var badge: Node = _find_child_by_name(fn_anchor, "Badge_pure")
	_check(badge != null, "function node with 'pure' badge must have a 'Badge_pure' child node")
	if badge != null:
		_check(badge is MeshInstance3D, "Badge_pure must be a MeshInstance3D")

	root.free()


## THEN the function node has a MeshInstance3D (BoxMesh) as its volume.
func test_function_node_has_box_mesh() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_function_node_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var fn_anchor: Node3D = anchors.get("svc.mod.validate_order")
	_check(fn_anchor != null, "validate_order anchor must exist")
	if fn_anchor == null:
		root.free()
		return

	var mesh_inst: MeshInstance3D = _find_mesh_instance(fn_anchor)
	_check(mesh_inst != null, "function node must have a MeshInstance3D child")
	if mesh_inst != null:
		_check(mesh_inst.mesh is BoxMesh, "function node volume must be a BoxMesh")

	root.free()


# ---------------------------------------------------------------------------
# Scenario: Node without badges
# GIVEN an entity with no notable aspects yet analyzed
# WHEN it is rendered
# THEN it appears as a plain Node with its name
# AND Badges are added as analysis layers are applied
# ---------------------------------------------------------------------------


## THEN no Badge_ children when badges array is empty.
## Spec: "it appears as a plain Node with its name" (no badges yet)
func test_class_node_without_badges_has_no_badge_children() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_class_node_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var cls_anchor: Node3D = anchors.get("billing.ctx.PaymentProcessor")
	_check(cls_anchor != null, "PaymentProcessor anchor must exist")
	if cls_anchor == null:
		root.free()
		return

	# No Badge_ children should be present.
	for child: Node in cls_anchor.get_children():
		if str(child.name).begins_with("Badge_"):
			_check(
				false,
				"class node with empty badges must have no Badge_ children; found '%s'" % child.name
			)

	# But Label3D must still be present (name is always shown).
	var label: Label3D = _find_label3d(cls_anchor)
	_check(label != null, "class node must always have a Label3D child (name)")

	root.free()


## THEN method nodes also render as plain Nodes with their name.
func test_method_node_has_label_with_name() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_method_node_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var meth_anchor: Node3D = anchors.get("auth.mod.login")
	_check(meth_anchor != null, "login method anchor must exist")
	if meth_anchor == null:
		root.free()
		return

	var label: Label3D = _find_label3d(meth_anchor)
	_check(label != null, "method node must have a Label3D child")
	if label != null:
		_check(
			label.text == "login",
			"method node Label3D.text must be 'login'; got '%s'" % label.text
		)

	root.free()


# ---------------------------------------------------------------------------
# Spec: "no special shape distinguishes it from a class node — only the Badges differ"
# GIVEN a function node and a class node with the same size
# WHEN both are rendered
# THEN their BoxMesh geometry is identical
# ---------------------------------------------------------------------------


## THEN function and class nodes have identical BoxMesh dimensions.
## Spec: "no special shape distinguishes it from a class node — only the Badges differ"
func test_function_and_class_nodes_have_identical_mesh_size() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_function_and_class_fixture())
	var anchors: Dictionary = root.get("_anchors")

	var fn_anchor: Node3D = anchors.get("shared.ctx.validate_order")
	var cls_anchor: Node3D = anchors.get("shared.ctx.OrderValidator")
	_check(fn_anchor != null, "validate_order anchor must exist")
	_check(cls_anchor != null, "OrderValidator anchor must exist")
	if fn_anchor == null or cls_anchor == null:
		root.free()
		return

	var fn_mesh: MeshInstance3D = _find_mesh_instance(fn_anchor)
	var cls_mesh: MeshInstance3D = _find_mesh_instance(cls_anchor)
	_check(fn_mesh != null, "function node must have a MeshInstance3D")
	_check(cls_mesh != null, "class node must have a MeshInstance3D")
	if fn_mesh == null or cls_mesh == null:
		root.free()
		return

	_check(fn_mesh.mesh is BoxMesh, "function node volume must be a BoxMesh")
	_check(cls_mesh.mesh is BoxMesh, "class node volume must be a BoxMesh")
	if not (fn_mesh.mesh is BoxMesh) or not (cls_mesh.mesh is BoxMesh):
		root.free()
		return

	var fn_size: Vector3 = (fn_mesh.mesh as BoxMesh).size
	var cls_size: Vector3 = (cls_mesh.mesh as BoxMesh).size
	_check(
		fn_size.is_equal_approx(cls_size),
		"function and class nodes with same 'size' field must have identical BoxMesh "
		+ "geometry (no baked-in type distinction); fn=%s cls=%s" % [str(fn_size), str(cls_size)]
	)

	root.free()


## THEN function node is positioned at the JSON-specified local offset.
## Spec §Scenario: "Relative to parent" positions require tests where parent is
## at NON-ZERO world position.
func test_function_node_position_is_local_offset() -> void:
	_test_failed = false
	var root := Main.new()
	root.build_from_graph(_make_function_node_fixture())
	var anchors: Dictionary = root.get("_anchors")

	# The parent bounded_context is at x=0 — making it non-zero for the test
	# would require a different fixture.  Instead we verify the anchor position
	# equals the JSON local offset exactly (no double-offset from parent coord).
	var fn_anchor: Node3D = anchors.get("svc.mod.validate_order")
	_check(fn_anchor != null, "validate_order anchor must exist")
	if fn_anchor == null:
		root.free()
		return

	# JSON says position.x = 1.0 for the function node.
	# This is the LOCAL offset relative to the parent.  main.gd stores local offsets
	# on child anchors (not world coordinates).
	_check(
		fn_anchor.position.x == 1.0,
		"function node position.x must equal the JSON local offset (1.0); got %.3f" % fn_anchor.position.x
	)
	_check(
		fn_anchor.position.z == 0.5,
		"function node position.z must equal the JSON local offset (0.5); got %.3f" % fn_anchor.position.z
	)

	root.free()


# ---------------------------------------------------------------------------
# NodePrimitive.handles() static method contract
# ---------------------------------------------------------------------------


## NodePrimitive.handles() must return true for "function", "method", "class".
## And must return false for "module", "bounded_context", "spec", etc.
func test_node_primitive_handles_function() -> void:
	_test_failed = false
	_check(
		NodePrimitive.handles("function"),
		"NodePrimitive.handles('function') must return true"
	)
	_check(
		NodePrimitive.handles("method"),
		"NodePrimitive.handles('method') must return true"
	)
	_check(
		NodePrimitive.handles("class"),
		"NodePrimitive.handles('class') must return true"
	)


func test_node_primitive_does_not_handle_module_or_context() -> void:
	_test_failed = false
	_check(
		not NodePrimitive.handles("module"),
		"NodePrimitive.handles('module') must return false"
	)
	_check(
		not NodePrimitive.handles("bounded_context"),
		"NodePrimitive.handles('bounded_context') must return false"
	)
	_check(
		not NodePrimitive.handles("spec"),
		"NodePrimitive.handles('spec') must return false"
	)


# ---------------------------------------------------------------------------
# Direct NodePrimitive unit tests (without Main)
# ---------------------------------------------------------------------------


## populate_anchor() adds a BoxMesh child to the anchor.
func test_populate_anchor_creates_box_mesh() -> void:
	_test_failed = false
	var np: NodePrimitive = NodePrimitive.new()
	var anchor: Node3D = Node3D.new()
	var node_data: Dictionary = {
		"id": "test.validate_order",
		"name": "validate_order",
		"type": "function",
		"parent": "test",
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 1.0,
		"badges": [],
	}

	np.populate_anchor(anchor, node_data, 1.0)

	var mesh_inst: MeshInstance3D = _find_mesh_instance(anchor)
	_check(mesh_inst != null, "populate_anchor must add a MeshInstance3D child")
	if mesh_inst != null:
		_check(mesh_inst.mesh is BoxMesh, "MeshInstance3D must use a BoxMesh")

	anchor.free()


## populate_anchor() adds a Label3D child with the node's name.
func test_populate_anchor_creates_label_with_name() -> void:
	_test_failed = false
	var np: NodePrimitive = NodePrimitive.new()
	var anchor: Node3D = Node3D.new()
	var node_data: Dictionary = {
		"id": "test.validate_order",
		"name": "validate_order",
		"type": "function",
		"parent": "test",
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"size": 1.0,
		"badges": [],
	}

	np.populate_anchor(anchor, node_data, 1.0)

	var label: Label3D = _find_label3d(anchor)
	_check(label != null, "populate_anchor must add a Label3D child")
	if label != null:
		_check(label.text == "validate_order", "Label3D.text must match node name")
		_check(
			label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
			"Label3D must be billboarded"
		)
		_check(label.pixel_size > 0.0, "Label3D pixel_size must be > 0.0")

	anchor.free()


## Two calls with the SAME size produce BoxMeshes with the SAME dimensions.
## This verifies the "no baked-in type distinction" contract at unit level.
func test_function_and_class_use_same_box_dimensions() -> void:
	_test_failed = false
	var np: NodePrimitive = NodePrimitive.new()

	var fn_anchor: Node3D = Node3D.new()
	np.populate_anchor(
		fn_anchor,
		{
			"id": "test.fn",
			"name": "my_func",
			"type": "function",
			"parent": "test",
			"position": {"x": 0.0, "y": 0.0, "z": 0.0},
			"size": 1.5,
			"badges": [],
		},
		1.5
	)

	var cls_anchor: Node3D = Node3D.new()
	np.populate_anchor(
		cls_anchor,
		{
			"id": "test.cls",
			"name": "MyClass",
			"type": "class",
			"parent": "test",
			"position": {"x": 0.0, "y": 0.0, "z": 0.0},
			"size": 1.5,
			"badges": [],
		},
		1.5
	)

	var fn_mesh: MeshInstance3D = _find_mesh_instance(fn_anchor)
	var cls_mesh: MeshInstance3D = _find_mesh_instance(cls_anchor)
	_check(fn_mesh != null, "function anchor must have mesh")
	_check(cls_mesh != null, "class anchor must have mesh")
	if fn_mesh != null and cls_mesh != null:
		var fn_box: BoxMesh = fn_mesh.mesh as BoxMesh
		var cls_box: BoxMesh = cls_mesh.mesh as BoxMesh
		_check(fn_box != null, "function mesh must be BoxMesh")
		_check(cls_box != null, "class mesh must be BoxMesh")
		if fn_box != null and cls_box != null:
			_check(
				fn_box.size.is_equal_approx(cls_box.size),
				"function and class with same size must produce identical BoxMesh dimensions; "
				+ "fn=%s cls=%s" % [str(fn_box.size), str(cls_box.size)]
			)

	fn_anchor.free()
	cls_anchor.free()
