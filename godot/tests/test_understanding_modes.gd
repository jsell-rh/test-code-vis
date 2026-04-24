## Tests for UnderstandingAnalyzer — covers all THEN-clauses from
## specs/core/understanding-modes.spec.md.
##
## Each test instantiates real Node3D objects where scene-tree assertions are
## required, calls the analyzer, applies the resulting visual changes via
## UnderstandingAnalyzer.render_*() methods, and asserts actual scene-tree
## property values.
##
## THEN-clause → test function mapping
## ─────────────────────────────────────────────────────────────────────────────
## Conformance / Alignment scenarios:
##   THEN the human can see that the realized system has auth and user
##        management as separate components
##     → test_aligned_nodes_detected_as_separate
##   AND the correspondence between spec and realization is visually apparent
##     → test_aligned_nodes_have_annotation_in_scene
##   THEN the human can see the divergence between spec and realization
##     → test_divergent_nodes_detected
##   AND the specific nature of the divergence is clear (merged vs. separate)
##     → test_divergent_nodes_annotated_as_merged
##
## Evaluation / Quality scenarios:
##   THEN the coupling between those services is apparent
##     → test_tightly_coupled_pair_detected
##   AND the human can assess whether the coupling is problematic
##     → test_coupled_nodes_highlighted
##   THEN the criticality and centrality of that component is apparent
##     → test_central_node_detected_as_critical
##   AND the risk it represents is clear
##     → test_critical_node_annotated_with_spof_risk
##   THEN architectural problems are visible even though conformance is perfect
##     → test_coupling_detected_despite_perfect_alignment
##
## Simulation / Impact scenarios:
##   THEN the impact on dependent services is visible
##     → test_split_dependents_detected
##   AND new dependencies or interfaces that would be required are shown
##     → test_split_new_interfaces_shown
##   THEN the cascade of effects through the system is visible
##     → test_failure_cascade_detected
##   AND components that would be affected are clearly identified
##     → test_failure_affected_nodes_highlighted
##
## Label3D readability (mandatory per project guidelines):
##   → test_annotation_label3d_has_billboard_and_pixel_size

const UnderstandingAnalyzer = preload("res://scripts/understanding_analyzer.gd")

var _test_failed: bool = false
var _runner: Object = null


func _check(condition: bool, message: String) -> void:
	if not condition:
		_test_failed = true
		if _runner != null and _runner.has_method("record_failure"):
			_runner.record_failure(message)


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

## Create a Node3D anchor for a given ID (dots replaced for GDScript compat).
func _make_anchor(id: String) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = id.replace(".", "_")
	return anchor


## Create a Node3D anchor with a MeshInstance3D child carrying a neutral material.
func _make_anchor_with_mesh(id: String) -> Node3D:
	var anchor := _make_anchor(id)
	var mesh_instance := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	mesh_instance.material_override = mat
	anchor.add_child(mesh_instance)
	return anchor


# ===========================================================================
# Alignment check — Conformance scenarios
# ===========================================================================

## THEN the human can see that the realized system has auth and user management
##      as separate components
func test_aligned_nodes_detected_as_separate() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var actual_nodes: Array = [
		{"id": "auth", "type": "bounded_context"},
		{"id": "user_management", "type": "bounded_context"},
	]
	var spec_node_ids: Array = ["auth", "user_management"]

	var result: Dictionary = analyzer.check_alignment(actual_nodes, spec_node_ids)

	_check(result.get("aligned", []).has("auth"),
		"auth should be aligned — it exists as a separate node")
	_check(result.get("aligned", []).has("user_management"),
		"user_management should be aligned — it exists as a separate node")
	_check(result.get("divergent", []).is_empty(),
		"no divergent nodes expected when all spec components are present")
	_check(result.get("missing", []).is_empty(),
		"no missing nodes expected when all spec components are present")


## AND the correspondence between spec and realization is visually apparent
func test_aligned_nodes_have_annotation_in_scene() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var actual_nodes: Array = [
		{"id": "auth", "type": "bounded_context"},
		{"id": "user_mgmt", "type": "bounded_context"},
	]
	var alignment: Dictionary = analyzer.check_alignment(actual_nodes, ["auth", "user_mgmt"])

	var auth_anchor := _make_anchor("auth")
	var user_anchor := _make_anchor("user_mgmt")
	var scene_root := Node3D.new()
	scene_root.add_child(auth_anchor)
	scene_root.add_child(user_anchor)
	var anchors: Dictionary = {"auth": auth_anchor, "user_mgmt": user_anchor}

	analyzer.render_alignment(alignment, anchors, scene_root)

	# render_alignment adds Label3D children to scene_root for aligned nodes.
	var label_count: int = 0
	for child in scene_root.get_children():
		if child is Label3D:
			label_count += 1
	_check(label_count >= 1,
		"at least one annotation Label3D should appear for aligned nodes")


## THEN the human can see the divergence between spec and realization
func test_divergent_nodes_detected() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	# Actual graph only has 'order_service'; spec expects 'payment_service' separately.
	var actual_nodes: Array = [
		{"id": "order_service", "type": "bounded_context"},
	]
	var spec_node_ids: Array = ["payment_service"]

	var result: Dictionary = analyzer.check_alignment(actual_nodes, spec_node_ids)

	# payment_service is absent — it must be flagged as divergent or missing.
	var detected: bool = (
		result.get("missing", []).has("payment_service") or
		result.get("divergent", []).has("payment_service")
	)
	_check(detected, "payment_service should be detected as divergent or missing")


## AND the specific nature of the divergence is clear (merged vs. separate)
func test_divergent_nodes_annotated_as_merged() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	# 'payment_order' is the merged node (contains spec id 'payment' as substring).
	var actual_nodes: Array = [
		{"id": "payment_order", "type": "bounded_context"},
	]
	var spec_node_ids: Array = ["payment"]

	var result: Dictionary = analyzer.check_alignment(actual_nodes, spec_node_ids)
	# 'payment' is a substring of 'payment_order' → divergent (merged).
	_check(result.get("divergent", []).has("payment"),
		"'payment' should be divergent because it is merged into 'payment_order'")

	var merged_anchor := _make_anchor("payment")
	var scene_root := Node3D.new()
	scene_root.add_child(merged_anchor)
	var anchors: Dictionary = {"payment": merged_anchor}

	analyzer.render_alignment(result, anchors, scene_root)

	var found_merged: bool = false
	for child in scene_root.get_children():
		if child is Label3D and "MERGED" in child.text:
			found_merged = true
	_check(found_merged, "a Label3D with 'MERGED' text must appear for divergent nodes")


# ===========================================================================
# Quality analysis — Evaluation scenarios
# ===========================================================================

## THEN the coupling between those services is apparent
func test_tightly_coupled_pair_detected() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "service_a", "type": "bounded_context"},
		{"id": "service_b", "type": "bounded_context"},
	]
	# Three edges in total between service_a and service_b → high coupling score.
	var edges: Array = [
		{"source": "service_a", "target": "service_b"},
		{"source": "service_b", "target": "service_a"},
		{"source": "service_a", "target": "service_b"},
	]

	var result: Dictionary = analyzer.analyze_coupling(nodes, edges, 2)
	var pairs: Array = result.get("pairs", [])

	_check(pairs.size() >= 1, "at least one tightly coupled pair should be detected")
	_check(pairs[0].get("coupling_score", 0) >= 2, "coupling score should be >= 2")


## AND the human can assess whether the coupling is problematic
func test_coupled_nodes_highlighted() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "svc_x", "type": "bounded_context"},
		{"id": "svc_y", "type": "bounded_context"},
	]
	var edges: Array = [
		{"source": "svc_x", "target": "svc_y"},
		{"source": "svc_y", "target": "svc_x"},
	]

	var coupling: Dictionary = analyzer.analyze_coupling(nodes, edges, 1)

	var anchor_x := _make_anchor_with_mesh("svc_x")
	var anchor_y := _make_anchor_with_mesh("svc_y")
	var scene_root := Node3D.new()
	scene_root.add_child(anchor_x)
	scene_root.add_child(anchor_y)
	var anchors: Dictionary = {"svc_x": anchor_x, "svc_y": anchor_y}

	analyzer.render_coupling(coupling, anchors, scene_root)

	var expected_color: Color = UnderstandingAnalyzer.HIGHLIGHT_COLOR
	var mesh_x: MeshInstance3D = anchor_x.get_child(0) as MeshInstance3D
	_check(
		mesh_x.material_override.get("albedo_color") == expected_color,
		"svc_x must be highlighted to show its coupling is problematic"
	)
	var mesh_y: MeshInstance3D = anchor_y.get_child(0) as MeshInstance3D
	_check(
		mesh_y.material_override.get("albedo_color") == expected_color,
		"svc_y must be highlighted to show its coupling is problematic"
	)


## THEN the criticality and centrality of that component is apparent
func test_central_node_detected_as_critical() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "hub", "type": "bounded_context"},
		{"id": "svc_1", "type": "bounded_context"},
		{"id": "svc_2", "type": "bounded_context"},
		{"id": "svc_3", "type": "bounded_context"},
	]
	# All three services depend on hub → hub has in-degree 3.
	var edges: Array = [
		{"source": "svc_1", "target": "hub"},
		{"source": "svc_2", "target": "hub"},
		{"source": "svc_3", "target": "hub"},
	]

	var result: Dictionary = analyzer.analyze_criticality(nodes, edges, 2)
	var critical: Array = result.get("critical", [])

	_check(critical.size() >= 1, "at least one critical node should be detected")
	_check(critical[0].get("node_id", "") == "hub",
		"hub should be the most critical node (highest in-degree)")
	_check(critical[0].get("in_degree", 0) == 3,
		"hub's in-degree should be 3 (all three services depend on it)")


## AND the risk it represents is clear
func test_critical_node_annotated_with_spof_risk() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "central", "type": "bounded_context"},
		{"id": "dep_a", "type": "bounded_context"},
		{"id": "dep_b", "type": "bounded_context"},
	]
	var edges: Array = [
		{"source": "dep_a", "target": "central"},
		{"source": "dep_b", "target": "central"},
	]

	var criticality: Dictionary = analyzer.analyze_criticality(nodes, edges, 2)

	var central_anchor := _make_anchor("central")
	var scene_root := Node3D.new()
	scene_root.add_child(central_anchor)
	var anchors: Dictionary = {"central": central_anchor}

	analyzer.render_criticality(criticality, anchors, scene_root)

	# The risk annotation must contain "SPOF" to communicate the risk clearly.
	var found_spof: bool = false
	for child in scene_root.get_children():
		if child is Label3D and "SPOF" in child.text:
			found_spof = true
	_check(found_spof,
		"a Label3D with 'SPOF' in its text must appear for high-criticality nodes")


## THEN architectural problems are visible even though conformance is perfect
func test_coupling_detected_despite_perfect_alignment() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "svc_auth", "type": "bounded_context"},
		{"id": "svc_user", "type": "bounded_context"},
	]
	# Perfect alignment: both spec nodes exist as separate entities.
	var alignment: Dictionary = analyzer.check_alignment(nodes, ["svc_auth", "svc_user"])
	_check(alignment.get("aligned", []).size() == 2,
		"both nodes should be aligned (perfect conformance)")

	# Despite perfect alignment, coupling analysis still detects the quality problem.
	var edges: Array = [
		{"source": "svc_auth", "target": "svc_user"},
		{"source": "svc_user", "target": "svc_auth"},
	]
	var coupling: Dictionary = analyzer.analyze_coupling(nodes, edges, 1)
	_check(
		coupling.get("pairs", []).size() >= 1,
		"coupling problem must be visible even when structural conformance is perfect"
	)


# ===========================================================================
# Impact analysis — Simulation scenarios
# ===========================================================================

## THEN the impact on dependent services is visible
func test_split_dependents_detected() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "monolith", "type": "bounded_context"},
		{"id": "client_a", "type": "bounded_context"},
		{"id": "client_b", "type": "bounded_context"},
	]
	# client_a and client_b both depend on monolith.
	var edges: Array = [
		{"source": "client_a", "target": "monolith"},
		{"source": "client_b", "target": "monolith"},
	]

	var result: Dictionary = analyzer.simulate_split(nodes, edges, "monolith")
	var dependents: Array = result.get("dependents", [])

	_check(dependents.has("client_a"),
		"client_a should be detected as a dependent — it will be affected by the split")
	_check(dependents.has("client_b"),
		"client_b should be detected as a dependent — it will be affected by the split")


## AND new dependencies or interfaces that would be required are shown
func test_split_new_interfaces_shown() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "big_svc", "type": "bounded_context"},
		{"id": "caller", "type": "bounded_context"},
	]
	var edges: Array = [
		{"source": "caller", "target": "big_svc"},
	]

	var split_result: Dictionary = analyzer.simulate_split(nodes, edges, "big_svc")

	# New interfaces should be listed for each dependent.
	_check(
		split_result.get("new_interfaces", []).size() >= 1,
		"new_interfaces must be populated to show what the split would require"
	)

	var big_anchor := _make_anchor_with_mesh("big_svc")
	var caller_anchor := _make_anchor_with_mesh("caller")
	var scene_root := Node3D.new()
	scene_root.add_child(big_anchor)
	scene_root.add_child(caller_anchor)
	var anchors: Dictionary = {"big_svc": big_anchor, "caller": caller_anchor}

	analyzer.render_split_impact(split_result, "big_svc", anchors, scene_root)

	# 'caller' (a dependent) must be highlighted to show it is impacted.
	var expected_color: Color = UnderstandingAnalyzer.HIGHLIGHT_COLOR
	var mesh_caller: MeshInstance3D = caller_anchor.get_child(0) as MeshInstance3D
	_check(
		mesh_caller.material_override.get("albedo_color") == expected_color,
		"caller must be highlighted to make the split impact visible"
	)

	# An annotation marking the impact must be present.
	var found_split_annotation: bool = false
	for child in scene_root.get_children():
		if child is Label3D and "split" in child.text.to_lower():
			found_split_annotation = true
	_check(found_split_annotation,
		"a Label3D annotation indicating split impact must appear in the scene")


## THEN the cascade of effects through the system is visible
func test_failure_cascade_detected() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "db", "type": "bounded_context"},
		{"id": "api", "type": "bounded_context"},
		{"id": "frontend", "type": "bounded_context"},
	]
	# api depends on db; frontend depends on api.
	var edges: Array = [
		{"source": "api", "target": "db"},
		{"source": "frontend", "target": "api"},
	]

	var result: Dictionary = analyzer.simulate_failure(nodes, edges, "db")
	var cascade: Array = result.get("cascade", [])

	_check(cascade.has("api"),
		"api must be in the cascade — it directly depends on the failed db")
	_check(cascade.has("frontend"),
		"frontend must be in the cascade — it transitively depends on db via api")


## AND components that would be affected are clearly identified
func test_failure_affected_nodes_highlighted() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	var nodes: Array = [
		{"id": "core_svc", "type": "bounded_context"},
		{"id": "consumer_1", "type": "bounded_context"},
	]
	var edges: Array = [
		{"source": "consumer_1", "target": "core_svc"},
	]

	var failure_result: Dictionary = analyzer.simulate_failure(nodes, edges, "core_svc")

	var core_anchor := _make_anchor_with_mesh("core_svc")
	var c1_anchor := _make_anchor_with_mesh("consumer_1")
	var scene_root := Node3D.new()
	scene_root.add_child(core_anchor)
	scene_root.add_child(c1_anchor)
	var anchors: Dictionary = {"core_svc": core_anchor, "consumer_1": c1_anchor}

	analyzer.render_failure_cascade(failure_result, "core_svc", anchors, scene_root)

	# consumer_1 is in the cascade and must be highlighted.
	var expected_color: Color = UnderstandingAnalyzer.HIGHLIGHT_COLOR
	var mesh_c1: MeshInstance3D = c1_anchor.get_child(0) as MeshInstance3D
	_check(
		mesh_c1.material_override.get("albedo_color") == expected_color,
		"consumer_1 must be highlighted — it is a component affected by the failure"
	)

	# The failed node itself must be annotated as failed.
	var found_failed_annotation: bool = false
	for child in scene_root.get_children():
		if child is Label3D and "FAILED" in child.text:
			found_failed_annotation = true
	_check(found_failed_annotation,
		"a Label3D with 'FAILED' text must mark the failed component")


# ===========================================================================
# Label3D readability (mandatory per project guidelines)
# ===========================================================================

## All annotation Label3D nodes must have billboard enabled and pixel_size > 0.
## UnderstandingAnalyzer._add_annotation() sets both; this test asserts the
## values on nodes created through the analyzer pipeline.
func test_annotation_label3d_has_billboard_and_pixel_size() -> void:
	_test_failed = false
	var analyzer := UnderstandingAnalyzer.new()

	# Use the criticality path to trigger annotation creation.
	var nodes: Array = [
		{"id": "watched_svc", "type": "bounded_context"},
		{"id": "dep_x", "type": "bounded_context"},
		{"id": "dep_y", "type": "bounded_context"},
	]
	var edges: Array = [
		{"source": "dep_x", "target": "watched_svc"},
		{"source": "dep_y", "target": "watched_svc"},
	]

	var criticality: Dictionary = analyzer.analyze_criticality(nodes, edges, 1)

	var anchor := _make_anchor("watched_svc")
	var scene_root := Node3D.new()
	scene_root.add_child(anchor)
	var anchors: Dictionary = {"watched_svc": anchor}

	analyzer.render_criticality(criticality, anchors, scene_root)

	# Find the annotation Label3D added by render_criticality.
	var label: Label3D = null
	for child in scene_root.get_children():
		if child is Label3D:
			label = child as Label3D
			break

	_check(label != null, "annotation Label3D must be created by the render_criticality pipeline")
	if label != null:
		_check(
			label.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
			"billboard must be BILLBOARD_ENABLED for the annotation to be legible in 3D"
		)
		_check(
			label.pixel_size > 0.0,
			"pixel_size must be > 0.0 for the annotation to be legible in 3D"
		)
