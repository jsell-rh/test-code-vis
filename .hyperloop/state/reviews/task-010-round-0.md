---
task_id: task-010
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — specs/prototype/godot-application.spec.md — task-010

All review performed against the worktree at:
`/home/jsell/code/sandbox/code-vis/worktrees/workers/task-010/`

Implementation files examined:
- `godot/scripts/main.gd`
- `godot/scripts/camera_controller.gd`
- `godot/scripts/scene_graph_loader.gd`
- `godot/tests/test_scene_graph_loading.gd`
- `godot/tests/test_containment_rendering.gd`
- `godot/tests/test_dependency_rendering.gd`
- `godot/tests/test_size_encoding.gd`
- `godot/tests/test_camera_controls.gd`
- `godot/tests/test_engine_version.gd`
- `godot/tests/run_tests.gd`
- `godot/project.godot`

---

## Requirement Coverage

### 1. JSON Scene Graph Loading — COVERED

**Implementation (`main.gd`):**
- `_ready()` opens the scene-graph file with `FileAccess.open(scene_graph_path, FileAccess.READ)` and reads it with `file.get_as_text()` (Godot 4.6 API).
- Parses via `JSON.new().parse()` then delegates to `SceneGraphLoader.load_from_dict()`.
- `build_from_graph()` creates a `Node3D` anchor with `BoxMesh` + `Label3D` for every node, and calls `_create_edge()` for every edge.
- Anchor positions are set from JSON `position.{x,y,z}`.

**Tests (`test_scene_graph_loading.gd` — bool-return pattern):**
- `test_volumes_created_for_each_node` → asserts `_anchors.has("ctx1")` and `_anchors.has("mod1")`. ✓
- `test_mesh_instances_exist_in_anchors` → asserts each anchor has a `MeshInstance3D` child. ✓
- `test_edge_mesh_instances_created` → asserts ≥ 2 `MeshInstance3D` children on main_node after edge creation. ✓
- `test_anchor_positions_match_json` → asserts anchor positions equal JSON coordinates. ✓
- `test_labels_are_billboard_and_readable` → asserts `Label3D.billboard == BILLBOARD_ENABLED`, `pixel_size > 0`, `no_depth_test == true`. ✓

All THEN-clauses of the scenario covered. ✓

---

### 2. Containment Rendering — COVERED

**Implementation (`main.gd._create_volume()`):**
- Bounded contexts: `mat.transparency = TRANSPARENCY_ALPHA`, `albedo_color.a = 0.18`, `mat.cull_mode = CULL_DISABLED`, large flat box.
- Modules: `albedo_color.a = 1.0` (opaque), compact box sized proportionally.
- `build_from_graph()` parents module anchors as children of their context anchor.

**Tests (`test_containment_rendering.gd` — bool-return pattern):**
- `test_bounded_context_is_translucent` → `transparency != DISABLED` and `alpha < 1.0`. ✓
- `test_module_is_opaque` → `albedo_color.a >= 1.0`. ✓
- `test_module_parented_inside_context` → `mod_anchor.get_parent() == ctx_anchor`. ✓
- `test_bounded_context_larger_than_module` → `ctx_mesh.size.x > mod_mesh.size.x`. ✓
- `test_bounded_context_cull_disabled` → `cull_mode == CULL_DISABLED`. ✓

All THEN-clauses covered. ✓

---

### 3. Dependency Rendering — COVERED

**Implementation (`main.gd._create_edge()`):**
- Builds an `ImmediateMesh` with `PRIMITIVE_LINES` connecting world-space endpoints.
- Places a `CylinderMesh` with `top_radius = 0.0` (cone) at the target end, oriented via `Basis(Quaternion(Vector3.UP, dir))`.
- Cross-context edges colored orange `Color(1.0, 0.50, 0.10)`.

**Tests (`test_dependency_rendering.gd` — bool-return pattern):**
- `test_edge_line_mesh_created` → `ImmediateMesh` child found. ✓
- `test_direction_indicator_cone_created` → `CylinderMesh` with `top_radius == 0.0` found. ✓
- `test_direction_cone_near_target` → cone position within 2 units of target. ✓
- `test_cross_context_cone_is_orange` → `albedo_color.r > 0.8` and `albedo_color.b < 0.3`. ✓

All THEN-clauses covered. ✓

---

### 4. Size Encoding — COVERED

**Implementation (`main.gd._create_volume()`):**
- `sz = float(nd["size"])` applied directly as `box.size = Vector3(sz, sz * 0.6, sz)` for modules.
- Linear mapping preserves metric ratios exactly.

**Tests (`test_size_encoding.gd` — bool-return pattern):**
- `test_large_module_has_bigger_mesh` → `large_mesh.size.x > small_mesh.size.x`. ✓
- `test_mesh_sizes_proportional_to_metric` → `abs(actual_ratio - 3.0) < 0.001` with inputs 9.0 / 3.0. ✓

All THEN-clauses covered. ✓

---

### 5. Camera Controls — PARTIAL ← causes FAIL

**Implementation (`camera_controller.gd`):**
- Spherical-coordinate camera: `_theta = 0.15` (≈8.6° from overhead) satisfies "top-down".
- `MOUSE_BUTTON_WHEEL_UP/DOWN` → adjusts `_distance` clamped to `[min_distance, max_distance]`.
- Middle-mouse drag → updates `_phi` (azimuth) and `_theta` (polar, clamped to `[0.01, PI-0.01]`).
- `_update_transform()` calls `look_at(_pivot, Vector3.UP)` when inside the scene tree.

**Tests (`test_camera_controls.gd` — bool-return pattern):**

*Scenario: Top-down overview*
- `test_initial_theta_is_near_top_down` → `cam._theta < PI/4.0`. ✓
- `test_initial_distance_is_positive` → `cam._distance > 0.0`. ✓

*Scenario: Zooming in*
- `test_scroll_up_decreases_distance` → distance decreases after WHEEL_UP. ✓
- `test_scroll_down_increases_distance` → distance increases after WHEEL_DOWN. ✓
- `test_zoom_clamped_at_minimum` → 200× WHEEL_UP leaves `_distance >= min_distance`. ✓
- "AND internal structure becomes visible as the camera approaches" — covered indirectly by containment tests (translucent parent + nested children). ✓
- "AND labels scale to remain readable" — covered by `test_labels_are_billboard_and_readable` in `test_scene_graph_loading.gd` (asserts `BILLBOARD_ENABLED`, `pixel_size > 0`, `no_depth_test == true`). ✓

*Scenario: Orbiting*
- `test_orbit_horizontal_drag_changes_phi` → middle-mouse drag changes `_phi`. ✓
- `test_orbit_vertical_drag_changes_theta` → middle-mouse drag changes `_theta`. ✓
- **"AND orientation remains intuitive (up stays up)"** — ✗ **NO TEST.**

The implementation clamps `_theta` to `[0.01, PI-0.01]` to prevent camera flip and calls
`look_at(_pivot, Vector3.UP)` when in-tree. Neither the clamping behavior nor the resulting
orientation is exercised by any test.

**What the implementer must add** — one test in `test_camera_controls.gd`:

```gdscript
## AND orientation remains intuitive (up stays up) —
## theta is clamped so the camera never flips past the vertical poles.
func test_orbit_theta_clamped_prevents_flip() -> bool:
    var cam = CameraScript.new()
    # Begin orbiting.
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_MIDDLE
    press.pressed = true
    press.position = Vector2(100.0, 100.0)
    cam._handle_button(press)
    # Drag a huge distance downward — without clamping this would push theta past PI.
    var motion := InputEventMouseMotion.new()
    motion.position = Vector2(100.0, 1000000.0)
    cam._handle_motion(motion)
    # theta must stay at or below PI-0.01 (clamped), preventing camera inversion.
    var result: bool = cam._theta <= PI - 0.01
    cam.free()
    return result
```

---

### 6. Godot 4.6 — COVERED

**Implementation:**
- `project.godot` declares `config/features=PackedStringArray("4.6")`.
- All scripts in `godot/scripts/` are `.gd` (GDScript only).
- All file I/O uses `FileAccess.open()` + `get_as_text()` — the Godot 4.6 API.

**Tests (`test_engine_version.gd` — bool-return pattern):**
- `test_project_godot_declares_46` → `"4.6" in text`. ✓
- `test_features_line_contains_46` → `'PackedStringArray("4.6")' in text`. ✓
- `test_fileaccess_open_returns_non_null` → exercises `FileAccess.open()` + `get_as_text()`. ✓

All THEN-clauses covered. ✓

---

## Summary

| Requirement              | Status  | Notes                                                          |
|--------------------------|---------|----------------------------------------------------------------|
| JSON Scene Graph Loading | COVERED | All 5 scenario THEN-clauses tested                            |
| Containment Rendering    | COVERED | All 5 scenario THEN-clauses tested                            |
| Dependency Rendering     | COVERED | Both THEN-clauses tested with 4 assertions                    |
| Size Encoding            | COVERED | Both THEN-clauses tested                                      |
| Camera Controls          | PARTIAL | Orbiting "up stays up" THEN-clause has no test                |
| Godot 4.6                | COVERED | Version string + API exercised                                |

**Verdict: FAIL**

One THEN-clause of a MUST requirement (Camera Controls → Orbiting scenario →
"AND orientation remains intuitive (up stays up)") has no corresponding behavioral test.
The implementation is correct (`_theta` clamped to `[0.01, PI-0.01]`, `look_at(pivot,
Vector3.UP)`) but the clamping behavior is untested. Add
`test_orbit_theta_clamped_prevents_flip()` as shown above to satisfy this condition.