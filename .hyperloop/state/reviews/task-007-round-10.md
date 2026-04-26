---
task_id: task-007
round: 10
role: verifier
verdict: fail
---
Code review of task-007: Godot Application spec
(specs/prototype/godot-application.spec.md)
Date: 2026-04-25

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

## Check Script Results

run-all-checks.sh synced from main (32 scripts, one new: check-not-on-main.sh).

--- check-branch-adds-source-files.sh ---
OK: Branch adds/modifies 12 source file(s) outside .hyperloop/:
  extractor/extractor.py, extractor/tests/test_extractor.py,
  godot/data/scene_graph.json, godot/scripts/camera_controller.gd,
  godot/scripts/main.gd, godot/tests/run_tests.gd,
  godot/tests/test_camera_controls.gd, godot/tests/test_dependency_rendering.gd,
  godot/tests/test_engine_version.gd, godot/tests/test_scene_graph_loader.gd,
  ... (and 2 more)
[EXIT 0]

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-007' has 4 commit(s) above main.
[EXIT 0]

--- check-checkpoint-commit.sh ---
OK: Checkpoint commit found — 'chore: begin task-007'
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present in this worktree
[EXIT 0]

--- check-clamp-boundary-tests.sh ---
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_theta' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: All 2 clamped variable(s) have boundary-asserting tests
[EXIT 0]

--- check-compound-coverage-not-falsified.sh ---
OK: check-compound-then-clause-coverage.sh exits 0 — no cross-validation needed.
[EXIT 0]

--- check-compound-then-clause-coverage.sh ---
SKIP: No compound THEN-clauses (containing 'and') found in THEN→test mapping.
[EXIT 0]

--- check-coordinator-calls-pipeline.sh ---
SKIP: No pipeline consumer method (apply_spec / render_spec / etc.) found in godot/scripts/.
[EXIT 0]

--- check-desktop-platform-tested.sh ---
INFO: Desktop/native-platform constraint detected in spec(s):
  specs/prototype/nfr.spec.md
OK: OS.has_feature() test(s) found covering desktop-platform constraint:
  godot/tests/test_desktop_platform.gd
  godot/tests/test_engine_version.gd
[EXIT 0]

--- check-direction-test-derivations.sh ---
OK: godot/tests/test_camera_controls.gd :: test_orbit_horizontal_drag_changes_phi — derivation comment found.
OK: godot/tests/test_camera_controls.gd :: test_orbit_vertical_drag_changes_theta — derivation comment found.
FAIL: godot/tests/test_camera_controls.gd :: test_zoom_toward_point_moves_pivot_toward_target — direction/sign-convention test is missing a
      sign-chain derivation comment (must contain '→' or '->' showing
      how the spec's behavioral reference maps to the expected predicate).
      Add a comment like:
        # drag left → delta.x < 0 → × right_vec × minus sign → pivot.x increases ✓
OK: godot/tests/test_dependency_rendering.gd :: test_direction_indicator_cone_created — derivation comment found.
OK: godot/tests/test_dependency_rendering.gd :: test_direction_cone_near_target — derivation comment found.
OK: godot/tests/test_scene_graph_loader.gd :: test_edge_direction_preserved_source_to_target — derivation comment found.
OK: godot/tests/test_system_purpose.gd :: test_dependency_direction_is_encoded_in_edges — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_right_decreases_pivot_x — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_left_increases_pivot_x — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_drag_direction_matches_view_movement — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_down_decreases_pivot_z — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_up_increases_pivot_z — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_zoom_toward_cursor_shifts_pivot_toward_cursor — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_proportional_to_drag_speed — derivation comment found.

FAIL: 1 direction test(s) lack a sign-chain derivation comment.
[EXIT 1 — FAIL]

--- check-end-to-end-integration-test.sh ---
SKIP: Both a pipeline producer and consumer must exist for this check to apply.
[EXIT 0]

--- check-extractor-cli-tested.sh ---
OK: A test calls main() from the extractor CLI entry point.
[EXIT 0]

--- check-extractor-stdlib-only.sh ---
OK: A test using sys.stdlib_module_names to verify stdlib-only imports found.
[EXIT 0]

--- check-gdscript-only-test.sh ---
OK: DirAccess iteration test found — 'all scripts use GDScript' constraint is exercised
[EXIT 0]

--- check-gdscript-test-bool-return.sh ---
OK: No inert bool-returning test functions found in Pattern-1 suites (8 suite(s) checked)
[EXIT 0]

--- check-kartograph-integration-test.sh ---
OK: Integration test referencing kartograph codebase with expected-context assertions found.
[EXIT 0]

--- check-no-state-files-committed.sh ---
FAIL: Branch commits include .hyperloop/state/ files managed by the orchestrator.

      These files conflict with the orchestrator's own state on main and
      will cause permanent rebase failures, forcing a branch reset.

      State files committed on this branch:
  .hyperloop/state/intake-2026-04-25.md

      To confirm: run 'git log main..HEAD --oneline -- <file>' for each
      listed file and verify a commit on this branch introduced it.

      Remove them from the branch history:
        git filter-branch --index-filter \
          'git rm --cached --ignore-unmatch .hyperloop/state/*' HEAD
      OR cherry-pick only non-state commits onto a fresh branch.

      Prevention: never use 'git add -A' or 'git add .'. Stage only
      source files and .hyperloop/worker-result.yaml explicitly.
[EXIT 1 — FAIL]

--- check-not-in-scope.sh ---
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-not-on-main.sh ---
OK: Current branch is 'hyperloop/task-007' (not main)
[EXIT 0]

--- check-pan-grab-model-comments.sh ---
OK: All 5 pan/drag direction test(s) contain user-visible-outcome derivation language.
[EXIT 0]

--- check-pipeline-wiring.sh ---
SKIP: No parse_response / parse_view_spec function found in godot/scripts/.
[EXIT 0]

--- check-reflects-mapping-consistency.sh ---
SKIP: No 'reflect(s)' THEN-clauses found in mapping table.
[EXIT 0]

--- check-report-scope-section.sh ---
[checked against this file — see Scope Check Output section above]
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- check-then-test-mapping.sh ---
SKIP: No test function references found in .hyperloop/worker-result.yaml THEN→test mapping.
[EXIT 0]

--- extractor-lint.sh ---
All checks passed!
8 files already formatted
Running extractor tests...
97 passed in 0.44s
[EXIT 0]

--- godot-compile.sh ---
Godot Engine v4.6.2.stable.official.71f334935
Godot project compiles successfully.
[EXIT 0]

--- godot-fileaccess-tested.sh ---
Found FileAccess.open() in 1 production script file(s).
OK: FileAccess.open() is exercised in 4 test file(s).
[EXIT 0]

--- godot-label3d.sh ---
PASS: All Label3D nodes have billboard and pixel_size set and tested.
[EXIT 0]

--- godot-tests.sh ---
Found 16 GDScript test file(s) in godot/tests/.
All GDScript tests pass (74 pass, 0 fail).
GDScript behavioral tests passed.
[EXIT 0]

=== Summary: 31 check(s) run ===
RESULT: FAIL — one or more checks exited non-zero
MASTER EXIT: 1

## THEN→Test Mapping

Independent reviewer mapping (constructed from reading source files):

| THEN-clause | Test function(s) | File | Status |
|---|---|---|---|
| THEN it reads the JSON file | `test_file_access_reads_fixture_json` | test_scene_graph_loading.gd | COVERED |
| AND generates 3D volumes for each node | `test_volumes_created_for_each_node`, `test_mesh_instances_exist_in_anchors` | test_scene_graph_loading.gd | COVERED |
| AND generates connections for each edge | `test_edge_mesh_instances_created`, `test_edge_line_mesh_created` | test_scene_graph_loading.gd, test_dependency_rendering.gd | COVERED |
| AND positions elements according to the layout data | `test_anchor_positions_match_json`, `test_volumes_positioned_from_json` | test_scene_graph_loading.gd | COVERED |
| THEN the bounded context appears as a larger translucent volume | `test_bounded_context_is_translucent`, `test_bounded_context_larger_than_module` | test_containment_rendering.gd | COVERED |
| AND its child modules appear as smaller opaque volumes inside it | `test_module_is_opaque`, `test_module_parented_inside_context` | test_containment_rendering.gd | COVERED |
| AND the boundary of the parent is visually distinct from the children | `test_bounded_context_cull_disabled`, `test_bounded_context_is_translucent` | test_containment_rendering.gd | COVERED |
| THEN a line connects the two context volumes | `test_edge_line_mesh_created` | test_dependency_rendering.gd | COVERED |
| AND the line's direction is visually indicated | `test_direction_indicator_cone_created`, `test_direction_cone_near_target` | test_dependency_rendering.gd | COVERED |
| THEN the module with more code appears as a larger volume | `test_large_module_has_bigger_mesh` | test_size_encoding.gd | COVERED |
| AND the relative sizes are proportional to the metric | `test_mesh_sizes_proportional_to_metric` | test_size_encoding.gd | COVERED |
| THEN the camera defaults to a top-down view showing the entire system | `test_initial_theta_is_near_top_down`, `test_initial_camera_is_above_pivot` | test_camera_controls.gd | COVERED |
| THEN the camera moves closer | `test_scroll_up_decreases_distance` | test_camera_controls.gd | COVERED |
| AND internal structure becomes visible as the camera approaches | `test_medium_distance_shows_modules`, `test_far_distance_shows_only_bounded_contexts` | test_spatial_structure.gd | COVERED |
| AND labels scale to remain readable | `test_labels_are_billboard_and_readable` | test_scene_graph_loading.gd | COVERED |
| THEN the camera rotates around the current focal point | `test_orbit_horizontal_drag_changes_phi`, `test_orbit_vertical_drag_changes_theta` | test_camera_controls.gd | COVERED |
| AND orientation remains intuitive (up stays up) | `test_theta_clamped_at_minimum_to_prevent_flip`, `test_theta_clamped_at_maximum_to_prevent_flip` | test_camera_controls.gd | COVERED |
| THEN it uses Godot 4.6.x | `test_project_godot_version`, `test_project_uses_godot_4_6` | test_engine_version.gd | COVERED |
| AND all scripts use GDScript | `test_all_scripts_are_gdscript`, `test_scripts_dir_contains_only_gdscript` | test_engine_version.gd | COVERED |
| AND all API calls are valid for the Godot 4.6 API | `test_file_access_get_as_text_is_usable`, `test_file_access_reads_file` | test_engine_version.gd | COVERED |

## Commit Trailer Verification

- `Spec-Ref: specs/prototype/godot-application.spec.md@3e5e297e216c7876224564ee099a38334e3dbd55` ✓
- `Task-Ref: task-007` ✓
Present in all 3 implementation commits.

## Implementation Assessment

**main.gd**: Fully implemented. `_ready()` reads JSON via `FileAccess.open()` +
`get_as_text()`, parses via `JSON.new()`, delegates to `SceneGraphLoader.load_from_dict()`,
then calls `build_from_graph()`. Not a stub.

**All 20 THEN-clauses**: Have real behavioral test coverage with fixture data and
property assertions. 74 GDScript tests all pass. 97 Python tests all pass.

## Findings

### F1 — FAIL: check-direction-test-derivations.sh exits 1 (BLOCKING)

`test_zoom_toward_point_moves_pivot_toward_target` in `godot/tests/test_camera_controls.gd`
(line 181) has its sign-chain derivation in the GDScript docstring (## lines) PRECEDING
the `func` declaration, not inside the function body. The check script uses awk to extract
lines AFTER the `func` line and greps those for `→` or `->`. Since the arrows are in
the docstring above, the check does not find them.

**Fix**: Move (or duplicate) the derivation comment inside the function body as an
inline `#` comment before the assertions. Example:
```
func test_zoom_toward_point_moves_pivot_toward_target() -> bool:
    # Sign-chain: call set_pivot(target, dist) → _pivot = target → distance = dist ✓
    var cam = CameraScript.new()
    ...
```

This is a purely mechanical fix — the derivation reasoning is correct, just placed in
the wrong location for the check script to find.

### F2 — FAIL: check-no-state-files-committed.sh exits 1 (BLOCKING)

Commit `032589eb feat(tests): add spec-named test aliases and expand coverage for task-007`
introduced `.hyperloop/state/intake-2026-04-25.md` to the branch. Confirmed via:
```
git log main..HEAD --oneline -- .hyperloop/state/intake-2026-04-25.md
032589eb feat(tests): add spec-named test aliases and expand coverage for task-007
```

The commit message says the author intended to "sync .hyperloop/state/intake-2026-04-25.md
from main to eliminate the state-file diff" — but this is the opposite of the fix.
Committing state files on a worker branch causes rebase conflicts when the orchestrator
updates those files on main. The correct fix is to NEVER commit state files; use
`git add` on specific files only (never `git add -A` or `git add .`).

**Fix**: Remove the state file from the branch history using `git filter-branch` or
by cherry-picking only the non-state commits onto a clean branch.

### Note: Implementer's worker-result.yaml was deleted by orchestrator

The prior `worker-result.yaml` was deleted by the orchestrator's "clean worker verdict"
commit (`5dc5be61`). Content recovered via `git show 6616194e:.hyperloop/worker-result.yaml`.
The recovered file's scope section contained "OK: No prohibited" — scope check was run
correctly during implementation.

### Note: Checks synced from main added check-not-on-main.sh

One new check (`check-not-on-main.sh`) was present on main but absent from the worktree
before sync. This is NOT a process violation by the implementer (the check was added
after branch creation). However, the check now passes (branch is 'hyperloop/task-007').

## Verdict: FAIL

Two blocking check failures prevent acceptance:
1. **F1** `check-direction-test-derivations.sh` EXIT 1 — derivation comment in docstring
   instead of function body for `test_zoom_toward_point_moves_pivot_toward_target`
2. **F2** `check-no-state-files-committed.sh` EXIT 1 — `.hyperloop/state/intake-2026-04-25.md`
   committed in task-007 commit `032589eb`

The underlying implementation is correct and complete: `main.gd` is fully implemented,
all 20 THEN-clauses have real behavioral test coverage, 74 GDScript tests and 97 Python
tests all pass, and scope is clean. Both failures are fixable without changing the
production implementation.