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
##     GIVEN a codebase and its corresponding specification files
##     WHEN both are loaded into the system
##     THEN the spec is treated as the intended design
##       → test_spec_rendered_as_intended_design
##     AND the codebase is treated as the realized design
##       → test_code_rendered_as_realized_design
##     AND the relationship between them is available for inspection
##       → test_spec_and_code_coexist_for_inspection
##
##   Requirement: Support the Architecture Feedback Loop
##   Scenario: Post-build evaluation
##     GIVEN an agent has built or modified a system based on a spec
##     WHEN the human opens the system for evaluation
##     THEN the human can determine whether the build matches the spec
##       → test_build_spec_comparison_available
##     AND the human can determine whether the build is architecturally sound
##       → test_architectural_soundness_assessable
##     AND the human can explore the impact of potential changes before updating the spec
##       → test_change_impact_explorable
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


# ---------------------------------------------------------------------------
# Fixture — a system with BOTH spec nodes (intended design) and code nodes
# (realized design), simulating a codebase loaded alongside its spec files.
# ---------------------------------------------------------------------------

func _make_spec_driven_fixture() -> Dictionary:
	## Returns a scene graph containing both spec nodes (intended design) and
	## code nodes (realized design) so Scenario 2 tests can verify both are
	## rendered distinctly and coexist in the scene.
	return {
		"nodes": [
			{
				"id": "auth",
				"name": "AuthService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -5.0, "y": 0.0, "z": 0.0},
				"size": 6.0,
				"metrics": {"loc": 400},
			},
			{
				"id": "spec.core.system_purpose",
				"name": "System Purpose",
				"type": "spec",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": -15.0},
				"size": 2.0,
			},
			{
				"id": "spec.billing_spec",
				"name": "Billing Spec",
				"type": "spec",
				"parent": null,
				"position": {"x": 3.0, "y": 0.0, "z": -15.0},
				"size": 1.5,
			},
		],
		"edges": [],
		"metadata": {
			"source_path": "/tmp/example_with_specs",
			"timestamp": "2026-04-24T00:00:00Z",
		},
	}


# ---------------------------------------------------------------------------
# Requirement: Spec-Driven Context
# Scenario: Spec and codebase loaded together
#
# THEN the spec is treated as the intended design
# ---------------------------------------------------------------------------

## Spec nodes must be rendered with a visually distinct style that signals
## "intended design" — gold colour distinguishes them from blue/green code nodes.
## Implemented by: main.gd → _create_volume() → is_spec branch → gold Color(0.95, 0.80, 0.10, …)
func test_spec_rendered_as_intended_design() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_spec_driven_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	## Spec node anchor must exist.
	var spec_anchor: Node3D = anchors.get("spec.core.system_purpose")
	_check(spec_anchor != null,
		"spec node 'spec.core.system_purpose' must be present in the scene as intended design")
	if spec_anchor == null:
		return

	## Spec node must have a MeshInstance3D (visual representation).
	var mesh: MeshInstance3D = null
	for child: Node in spec_anchor.get_children():
		if child is MeshInstance3D:
			mesh = child as MeshInstance3D
			break
	_check(mesh != null,
		"Spec node must have a MeshInstance3D to be visible as intended design")
	if mesh == null:
		return

	## The material must be gold (R ≥ 0.9) to signal "intended / authoritative".
	var mat := mesh.material_override as StandardMaterial3D
	_check(mat != null, "Spec node MeshInstance3D must have a StandardMaterial3D material")
	if mat == null:
		return
	## Gold: red channel ≥ 0.9, green channel ≥ 0.7, blue channel < 0.3.
	## This distinguishes spec nodes (gold = intended design) from code nodes
	## (blue = bounded_context, green = module).
	_check(mat.albedo_color.r >= 0.9,
		"Spec node must use gold colour (r >= 0.9) to indicate intended design; " +
		"got r=%.2f" % mat.albedo_color.r)
	_check(mat.albedo_color.b < 0.3,
		"Spec node must not be blue (b < 0.3) so it is distinct from code nodes; " +
		"got b=%.2f" % mat.albedo_color.b)


# ---------------------------------------------------------------------------
# AND the codebase is treated as the realized design
# ---------------------------------------------------------------------------

## Code nodes (bounded_context) must use the blue colour that distinguishes them
## as realized design — not gold (which belongs to spec / intended design).
## This ensures the human can always tell spec from code at a glance.
## Implemented by: main.gd → _create_volume() → is_context branch → blue Color(0.25, 0.45, 0.85, …)
func test_code_rendered_as_realized_design() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_spec_driven_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	var auth_anchor: Node3D = anchors.get("auth")
	_check(auth_anchor != null, "bounded_context node 'auth' must be present as realized design")
	if auth_anchor == null:
		return

	var mesh: MeshInstance3D = null
	for child: Node in auth_anchor.get_children():
		if child is MeshInstance3D:
			mesh = child as MeshInstance3D
			break
	_check(mesh != null, "bounded_context anchor must have a MeshInstance3D")
	if mesh == null:
		return

	var mat := mesh.material_override as StandardMaterial3D
	_check(mat != null, "bounded_context anchor MeshInstance3D must have a StandardMaterial3D")
	if mat == null:
		return

	## Code node colour must be blue (b > 0.7) — realized design, not gold spec.
	## This is the visual marker that distinguishes realized from intended design.
	_check(mat.albedo_color.b > 0.7,
		"Bounded context node must use blue colour (b > 0.7) to indicate realized design " +
		"so humans can distinguish it from gold spec nodes; got b=%.2f" % mat.albedo_color.b)
	## Must NOT be gold (would mean it was mistakenly rendered as a spec node).
	_check(mat.albedo_color.r < 0.5 or mat.albedo_color.b > 0.5,
		"Bounded context must not be gold — it is realized design, not intended design")


# ---------------------------------------------------------------------------
# AND the relationship between them is available for inspection
# ---------------------------------------------------------------------------

## Both spec (intended design) and code (realized design) nodes must coexist
## in the same scene so the human can inspect the relationship between them.
## The human can see which specs exist alongside which code modules — this is
## the minimum viable "relationship available for inspection" for the prototype.
## Implemented by: main.gd → build_from_graph() handles type='spec' nodes the same
## way as type='bounded_context' nodes — each gets an anchor in _anchors.
func test_spec_and_code_coexist_for_inspection() -> void:
	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(_make_spec_driven_fixture())
	var anchors: Dictionary = main_node.get("_anchors")

	## Spec nodes must be present.
	var has_spec: bool = false
	for node_id: String in anchors.keys():
		if (node_id as String).begins_with("spec."):
			has_spec = true
			break
	_check(has_spec,
		"At least one spec node must be present in _anchors so the human can " +
		"inspect the relationship between intended design and realized code")

	## Code nodes must also be present — relationship requires both sides.
	_check(anchors.has("auth"),
		"Code node 'auth' must be present alongside spec nodes for relationship inspection")

	## Spec labels must be visible (billboard + pixel_size > 0) so they can be read.
	var spec_anchor: Node3D = anchors.get("spec.core.system_purpose")
	_check(spec_anchor != null, "spec anchor 'spec.core.system_purpose' must exist")
	if spec_anchor == null:
		return

	var label: Label3D = null
	for child: Node in spec_anchor.get_children():
		if child is Label3D:
			label = child as Label3D
			break
	_check(label != null, "Spec anchor must have a Label3D so its name is readable")
	if label == null:
		return
	_check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		"Spec node label must face the camera (BILLBOARD_ENABLED) to remain readable during inspection")
	_check(label.pixel_size > 0.0,
		"Spec node label must have pixel_size > 0.0 to be legible during relationship inspection")


# ---------------------------------------------------------------------------
# Requirement: Support the Architecture Feedback Loop
# Scenario: Post-build evaluation
#
# THEN the human can determine whether the build matches the spec
# ---------------------------------------------------------------------------

## The alignment overlay (H key) colours each node by spec_status so the human
## can determine whether the realized build matches the intended spec design.
## "aligned" → green, "divergent" → red: the match/mismatch is immediately visible.
## Implemented by: main.gd → _apply_alignment_overlay() → UnderstandingOverlay.apply_alignment_overlay()
func test_build_spec_comparison_available() -> void:
	## Build a scene where one node is spec-aligned and one is divergent.
	var fixture: Dictionary = _make_system_fixture()
	fixture["nodes"][0]["spec_status"] = "aligned"
	fixture["nodes"][1]["spec_status"] = "divergent"

	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(fixture)

	## Calling _apply_alignment_overlay must not crash and must change node colours.
	## Before the overlay, nodes have their default colours.
	var anchors: Dictionary = main_node.get("_anchors")
	var billing_anchor: Node3D = anchors.get("billing")
	_check(billing_anchor != null, "billing anchor must exist for spec comparison test")
	if billing_anchor == null:
		return

	## Record the colour before overlay.
	var color_before: Color = Color.TRANSPARENT
	for child: Node in billing_anchor.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				color_before = mat.albedo_color
			break

	## Trigger the alignment overlay — this is the mechanism by which the human
	## determines whether the build matches the spec.
	main_node.call("_apply_alignment_overlay")

	## After the overlay, the divergent node must be red (DIVERGENT_COLOR from UnderstandingOverlay).
	var color_after: Color = Color.TRANSPARENT
	for child: Node in billing_anchor.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				color_after = mat.albedo_color
			break

	## The divergent node must turn red — indicating the build does NOT match the spec at that point.
	## divergent_color.r >= 0.8 (red channel dominant).
	_check(color_after.r >= 0.8,
		"Divergent node must turn red after alignment overlay so human can see " +
		"where the build does not match the spec; got color " + str(color_after))


# ---------------------------------------------------------------------------
# AND the human can determine whether the build is architecturally sound
# ---------------------------------------------------------------------------

## The quality overlay (J key) colours nodes by coupling and centrality metrics
## so the human can assess whether the realized system is architecturally sound,
## independently of whether it matches the spec.
## Implemented by: main.gd → _apply_quality_overlay() → UnderstandingOverlay.apply_quality_overlay()
func test_architectural_soundness_assessable() -> void:
	## Build a scene where one node has high in-degree (a critical/unsafe node).
	## source → target means target has in_degree +1. We need in_degree >= 3.
	var fixture: Dictionary = {
		"nodes": [
			{
				"id": "hub",
				"name": "HubService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 5.0,
				"metrics": {"loc": 500},
			},
			{
				"id": "a",
				"name": "ServiceA",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 5.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"metrics": {"loc": 200},
			},
			{
				"id": "b",
				"name": "ServiceB",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": -5.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"metrics": {"loc": 200},
			},
			{
				"id": "c",
				"name": "ServiceC",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 5.0},
				"size": 3.0,
				"metrics": {"loc": 200},
			},
		],
		"edges": [
			{"source": "a", "target": "hub", "type": "cross_context"},
			{"source": "b", "target": "hub", "type": "cross_context"},
			{"source": "c", "target": "hub", "type": "cross_context"},
		],
		"metadata": {
			"source_path": "/tmp/hub_test",
			"timestamp": "2026-04-24T00:00:00Z",
		},
	}

	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(fixture)

	## Trigger the quality overlay so the human can assess architectural soundness.
	main_node.call("_apply_quality_overlay")

	var anchors: Dictionary = main_node.get("_anchors")
	var hub_anchor: Node3D = anchors.get("hub")
	_check(hub_anchor != null, "hub anchor must exist for soundness assessment test")
	if hub_anchor == null:
		return

	## Hub has in_degree=3 (a, b, c all depend on it) → CRITICAL_COLOR (deep red).
	## This visual signal lets the human assess that hub is a single point of failure
	## and therefore the build is NOT architecturally sound as-is.
	## CRITICAL_COLOR.r >= 0.9 from UnderstandingOverlay constants.
	var color: Color = Color.TRANSPARENT
	for child: Node in hub_anchor.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				color = mat.albedo_color
			break
	_check(color.r >= 0.9,
		"High-centrality node must be highlighted red (r >= 0.9) after quality overlay " +
		"so the human can determine that the build has an architectural soundness issue; " +
		"got color " + str(color))


# ---------------------------------------------------------------------------
# AND the human can explore the impact of potential changes before updating the spec
# ---------------------------------------------------------------------------

## The failure impact overlay (K key) simulates the cascade of a hypothetical
## node failure, colouring all transitively affected nodes so the human can
## explore the impact of a potential change BEFORE updating the spec.
## Implemented by: main.gd → _apply_failure_impact_overlay() → UnderstandingOverlay.apply_failure_overlay()
func test_change_impact_explorable() -> void:
	## Build a chain: auth → billing → reporting.
	## If auth fails, billing is directly affected, reporting is transitively affected.
	## sign-chain: auth fails → billing depends on auth → billing affected →
	##             reporting depends on billing → reporting affected ✓
	var fixture: Dictionary = {
		"nodes": [
			{
				"id": "auth",
				"name": "AuthService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"size": 5.0,
				"metrics": {"loc": 500},
			},
			{
				"id": "billing",
				"name": "BillingService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 5.0, "y": 0.0, "z": 0.0},
				"size": 4.0,
				"metrics": {"loc": 300},
			},
			{
				"id": "reporting",
				"name": "ReportingService",
				"type": "bounded_context",
				"parent": null,
				"position": {"x": 10.0, "y": 0.0, "z": 0.0},
				"size": 3.0,
				"metrics": {"loc": 200},
			},
		],
		"edges": [
			{"source": "billing", "target": "auth", "type": "cross_context"},
			{"source": "reporting", "target": "billing", "type": "cross_context"},
		],
		"metadata": {
			"source_path": "/tmp/chain_test",
			"timestamp": "2026-04-24T00:00:00Z",
		},
	}

	var main_node: Node3D = MainScript.new()
	main_node.build_from_graph(fixture)

	## Trigger failure impact overlay — simulates failing the first node (auth).
	## This lets the human explore what would be impacted if auth were changed or removed.
	main_node.call("_apply_failure_impact_overlay")

	var anchors: Dictionary = main_node.get("_anchors")

	## billing directly depends on auth → must be AFFECTED (magenta from AFFECTED_COLOR).
	## reporting transitively depends → must also be AFFECTED.
	for affected_id: String in ["billing", "reporting"]:
		var anchor: Node3D = anchors.get(affected_id)
		_check(anchor != null, "%s anchor must exist for change impact test" % affected_id)
		if anchor == null:
			continue
		var color: Color = Color.TRANSPARENT
		for child: Node in anchor.get_children():
			if child is MeshInstance3D:
				var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
				if mat != null:
					color = mat.albedo_color
				break
		## AFFECTED_COLOR = Color(0.85, 0.1, 0.55) — magenta. g < 0.3 is the key marker.
		_check(color.g < 0.3,
			"%s must be highlighted as affected (magenta, g < 0.3) after failure overlay " % affected_id +
			"so the human can explore the impact of the hypothetical change; got color " + str(color))
