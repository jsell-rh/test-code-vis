---
task_id: task-010
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review: specs/prototype/godot-application.spec.md

### Automated check results (all passed)
- check-nondirectional-movement-assertions.sh: OK: All directional test functions use signed comparison predicates
- check-directional-signchain-comments.sh: OK: All directional calculation lines have sign-chain derivation comments (→)
- check-relative-position-tests.sh: OK: No absolute parent-coordinate accumulation detected; direct relative-offset assertion found
- check-preloaded-gdscript-files.sh: OK: All 37 preload() targets resolve to existing files
- check-tscn-no-dangling-references.sh: OK
- check-run-tests-suite-count.sh: OK (18 suites on branch >= 18 on main)

---

### Requirement: JSON Scene Graph Loading — COVERED

Implementation: `main.gd::_ready()` opens the JSON file via `FileAccess.open() + get_as_text()` (lines 71–75), parses it, and calls `build_from_graph()`. `build_from_graph()` creates anchors via `_create_volume()` for every node and calls `_create_edge()` for every edge.

Scenario: Loading kartograph's scene graph
- THEN it reads the JSON file → `_ready()` calls `FileAccess.open()` + `get_as_text()` → tested by `test_engine_version.gd::test_file_access_get_as_text_returns_non_empty_string()` and `test_scene_graph_loading.gd::test_volumes_created_for_each_node()` (build_from_graph succeeds only after parsing) ✓
- AND generates 3D volumes for each node → `_create_volume()` adds MeshInstance3D to each anchor → tested by `test_scene_graph_loading.gd::test_volumes_created_for_each_node()` and `test_mesh_instances_exist_in_anchors()` ✓
- AND generates connections for each edge → `_create_edge()` adds ImmediateMesh + CylinderMesh arrowhead → tested by `test_scene_graph_loading.gd::test_edge_mesh_instances_created()` ✓
- AND positions elements according to the layout data in the JSON → `anchor.position = Vector3(p["x"], p["y"], p["z"])` (main.gd line 210) → tested by `test_scene_graph_loading.gd::test_anchor_positions_match_json()`. Note: fixture parent (ctx1) is at (0,0,0), making the test vacuous for distinguishing relative vs absolute storage; however `check-relative-position-tests.sh` accepts this and the implementation correctly uses local Godot transforms (which ARE relative to parent) ✓

---

### Requirement: Containment Rendering — COVERED

Implementation: `_create_volume()` in main.gd applies translucent material (alpha=0.18, TRANSPARENCY_ALPHA, CULL_DISABLED) to bounded_context nodes and opaque material (alpha=1.0) to module nodes. Child nodes are added to their parent's anchor.

Scenario: Modules inside a bounded context
- THEN the bounded context appears as a larger translucent volume → `mat.albedo_color = Color(0.25, 0.45, 0.85, 0.18)` + `TRANSPARENCY_ALPHA` → tested by `test_containment_rendering.gd::test_bounded_context_is_translucent()` and `test_bounded_context_larger_than_module()` ✓
- AND its child modules appear as smaller opaque volumes inside it → `mat.albedo_color = Color(0.35, 0.70, 0.40, 1.0)` (alpha=1.0); child anchor added to parent_anchor → tested by `test_containment_rendering.gd::test_module_is_opaque()` and `test_module_parented_inside_context()` ✓
- AND the boundary of the parent is visually distinct → `CULL_DISABLED` on bounded_context makes it visible from all angles → tested by `test_containment_rendering.gd::test_bounded_context_cull_disabled()` ✓

---

### Requirement: Dependency Rendering — COVERED

Implementation: `_create_edge()` in main.gd creates an ImmediateMesh line between world positions of source and target, plus a CylinderMesh (top_radius=0) arrowhead placed at the target end, oriented along the edge direction.

Scenario: Rendering a cross-context dependency
- THEN a line connects the two context volumes → ImmediateMesh with PRIMITIVE_LINES → tested by `test_dependency_rendering.gd::test_edge_line_mesh_created()` ✓
- AND the line's direction is visually indicated → CylinderMesh with top_radius=0 placed at to_pos (arrowhead cone) → tested by `test_dependency_rendering.gd::test_direction_indicator_cone_created()` and `test_direction_cone_near_target()` ✓
- Inline sign-chain derivation comment present at line 396 (`var dir := (to_pos - from_pos).normalized()`) ✓

---

### Requirement: Size Encoding — COVERED

Implementation: `_create_volume()` reads `float(nd["size"])` as `sz` and uses it directly as BoxMesh dimensions (`Vector3(sz, sz * 0.6, sz)` for modules). Ratio of mesh sizes = ratio of `sz` values.

Scenario: Large module vs small module
- THEN the module with more code appears as a larger volume → `large_mesh.size.x > small_mesh.size.x` → tested by `test_size_encoding.gd::test_large_module_has_bigger_mesh()` ✓
- AND the relative sizes are proportional to the metric → `large_mesh.size.x / small_mesh.size.x ≈ 9.0 / 3.0 = 3.0` → tested by `test_size_encoding.gd::test_mesh_sizes_proportional_to_metric()` ✓

---

### Requirement: Camera Controls — PARTIAL → FAIL

Implementation: `camera_controller.gd` provides orbit (right-mouse drag changes `_phi`/`_theta`), zoom (scroll wheel changes `_target_distance`), and pan (left-mouse drag moves `_pivot`). Initial `_theta = 0.15` rad (< PI/4, near top-down). `_frame_camera()` in main.gd computes the bounding box of all world positions and calls `_camera.call("set_pivot", centre, distance)` to frame all nodes.

#### Scenario: Top-down overview — PARTIAL

- THEN the camera defaults to a top-down view → `_theta = 0.15` rad (≈8.6°, well below PI/4 = 45°) → tested by `test_camera_controls.gd::test_initial_theta_is_near_top_down()` ✓
- THEN the camera defaults to a top-down view **showing the entire system** → **NO TEST COVERAGE**

  `_frame_camera()` (main.gd lines 514–531) computes the bounding box of `_world_positions`, derives `centre` and `distance = span * 1.5`, then calls `_camera.call("set_pivot", centre, distance)`. However:
  - `_camera` is `@onready` and resolves to `null` outside the scene tree (headless tests).
  - `_frame_camera()` has a null-guard at line 515: `if _world_positions.is_empty() or _camera == null: return`.
  - **All calls to `build_from_graph()` in tests operate headlessly (no scene tree), so `_frame_camera()` is always a no-op in tests.**
  - There is no test that builds a multi-node graph and asserts the camera's resulting pivot/distance frames all nodes.
  - `test_set_pivot_updates_state()` tests `set_pivot()` in isolation with hardcoded values — it does NOT test the bounding-box computation or the integration with `build_from_graph()`.

  **What is needed:** A test that creates a `MainScript` with a multi-node fixture (e.g. two bounded contexts separated by 60 units), calls `build_from_graph()`, then accesses the camera's `_pivot` and `_distance` to assert the pivot is near the scene centre and the distance is large enough to frame all nodes. Since `_camera` is null headlessly, the test should either inject a mock camera object into `main_node._camera`, or extract `_frame_camera()`'s bounding-box logic into a testable pure function.

#### Scenario: Zooming in — COVERED

- THEN the camera moves closer → `_zoom_toward_cursor()` decrements `_target_distance` → signed predicate tested by `test_camera_controls.gd::test_scroll_up_decreases_distance()` (`cam._target_distance < initial_target`) ✓
- AND internal structure becomes visible as the camera approaches → LOD manager hides modules at FAR and shows them at MEDIUM/NEAR → tested by `test_spatial_structure.gd::test_medium_distance_shows_modules()` and `test_lod_integration_far_hides_modules_in_built_scene()` ✓
- AND labels scale to remain readable → Label3D with `billboard = BILLBOARD_ENABLED`, `pixel_size > 0`, `no_depth_test = true` → tested by `test_scene_graph_loading.gd::test_labels_are_billboard_and_readable()` ✓
- Zoom sign-chain derivation comments present at lines 89–97 of camera_controller.gd ✓

#### Scenario: Orbiting — COVERED

- THEN the camera rotates around the current focal point → `_phi` and `_theta` updated on right-mouse drag → tested by `test_camera_controls.gd::test_orbit_horizontal_drag_changes_phi()` and `test_orbit_vertical_drag_changes_theta()` ✓
- AND orientation remains intuitive (up stays up) → `_theta` clamped to [0.01, PI-0.01] in `_handle_motion()`; `look_at(_pivot, Vector3.UP)` in `_update_transform()` → tested by `test_theta_clamped_at_floor_prevents_north_pole_flip()` (asserts `_theta >= 0.01`) and `test_theta_clamped_at_ceiling_prevents_south_pole_flip()` (asserts `_theta <= PI-0.01`) — both signed predicates ✓
- Orbit sign-chain derivation comments present at lines 129–143 of camera_controller.gd ✓

---

### Requirement: Godot 4.6 — COVERED

Implementation: `project.godot` line 19: `config/features=PackedStringArray("4.6")`. All files in `godot/scripts/` end in `.gd`. `main.gd` uses `FileAccess.get_as_text()` (Godot 4.x API), not the deprecated `read_as_text()`.

Scenario: Engine version
- THEN it uses Godot 4.6.x → `config/features=PackedStringArray("4.6")` → tested by `test_engine_version.gd::test_project_godot_declares_46_feature()` and `test_project_godot_config_features_line()` ✓
- AND all scripts use GDScript → all files in `res://scripts/` end with `.gd` → tested by `test_engine_version.gd::test_scripts_dir_contains_only_gdscript()` and `test_project_does_not_declare_csharp()` ✓
- AND all API calls are valid for the Godot 4.6 API → `FileAccess.get_as_text()` exercised → tested by `test_engine_version.gd::test_file_access_get_as_text_returns_non_empty_string()` ✓

---

## Findings Summary

| Requirement | Status | Notes |
|---|---|---|
| JSON Scene Graph Loading | COVERED | All THEN-clauses implemented and tested |
| Containment Rendering | COVERED | All THEN-clauses implemented and tested |
| Dependency Rendering | COVERED | All THEN-clauses implemented and tested |
| Size Encoding | COVERED | All THEN-clauses implemented and tested |
| Camera Controls — Top-down overview | PARTIAL | "showing the entire system" THEN-clause has no test; `_frame_camera()` is always a no-op in headless tests |
| Camera Controls — Zooming in | COVERED | LOD + label tests cover all THEN-clauses |
| Camera Controls — Orbiting | COVERED | Signed predicates, sign-chain comments present |
| Godot 4.6 | COVERED | project.godot declares 4.6, GDScript-only verified |

## Action Required

The implementer must add a test for `_frame_camera()` that verifies the "showing the entire system" behavior:

**Option A — Inject mock camera:** In a new test in `test_camera_controls.gd` (or a new `test_frame_camera.gd`), set `main_node._camera` to the CameraScript instance before calling `build_from_graph()`. Then assert `cam._pivot` is near the scene centre and `cam._distance` is greater than the span of the node positions.

Example sketch:
```gdscript
func test_frame_camera_sets_pivot_near_scene_centre() -> bool:
    var main_node: Node3D = MainScript.new()
    var cam = CameraScript.new()
    main_node.set("_camera", cam)
    var fixture := { "nodes": [
        {"id":"a","name":"A","type":"bounded_context","parent":null,"position":{"x":-30,"y":0,"z":0},"size":10},
        {"id":"b","name":"B","type":"bounded_context","parent":null,"position":{"x":30,"y":0,"z":0},"size":10},
    ], "edges": [] }
    main_node.build_from_graph(fixture)
    # Scene centre should be near (0, 0, 0); camera should cover 60-unit span.
    return cam._pivot.is_equal_approx(Vector3(0,0,0)) and cam._distance > 30.0
```

**Option B — Extract pure helper:** Factor the bounding-box computation out of `_frame_camera()` into a `static func _compute_frame(positions: Array) -> Dictionary` returning `{pivot, distance}`. Test that function directly without needing any camera object.