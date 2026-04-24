## Behavioral tests for specs/core/system-purpose.spec.md
##
## Spec: System Purpose Specification
## Purpose: Enable humans to acquire concrete understanding of agent-built software
##          systems, fast enough to make informed architectural decisions about them.
##
## Requirements and scenarios covered:
##
##   Requirement: Understanding Without Writing Code
##   Scenario: Architect evaluates unfamiliar system
##     GIVEN an agent-built software system the human has not read the code of
##     WHEN the human uses this system to explore it
##     THEN the human can correctly answer architectural questions about the system
##       → test_bounded_contexts_are_structurally_identifiable
##       → test_node_names_are_labelled_for_identification
##       → test_label_billboard_enabled_for_readability
##       → test_label_pixel_size_positive_for_readability
##     AND the human can identify structural problems in the system
##       → test_dependencies_are_visible_as_connections
##       → test_cross_context_and_internal_edges_are_distinguishable
##     AND the human can predict the impact of proposed changes
##       → test_dependency_direction_is_encoded_in_edges
##       → test_modules_are_contained_within_bounded_contexts
##
##   Requirement: Spec-Driven Context
##   Scenario: Spec and codebase loaded together
##     → NOT IMPLEMENTED: out of scope for the prototype
##       (prototype-scope.spec.md § Not In Scope: conformance mode is not implemented)
##
##   Requirement: Support the Architecture Feedback Loop
##   Scenario: Post-build evaluation
##     → NOT IMPLEMENTED: out of scope for the prototype
##       (prototype-scope.spec.md § Not In Scope: conformance/evaluation/simulation modes
##        are not implemented)
##
## Each test_* method is discovered and run by tests/run_tests.gd.

extends RefCounted

const MainScript := preload("res://scripts/main.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Fixture — a representative system with two bounded contexts, modules, and edges.
# Simulates an "agent-built software system" that a human is evaluating.
# ---------------------------------------------------------------------------

func _make_system_fixture() -> Dictionary:
	return {
		"nodes": [
			{
				"id": "auth",
				"name": "AuthService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -10.0, "y": 0.0, "z": 0.0},
				"size": 8.0,
				"metrics": {"loc": 500},
			},
			{
				"id": "billing",
				"name": "BillingService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 10.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
				"metrics": {"loc": 350},
			},
			{
				"id": "auth.domain",
				"name": "AuthDomain",
				"type": "module",
				"parent": "auth",
				"position": {"x": -2.0, "y": 0.0, "z": -2.0},
				"size": 3.0,
				"metrics": {"loc": 200},
			},
			{
				"id": "billing.payments",
				"name": "Payments",
				"type": "module",
				"parent": "billing",
				"position": {"x": 2.0, "y": 0.0, "z": 2.0},
				"size": 2.5,
				"metrics": {"loc": 150},
			},
		],
		"edges": [
			{"source": "billing", "target": "auth", "type": "cross_context"},
			{"source": "billing.payments", "target": "auth.domain", "type": "internal"},
		],
		"metadata": {
			"source_path": "/tmp/example_system",
			"timestamp": "2026-04-24T00:00:00Z",
		},
	}


# ---------------------------------------------------------------------------
# Requirement: Understanding Without Writing Code
# Scenario: Architect evaluates unfamiliar system
#
# THEN the human can correctly answer architectural questions about the system
# ---------------------------------------------------------------------------

## Architectural questions require being able to identify top-level bounded contexts.
## The system creates one Node3D anchor per top-level bounded context at its
## JSON-specified position, so the human can see which major components exist.
## Implemented by: main.gd → build_from_graph() → _create_volume() for nodes with parent=null
func test_bounded_contexts_are_structurally_identifiable() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	_check(anchors.has("auth"),
		"Bounded context 'auth' must be present in the scene for architectural identification")
	_check(anchors.has("billing"),
		"Bounded context 'billing' must be present in the scene for architectural identification")


## To answer "what is this component?", every structural element must have a visible name label.
## Implemented by: main.gd → _create_volume() → Label3D.text = nd["name"]
func test_node_names_are_labelled_for_identification() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	var auth_anchor: Node3D = anchors.get("auth")
	_check(auth_anchor != null, "auth anchor must exist")
	if auth_anchor == null:
		return

	var label: Label3D = null
	for child: Node in auth_anchor.get_children():
		if child is Label3D:
			label = child as Label3D
			break

	_check(label != null, "auth anchor must have a Label3D child for name identification")
	if label == null:
		return

	_check(label.text == "AuthService",
		"Label text must match the node name so humans can identify the component (expected 'AuthService')")


## Labels must use billboard mode so they always face the camera and remain readable
## from any angle during exploration. This is mandatory for understanding without code.
## Implemented by: main.gd → _create_volume() → label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
func test_label_billboard_enabled_for_readability() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	var billing_anchor: Node3D = anchors.get("billing")
	_check(billing_anchor != null, "billing anchor must exist")
	if billing_anchor == null:
		return

	var label: Label3D = null
	for child: Node in billing_anchor.get_children():
		if child is Label3D:
			label = child as Label3D
			break

	_check(label != null, "billing anchor must have a Label3D child")
	if label == null:
		return

	_check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		"Label must use BILLBOARD_ENABLED so it faces the camera and remains readable during exploration")


## Labels must have a positive pixel_size so text is legible at the scene scale.
## A pixel_size of 0 would make the label invisible; a very small value illegible.
## Implemented by: main.gd → _create_volume() → label.pixel_size = 0.012
func test_label_pixel_size_positive_for_readability() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	var auth_anchor: Node3D = anchors.get("auth")
	_check(auth_anchor != null, "auth anchor must exist")
	if auth_anchor == null:
		return

	var label: Label3D = null
	for child: Node in auth_anchor.get_children():
		if child is Label3D:
			label = child as Label3D
			break

	_check(label != null, "auth anchor must have a Label3D child")
	if label == null:
		return

	_check(label.pixel_size > 0.0,
		"Label pixel_size must be > 0.0 so labels are legible in 3D space (got %s)" % label.pixel_size)


# ---------------------------------------------------------------------------
# AND the human can identify structural problems in the system
# ---------------------------------------------------------------------------

## To identify structural problems (excessive coupling, tangled dependencies),
## the system must render dependency edges as visible line connections between nodes.
## Without visible edges, the human cannot see which components depend on which.
## Implemented by: main.gd → _create_edge() → ImmediateMesh line per edge
func test_dependencies_are_visible_as_connections() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())

	var line_found: bool = false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is ImmediateMesh:
				line_found = true
				break

	_check(line_found,
		"At least one dependency edge must be rendered as a visible line connection so structural problems are identifiable")


## To distinguish architectural problems (cross-context coupling is more serious
## than module-internal coupling), edges must be visually distinguishable by type.
## The system uses orange for cross-context and grey for internal.
## Implemented by: main.gd → _create_edge()
##   cross_context: Color(1.0, 0.50, 0.10) — orange
##   internal:      Color(0.55, 0.55, 0.55) — grey
func test_cross_context_and_internal_edges_are_distinguishable() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())

	var lod_entries: Array = main_node.get("_lod_edge_entries")
	_check(lod_entries.size() > 0,
		"Edge LOD entries must be populated — edges are required for structural problem identification")

	# Collect the distinct colors used for edge lines (ImmediateMesh visuals).
	var colors: Array = []
	for entry: Dictionary in lod_entries:
		var vis: MeshInstance3D = entry.get("visual") as MeshInstance3D
		if vis == null:
			continue
		var mat := vis.material_override as StandardMaterial3D
		if mat != null and not colors.has(mat.albedo_color):
			colors.append(mat.albedo_color)

	# At least two distinct colors must be present so the human can distinguish
	# cross-context from internal edges (different severity of coupling).
	_check(colors.size() >= 2,
		"Cross-context and internal edges must use distinct colors so structural problems are identifiable")


# ---------------------------------------------------------------------------
# AND the human can predict the impact of proposed changes
# ---------------------------------------------------------------------------

## To predict the impact of a proposed change, the human must be able to see
## the direction of dependencies — which component depends on which.
## Arrowhead cones are rendered at the target end of each edge.
## Implemented by: main.gd → _create_edge() → CylinderMesh arrowhead at to_pos
func test_dependency_direction_is_encoded_in_edges() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())

	# A directed arrowhead is a CylinderMesh cone (top_radius=0) placed at the
	# target end. The path_edge_entries track source/target so we can verify direction.
	var path_entries: Array = main_node.get("_path_edge_entries")
	_check(path_entries.size() > 0,
		"Path edge entries must be populated — direction encoding requires source/target tracking")

	var found_cross_context: bool = false
	for entry: Dictionary in path_entries:
		var src: String = entry.get("source", "")
		var tgt: String = entry.get("target", "")
		if src == "billing" and tgt == "auth":
			found_cross_context = true
			break

	_check(found_cross_context,
		"Edge billing→auth must be registered with correct direction so humans can predict change impact")


## To predict the impact of a proposed change, the human must see the containment
## structure so they know which modules are affected when a bounded context changes.
## Containment is expressed via scene-tree parenting: module anchors are children
## of their bounded context anchors.
## Implemented by: main.gd → build_from_graph()
##   for nd with parent != null: _create_volume(nd, parent_anchor)
func test_modules_are_contained_within_bounded_contexts() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_system_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	var auth_anchor: Node3D = anchors.get("auth")
	var domain_anchor: Node3D = anchors.get("auth.domain")

	_check(auth_anchor != null, "auth bounded context anchor must exist")
	_check(domain_anchor != null, "auth.domain module anchor must exist")
	if auth_anchor == null or domain_anchor == null:
		return

	_check(domain_anchor.get_parent() == auth_anchor,
		"Module 'auth.domain' must be contained (parented) within its bounded context 'auth' " +
		"so humans can predict which modules are impacted by changes to the context")
