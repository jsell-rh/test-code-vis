---
task_id: task-108
round: 1
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-108
Spec: specs/visualization/spatial-structure.spec.md
Branch: hyperloop/task-108

## Summary

FAIL. Two blocking issues:

1. **check-not-in-scope.sh FAIL** — task-108 introduces first-person navigation
   code (`godot/scripts/first_person_camera_controller.gd`,
   `godot/autoload/camera_mode.gd`, `godot/scripts/main.gd`) that is explicitly
   prohibited by `specs/prototype/prototype-scope.spec.md` §"Not In Scope":
   > AND first-person navigation is NOT implemented

   The automated gate confirms this:
   ```
   FAIL: Prohibited first-person navigation code detected (introduced by this branch).
     First-person navigation is explicitly excluded in prototype-scope.spec.md.
     Matched files:
       godot/scripts/first_person_camera_controller.gd
       godot/scripts/main.gd
       godot/autoload/camera_mode.gd
   ```

2. **check-aggregate-edge-impl.sh FAIL** — the codebase contains LOD/visualization
   code but no aggregate-edge implementation exists. The spec requires (Far scenario):
   > cross-context dependencies are shown as single aggregate edges per context pair,
   > with weight indicating total import count
   This contract is entirely unmet.

3. **check-nondirectional-movement-assertions.sh PASS** — all directional tests in
   `test_first_person_navigation.gd` use signed comparisons. No non-directional
   predicates found.

---

## Requirement-by-Requirement Findings

### Requirement: 3D Interactive Navigation (SHALL)

**Scenario: First-person exploration** — PARTIAL (out of prototype scope)

- Code: `godot/scripts/first_person_camera_controller.gd` implements WASD movement,
  mouse-look (yaw/pitch), scroll-speed adjustment, Tab/Esc mode toggle.
  `godot/autoload/camera_mode.gd` implements the mode singleton with
  `enter_first_person()` / `enter_orbital()` and `mode_changed` signal.
  `godot/scripts/camera_controller.gd` gains `_fps_mode` guard to pause orbital
  processing while FPS is active.

- Tests: `godot/tests/test_first_person_navigation.gd` covers:
  - CameraMode initial state (orbital default)
  - `enter_first_person()` / `enter_orbital()` state transitions
  - `mode_changed` signal emission with correct bool value
  - Mouse yaw: drag right → _yaw decreases (signed assertion) ✓
  - Mouse yaw: drag left → _yaw increases (signed assertion) ✓
  - Mouse pitch: drag down → _pitch increases (signed assertion) ✓
  - Mouse pitch: drag up → _pitch decreases (signed assertion) ✓
  - Pitch clamped at ±85° (PITCH_LIMIT boundary) ✓
  - Scroll-up increases _move_speed (signed) ✓
  - Scroll-down decreases _move_speed (signed) ✓
  - Speed clamped at MOVE_SPEED_MAX / MOVE_SPEED_MIN boundaries ✓
  - Orbital camera ignores scroll when `_fps_mode = true` ✓
  - Orbital camera responds to scroll when `_fps_mode = false` ✓
  - Directional sign-chain derivation comments present ✓

- Verdict: Code and tests both exist and are well-formed. BUT the feature is
  explicitly excluded from the prototype by `prototype-scope.spec.md`. The
  `check-not-in-scope.sh` gate exits 1. This task must not implement this feature.

**What is needed:** Remove `godot/scripts/first_person_camera_controller.gd`,
`godot/autoload/camera_mode.gd`, all FPS-related changes from
`godot/scripts/camera_controller.gd`, and the FPS additions in `godot/scripts/main.gd`.
Remove the test file `godot/tests/test_first_person_navigation.gd`. The prototype's
navigation requirement is satisfied by the existing top-down orbital camera.

---

### Requirement: Structure as Persistent Geography (SHALL)

**Scenario: Structural elements have spatial presence** — NOT IN THIS TASK'S SCOPE

This requirement was implemented by earlier tasks (scene graph with bounded-context
volumes and dependency edges). task-108 does not introduce or modify this functionality.
Not failed per guidelines: "Do NOT fail a task for missing features that are out of
prototype scope" — the structural geography rendering is pre-existing.

Status: COVERED (pre-existing, not this task's remit)

---

### Requirement: Scale Through Zoom (SHALL)

**Scenario: Far — bounded context architecture** — MISSING

`check-aggregate-edge-impl.sh` FAILS:

```
FAIL: This branch modifies LOD/visualization code but no aggregate-edge
  implementation was found in godot/scripts/ or godot/autoload/.

  The spec requires (at FAR distance):
    'cross-context dependencies are shown as single aggregate edges per
     context pair, with weight indicating total import count'

  Hiding all individual cross-context edges does NOT satisfy this.
  Required: a script that:
    1. Groups cross-context edges by (source_context, target_context) pair
    2. Sums import counts per pair
    3. Renders one MeshInstance3D / ImmediateMesh line per pair,
       with visual weight proportional to total import count
```

No code groups cross-context edges by (source, target) context pair. No code sums
import counts per pair. No code renders a weighted aggregate line per context pair.

**Scenario: Medium — module structure within contexts** — PARTIAL (pre-existing gap)

`check-lod-opacity-animation.sh` reports a pre-existing gap in `lod_manager.gd`
(binary `.visible` toggle, not opacity animation) but attributes it to the
originating task — not to task-108. Not failed here.

**Scenario: Near — full detail** — NOT IN THIS TASK'S SCOPE (no near-distance
detail rendering introduced by task-108)

**Scenario: Smooth transitions between levels** — NOT IN THIS TASK'S SCOPE

Status: MISSING for the Far/aggregate-edge scenario. Implementer must add an
aggregate-edge grouping and rendering script.

---

### Requirement: Cluster Collapsing (SHALL)

**All four scenarios** — OUT OF PROTOTYPE SCOPE

The prototype-scope.spec.md does not include cluster collapsing. Not failed per
guidelines. No code or tests for collapse/expand/suggestions/nested introduced by
this branch.

Status: OUT OF PROTOTYPE SCOPE — not evaluated

---

## Blocking Issues for Next Round

1. **Remove the first-person navigation implementation.** Files to delete:
   - `godot/scripts/first_person_camera_controller.gd`
   - `godot/autoload/camera_mode.gd`
   - `godot/tests/test_first_person_navigation.gd`
   Revert FPS-related changes in `godot/scripts/camera_controller.gd` (`_fps_mode`
   field, `_on_fps_mode_changed`, `_set_orbit_pivot` guard) and in
   `godot/scripts/main.gd` (CameraMode wiring and FPS controller child).
   Remove "CameraMode" autoload from `godot/project.godot`.
   This is a hard requirement from `prototype-scope.spec.md`.

2. **Implement aggregate-edge rendering for the LOD Far distance.**
   Add a script (e.g. `godot/scripts/aggregate_edge_renderer.gd`) that:
   - Reads the scene graph's cross-context dependency list
   - Groups edges by `(source_context, target_context)` pair
   - Sums import counts per pair
   - Renders one weighted line (MeshInstance3D / ImmediateMesh) per pair
   - Makes individual cross-context edges invisible at FAR distance
   Add a GDScript behavioral test with a known fixture (≥2 contexts, multiple
   cross-context edges between the same pair) that asserts:
   - Exactly one aggregate line is rendered per context pair
   - The line weight/thickness or metadata reflects total import count
   - Individual module-level cross-context edges are not visible