---
task_id: task-008
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — specs/prototype/godot-application.spec.md

### check-nondirectional-movement-assertions.sh
```
OK: All directional test functions use signed comparison predicates
```

### check-directional-signchain-comments.sh
```
OK: All directional calculation lines have sign-chain derivation comments (→)
```

---

## Requirement: JSON Scene Graph Loading — COVERED

**Implementation:** `godot/scripts/main.gd::_ready()` opens the JSON file with
`FileAccess.open(scene_graph_path, FileAccess.READ)`, reads it with
`file.get_as_text()`, parses with `JSON.new() + json.parse()`, then passes the
result to `SceneGraphLoader.load_from_dict()` before calling `build_from_graph()`.
`godot/data/scene_graph.json` contains a real kartograph scene graph. The
`@export var scene_graph_path` allows different files without code changes.

**Scenario: Loading kartograph's scene graph**

- THEN it reads the JSON file →
  `test_godot_version.gd::test_main_uses_godot4_fileaccess_api()` reads
  `main.gd` via `FileAccess.open()` + `get_as_text()` and asserts the source
  contains `FileAccess.open(` and `get_as_text()` while not containing the
  deprecated `File.new()` or `read_as_text()`. COVERED.

- AND generates 3D volumes for each node →
  `test_scene_graph_loading.gd::test_volumes_created_for_each_node()` asserts
  `_anchors.has("ctx1")` and `_anchors.has("mod1")`;
  `test_mesh_instances_exist_in_anchors()` asserts each anchor has a
  `MeshInstance3D` child. COVERED.

- AND generates connections for each edge →
  `test_scene_graph_loading.gd::test_edge_mesh_instances_created()` asserts at
  least 2 `MeshInstance3D` children (line + arrowhead) after one edge. COVERED.

- AND positions elements according to the layout data →
  `test_scene_graph_loading.gd::test_anchor_positions_match_json()` asserts
  `ctx_anchor.position.is_equal_approx(Vector3(0,0,0))` and
  `mod_anchor.position.is_equal_approx(Vector3(2,0,2))` for JSON
  `position: {x:2, y:0, z:2}`. Parent is at (0,0,0) so this also verifies that
  child positions are stored as local offsets and are not vacuous. COVERED.

---

## Requirement: Containment Rendering — COVERED

**Implementation:** `main.gd::_create_volume()` uses `TRANSPARENCY_ALPHA` +
`alpha=0.18` for bounded_context and `alpha=1.0` opaque for modules; child
nodes are added as Godot scene-tree children of the parent anchor.

**Scenario: Modules inside a bounded context**

- THEN bounded context appears as larger translucent volume →
  `test_containment_rendering.gd::test_bounded_context_is_translucent()` (alpha
  < 1.0, TRANSPARENCY != DISABLED) and
  `test_bounded_context_larger_than_module()` (BoxMesh.size.x comparison).
  COVERED.

- AND child modules appear as smaller opaque volumes inside it →
  `test_module_is_opaque()` (alpha >= 1.0) and
  `test_module_parented_inside_context()` (mod_anchor.get_parent() ==
  ctx_anchor). COVERED.

- AND boundary of parent is visually distinct →
  `test_bounded_context_cull_disabled()` asserts
  `mat.cull_mode == BaseMaterial3D.CULL_DISABLED` for the context volume,
  distinguishing it from children which use default back-face culling. COVERED.

---

## Requirement: Dependency Rendering — COVERED

**Implementation:** `main.gd::_create_edge()` creates an `ImmediateMesh`
`PRIMITIVE_LINES` segment plus a `CylinderMesh` (top_radius=0) arrowhead at
the target end, oriented along the edge direction via `Basis(Quaternion(...))`.

**Scenario: Rendering a cross-context dependency**

- THEN a line connects the two context volumes →
  `test_dependency_rendering.gd::test_edge_line_mesh_created()` asserts an
  `ImmediateMesh` `MeshInstance3D` child exists. COVERED.

- AND the line's direction is visually indicated →
  `test_direction_indicator_cone_created()` asserts `CylinderMesh` with
  `top_radius == 0.0` exists; `test_direction_cone_near_target()` asserts cone
  is within 2 units of target (20,0,0); `test_cross_context_cone_is_orange()`
  asserts `R > 0.8 and B < 0.3`. COVERED.

---

## Requirement: Size Encoding — COVERED

**Implementation:** `main.gd::_create_volume()` uses `sz = float(nd["size"])`
directly as the `BoxMesh.size` x-dimension, making mesh width proportional to
the JSON `size` field (which is derived from LOC by the Python extractor).

**Scenario: Large module vs small module**

- THEN module with more code appears as larger volume →
  `test_size_encoding.gd::test_large_module_has_bigger_mesh()` asserts
  `large_mesh.size.x > small_mesh.size.x`. COVERED.

- AND relative sizes are proportional to metric →
  `test_mesh_sizes_proportional_to_metric()` asserts
  `abs(large.size.x / small.size.x - 3.0) < 0.001` (fixture has size 9 vs 3).
  COVERED.

---

## Requirement: Camera Controls — PARTIAL → FAIL

**Scenario: Top-down overview** — COVERED

- THEN camera defaults to top-down view →
  `test_camera_controls.gd::test_initial_theta_is_near_top_down()` asserts
  `_theta < PI/4.0`; `test_initial_distance_is_positive()` asserts
  `_distance > 0`. COVERED.

**Scenario: Zooming in** — COVERED

- THEN camera moves closer →
  `test_scroll_up_decreases_distance()` asserts
  `_target_distance < initial_target` after MOUSE_BUTTON_WHEEL_UP. COVERED.

- AND internal structure becomes visible as camera approaches →
  `test_spatial_structure.gd::test_medium_distance_shows_modules()` asserts
  module anchor visible at mid-distance;
  `test_lod_integration_far_hides_modules_in_built_scene()` asserts module
  hidden at far distance via end-to-end LOD integration. COVERED.

- AND labels scale to remain readable →
  `test_scene_graph_loading.gd::test_labels_are_billboard_and_readable()`
  asserts `billboard == BILLBOARD_ENABLED`, `pixel_size > 0`, and
  `no_depth_test == true`. COVERED.

**Scenario: Orbiting** — PARTIAL

- THEN camera rotates around current focal point →
  `test_orbit_horizontal_drag_changes_phi()` asserts `_phi != initial_phi`
  after right-drag (non-directional but direction not specified in spec).
  `test_orbit_vertical_drag_changes_theta()` asserts `_theta != initial_theta`
  after vertical drag. COVERED for the rotation-occurs contract.

- **AND orientation remains intuitive (up stays up)** → **MISSING TEST**

  **Implementation:** `camera_controller.gd::_handle_motion()` clamps theta:
  ```
  _theta = clamp(_theta - delta.y * orbit_speed, 0.01, PI - 0.01)
  ```
  `_update_transform()` calls `look_at(_pivot, Vector3.UP)` keeping the up
  vector stable. The clamp prevents pole-flipping.

  **Required test:** There is NO test that verifies theta stays within
  `(0.01, PI - 0.01)` under extreme drag input. `test_zoom_clamped_at_minimum()`
  correctly verifies the zoom clamp; the symmetrical theta clamp has no
  equivalent test. An implementer could remove the `clamp()` call and no
  existing test would fail. This THEN-clause of a MUST requirement lacks test
  coverage.

  **What is needed:** A test that simulates extreme vertical drag (e.g., 10 000
  pixels up or down) and asserts:
  ```gdscript
  cam._theta >= 0.01 and cam._theta <= PI - 0.01
  ```
  This directly covers the "up stays up" contract by proving the clamp prevents
  the camera from flipping through the vertical poles.

---

## Requirement: Godot 4.6 — COVERED

**Implementation:** `godot/project.godot` declares
`config/features=PackedStringArray("4.6")`. All files in `godot/scripts/` are
`.gd`. `main.gd` uses `FileAccess.open()` and `file.get_as_text()` (Godot 4.x
API), not the deprecated `File.new()` / `read_as_text()`.

**Scenario: Engine version**

- THEN it uses Godot 4.6.x →
  `test_engine_version.gd::test_project_godot_declares_46_feature()` reads
  project.godot and asserts `content.contains("4.6")`;
  `test_project_godot_config_features_line()` asserts the `config/features`
  entry contains `"4.6"`. COVERED.

- AND all scripts use GDScript →
  `test_scripts_dir_contains_only_gdscript()` iterates `res://scripts/` via
  `DirAccess` and asserts every file ends with `.gd`;
  `test_project_does_not_declare_csharp()` asserts no Mono/C# in project.godot.
  COVERED.

- AND all API calls are valid for the Godot 4.6 API →
  `test_file_access_get_as_text_returns_non_empty_string()` exercises
  `FileAccess.open() + get_as_text()` directly (not `read_as_text()`);
  `test_main_uses_godot4_fileaccess_api()` reads `main.gd` source and asserts
  the correct API pattern is used. COVERED.

---

## Summary

| Requirement              | Status  |
|--------------------------|---------|
| JSON Scene Graph Loading | COVERED |
| Containment Rendering    | COVERED |
| Dependency Rendering     | COVERED |
| Size Encoding            | COVERED |
| Camera Controls          | PARTIAL |
| Godot 4.6                | COVERED |

**Verdict: FAIL**

One THEN-clause of the Camera Controls MUST requirement — "AND orientation
remains intuitive (up stays up)" in the Orbiting scenario — has implementation
(`clamp(_theta ..., 0.01, PI - 0.01)` + `look_at(..., Vector3.UP)`) but no
test that exercises the clamp boundary. A test exercising extreme vertical drag
and asserting `0.01 <= _theta <= PI - 0.01` is required.