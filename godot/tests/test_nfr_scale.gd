## NFR Performance at Kartograph Scale — structural correctness tests.
##
## Spec: specs/prototype/nfr.spec.md
## Requirement: Performance at Kartograph Scale
##
## "The prototype MUST render kartograph's full structure (6 bounded contexts,
##  ~50 modules, ~100 files) without perceptible lag during navigation."
##
## Scenario: Smooth navigation
##   GIVEN kartograph's scene graph is loaded
##   WHEN the user pans, zooms, or orbits
##   THEN the frame rate remains above 30fps
##   AND there is no perceptible stutter or pop-in
##
## Frame rate cannot be measured in a headless test (no render pipeline).
## What IS verifiable: build_from_graph() must complete without errors at
## kartograph scale and produce the correct number of Node3D anchors.
## A scene that builds correctly at this scale is a necessary (though not
## sufficient) condition for smooth navigation.
##
## Scale contract from spec:
##   6 bounded contexts, ~50 modules, ~100 files
##
## Test fixture:
##   6 bounded contexts × 9 modules each = 54 modules  (total nodes: 60)
##   This satisfies "~50 modules" at kartograph scale.
##
## Untestable THEN-clauses (documented here per guidelines):
##   "THEN the frame rate remains above 30fps"
##     Cannot measure FPS without a render pipeline. Evidence of compliance:
##     LOD system (lod_manager.gd) is present and integrated in main.gd,
##     which actively culls invisible geometry per frame.
##   "AND there is no perceptible stutter or pop-in"
##     Same headless limitation. The LOD thresholds in lod_manager.gd provide
##     architectural evidence that pop-in is managed.
##
## Tests in this file (all Pattern-1 using _check()):
##   test_kartograph_scale_anchor_count
##   test_kartograph_scale_context_anchors_exist
##   test_kartograph_scale_module_anchors_exist
##   test_kartograph_scale_build_produces_world_positions

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
# Fixture: kartograph-scale scene graph
# 6 bounded contexts × 9 modules = 54 modules (60 nodes total)
# ---------------------------------------------------------------------------

func _make_kartograph_scale_fixture() -> Dictionary:
	## Returns a scene graph with 6 bounded contexts and 9 modules each
	## (54 modules total, satisfying "~50 modules" from the spec).
	## Contexts match kartograph's real bounded contexts:
	##   iam, shared_kernel, graph, billing, notifications, audit
	## Modules per context:
	##   domain, application, infrastructure, ports, adapters,
	##   services, repositories, events, queries
	var context_names: Array = [
		"iam", "shared_kernel", "graph", "billing", "notifications", "audit"
	]
	var module_names: Array = [
		"domain", "application", "infrastructure",
		"ports", "adapters", "services",
		"repositories", "events", "queries"
	]

	var nodes: Array = []
	var edges: Array = []
	var ctx_index: int = 0

	for ctx_name in context_names:
		var ctx_x: float = float(ctx_index) * 40.0 - 100.0
		nodes.append({
			"id": ctx_name,
			"name": ctx_name.capitalize(),
			"type": "bounded_context",
			"parent": null,
			"position": {"x": ctx_x, "y": 0.0, "z": 0.0},
			"size": 18.0,
		})

		var mod_index: int = 0
		for mod_name in module_names:
			var mod_x: float = float(mod_index % 3) * 5.0 - 5.0
			var mod_z: float = float(mod_index / 3) * 5.0 - 5.0
			nodes.append({
				"id": ctx_name + "." + mod_name,
				"name": mod_name.capitalize(),
				"type": "module",
				"parent": ctx_name,
				"position": {"x": mod_x, "y": 0.0, "z": mod_z},
				"size": 3.0,
			})
			mod_index += 1

		ctx_index += 1

	# Cross-context edges between consecutive bounded contexts.
	for i in range(context_names.size() - 1):
		edges.append({
			"source": context_names[i] + ".domain",
			"target": context_names[i + 1] + ".domain",
			"type": "cross_context",
		})

	# One internal edge to exercise the edge render path.
	edges.append({
		"source": "iam.domain",
		"target": "iam.application",
		"type": "internal",
	})

	return {
		"nodes": nodes,
		"edges": edges,
		"metadata": {
			"source_path": "/home/user/code/kartograph",
			"timestamp": "2026-01-01T00:00:00Z",
		},
	}


# ---------------------------------------------------------------------------
# Tests — structural correctness at kartograph scale
# ---------------------------------------------------------------------------

## THEN the scene builds without errors at kartograph scale:
## build_from_graph() creates exactly one anchor per node
## (6 contexts + 54 modules = 60 total).
## Implemented by: main.gd → build_from_graph() → _create_volume()
##   `_anchors[nd["id"]] = anchor`
func test_kartograph_scale_anchor_count() -> void:
	var main_node: Node3D = MainScript.new()
	var graph: Dictionary = _make_kartograph_scale_fixture()
	main_node.build_from_graph(graph)

	var anchors: Dictionary = main_node.get("_anchors")
	var expected_count: int = graph["nodes"].size()  # 60

	_check(
		anchors.size() == expected_count,
		"build_from_graph() must create exactly %d anchors at kartograph scale, got %d"
			% [expected_count, anchors.size()]
	)


## THEN all 6 bounded-context anchors exist after a kartograph-scale build.
## Implemented by: main.gd → build_from_graph() → _create_volume() (parent==null branch)
func test_kartograph_scale_context_anchors_exist() -> void:
	var main_node: Node3D = MainScript.new()
	var graph: Dictionary = _make_kartograph_scale_fixture()
	main_node.build_from_graph(graph)

	var anchors: Dictionary = main_node.get("_anchors")
	var context_ids: Array = [
		"iam", "shared_kernel", "graph", "billing", "notifications", "audit"
	]

	for ctx_id in context_ids:
		_check(
			anchors.has(ctx_id),
			"Anchor for bounded context '%s' must exist after kartograph-scale build" % ctx_id
		)


## THEN all 54 module anchors exist after a kartograph-scale build.
## Implemented by: main.gd → build_from_graph() → _create_volume() (parent!=null branch)
func test_kartograph_scale_module_anchors_exist() -> void:
	var main_node: Node3D = MainScript.new()
	var graph: Dictionary = _make_kartograph_scale_fixture()
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
		"Fixture must contain 54 module nodes (9 per context × 6 contexts), got %d" % module_count
	)


## THEN world positions are computed for every node at kartograph scale,
## confirming build_from_graph() ran to completion without errors.
## Implemented by: main.gd → build_from_graph() → _compute_world_positions()
##   `_world_positions[nd["id"]] = _resolve_world_pos(nd, node_data_map)`
func test_kartograph_scale_build_produces_world_positions() -> void:
	var main_node: Node3D = MainScript.new()
	var graph: Dictionary = _make_kartograph_scale_fixture()
	main_node.build_from_graph(graph)

	var world_positions: Dictionary = main_node.get("_world_positions")
	var expected_count: int = graph["nodes"].size()  # 60

	_check(
		world_positions.size() == expected_count,
		"_world_positions must contain %d entries at kartograph scale, got %d"
			% [expected_count, world_positions.size()]
	)
