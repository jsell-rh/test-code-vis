## Tests for UnderstandingOverlay — the visual overlay system that satisfies the
## three understanding modes defined in specs/core/understanding-modes.spec.md.
##
## Every THEN-clause from the spec is mapped to a named test:
##
## Conformance Mode (apply_alignment_overlay):
##   THEN "the human can see that the realized system has auth and user management
##         as separate components"
##     → test_aligned_nodes_displayed_as_separate_components
##   AND  "the correspondence between spec and realization is visually apparent"
##     → test_aligned_node_receives_aligned_color
##   THEN "the human can see the divergence between spec and realization"
##     → test_divergent_node_receives_divergent_color
##   AND  "the specific nature of the divergence is clear (merged vs. separate)"
##     → test_divergent_node_has_divergence_label
##
## Evaluation Mode (apply_quality_overlay):
##   THEN "the coupling between those services is apparent"
##   AND  "the human can assess whether the coupling is problematic"
##     → test_coupling_between_services_apparent
##   THEN "the criticality and centrality of that component is apparent"
##     → test_critical_component_centrality_apparent
##   AND  "the risk it represents is clear"
##     → test_critical_color_distinct_from_normal
##   THEN "architectural problems are visible even though conformance is perfect"
##     → test_quality_overlay_independent_of_alignment
##
## Simulation Mode — splitting (apply_split_overlay):
##   THEN "the impact on dependent services is visible"
##     → test_split_impact_on_dependents_visible
##   AND  "new dependencies or interfaces that would be required are shown"
##     → test_split_shows_required_new_interfaces
##
## Simulation Mode — failure injection (apply_failure_overlay):
##   THEN "the cascade of effects through the system is visible"
##     → test_failure_cascade_effects_visible
##   AND  "components that would be affected are clearly identified"
##     → test_failure_affected_components_clearly_identified

const UnderstandingOverlay = preload("res://scripts/understanding_overlay.gd")

var _test_failed: bool = false
var _runner: Object = null


func _check(condition: bool, msg: String) -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg)


# ---------------------------------------------------------------------------
# Fixture helpers — create real Node3D objects with MeshInstance3D children
# ---------------------------------------------------------------------------

func _make_anchor(id: String, pos: Vector3) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = id.replace(".", "_")
	anchor.position = pos

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	mesh_instance.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 0.4, 1.0)  # default colour before overlay
	mesh_instance.material_override = mat

	anchor.add_child(mesh_instance)
	return anchor


func _get_mesh_color(anchor: Node3D) -> Color:
	for child in anchor.get_children():
		if child is MeshInstance3D:
			var mat = (child as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				return (mat as StandardMaterial3D).albedo_color
	return Color.TRANSPARENT


func _find_label_text(node: Node3D) -> String:
	for child in node.get_children():
		if child is Label3D:
			return (child as Label3D).text
	return ""


func _has_label(node: Node3D) -> bool:
	for child in node.get_children():
		if child is Label3D:
			return true
	return false


func _has_label_in_scene(scene_root: Node3D, text: String) -> bool:
	for child in scene_root.get_children():
		if child is Label3D and (child as Label3D).text == text:
			return true
	return false


# ---------------------------------------------------------------------------
# Conformance Mode tests — apply_alignment_overlay
# ---------------------------------------------------------------------------

## THEN "the human can see that the realized system has auth and user management
##       as separate components"
## Each aligned node is a distinct anchor in the scene; apply_alignment_overlay
## colours them individually, confirming they are separate rather than merged.
func test_aligned_nodes_displayed_as_separate_components() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()

	var auth_anchor := _make_anchor("auth", Vector3(0.0, 0.0, 0.0))
	var user_mgmt_anchor := _make_anchor("user_mgmt", Vector3(10.0, 0.0, 0.0))

	var anchors: Dictionary = {"auth": auth_anchor, "user_mgmt": user_mgmt_anchor}
	var nodes_data: Array = [
		{"id": "auth", "spec_status": "aligned"},
		{"id": "user_mgmt", "spec_status": "aligned"},
	]

	overlay.apply_alignment_overlay(nodes_data, anchors)

	# The two anchors are distinct objects (separate components).
	_check(auth_anchor != user_mgmt_anchor, "auth and user_mgmt must be separate anchors")
	# Both receive ALIGNED_COLOR, confirming correspondence with spec.
	_check(
		_get_mesh_color(auth_anchor).is_equal_approx(UnderstandingOverlay.ALIGNED_COLOR),
		"auth anchor must receive ALIGNED_COLOR"
	)
	_check(
		_get_mesh_color(user_mgmt_anchor).is_equal_approx(UnderstandingOverlay.ALIGNED_COLOR),
		"user_mgmt anchor must receive ALIGNED_COLOR"
	)


## AND "the correspondence between spec and realization is visually apparent"
## An aligned node receives ALIGNED_COLOR (green) — a distinct, positive colour
## that makes the spec–realization match immediately apparent.
func test_aligned_node_receives_aligned_color() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var anchor := _make_anchor("auth", Vector3.ZERO)
	var anchors: Dictionary = {"auth": anchor}
	var nodes_data: Array = [{"id": "auth", "spec_status": "aligned"}]

	overlay.apply_alignment_overlay(nodes_data, anchors)

	var color: Color = _get_mesh_color(anchor)
	_check(
		color.is_equal_approx(UnderstandingOverlay.ALIGNED_COLOR),
		"aligned node must receive ALIGNED_COLOR (%.2f, %.2f, %.2f), got (%.2f, %.2f, %.2f)" % [
			UnderstandingOverlay.ALIGNED_COLOR.r,
			UnderstandingOverlay.ALIGNED_COLOR.g,
			UnderstandingOverlay.ALIGNED_COLOR.b,
			color.r, color.g, color.b,
		]
	)
	# ALIGNED_COLOR is visually distinct from default grey — confirms correspondence.
	_check(
		not color.is_equal_approx(Color(0.3, 0.6, 0.4, 1.0)),
		"aligned node must change colour from the pre-overlay default"
	)


## THEN "the human can see the divergence between spec and realization"
## A divergent node receives DIVERGENT_COLOR (red) — distinct from ALIGNED_COLOR —
## making the spec–realization mismatch immediately visible.
func test_divergent_node_receives_divergent_color() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var anchor := _make_anchor("payment", Vector3.ZERO)
	var anchors: Dictionary = {"payment": anchor}
	var nodes_data: Array = [
		{"id": "payment", "spec_status": "divergent", "spec_divergence": "merged with order service"}
	]

	overlay.apply_alignment_overlay(nodes_data, anchors)

	var color: Color = _get_mesh_color(anchor)
	_check(
		color.is_equal_approx(UnderstandingOverlay.DIVERGENT_COLOR),
		"divergent node must receive DIVERGENT_COLOR"
	)
	# DIVERGENT_COLOR is distinct from ALIGNED_COLOR — divergence is clear.
	_check(
		not color.is_equal_approx(UnderstandingOverlay.ALIGNED_COLOR),
		"DIVERGENT_COLOR must differ from ALIGNED_COLOR"
	)


## AND "the specific nature of the divergence is clear (merged vs. separate)"
## A divergent node receives an annotation label whose text describes how the
## implementation diverges from the spec (e.g. "merged with order service").
func test_divergent_node_has_divergence_label() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var anchor := _make_anchor("payment", Vector3.ZERO)
	var anchors: Dictionary = {"payment": anchor}
	var nodes_data: Array = [
		{"id": "payment", "spec_status": "divergent", "spec_divergence": "merged with order service"}
	]

	overlay.apply_alignment_overlay(nodes_data, anchors)

	# A Label3D child must exist with the divergence description.
	_check(_has_label(anchor), "divergent node must have a Label3D annotation")
	_check(
		_find_label_text(anchor) == "merged with order service",
		"divergence label text must match spec_divergence field"
	)


## Label3D legibility check for alignment overlay labels.
func test_divergence_label_has_billboard_and_pixel_size() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var anchor := _make_anchor("payment", Vector3.ZERO)
	var anchors: Dictionary = {"payment": anchor}
	var nodes_data: Array = [
		{"id": "payment", "spec_status": "divergent", "spec_divergence": "some divergence"}
	]

	overlay.apply_alignment_overlay(nodes_data, anchors)

	for child in anchor.get_children():
		if child is Label3D:
			var lbl := child as Label3D
			_check(
				lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
				"divergence label must have billboard=BILLBOARD_ENABLED for legibility"
			)
			_check(lbl.pixel_size > 0.0, "divergence label must have pixel_size > 0.0")
			return
	_check(false, "no Label3D found on divergent anchor")


# ---------------------------------------------------------------------------
# Evaluation Mode tests — apply_quality_overlay
# ---------------------------------------------------------------------------

## THEN "the coupling between those services is apparent"
## AND  "the human can assess whether the coupling is problematic"
## Two services with a mutual edge pair (A→B and B→A) receive COUPLED_COLOR,
## making their tight interdependence immediately apparent.
func test_coupling_between_services_apparent() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var scene_root := Node3D.new()

	var svc_a := _make_anchor("svc_a", Vector3(0.0, 0.0, 0.0))
	var svc_b := _make_anchor("svc_b", Vector3(5.0, 0.0, 0.0))
	scene_root.add_child(svc_a)
	scene_root.add_child(svc_b)
	var anchors: Dictionary = {"svc_a": svc_a, "svc_b": svc_b}

	var nodes_data: Array = [{"id": "svc_a"}, {"id": "svc_b"}]
	# Mutual edges: svc_a depends on svc_b AND svc_b depends on svc_a.
	var edges_data: Array = [
		{"source": "svc_a", "target": "svc_b", "type": "cross_context"},
		{"source": "svc_b", "target": "svc_a", "type": "cross_context"},
	]

	overlay.apply_quality_overlay(nodes_data, edges_data, anchors)

	_check(
		_get_mesh_color(svc_a).is_equal_approx(UnderstandingOverlay.COUPLED_COLOR),
		"svc_a must receive COUPLED_COLOR when mutually coupled with svc_b"
	)
	_check(
		_get_mesh_color(svc_b).is_equal_approx(UnderstandingOverlay.COUPLED_COLOR),
		"svc_b must receive COUPLED_COLOR when mutually coupled with svc_a"
	)


## THEN "the criticality and centrality of that component is apparent"
## A node with three or more incoming edges is a single point of failure.
## It receives CRITICAL_COLOR, making its centrality and risk visible.
func test_critical_component_centrality_apparent() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()

	var hub := _make_anchor("hub", Vector3(0.0, 0.0, 0.0))
	var svc1 := _make_anchor("svc1", Vector3(5.0, 0.0, 0.0))
	var svc2 := _make_anchor("svc2", Vector3(10.0, 0.0, 0.0))
	var svc3 := _make_anchor("svc3", Vector3(15.0, 0.0, 0.0))
	var anchors: Dictionary = {"hub": hub, "svc1": svc1, "svc2": svc2, "svc3": svc3}

	var nodes_data: Array = [
		{"id": "hub"}, {"id": "svc1"}, {"id": "svc2"}, {"id": "svc3"}
	]
	# All three services depend on hub → hub has in_degree 3.
	var edges_data: Array = [
		{"source": "svc1", "target": "hub", "type": "cross_context"},
		{"source": "svc2", "target": "hub", "type": "cross_context"},
		{"source": "svc3", "target": "hub", "type": "cross_context"},
	]

	overlay.apply_quality_overlay(nodes_data, edges_data, anchors)

	_check(
		_get_mesh_color(hub).is_equal_approx(UnderstandingOverlay.CRITICAL_COLOR),
		"hub with 3 dependents must receive CRITICAL_COLOR"
	)


## AND "the risk it represents is clear"
## CRITICAL_COLOR is visually distinct from COUPLED_COLOR so the human can
## distinguish 'high coupling' from 'single-point-of-failure risk'.
func test_critical_color_distinct_from_normal() -> void:
	_test_failed = false
	# CRITICAL_COLOR must differ from COUPLED_COLOR (risk levels are distinguishable).
	_check(
		not UnderstandingOverlay.CRITICAL_COLOR.is_equal_approx(UnderstandingOverlay.COUPLED_COLOR),
		"CRITICAL_COLOR must differ from COUPLED_COLOR"
	)
	# Both must differ from ALIGNED_COLOR (quality overlay is independent of alignment).
	_check(
		not UnderstandingOverlay.CRITICAL_COLOR.is_equal_approx(UnderstandingOverlay.ALIGNED_COLOR),
		"CRITICAL_COLOR must differ from ALIGNED_COLOR"
	)


## THEN "architectural problems are visible even though conformance is perfect"
## A node whose spec_status is "aligned" (perfect conformance) can still have
## high in-degree. The quality overlay colours it CRITICAL_COLOR regardless,
## making the architectural problem visible despite perfect conformance.
func test_quality_overlay_independent_of_alignment() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()

	var hub := _make_anchor("hub", Vector3(0.0, 0.0, 0.0))
	var svc1 := _make_anchor("svc1", Vector3(5.0, 0.0, 0.0))
	var svc2 := _make_anchor("svc2", Vector3(10.0, 0.0, 0.0))
	var svc3 := _make_anchor("svc3", Vector3(15.0, 0.0, 0.0))
	var anchors: Dictionary = {"hub": hub, "svc1": svc1, "svc2": svc2, "svc3": svc3}

	# Hub is spec-aligned (perfect conformance) but still has 3 incoming edges.
	var nodes_data: Array = [
		{"id": "hub", "spec_status": "aligned"},  # perfectly conforms to spec
		{"id": "svc1"}, {"id": "svc2"}, {"id": "svc3"},
	]
	var edges_data: Array = [
		{"source": "svc1", "target": "hub", "type": "cross_context"},
		{"source": "svc2", "target": "hub", "type": "cross_context"},
		{"source": "svc3", "target": "hub", "type": "cross_context"},
	]

	overlay.apply_quality_overlay(nodes_data, edges_data, anchors)

	# Even though hub is "aligned", quality overlay still exposes the SPOF risk.
	_check(
		_get_mesh_color(hub).is_equal_approx(UnderstandingOverlay.CRITICAL_COLOR),
		"hub must receive CRITICAL_COLOR from quality overlay regardless of spec_status"
	)


# ---------------------------------------------------------------------------
# Simulation Mode tests — apply_split_overlay (splitting a service)
# ---------------------------------------------------------------------------

## THEN "the impact on dependent services is visible"
## When simulating a split of 'monolith', the services that depend on it
## are coloured AFFECTED_COLOR, making their impact visible.
func test_split_impact_on_dependents_visible() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var scene_root := Node3D.new()

	var monolith := _make_anchor("monolith", Vector3(0.0, 0.0, 0.0))
	var svc_a := _make_anchor("svc_a", Vector3(5.0, 0.0, 0.0))
	scene_root.add_child(monolith)
	scene_root.add_child(svc_a)
	var anchors: Dictionary = {"monolith": monolith, "svc_a": svc_a}

	# svc_a depends on monolith (svc_a has edge → monolith).
	var graph: Dictionary = {
		"nodes": [{"id": "monolith"}, {"id": "svc_a"}],
		"edges": [{"source": "svc_a", "target": "monolith", "type": "cross_context"}],
	}

	overlay.apply_split_overlay("monolith", graph, anchors, scene_root)

	_check(
		_get_mesh_color(svc_a).is_equal_approx(UnderstandingOverlay.AFFECTED_COLOR),
		"svc_a must receive AFFECTED_COLOR when it depends on the service being split"
	)


## AND "new dependencies or interfaces that would be required are shown"
## Each dependent of the split service is annotated "requires new interface"
## to indicate that after the split it must bind to one of the resulting parts.
func test_split_shows_required_new_interfaces() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var scene_root := Node3D.new()

	var monolith := _make_anchor("monolith", Vector3(0.0, 0.0, 0.0))
	var svc_a := _make_anchor("svc_a", Vector3(5.0, 0.0, 0.0))
	scene_root.add_child(monolith)
	scene_root.add_child(svc_a)
	var anchors: Dictionary = {"monolith": monolith, "svc_a": svc_a}

	var graph: Dictionary = {
		"nodes": [{"id": "monolith"}, {"id": "svc_a"}],
		"edges": [{"source": "svc_a", "target": "monolith", "type": "cross_context"}],
	}

	overlay.apply_split_overlay("monolith", graph, anchors, scene_root)

	# A "requires new interface" label must appear in the scene for svc_a.
	_check(
		_has_label_in_scene(scene_root, "requires new interface"),
		"scene must contain a 'requires new interface' label for the affected dependent"
	)


## Label3D legibility check for impact overlay (split).
func test_split_label_has_billboard_and_pixel_size() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var scene_root := Node3D.new()

	var monolith := _make_anchor("monolith", Vector3(0.0, 0.0, 0.0))
	var svc_a := _make_anchor("svc_a", Vector3(5.0, 0.0, 0.0))
	scene_root.add_child(monolith)
	scene_root.add_child(svc_a)
	var anchors: Dictionary = {"monolith": monolith, "svc_a": svc_a}

	var graph: Dictionary = {
		"nodes": [{"id": "monolith"}, {"id": "svc_a"}],
		"edges": [{"source": "svc_a", "target": "monolith", "type": "cross_context"}],
	}

	overlay.apply_split_overlay("monolith", graph, anchors, scene_root)

	for child in scene_root.get_children():
		if child is Label3D:
			var lbl := child as Label3D
			_check(
				lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
				"split impact label must have billboard=BILLBOARD_ENABLED"
			)
			_check(lbl.pixel_size > 0.0, "split impact label must have pixel_size > 0.0")
			return
	_check(false, "no Label3D found in scene root for split overlay")


# ---------------------------------------------------------------------------
# Simulation Mode tests — apply_failure_overlay (failure injection)
# ---------------------------------------------------------------------------

## THEN "the cascade of effects through the system is visible"
## When svc_a fails: svc_b (which depends on svc_a) is directly affected,
## and svc_c (which depends on svc_b) is transitively affected.
## Both appear as AFFECTED_COLOR, making the cascade visible.
func test_failure_cascade_effects_visible() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var scene_root := Node3D.new()

	var svc_a := _make_anchor("svc_a", Vector3(0.0, 0.0, 0.0))
	var svc_b := _make_anchor("svc_b", Vector3(5.0, 0.0, 0.0))
	var svc_c := _make_anchor("svc_c", Vector3(10.0, 0.0, 0.0))
	scene_root.add_child(svc_a)
	scene_root.add_child(svc_b)
	scene_root.add_child(svc_c)
	var anchors: Dictionary = {"svc_a": svc_a, "svc_b": svc_b, "svc_c": svc_c}

	# Chain: svc_b depends on svc_a; svc_c depends on svc_b.
	var graph: Dictionary = {
		"nodes": [{"id": "svc_a"}, {"id": "svc_b"}, {"id": "svc_c"}],
		"edges": [
			{"source": "svc_b", "target": "svc_a", "type": "cross_context"},
			{"source": "svc_c", "target": "svc_b", "type": "cross_context"},
		],
	}

	overlay.apply_failure_overlay("svc_a", graph, anchors, scene_root)

	# svc_b is directly affected (cascade step 1).
	_check(
		_get_mesh_color(svc_b).is_equal_approx(UnderstandingOverlay.AFFECTED_COLOR),
		"svc_b must receive AFFECTED_COLOR (direct cascade from svc_a failure)"
	)
	# svc_c is transitively affected (cascade step 2).
	_check(
		_get_mesh_color(svc_c).is_equal_approx(UnderstandingOverlay.AFFECTED_COLOR),
		"svc_c must receive AFFECTED_COLOR (transitive cascade through svc_b)"
	)


## AND "components that would be affected are clearly identified"
## Each affected node in the cascade receives an "AFFECTED" label so the human
## can immediately identify which components would be impacted by the failure.
func test_failure_affected_components_clearly_identified() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var scene_root := Node3D.new()

	var svc_a := _make_anchor("svc_a", Vector3(0.0, 0.0, 0.0))
	var svc_b := _make_anchor("svc_b", Vector3(5.0, 0.0, 0.0))
	scene_root.add_child(svc_a)
	scene_root.add_child(svc_b)
	var anchors: Dictionary = {"svc_a": svc_a, "svc_b": svc_b}

	var graph: Dictionary = {
		"nodes": [{"id": "svc_a"}, {"id": "svc_b"}],
		"edges": [{"source": "svc_b", "target": "svc_a", "type": "cross_context"}],
	}

	overlay.apply_failure_overlay("svc_a", graph, anchors, scene_root)

	# The scene root must contain an "AFFECTED" label for svc_b.
	_check(
		_has_label_in_scene(scene_root, "AFFECTED"),
		"scene must contain an 'AFFECTED' label identifying the affected component"
	)


## Label3D legibility check for failure overlay labels.
func test_failure_label_has_billboard_and_pixel_size() -> void:
	_test_failed = false
	var overlay := UnderstandingOverlay.new()
	var scene_root := Node3D.new()

	var svc_a := _make_anchor("svc_a", Vector3(0.0, 0.0, 0.0))
	var svc_b := _make_anchor("svc_b", Vector3(5.0, 0.0, 0.0))
	scene_root.add_child(svc_a)
	scene_root.add_child(svc_b)
	var anchors: Dictionary = {"svc_a": svc_a, "svc_b": svc_b}

	var graph: Dictionary = {
		"nodes": [{"id": "svc_a"}, {"id": "svc_b"}],
		"edges": [{"source": "svc_b", "target": "svc_a", "type": "cross_context"}],
	}

	overlay.apply_failure_overlay("svc_a", graph, anchors, scene_root)

	for child in scene_root.get_children():
		if child is Label3D:
			var lbl := child as Label3D
			_check(
				lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
				"failure label must have billboard=BILLBOARD_ENABLED"
			)
			_check(lbl.pixel_size > 0.0, "failure label must have pixel_size > 0.0")
			return
	_check(false, "no Label3D found in scene root for failure overlay")
