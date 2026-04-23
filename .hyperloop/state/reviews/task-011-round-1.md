---
task_id: task-011
round: 1
role: implementer
verdict: fail
---
## Code Reviewer Verdict — task-011 (fresh cycle post-reset)
## Spec: specs/prototype/godot-application.spec.md

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Check Script Results

| Script | Result |
|--------|--------|
| check-not-in-scope.sh | OK |
| check-kartograph-integration-test.sh | OK |
| extractor-lint.sh | PASS — ruff clean, 90 pytest tests pass |
| godot-compile.sh | PASS — Godot 4.6.2.stable.official |
| godot-tests.sh | 56 PASS / 0 FAIL |
| godot-fileaccess-tested.sh | OK — FileAccess.open() exercised in 2 test files |
| godot-label3d.sh | PASS |

---

## Blocking Finding: Missing Theta-Clamping Constraint Test

**Guideline violated:**
> Constraint behaviors require explicit constraint tests. If a THEN-clause is satisfied
> by clamping, bounding, or limiting a value (e.g., camera theta clamped to prevent flip),
> confirm a test exists that drives the input past the limit and asserts the clamped result.
> A test that only exercises the normal range does not cover the constraint THEN-clause.

**Spec THEN-clause:** "AND orientation remains intuitive (up stays up)"
(Scenario: Orbiting, Requirement: Camera Controls)

**Implementation:** `camera_controller.gd` line 73:
```gdscript
_theta = clamp(_theta - delta.y * orbit_speed, 0.01, PI - 0.01)
```
Theta is clamped to `[0.01, PI - 0.01]` to prevent the camera from flipping past the
poles. This is the literal example from the constraint-behavior guideline.

**Tests present for orbiting:**
- `test_orbit_vertical_drag_changes_theta` — starts at `_theta = 0.15`, applies a
  20-pixel drag. Resulting theta = `clamp(0.15 + 0.1, ...) = 0.25`. Normal range only.
  Asserts `cam._theta != initial_theta` — does NOT assert the clamped boundary value.
- `test_zoom_clamped_at_minimum` — tests `_distance` zoom clamping. Unrelated to theta.

**No test exists that:**
1. Drives `_theta` toward `0.01` (upper pole) with an extreme drag input, AND asserts
   `cam._theta >= 0.01`, OR
2. Drives `_theta` toward `PI - 0.01` (lower pole) and asserts `cam._theta <= PI - 0.01`.

**Required fix:** Add one or both tests to `godot/tests/test_camera_controls.gd`:

```gdscript
## Theta is clamped at lower pole so camera never flips past the top —
## a massive upward drag must leave _theta >= 0.01.
func test_theta_clamped_at_minimum() -> bool:
    var cam = CameraScript.new()
    cam._theta = 0.02  # near lower bound
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_MIDDLE
    press.pressed = true
    press.position = Vector2(100.0, 100.0)
    cam._handle_button(press)
    # Huge downward drag (positive delta.y) would push theta below 0 without clamping
    var motion := InputEventMouseMotion.new()
    motion.position = Vector2(100.0, 20100.0)
    cam._handle_motion(motion)
    return cam._theta >= 0.01
```

---

## THEN-Clause Coverage Map

### REQ-1: JSON Scene Graph Loading

| THEN-clause | Test | Status |
|-------------|------|--------|
| reads the JSON file | `test_file_access_get_as_text_returns_non_empty_string` (FileAccess path) | COVERED |
| generates 3D volumes for each node | `test_volumes_created_for_each_node`, `test_mesh_instances_exist_in_anchors` | COVERED |
| generates connections for each edge | `test_edge_mesh_instances_created` (>=2 MeshInstance3D per edge) | COVERED |
| positions elements per layout data | `test_anchor_positions_match_json` (`position.is_equal_approx(Vector3(...))`) | COVERED |

### REQ-2: Containment Rendering

| THEN-clause | Test | Status |
|-------------|------|--------|
| bounded context: larger translucent volume | `test_bounded_context_is_translucent`, `test_bounded_context_larger_than_module` | COVERED |
| modules: smaller opaque volumes inside parent | `test_module_is_opaque`, `test_module_parented_inside_context` | COVERED |
| boundary visually distinct from children | `test_bounded_context_cull_disabled` (CULL_DISABLED vs default) | COVERED |

### REQ-3: Dependency Rendering

| THEN-clause | Test | Status |
|-------------|------|--------|
| line connects two context volumes | `test_edge_line_mesh_created` (ImmediateMesh MeshInstance3D) | COVERED |
| direction visually indicated | `test_direction_indicator_cone_created` (CylinderMesh top_radius==0.0), `test_direction_cone_near_target` | COVERED |

### REQ-4: Size Encoding

| THEN-clause | Test | Status |
|-------------|------|--------|
| larger LOC → larger volume | `test_large_module_has_bigger_mesh` (BoxMesh.size.x comparison) | COVERED |
| sizes proportional to metric | `test_mesh_sizes_proportional_to_metric` (ratio 9/3=3.0 within 0.001) | COVERED |

### REQ-5: Camera Controls

| THEN-clause | Test | Status |
|-------------|------|--------|
| defaults to top-down view | `test_initial_theta_is_near_top_down` (_theta=0.15 < PI/4) | COVERED |
| camera moves closer on scroll | `test_scroll_up_decreases_distance` | COVERED |
| labels remain readable | `test_labels_are_billboard_and_readable` | COVERED |
| camera rotates around focal point | `test_orbit_horizontal_drag_changes_phi`, `test_orbit_vertical_drag_changes_theta` | COVERED |
| **up stays up (theta clamped)** | **MISSING** — no test drives theta past 0.01 or PI-0.01 boundary | **FAIL** |

### REQ-6: Godot 4.6

| THEN-clause | Test | Status |
|-------------|------|--------|
| uses Godot 4.6.x | `test_project_godot_declares_46_feature`, `test_project_godot_config_features_line` | COVERED |
| all scripts use GDScript | `test_project_does_not_declare_csharp` (absence of "Mono"/"C#" in project.godot) | COVERED |
| API calls valid for Godot 4.6 | `test_file_access_get_as_text_returns_non_empty_string` | COVERED |

---

## Non-Blocking Observations

- **No .hyperloop/state/ files on branch.** Commit 076c5e4 correctly removed them.
- **main.gd _ready() is fully implemented.** FileAccess.open() + get_as_text() +
  JSON.new() + build_from_graph() all present — not a stub.
- **Arrowhead is a concrete rendering element** (CylinderMesh, top_radius=0). The
  "direction is visually indicated" THEN-clause satisfies the guideline requirement for
  an explicit rendering element beyond plain line or colour difference.
- **Assertion predicates match THEN-clauses** for all covered scenarios — real Node3D
  instances are instantiated, `build_from_graph()` is called with fixture data, and
  `.position.x/y/z`, `.size.x`, `albedo_color.a`, `transparency`, `cull_mode`, and
  `billboard` are directly asserted.
- **Commit trailers** (Spec-Ref, Task-Ref) present on all implementation commits.
- **56 tests all pass, 0 failures.** All check scripts pass.

---

## Summary

One blocking finding: the Orbiting scenario THEN-clause "AND orientation remains
intuitive (up stays up)" is implemented via theta clamping to `[0.01, PI-0.01]` in
`camera_controller.gd`, but no test drives theta past the boundary and asserts the
clamped result. The constraint-behavior guideline explicitly names this exact case
("camera theta clamped to prevent flip") as requiring a boundary test.

All other requirements are COVERED with correct predicate assertions.

**Verdict: FAIL**

Fix: add `test_theta_clamped_at_minimum` (and optionally `test_theta_clamped_at_maximum`)
to `godot/tests/test_camera_controls.gd` that applies an extreme orbit drag past the
theta limit and asserts `cam._theta >= 0.01`.