---
task_id: task-034
round: 0
role: verifier
verdict: fail
---
## Code Review: task-034 — Prototype Scope Specification

Branch: hyperloop/task-034
Reviewer: independent code reviewer
Review date: 2026-04-24

---

## run-all-checks.sh Output

```
=== run-all-checks.sh ===

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-034' has 20 commit(s) above main.
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present in this worktree
[EXIT 0]

--- check-clamp-boundary-tests.sh ---
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_target_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_theta' clamped in camera_controller.gd — boundary assertion found in test_ux_polish.gd
OK: All 4 clamped variable(s) have boundary-asserting tests
[EXIT 0]

--- check-coordinator-calls-pipeline.sh ---
SKIP: No pipeline consumer method (apply_spec / render_spec / etc.) found in godot/scripts/.
[EXIT 0]

--- check-direction-test-derivations.sh ---
OK: All 10 direction/sign-convention test(s) contain derivation comments.
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
OK: No inert bool-returning test functions found in Pattern-1 suites (4 suite(s) checked)
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

--- check-report-scope-section.sh ---
FAIL: .hyperloop/worker-result.yaml is missing a '## Scope Check Output' section header.
      Add a standalone '## Scope Check Output' heading with the verbatim
      stdout of '.hyperloop/checks/check-not-in-scope.sh' beneath it.
      Do NOT summarise the result in a bullet list — paste the raw output.
[EXIT 1 — FAIL]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- extractor-lint.sh ---
Linting extractor...
All checks passed!
9 files already formatted
95 passed in 0.40s
Extractor checks passed.
[EXIT 0]

--- godot-compile.sh ---
Godot project compiles successfully.
[EXIT 0]

--- godot-fileaccess-tested.sh ---
OK: FileAccess.open() is exercised in 2 test file(s).
[EXIT 0]

--- godot-label3d.sh ---
PASS: All Label3D nodes have billboard and pixel_size set and tested.
[EXIT 0]

--- godot-tests.sh ---
Found 11 GDScript test file(s) in godot/tests/.
95 passed, 0 failed.
[EXIT 0]

=== Summary: 20 check(s) run ===
RESULT: 1 FAIL(S) — see above
```

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

---

## Findings

### FAIL: check-report-scope-section.sh — wrong section header in worker-result.yaml

**Severity: Blocking**

The implementer's `worker-result.yaml` contains a section headed `## Scope Check`
but the check script requires the exact header `## Scope Check Output`. Because the
header does not match `^## Scope Check Output`, `check-report-scope-section.sh`
exits 1.

The guidelines state explicitly: *"Reject any submission that omits the '## Scope
Check Output' section. If that section is absent or does not contain the text
'OK: No prohibited', issue a FAIL even if your own scope check passes — the missing
section is evidence the check was not run during implementation."*

The verbatim scope check output IS present in the section body (`OK: No prohibited
(not-in-scope) features detected.`) and `check-scope-report-not-falsified.sh`
passes — so there is no falsification here. The error is purely the section header
spelling.

**Required fix:** In `worker-result.yaml`, rename `## Scope Check` to
`## Scope Check Output` and paste the raw stdout of `check-not-in-scope.sh`
directly under it (not as a bullet list). Re-run `check-report-scope-section.sh`
to confirm exit 0 before resubmitting.

---

## Summary Table

| Check | Result |
|---|---|
| check-branch-has-commits.sh | PASS |
| check-checks-in-sync.sh | PASS |
| check-clamp-boundary-tests.sh | PASS |
| check-coordinator-calls-pipeline.sh | SKIP |
| check-direction-test-derivations.sh | PASS |
| check-end-to-end-integration-test.sh | SKIP |
| check-extractor-cli-tested.sh | PASS |
| check-extractor-stdlib-only.sh | PASS |
| check-gdscript-only-test.sh | PASS |
| check-gdscript-test-bool-return.sh | PASS |
| check-kartograph-integration-test.sh | PASS |
| check-not-in-scope.sh | PASS |
| check-pipeline-wiring.sh | SKIP |
| **check-report-scope-section.sh** | **FAIL** |
| check-scope-report-not-falsified.sh | PASS |
| extractor-lint.sh | PASS |
| godot-compile.sh | PASS |
| godot-fileaccess-tested.sh | PASS |
| godot-label3d.sh | PASS |
| godot-tests.sh | PASS |

---

## Verdict

**FAIL.** 19 of 20 automated checks pass. 95 GDScript tests and 95 Python extractor
tests pass. The implementation is substantively complete and correct.

The single blocking failure is a process defect: the implementer's worker-result.yaml
uses the section header `## Scope Check` instead of the required `## Scope Check Output`.
`check-report-scope-section.sh` exits 1 as a result. Per the review guidelines this is
an automatic FAIL regardless of the underlying check result.

**Resolution is trivial:** rename the section header in worker-result.yaml and resubmit.
No implementation changes are required.

Spec-Ref: specs/prototype/prototype-scope.spec.md
Task-Ref: task-034