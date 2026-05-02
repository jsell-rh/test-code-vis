---
task_id: task-013
round: 0
role: verifier
verdict: fail
---
## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

## Check Sync

```
OK: All check scripts from main are present and content-identical in working tree (60 checked).
```

## Rebase Check

```
FAIL: Branch 'hyperloop/task-013' is NOT rebased onto origin/main.

  Fork point (merge-base): c39079c
  origin/main HEAD:        802c819
  Commits on main not in branch: 3

  RISK: Merging this branch as-is would REVERT all 3 commit(s)
  that main added after c39079c.
```

The 3 missing main commits are:
- `802c8191 process: extend push-main mandate to intake sessions`
- `5d785278 process: clarify check-sync ≠ rebase, mandate rebase check after every sync`
- `031e6730 chore(intake): sixteenth PM pass — 3 new tasks from modified specs`

All 3 are `.hyperloop/`-only changes (process docs and task state files). They do not
touch any implementation files, test files, or check scripts. No conflicts are expected
during rebase.

Per protocol, check-rebased-onto-main.sh exiting non-zero requires an immediate FAIL.

## Run-All-Checks Output Summary

```
=== Summary: 59 check(s) run ===
RESULT: FAIL — one or more checks exited non-zero
```

All 59 checks ran. The only EXIT 1 is check-rebased-onto-main.sh (above).
All other 58 checks exit 0, including:

| Check | Result |
|---|---|
| check-aggregate-edge-impl.sh | EXIT 0 (not applicable) |
| check-assigned-spec-in-scope.sh | EXIT 0 (SKIP — orchestrator gate) |
| check-branch-forked-from-main.sh | EXIT 0 |
| check-branch-has-commits.sh | EXIT 0 — 6 commits above main |
| check-branch-has-impl-files.sh | EXIT 0 — 2 non-.hyperloop/ files changed |
| check-checks-in-sync.sh | EXIT 0 — 60 scripts in sync |
| check-circular-position-y-axis.sh | EXIT 0 |
| check-clamp-boundary-tests.sh | EXIT 0 — all 4 clamped vars have boundary tests |
| check-commit-trailer-task-ref.sh | EXIT 0 — task-013 matches |
| check-compute-functions-called-from-entry-point.sh | EXIT 0 — all 7 compute_*() called |
| check-cycle-gate.sh | EXIT 0 |
| check-directional-signchain-comments.sh | EXIT 0 |
| check-extractor-cli-tested.sh | EXIT 0 |
| check-extractor-stdlib-only.sh | EXIT 0 |
| check-gdscript-only-test.sh | EXIT 0 |
| check-godot-no-script-errors.sh | EXIT 0 (Godot warnings are leak warnings, not parse errors) |
| check-kartograph-integration-test.sh | EXIT 0 |
| check-lod-level-tests.sh | EXIT 0 (not applicable) |
| check-lod-opacity-animation.sh | EXIT 0 (not applicable) |
| check-main-local-vs-remote.sh | EXIT 0 (synced after fetch) |
| check-no-gdscript-duplicate-functions.sh | EXIT 0 |
| check-nondirectional-movement-assertions.sh | EXIT 0 |
| check-not-in-scope.sh | EXIT 0 |
| check-no-zero-commit-reattempt.sh | EXIT 0 (SKIP — no prior FAIL) |
| check-pass-report-no-raw-fail-lines.sh | EXIT 0 |
| check-pytest-passes.sh | EXIT 0 — 204 passed, 0 failed |
| check-racf-prior-cycle.sh | EXIT 0 (SKIP — no prior FAIL) |
| check-rebased-onto-main.sh | EXIT 1 — FAIL (see above) |
| check-ruff-format.sh | EXIT 0 |
| check-run-tests-suite-count.sh | EXIT 0 — branch 20 ≥ origin/main 19 |
| check-spec-ref-staleness.sh | EXIT 0 — no drift for task-013 commit |
| check-tscn-no-dangling-references.sh | EXIT 0 |
| check-typeddict-fields-extractor-tested.sh | EXIT 0 |
| godot-compile.sh | EXIT 0 — Godot 4.6.2.stable compiles cleanly |
| godot-fileaccess-tested.sh | EXIT 0 |
| godot-label3d.sh | EXIT 0 |
| godot-tests.sh | EXIT 0 — 195 passed, 0 failed |
| extractor-lint.sh | EXIT 0 — ruff clean |

## Spec-Drift Analysis

check-spec-ref-staleness.sh reports:
- `OK (no drift)` for Spec-Ref `2e37f945` (the task-013 implementation commit)
- SPEC-DRIFT for Spec-Ref `5941b0f3` (the prior verifier commit at 015c392e — not this round's work)

The task-013 implementation commit (`afc58b1f`) uses Spec-Ref `2e37f945`, which is
content-identical to HEAD. No spec drift applies to this implementation round.

The spec the implementer worked against already includes the "Godot 4.6" requirement
with the FileAccess API requirement. No requirements are SPEC-DRIFT.

## Commit Trailers

Implementation commit `afc58b1f`:
- `Spec-Ref: specs/prototype/godot-application.spec.md@2e37f945fe1fa9f27d2b1d46b4eea625cb89038e` ✓
- `Task-Ref: task-013` ✓

Both required trailers are present and correct.

## Implementation Quality

**Branch adds:**
- `godot/tests/test_godot_app_spec.gd` — 15 new integration test functions
- `godot/tests/run_tests.gd` — registers the new suite

**Test execution: 195 GDScript tests passed, 0 failed (up from 180 before this commit).**

### Onready Null-Guard — HANDLED CORRECTLY

`main.gd::_frame_camera()` guards on `if _world_positions.is_empty() or _camera == null: return`.
The test `test_camera_frames_entire_system` injects a real `CameraScript` instance via
`main_node.set("_camera", cam)` before calling `build_from_graph()`, bypassing the null-guard.
The test then asserts:
- `cam._pivot.x` ≈ 10 (centre of nodes at x=0 and x=20) — signed spatial value
- `cam._distance > 0`
- `cam._theta < PI / 4` (top-down orientation)

This follows the onready-null-guard guideline exactly.

### Requirement Coverage (vs committed spec at Spec-Ref 2e37f945)

| Requirement | THEN-clause | Test | Status |
|---|---|---|---|
| R1 JSON Loading | reads JSON file | test_main_uses_godot46_fileaccess_api (asserts FileAccess.open + get_as_text in main.gd) | COVERED |
| R1 JSON Loading | generates 3D volumes | test_reads_json_and_builds_volumes | COVERED |
| R1 JSON Loading | generates connections for edges | test_edge_connections_created | COVERED |
| R1 JSON Loading | positions from JSON | test_positions_set_from_json | COVERED |
| R2 Containment | bounded context is translucent volume | test_bounded_context_is_translucent_volume | COVERED |
| R2 Containment | modules opaque and inside context | test_modules_are_opaque_and_inside_context | COVERED |
| R2 Containment | boundary visually distinct | existing test_containment_rendering.gd (cull_mode=CULL_DISABLED) | COVERED |
| R3 Dependency | line connects volumes | test_cross_context_line_created (ImmediateMesh) | COVERED |
| R3 Dependency | direction visually indicated | test_direction_cone_at_target (CylinderMesh top_radius=0 arrowhead) | COVERED |
| R4 Size Encoding | larger volume for more code | test_size_proportional_to_metric | COVERED |
| R4 Size Encoding | sizes proportional to metric | test_size_proportional_to_metric (ratio within 0.001) | COVERED |
| R5 Camera Top-down | top-down view showing entire system | test_camera_frames_entire_system (injection; asserts pivot.x≈10, distance>0, theta<PI/4) | COVERED |
| R5 Camera Zoom | camera moves closer | test_scroll_zoom_changes_distance | COVERED |
| R5 Camera Zoom | internal structure visible approaching | existing test_camera_controls.gd + test_spatial_structure.gd (LOD integration) | COVERED |
| R5 Camera Zoom | labels scale readable | existing test_scene_graph_loading.gd::test_labels_are_billboard_and_readable | COVERED |
| R5 Camera Orbit | camera rotates around focal point | test_orbit_changes_phi_and_theta | COVERED |
| R5 Camera Orbit | orientation intuitive (up stays up) | test_orbit_theta_clamped_prevents_pole_flip | COVERED |
| R6 Godot 4.6 | project declares 4.6.x | test_project_declares_godot_46 | COVERED |
| R6 Godot 4.6 | all scripts GDScript | test_all_scripts_are_gdscript | COVERED |
| R6 Godot 4.6 | all API calls valid for 4.6 | test_main_uses_godot46_fileaccess_api | COVERED |

All 20 THEN-clauses are COVERED.

### Minor Documentation Inconsistency (not a FAIL driver)

The test file's header comment lists two function names that do not match the actual
function names in the file:
- Listed: `test_initial_theta_near_top_down` — does not exist; the actual function is
  `test_camera_frames_entire_system` which covers this THEN-clause fully (theta < PI/4)
- Listed: `test_fileaccess_get_as_text_works` — does not exist; the actual function is
  `test_main_uses_godot46_fileaccess_api` which covers this THEN-clause

Both THEN-clauses have genuine test coverage from correctly-named functions that actually
exist and passed. The stale names in the comment header are documentation noise; they
do not indicate fabricated coverage — the tests are real and ran in the 195-test suite.

## Verdict

FAIL — check-rebased-onto-main.sh exits non-zero.

**Fix required (trivial — no implementation changes needed):**

```bash
git fetch origin main:main
git rebase origin/main
```

No conflicts are expected. The 3 new main commits are:
1. `802c8191 process: extend push-main mandate to intake sessions`
2. `5d785278 process: clarify check-sync ≠ rebase, mandate rebase check after every sync`
3. `031e6730 chore(intake): sixteenth PM pass — 3 new tasks from modified specs`

All 3 touch only `.hyperloop/agents/process/` and `.hyperloop/state/tasks/` — files this
branch does not touch. After rebase, all checks should pass.

Suggested commit message after rebase:
```
chore(task-013): rebase onto origin/main (process-only commits)

Rebase onto 802c819 to pick up 3 process/intake commits added to main
after implementation. No implementation changes — rebase has no conflicts.

Task-Ref: task-013
```