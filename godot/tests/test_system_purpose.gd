## Behavioral tests tied to specs/core/system-purpose.spec.md.
##
## The system purpose spec defines three scenarios with THEN-clauses that
## describe outcomes the system must support.  These tests verify that the
## Godot visualization fulfils each testable THEN-clause at the prototype level.
##
## Coverage map (THEN-clause → test function):
##
##   Scenario "Architect evaluates unfamiliar system"
##     THEN the human can correctly answer architectural questions
##       → test_all_scene_nodes_have_visible_name_labels
##       → test_bounded_context_nodes_distinguishable_by_type
##     AND the human can identify structural problems
##       → test_node_size_grows_with_scene_graph_size_value
##       → test_dependency_edges_expose_coupling_in_scene
##     AND the human can predict the impact of proposed changes
##       → test_cross_context_edge_has_directional_arrowhead
##
##   Scenario "Spec and codebase loaded together"
##     AND the codebase is treated as the realized design
##       → test_scene_graph_loader_reads_codebase_json
##     NOTE: "spec is treated as intended design" and
##           "relationship between them is available for inspection"
##           are NOT testable at prototype level (spec-extraction and
##           spec-overlay-comparison are out of scope per prototype-scope.spec.md).
##
##   Scenario "Post-build evaluation"
##     AND the human can determine whether build is architecturally sound
##       → test_structural_metrics_available_in_scene
##     AND the human can explore impact of potential changes
##       → test_navigation_methods_exist_on_camera_controller
##     NOTE: "human can determine whether the build matches the spec"
##           is NOT testable at prototype level (spec-overlay comparison
##           is out of scope per prototype-scope.spec.md).

extends RefCounted

const Main = preload("res://scripts/main.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const SceneGraphLoader = preload("res://scripts/scene_graph_loader.gd")

var _runner: Object = null
var _test_failed: bool = false


func _check(condition: bool, msg: String = "") -> void:
	if not condition:
		_test_failed = true
		if _runner != null:
			_runner.record_failure(msg if msg != "" else "Assertion failed")


# ---------------------------------------------------------------------------
# Shared fixture helpers
# ---------------------------------------------------------------------------

func _make_two_context_graph() -> Dictionary:
	## Two bounded contexts (iam, graph) with a cross-context dependency.
	return {
		"nodes": [
			{
				"id": "iam",
				"name": "iam",
				"type": "bounded_context",
				"parent": null,
				"size": 3.0,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"metrics": {"loc": 200}
			},
			{
				"id": "graph",
				"name": "graph",
				"type": "bounded_context",
				"parent": null,
				"size": 2.5,
				"position": {"x": 20.0, "y": 0.0, "z": 0.0},
				"metrics": {"loc": 150}
			},
		],
		"edges": [
			{
				"source": "iam",
				"target": "graph",
				"type": "cross_context"
			}
		],
		"metadata": {
			"source_path": "/tmp/test",
			"generated_at": "2026-01-01T00:00:00Z"
		}
	}


func _make_large_module_graph() -> Dictionary:
	## Two modules where one is explicitly much larger (size 5.0 vs 1.0).
	return {
		"nodes": [
			{
				"id": "big",
				"name": "big",
				"type": "bounded_context",
				"parent": null,
				"size": 5.0,
				"position": {"x": 0.0, "y": 0.0, "z": 0.0},
				"metrics": {"loc": 5000}
			},
			{
				"id": "small",
				"name": "small",
				"type": "bounded_context",
				"parent": null,
				"size": 1.0,
				"position": {"x": 30.0, "y": 0.0, "z": 0.0},
				"metrics": {"loc": 10}
			}
		],
		"edges": [],
		"metadata": {
			"source_path": "/tmp/test",
			"generated_at": "2026-01-01T00:00:00Z"
		}
	}


# ---------------------------------------------------------------------------
# THEN: human can correctly answer architectural questions about the system
# ---------------------------------------------------------------------------


func test_all_scene_nodes_have_visible_name_labels() -> void:
	## System-purpose THEN-clause: 'the human can correctly answer architectural
	## questions about the system' — the first such question is 'what is this
	## thing?'.  Every volume in the scene must carry a visible Label3D so the
	## human can identify it by name without reading source code.
	## Labels must also have billboard=ENABLED and pixel_size > 0 (legibility).
	var main_node: Node3D = Main.new()
	main_node.build_from_graph(_make_two_context_graph())

	var found_label_for_iam := false
	var found_label_for_graph := false

	for child: Node in main_node.get_children():
		if child is Node3D:
			for grandchild: Node in child.get_children():
				if grandchild is Label3D:
					var lbl := grandchild as Label3D
					_check(lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
						"Label3D must have billboard=ENABLED for legibility in 3D")
					_check(lbl.pixel_size > 0.0,
						"Label3D must have pixel_size > 0 for legibility in 3D")
					if lbl.text == "iam":
						found_label_for_iam = true
					if lbl.text == "graph":
						found_label_for_graph = true

	_check(found_label_for_iam, "Expected a Label3D with text 'iam' in the scene")
	_check(found_label_for_graph, "Expected a Label3D with text 'graph' in the scene")


func test_bounded_context_nodes_distinguishable_by_type() -> void:
	## System-purpose THEN-clause: 'human can correctly answer architectural
	## questions' — the human must be able to distinguish bounded contexts from
	## internal modules.  Bounded context volumes must use a different material
	## (translucent slab, TRANSPARENCY_ALPHA) vs. module volumes (opaque box).
	var main_node: Node3D = Main.new()
	main_node.build_from_graph(_make_two_context_graph())

	var found_transparent_bc := false
	for child: Node in main_node.get_children():
		if child is Node3D:
			for grandchild: Node in child.get_children():
				if grandchild is MeshInstance3D:
					var mi := grandchild as MeshInstance3D
					if mi.material_override is StandardMaterial3D:
						var mat := mi.material_override as StandardMaterial3D
						if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
							found_transparent_bc = true

	_check(found_transparent_bc,
		"Expected at least one bounded-context MeshInstance3D with TRANSPARENCY_ALPHA material")


# ---------------------------------------------------------------------------
# AND: human can identify structural problems in the system
# ---------------------------------------------------------------------------


func test_node_size_grows_with_scene_graph_size_value() -> void:
	## System-purpose THEN-clause: 'human can identify structural problems' —
	## a module with high LOC must appear visually larger so problems like
	## god classes or oversized bounded contexts stand out immediately.
	## The BoxMesh size must be proportional to the node's 'size' field.
	var main_node: Node3D = Main.new()
	main_node.build_from_graph(_make_large_module_graph())

	var big_mesh_x := 0.0
	var small_mesh_x := 0.0

	var big_anchor: Node3D = main_node.get_node_or_null("big")
	var small_anchor: Node3D = main_node.get_node_or_null("small")

	_check(big_anchor != null, "Expected anchor node 'big' in scene")
	_check(small_anchor != null, "Expected anchor node 'small' in scene")
	if big_anchor == null or small_anchor == null:
		return

	for child: Node in big_anchor.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is BoxMesh:
				big_mesh_x = (mi.mesh as BoxMesh).size.x
				break

	for child: Node in small_anchor.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is BoxMesh:
				small_mesh_x = (mi.mesh as BoxMesh).size.x
				break

	_check(big_mesh_x > small_mesh_x,
		"Expected big node BoxMesh.size.x (%s) > small node BoxMesh.size.x (%s)" % [big_mesh_x, small_mesh_x])


func test_dependency_edges_expose_coupling_in_scene() -> void:
	## System-purpose THEN-clause: 'human can identify structural problems' —
	## coupling between bounded contexts must be visible as line geometry in the
	## scene so the human can see which contexts are tightly coupled.
	var main_node: Node3D = Main.new()
	main_node.build_from_graph(_make_two_context_graph())

	# An ImmediateMesh with PRIMITIVE_LINES encodes the dependency line.
	var found_line := false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is ImmediateMesh:
				found_line = true
				break

	_check(found_line, "Expected a MeshInstance3D with ImmediateMesh for coupling line geometry")


# ---------------------------------------------------------------------------
# AND: human can predict the impact of proposed changes
# ---------------------------------------------------------------------------


func test_cross_context_edge_has_directional_arrowhead() -> void:
	## System-purpose THEN-clause: 'human can predict the impact of proposed
	## changes' — to follow the dependency graph and assess change impact, the
	## direction of each dependency must be discernible.  A CylinderMesh with
	## top_radius == 0 (arrowhead cone) placed at the target end encodes direction.
	# dependency flows source → target → arrowhead cone (top_radius=0) placed at target end → direction discernible ✓
	var main_node: Node3D = Main.new()
	main_node.build_from_graph(_make_two_context_graph())

	var found_arrowhead := false
	for child: Node in main_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is CylinderMesh:
				var cone := mi.mesh as CylinderMesh
				if cone.top_radius == 0.0:
					found_arrowhead = true
					break

	_check(found_arrowhead,
		"Expected a MeshInstance3D with CylinderMesh (top_radius=0) as directional arrowhead")


# ---------------------------------------------------------------------------
# AND: codebase is treated as the realized design
# ---------------------------------------------------------------------------


func test_scene_graph_loader_reads_codebase_json() -> void:
	## System-purpose THEN-clause: 'the codebase is treated as the realized
	## design' — the Godot application loads the JSON produced by the extractor
	## (which reads the actual codebase) and builds the 3D scene from it.
	## This test verifies that SceneGraphLoader.load_from_dict() converts a
	## raw JSON dictionary into a validated scene graph with nodes and edges.
	var raw := _make_two_context_graph()
	var graph: Dictionary = SceneGraphLoader.load_from_dict(raw)

	_check(graph.has("nodes"), "SceneGraphLoader output must have 'nodes' key")
	_check(graph.has("edges"), "SceneGraphLoader output must have 'edges' key")
	_check(graph["nodes"].size() == 2,
		"Expected 2 nodes in graph, got %d" % graph["nodes"].size())


# ---------------------------------------------------------------------------
# AND: human can determine whether the build is architecturally sound
# ---------------------------------------------------------------------------


func test_structural_metrics_available_in_scene() -> void:
	## System-purpose THEN-clause: 'human can determine whether the build is
	## architecturally sound regardless of spec compliance' — soundness
	## evaluation requires seeing complexity (node size) and coupling (edges).
	## This test verifies that BOTH size-encoding and edge-geometry are present
	## in a scene built from a graph with nodes and a cross-context edge.
	var main_node: Node3D = Main.new()
	main_node.build_from_graph(_make_two_context_graph())

	var has_size_encoded_box := false
	var has_edge_line := false

	for child: Node in main_node.get_children():
		if child is Node3D:
			for grandchild: Node in child.get_children():
				if grandchild is MeshInstance3D:
					if (grandchild as MeshInstance3D).mesh is BoxMesh:
						has_size_encoded_box = true
		if child is MeshInstance3D:
			if (child as MeshInstance3D).mesh is ImmediateMesh:
				has_edge_line = true

	_check(has_size_encoded_box, "Expected at least one BoxMesh (size-encoded) in scene")
	_check(has_edge_line, "Expected at least one ImmediateMesh (coupling edge) in scene")


# ---------------------------------------------------------------------------
# AND: human can explore the impact of potential changes
# ---------------------------------------------------------------------------


func test_navigation_methods_exist_on_camera_controller() -> void:
	## System-purpose THEN-clause: 'human can explore the impact of potential
	## changes before updating the spec' — exploration requires navigating the
	## 3D space (pan, zoom, orbit).  The camera controller must expose these
	## capabilities so the human can freely inspect the visualized system.
	var cam = CameraController.new()

	# The controller must expose set_pivot (framing), get_distance (LOD),
	# and the internal state variables used for pan, orbit, and zoom.
	_check(cam.has_method("set_pivot"), "CameraController must have set_pivot method")
	_check(cam.has_method("get_distance"), "CameraController must have get_distance method")
	_check(cam.has_method("_handle_button"), "CameraController must have _handle_button method")
	_check(cam.has_method("_handle_motion"), "CameraController must have _handle_motion method")
	_check(cam.has_method("_zoom_toward_cursor"), "CameraController must have _zoom_toward_cursor method")

	cam.free()
