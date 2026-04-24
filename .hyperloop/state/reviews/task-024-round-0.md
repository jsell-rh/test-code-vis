---
task_id: task-024
round: 0
role: verifier
verdict: fail
---
## Code Reviewer Verdict — task-024 (UX Polish)

Branch: hyperloop/task-024
Reviewer action: synced `.hyperloop/checks/` from main before running master runner.

---

## run-all-checks.sh Output (verbatim, after sync from main)

```
=== run-all-checks.sh ===

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-024' has 24 commit(s) above main.
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

--- check-extractor-cli-tested.sh ---
FAIL: No test exercises the CLI entry point (main() in extractor/__main__.py).
  Required: a pytest test in extractor/tests/ that calls:
    from extractor.__main__ import main
    rc = main([str(src_path), '--output', str(out)])
    assert rc == 0
    assert out.exists()
  OR a subprocess invocation: subprocess.run(['python', '-m', 'extractor', ...], check=True)
  A THEN-clause 'runs as a standalone CLI tool' is PARTIAL until this test exists.
[EXIT 1 — FAIL]

--- check-extractor-stdlib-only.sh ---
FAIL: No test verifies the 'stdlib-only' constraint for the extractor.
  Required: a pytest test that inspects extractor imports and asserts all
  are from the standard library, e.g.:
    import sys, ast, pathlib
    import extractor  # triggers all imports
    # parse all .py files in extractor/ with ast, collect Import/ImportFrom names
    # assert each name in sys.stdlib_module_names or is the extractor package itself
  A THEN-clause 'requires no dependencies beyond stdlib' is PARTIAL until this test exists.
[EXIT 1 — FAIL]

--- check-gdscript-only-test.sh ---
OK: DirAccess iteration test found — 'all scripts use GDScript' constraint is exercised
[EXIT 0]

--- check-kartograph-integration-test.sh ---
OK: Integration test referencing kartograph codebase with expected-context assertions found.
[EXIT 0]

--- check-not-in-scope.sh ---
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-pipeline-wiring.sh ---
SKIP: No parse_response / parse_view_spec function found in godot/scripts/.
      This check only applies to tasks that implement the LLM→view-spec pipeline.
[EXIT 0]

--- check-report-scope-section.sh ---
OK: worker-result.yaml contains a valid '## Scope Check Output' section.
[EXIT 0]

--- extractor-lint.sh ---
Linting extractor...
All checks passed!
7 files already formatted
Running extractor tests...
90 passed in 0.13s
Extractor checks passed.
[EXIT 0]

--- godot-compile.sh ---
Compiling Godot project...
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org
Godot project compiles successfully.
[EXIT 0]

--- godot-fileaccess-tested.sh ---
Found FileAccess.open() in 1 production script file(s).
OK: FileAccess.open() is exercised in 2 test file(s).
[EXIT 0]

--- godot-label3d.sh ---
PASS: All Label3D nodes have billboard and pixel_size set and tested.
[EXIT 0]

--- godot-tests.sh ---
Found 10 GDScript test file(s) in godot/tests/.
Running custom headless test runner...
=== code-vis GDScript Tests ===
Results: 91 passed, 0 failed
GDScript behavioral tests passed.
[EXIT 0]

=== Summary: 15 check(s) run ===
RESULT: 2 FAIL(s)
```

---

## Findings

### FINDING 1 — BLOCKING FAIL: check-extractor-cli-tested.sh exits 1

`check-extractor-cli-tested.sh` was added to main after the branch was created. After syncing
checks from main (required by guidelines), it exits 1.

Confirmed independently: `extractor/tests/test_extractor.py` and `extractor/tests/test_schema.py`
contain no call to `main()`, no import of `extractor.__main__`, and no subprocess invocation of
`python -m extractor`. The `extractor/__main__.py` CLI entry point is exercised in production but
has no test.

**Fix required:** Add a pytest test in `extractor/tests/` that either:
  - calls `from extractor.__main__ import main; rc = main([str(src_path), '--output', str(out)]); assert rc == 0; assert out.exists()`, OR
  - uses `subprocess.run(['python', '-m', 'extractor', str(src_path), '--output', str(out)], check=True)` and asserts the output file contains valid JSON.

### FINDING 2 — BLOCKING FAIL: check-extractor-stdlib-only.sh exits 1

`check-extractor-stdlib-only.sh` was also added to main after the branch was created. It exits 1.

Confirmed independently: `grep -r "stdlib_module_names" extractor/tests/` returns no matches.
No test inspects extractor imports and asserts they are stdlib-only.

**Fix required:** Add a pytest test that parses all `.py` files in `extractor/` with `ast`,
collects all `Import` and `ImportFrom` module names, and asserts each is in
`sys.stdlib_module_names` (or is the extractor package itself).

### Process Note: Two check scripts absent from worktree before sync

`check-extractor-cli-tested.sh` and `check-extractor-stdlib-only.sh` were absent from the
worktree before I ran `git checkout main -- .hyperloop/checks/`. The implementer's
`check-checks-in-sync.sh` passed at submission time, which means these two scripts were added
to main AFTER the branch was committed. This is not a process violation by the implementer;
the scripts were not available for them to sync. However, per guidelines, both FAILs are
blocking regardless of when the checks were added.

---

## UX Polish Spec — THEN→Test Mapping (all PASS)

All UX Polish requirements are correctly implemented and tested. The FAIL verdict is solely
due to the extractor checks added to main after branch creation.

| # | THEN-clause | Test function | Assertion | Status |
|---|---|---|---|---|
| 1 | Camera pans in drag direction (LMB) | `test_lmb_drag_pans_camera` | `cam._pivot != initial_pivot` | PASS ✓ |
| 2 | Movement non-inverted (rightward drag → +X pivot) | `test_pan_direction_not_inverted` | `cam._pivot.x > 0.0` after +50px X drag | PASS ✓ |
| 3 | Scene moves same direction as drag (Google Maps) | `test_pan_direction_not_inverted` | Same test; covers both Scenario 1 + 2 THEN | PASS ✓ |
| 4 | View zooms toward point under cursor | `test_zoom_in_shifts_pivot_toward_cursor` | `cam._target_pivot.x > 0.0` (cursor at x=10) | PASS ✓ |
| 5 | Cursor component stays under cursor during zoom | `test_zoom_in_cursor_point_invariant` | `0 < pivot.x < 20` (cursor at x=20) | PASS ✓ |
| 6 | View zooms out from point under cursor | `test_zoom_out_shifts_pivot_away_from_cursor` | `cam._target_pivot.x < 0.0` (cursor at x=10) | PASS ✓ |
| 7 | Camera orbits around point under cursor at orbit start | `test_orbit_around_cursor_point` | `cam._pivot == world_pt` | PASS ✓ |
| 8 | Component remains at visual center during orbit | `test_orbit_pivot_is_world_point` | `cam._pivot.is_equal_approx(world_pt)` | PASS ✓ |
| 9 | Zoom animated smoothly (not instantaneous) | `test_smooth_zoom_target_differs_from_distance_after_scroll` | `cam._target_distance < cam._distance` after scroll | PASS ✓ |
| 9b | Zoom interpolates via _process() | `test_smooth_zoom_process_interpolates_distance` | `20 < _distance < 40` after _process(0.1) | PASS ✓ |
| 10 | Pan smooth and proportional to drag speed | `test_pan_proportional_to_drag_speed` | 50px drag > 10px drag displacement | PASS ✓ |

All 10 function names grepped against `godot/tests/test_camera_controls.gd` — all confirmed present.
All assertion predicates match their THEN-clause predicates (read from actual test bodies).

### Commit Trailers
PASS — `Spec-Ref: specs/prototype/ux-polish.spec.md@7392ee4176c1f464f5e7c34a11077a5a93cb7e7f`
and `Task-Ref: task-024` present on implementation commit.

### Scope Check
PASS — `check-not-in-scope.sh` exits 0. No prohibited features in code or tests.

### Clamp Boundary Tests
PASS — `check-clamp-boundary-tests.sh` exits 0. All 4 clamped variable instances have
boundary-driving tests: `test_set_pivot_clamps_distance_at_minimum`, `test_theta_clamped_at_minimum`,
`test_theta_clamped_at_maximum`, `test_zoom_clamped_at_minimum`.

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Summary

FAIL. Two check scripts added to main after branch creation now fail on this branch:

1. **check-extractor-cli-tested.sh** — no pytest test calls the `main()` CLI entry point or
   invokes `python -m extractor` via subprocess. The extractor CLI is untested.
2. **check-extractor-stdlib-only.sh** — no test uses `sys.stdlib_module_names` to verify the
   stdlib-only constraint mechanically.

The UX Polish spec implementation is complete and correct: all 7 scenarios are covered by named
tests with correct assertion predicates, all GDScript tests pass (91/91), the camera controller
correctly implements LMB pan (non-inverted), scroll-wheel zoom toward cursor, RMB orbit around
cursor world point, and smooth interpolated movement.

The extractor CLI and stdlib-only tests must be added before this branch can merge.