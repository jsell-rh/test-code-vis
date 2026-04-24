## Behavioral tests for NFR: Performance at Kartograph Scale
##
## Spec: specs/prototype/nfr.spec.md
## Requirement: Performance at Kartograph Scale
##
## "The prototype MUST render kartograph's full structure (6 bounded contexts,
## ~50 modules, ~100 files) without perceptible lag during navigation."
##
## Scenario: Smooth navigation
##   GIVEN kartograph's scene graph is loaded
##   WHEN the user pans, zooms, or orbits
##   THEN the frame rate remains above 30fps
##   AND there is no perceptible stutter or pop-in
##
## FPS cannot be measured in a headless test (no render pipeline), but the
## correctness of the scene-graph build at kartograph scale IS verifiable:
## build_from_graph() must complete without errors and produce the correct
## number of Node3D anchors (one per context + one per module).
##
## Tests in this file:
##   test_kartograph_scale_anchor_count
##   test_kartograph_scale_context_anchors_exist
##   test_kartograph_scale_module_anchors_exist
##   test_kartograph_scale_build_has_no_errors

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
# Fixture: kartograph-scale scene graph (6 bounded contexts, 54 modules)
# ---------------------------------------------------------------------------

## Returns a scene graph dictionary with 6 bounded contexts and 9 modules
## each (54 modules total), spread across distinct positions.
## This mirrors kartograph's real structure:
##   iam, shared_kernel, graph, billing, notifications, audit
## with 9 internal modules apiece (domain, application, infrastructure, etc.).
func _make_kartograph_scale_fixture() -> Dictionary:
	var context_names := [
		"iam", "shared_kernel", "graph", "billing", "notifications", "audit"
	]
	var module_names := [
		"domain", "application", "infrastructure",
		"ports", "adapters", "services",
		"repositories", "events", "queries"
	]

	var nodes: Array = []
	var edges: Array = []
	var ctx_index: int = 0

	for ctx_name in context_names:
		var ctx_x: float = float(ctx_index) * 40.0 - 100.0
		var ctx_node := {
			"id": ctx_name,
			"name": ctx_name.capitalize(),
			"type": "bounded_context",
			"parent": null,
			"position": {"x": ctx_x, "y": 0.0, "z": 0.0},
			"size": 18.0,
		}
		nodes.append(ctx_node)

		var mod_index: int = 0
		for mod_name in module_names:
			var mod_x: float = float(mod_index % 3) * 5.0 - 5.0
			var mod_z: float = float(mod_index / 3) * 5.0 - 5.0
			var mod_node := {
				"id": ctx_name + "." + mod_name,
				"name": mod_name.capitalize(),
				"type": "module",
				"parent": ctx_name,
				"position": {"x": mod_x, "y": 0.0, "z": mod_z},
				"size": 3.0,
			}
			nodes.append(mod_node)
			mod_index += 1

		ctx_index += 1

	# Add cross-context edges between consecutive bounded contexts to simulate
	# the real dependency graph.
	for i in range(context_names.size() - 1):
		edges.append({
			"source": context_names[i] + ".domain",
			"target": context_names[i + 1] + ".domain",
			"type": "cross_context",
		})

	# Add some internal edges within one context to exercise the full edge path.
	edges.append({
		"source": "iam.domain",
		"target": "iam.application",
		"type": "internal",
	})

	return {"nodes": nodes, "edges": edges, "metadata": {"source_path": "/kartograph", "timestamp": "2026-01-01T00:00:00Z"}}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## THEN build_from_graph() creates exactly one anchor per node
## (6 contexts + 54 modules = 60 total).
## Implemented by: main.gd → build_from_graph() → _create_volume()
##   `_anchors[nd["id"]] = anchor`
func test_kartograph_scale_anchor_count() -> void:
	var main_node: Node3D = MainScript.new()
	var graph := _make_kartograph_scale_fixture()
	main_node.build_from_graph(graph)

	var anchors: Dictionary = main_node.get("_anchors")
	var expected_count: int = graph["nodes"].size()  # 60

	_check(
		anchors.size() == expected_count,
		"build_from_graph() must create exactly %d anchors at kartograph scale, got %d"
			% [expected_count, anchors.size()]
	)


## THEN build_from_graph() creates an anchor for every bounded context.
## Asserts all 6 context IDs are present in _anchors.
## Implemented by: main.gd → build_from_graph() → _create_volume() for parent==null nodes
func test_kartograph_scale_context_anchors_exist() -> void:
	var main_node: Node3D = MainScript.new()
	var graph := _make_kartograph_scale_fixture()
	main_node.build_from_graph(graph)

	var anchors: Dictionary = main_node.get("_anchors")
	var context_ids := ["iam", "shared_kernel", "graph", "billing", "notifications", "audit"]

	for ctx_id in context_ids:
		_check(
			anchors.has(ctx_id),
			"Anchor for bounded context '%s' must exist after kartograph-scale build" % ctx_id
		)


## THEN build_from_graph() creates an anchor for every module node.
## Asserts 54 module anchors (9 per context × 6 contexts) are present in _anchors.
## Implemented by: main.gd → build_from_graph() → _create_volume() for parent!=null nodes
func test_kartograph_scale_module_anchors_exist() -> void:
	var main_node: Node3D = MainScript.new()
	var graph := _make_kartograph_scale_fixture()
	main_node.build_from_graph(graph)

	var anchors: Dictionary = main_node.get("_anchors")
	var module_count: int = 0
	for node in graph["nodes"]:
		if node["type"] == "module":
			module_count += 1
			_check(
				anchors.has(node["id"]),
				"Anchor for module '%s' must exist after kartograph-scale build" % node["id"]
			)

	_check(
		module_count == 54,
		"Fixture must contain 54 module nodes (9 modules × 6 contexts), got %d" % module_count
	)


## THEN build_from_graph() completes the scene build at kartograph scale without errors.
## Verifies that world-position entries exist for every node, confirming the full
## build pipeline ran to completion.
## Implemented by: main.gd → build_from_graph() → _compute_world_positions()
##   `_world_positions[nd["id"]] = _resolve_world_pos(nd, node_data_map)`
func test_kartograph_scale_build_produces_world_positions() -> void:
	var main_node: Node3D = MainScript.new()
	var graph := _make_kartograph_scale_fixture()
	main_node.build_from_graph(graph)

	var world_positions: Dictionary = main_node.get("_world_positions")
	var expected_count: int = graph["nodes"].size()  # 60

	_check(
		world_positions.size() == expected_count,
		"_world_positions must contain %d entries at kartograph scale, got %d"
			% [expected_count, world_positions.size()]
	)
