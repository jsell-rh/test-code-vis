---
task_id: task-024
round: 0
role: verifier
verdict: fail
---
## Reviewer: Independent spec-alignment review
## Task: task-024 — UX Polish
## Spec: specs/prototype/ux-polish.spec.md
## Branch: hyperloop/task-024
## Date: 2026-04-24

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## run-all-checks.sh Output (verbatim)

```
=== run-all-checks.sh ===

--- check-branch-adds-source-files.sh ---
OK: Branch adds/modifies 12 source file(s) outside .hyperloop/:
  extractor/extractor.py
  extractor/tests/test_cli.py
  extractor/tests/test_extractor.py
  godot/data/scene_graph.json
  godot/scripts/camera_controller.gd
  godot/scripts/lod_manager.gd
  godot/scripts/main.gd
  godot/tests/run_tests.gd
  godot/tests/test_camera_controls.gd
  godot/tests/test_dependency_rendering.gd
  ... (and 2 more)
[EXIT 0]

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-024' has 83 commit(s) above main.
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present in this worktree
[EXIT 0]

--- check-clamp-boundary-tests.sh ---
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_theta' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_theta' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: All 4 clamped variable(s) have boundary-asserting tests
[EXIT 0]

--- check-compound-then-clause-coverage.sh ---
OK: 'THEN pan movement is smooth and proportional to drag speed' cites 2 test(s) for compound clause.
OK: All 1 compound THEN-clause(s) cite multiple tests.
[EXIT 0]

--- check-coordinator-calls-pipeline.sh ---
SKIP: No pipeline consumer method (apply_spec / render_spec / etc.) found in godot/scripts/.
[EXIT 0]

--- check-desktop-platform-tested.sh ---
INFO: Desktop/native-platform constraint detected in spec(s): specs/prototype/nfr.spec.md
OK: OS.has_feature() test(s) found covering desktop-platform constraint:
  godot/tests/test_desktop_platform.gd
[EXIT 0]

--- check-direction-test-derivations.sh ---
OK: godot/tests/test_camera_controls.gd :: test_orbit_horizontal_drag_changes_phi — derivation comment found.
OK: godot/tests/test_camera_controls.gd :: test_orbit_vertical_drag_changes_theta — derivation comment found.
OK: godot/tests/test_camera_controls.gd :: test_lmb_drag_pans_camera — derivation comment found.
OK: godot/tests/test_camera_controls.gd :: test_pan_direction_not_inverted — derivation comment found.
OK: godot/tests/test_camera_controls.gd :: test_pan_proportional_to_drag_speed — derivation comment found.
OK: godot/tests/test_dependency_rendering.gd :: test_direction_indicator_cone_created — derivation comment found.
OK: godot/tests/test_dependency_rendering.gd :: test_direction_cone_near_target — derivation comment found.
OK: godot/tests/test_scene_graph_loader.gd :: test_edge_direction_preserved_source_to_target — derivation comment found.
OK: All 8 direction/sign-convention test(s) contain derivation comments.
[EXIT 0]

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
OK: No inert bool-returning test functions found in Pattern-1 suites (3 suite(s) checked)
[EXIT 0]

--- check-kartograph-integration-test.sh ---
OK: Integration test referencing kartograph codebase with expected-context assertions found.
[EXIT 0]

--- check-not-in-scope.sh ---
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-pipeline-wiring.sh ---
SKIP: No parse_response / parse_view_spec function found in godot/scripts/.
[EXIT 0]

--- check-reflects-mapping-consistency.sh ---
/home/jsell/code/sandbox/code-vis/worktrees/workers/task-024/.hyperloop/checks/check-reflects-mapping-consistency.sh: line 100: concept_to_test: unbound variable
/home/jsell/code/sandbox/code-vis/worktrees/workers/task-024/.hyperloop/checks/check-reflects-mapping-consistency.sh: line 101: count: unbound variable
[EXIT 1 — FAIL]

--- check-report-scope-section.sh ---
OK: worker-result.yaml contains a valid '## Scope Check Output' section.
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- check-then-test-mapping.sh ---
OK: 'test_lmb_drag_pans_camera' found in codebase
OK: 'test_orbit_around_cursor_point' found in codebase
OK: 'test_orbit_pivot_is_world_point' found in codebase
OK: 'test_orbit_uses_right_mouse_button' found in codebase
OK: 'test_pan_applied_immediately_no_lag' found in codebase
OK: 'test_pan_direction_not_inverted' found in codebase
OK: 'test_pan_proportional_to_drag_speed' found in codebase
OK: 'test_smooth_zoom_process_interpolates_distance' found in codebase
OK: 'test_smooth_zoom_target_differs_from_distance_after_scroll' found in codebase
OK: 'test_zoom_in_cursor_point_invariant' found in codebase
OK: 'test_zoom_in_shifts_pivot_toward_cursor' found in codebase
OK: 'test_zoom_out_shifts_pivot_away_from_cursor' found in codebase
OK: All 12 mapped test function(s) verified in codebase
[EXIT 0]

--- extractor-lint.sh ---
Linting extractor...
All checks passed!
8 files already formatted
Running extractor tests...
94 passed in 0.12s
Extractor checks passed.
[EXIT 0]

--- godot-compile.sh ---
Godot project compiles successfully.
[EXIT 0]

--- godot-fileaccess-tested.sh ---
Found FileAccess.open() in 1 production script file(s).
OK: FileAccess.open() is exercised in 3 test file(s).
[EXIT 0]

--- godot-label3d.sh ---
PASS: All Label3D nodes have billboard and pixel_size set and tested.
[EXIT 0]

--- godot-tests.sh ---
Results: 96 passed, 0 failed
GDScript behavioral tests passed.
[EXIT 0]

=== Summary ===
FAIL: check-reflects-mapping-consistency.sh exited 1
```

---

## Findings

### BLOCKING: check-reflects-mapping-consistency.sh exits 1 (infrastructure bug)

**Finding:** `check-reflects-mapping-consistency.sh` crashes with a bash unbound-variable
error at line 100 (`concept_to_test`) and line 101 (`count`). This is a pre-existing bug in
the check script itself — present on `main` too — not an implementation defect.

**Root cause (two compounding bugs in the check script):**

1. **BRE `\|` alternation bug:** The script uses `grep '^\|'` to filter for markdown table
   rows beginning with `|`. In GNU grep BRE mode, `\|` is the alternation operator, so
   `'^\|'` is parsed as `^` OR (empty string), which matches **every line** — not just lines
   starting with `|`. Confirmed by manual testing: `echo "normal line" | grep '^\|'` prints
   the line (matches).

2. **bash 5.2 `declare -A` + `set -u` bug:** With `set -uo pipefail`, accessing an empty
   associative array with `${#array[@]}` fails with "unbound variable" even when the array
   was declared with `declare -A`. Confirmed: `bash -c 'set -u; declare -A arr; echo
   ${#arr[@]}'` exits 1 in bash 5.2.37.

**How the bug is triggered now:** The embedded `## Check Script Results` section of
`worker-result.yaml` includes the line `--- check-reflects-mapping-consistency.sh ---`.
This line contains the word "reflects". The first grep (`grep -iP '\breflects?\b'`) matches
it. The second grep (`grep '^\|'`) — due to the BRE alternation bug — passes it through
instead of filtering it. The while loop receives this non-table-row and all iterations hit
`continue` (because `then_clause` is empty). `concept_to_test` is declared but never
populated. `${#concept_to_test[@]}` then fails under `set -u`.

**Why this was working before:** The check ran before the full check output was embedded
in `worker-result.yaml`. At that time, `worker-result.yaml` did not yet contain
`--- check-reflects-mapping-consistency.sh ---`, so the first grep found nothing and the
script exited via the SKIP path.

**This is not falsification.** The worker's report shows SKIP (which is what the check
returned at the time of their run). The failure only appears in subsequent runs after the
embedded output is present.

**Fix required (in the check script, not the implementation):**
- Line 41: change `grep '^\|'` to `grep '^|'` (remove the backslash; `|` is literal in
  BRE without backslash, and `^|` anchors to line start followed by literal pipe).
- Line 100: initialize `count` before the while loop or use `${#concept_to_test[@]:-0}`
  to handle the empty-array case safely under `set -u`.

**Classification:** Pre-existing check infrastructure bug, introduced before this task
branch was created. The implementation is not responsible for it. However, per reviewer
protocol ("A FAIL line from any check is blocking"), this remains a blocking FAIL.

---

## THEN-Clause Verification

Independent derivation and test-body verification for all 12 THEN-clauses:

| THEN-Clause | Mapped Test | Predicate Correct? |
|---|---|---|
| Camera pans in direction of drag | test_lmb_drag_pans_camera | YES — asserts `_pivot != initial_pivot` after LMB drag |
| Movement direction not inverted | test_pan_direction_not_inverted | YES — phi=PI/2, drag left (delta.x=-50), asserts `_pivot.x > 0` (correct per Google Maps convention) |
| Scene moves same direction as drag | test_pan_direction_not_inverted | YES — same test, same correct predicate |
| View zooms toward cursor | test_zoom_in_shifts_pivot_toward_cursor | YES — cursor at (10,0,0), zoom in, asserts `_target_pivot.x > 0` |
| Component stays under cursor during zoom | test_zoom_in_cursor_point_invariant | YES — asserts `0 < _target_pivot.x < 20` (geometric invariant) |
| View zooms out from cursor | test_zoom_out_shifts_pivot_away_from_cursor | YES — cursor at (10,0,0), zoom out, asserts `_target_pivot.x < 0` |
| Camera orbits around cursor at start (RMB) | test_orbit_uses_right_mouse_button | YES — RMB press+motion, asserts `_phi != initial_phi` |
| Camera orbits around cursor at start (pivot) | test_orbit_around_cursor_point | YES — asserts `_pivot == world_pt` after begin_orbit_at_world_point |
| Component remains at visual centre | test_orbit_pivot_is_world_point | YES — asserts `_pivot.is_equal_approx(world_pt)` |
| Zoom animated smoothly (target diverges) | test_smooth_zoom_target_differs_from_distance_after_scroll | YES — asserts `_target_distance < _distance` immediately after scroll |
| Zoom animated smoothly (process interpolates) | test_smooth_zoom_process_interpolates_distance | YES — asserts `20 < _distance < 40` after one _process(0.1) frame |
| Pan smooth and proportional to drag speed | test_pan_applied_immediately_no_lag + test_pan_proportional_to_drag_speed | YES — first tests no-lag (pivot==target_pivot), second tests proportionality (larger delta → larger displacement) |

All 12 THEN-clause predicates independently verified against test bodies. No wrong-predicate
mappings found.

**Pan direction sign-convention derivation (independent):**

Spec: "dragging left reveals content to the right (Google Maps)." At phi=PI/2, camera sits
on the +Z side. basis.x = world +X. Drag left means delta.x < 0. Code:
`_target_pivot -= right * delta.x * pan_amount` = `-=(+X)(negative)(positive)` → pivot.x
increases. Camera pivot moves right (+X in world), so left-side content exits screen and
right-side content enters. This matches Google Maps: "dragging left reveals content to the
right." Test asserts `_pivot.x > 0.0` — correct direction. ✓

---

## Implementation Quality

- `camera_controller.gd`: well-structured; clear spherical-coordinate orbit, cursor-aligned
  zoom with ratio-based pivot shift, smooth lerp via `_process()`. Headless-safe.
- `test_camera_controls.gd`: 23 tests, all Pattern-2 (bool-return), no inert tests.
  Derivation comments present on all direction/sign tests.
- Commit trailers present on both implementation commits:
  `Spec-Ref: specs/prototype/ux-polish.spec.md@7392ee4176c1f464f5e7c34a11077a5a93cb7e7f`
  `Task-Ref: task-024`

---

## Verdict

**FAIL** — `check-reflects-mapping-consistency.sh` exits 1 (blocking per protocol).

The failure is caused by two pre-existing bugs in the check script (`grep '^\|'` BRE
alternation matches all lines; `${#declare -A arr[@]}` unbound under bash 5.2 `set -u`).
The implementation itself is correct and complete: all 5 MUST requirements are covered,
all 12 THEN-clauses have correct algorithm-level tests, 96/96 GDScript tests pass,
94/94 Python tests pass.

**Required action:** Fix `check-reflects-mapping-consistency.sh` on `main` (change
`grep '^\|'` → `grep '^|'` and guard the empty-array case) so the check exits 0 (SKIP)
for specs with no "reflects" THEN-clauses.