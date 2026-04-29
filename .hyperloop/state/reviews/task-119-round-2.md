---
task_id: task-119
round: 2
role: implementer
verdict: fail
---
## Summary

`run-all-checks.sh` exits non-zero due to one check: `check-retry-not-scope-prohibited.sh`.
This is a systemic check infrastructure issue, not an implementation defect.
All 46 other checks pass. All task-119 requirements are correctly implemented and tested.

---

## Failing Check Analysis

### check-retry-not-scope-prohibited.sh [EXIT 2]

This script is an **orchestrator pre-retry gate** added to main on April 29, 2026
(commit `e772ca85`) to prevent scope-prohibited tasks from being retried. Its design:

- Requires a task ID as `$1`: `TASK_ID="${1:-}"`
- Exits 2 (usage error) when called without arguments
- Is intended for orchestrator invocation: `bash check-retry-not-scope-prohibited.sh task-028`

**The conflict:** `run-all-checks.sh` calls every `*.sh` in `.hyperloop/checks/` via
`bash "$script"` with **no arguments**. Every other check that cannot operate without
arguments handles this by exiting 0 (SKIP) — e.g., `check-fail-report-classification.sh`
outputs "SKIP: no fail-report path provided" and exits 0. This new check exits 2
instead, which `run-all-checks.sh` treats as FAIL.

**When given the task ID, the check passes cleanly:**

```
$ bash .hyperloop/checks/check-retry-not-scope-prohibited.sh task-119
=== CHECK A: spec_ref scope check ===
  Task: task-119  Spec: specs/core/visual-primitives.spec.md
  OK: ... → spec_ref passes scope check.

=== CHECK B: Task body keyword scan ===
  → No prohibited keywords found in task body.

=== CHECK C: Review file classification ===
  SKIP: No review files found for 'task-119'.

RESULT: No scope-prohibition detected for task-119.
EXIT 0 — Retry is permitted.
```

**Root cause:** The check is placed in `.hyperloop/checks/` (picked up by
`run-all-checks.sh`) but requires a positional argument that `run-all-checks.sh`
never provides. The fix is to add a SKIP (exit 0) path when `$1` is empty, matching
the convention used by `check-fail-report-classification.sh`. This fix must be applied
to `main` — an implementer cannot apply it without breaking `check-checks-in-sync.sh`.

---

## Implementation Status (Task-119 Requirements)

All task-119 requirements are complete. The prior cycle FAIL (`Task-Ref: task-061`
on an inherited commit) was resolved by rebasing onto main. The branch now has exactly
two task-119 commits:

- `cec262ca` — chore(checks): sync check scripts from main  (Task-Ref: task-119)
- `9a4c05d7` — feat(schema): document metrics object and extend validator  (Task-Ref: task-119)

### Requirement Coverage

| Requirement | Status |
|---|---|
| Schema: define `metrics` object with `loc` field | COVERED |
| Schema: clarify `size` vs `metrics.loc` distinction | COVERED |
| Schema: worked example with both fields | COVERED |
| Validator: metrics if present must be dict (rule 9) | COVERED |
| Validator: metrics.loc non-negative integer (rule 10) | COVERED |
| Validator: metrics optional | COVERED |
| Validator: additive (no rules removed) | COVERED |
| No extractor logic changes | COVERED |
| Spec LOD tier-0 total LOC downstream consumer | COVERED |

### Checks That Pass (46/47)

- check-branch-forked-from-main: OK
- check-commit-trailer-task-ref: OK (prior cycle FAIL resolved)
- check-spec-ref-valid: OK
- check-spec-ref-staleness: OK (no drift)
- check-pytest-passes: OK (178 tests passed)
- check-godot-no-script-errors: OK (154 GDScript tests passed)
- check-ruff-format: OK
- check-compute-functions-called-from-entry-point: OK
- check-typeddict-fields-extractor-tested: OK
- check-not-in-scope: OK
- check-report-scope-section: OK
- check-tscn-no-dangling-references: OK
- check-checks-in-sync: OK (48 check scripts; content-identical to main)
- All 33 other checks: OK / SKIP (not applicable)

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Recommended Orchestrator Action

Apply the following one-line fix to `main:.hyperloop/checks/check-retry-not-scope-prohibited.sh`
immediately after the `TASK_ID="${1:-}"` line:

```bash
if [ -z "$TASK_ID" ]; then
    echo "SKIP: No task ID provided — this is an orchestrator tool. Run manually:"
    echo "  bash .hyperloop/checks/check-retry-not-scope-prohibited.sh <task-id>"
    exit 0
fi
```

Then re-verify task-119: with this fix, `run-all-checks.sh` would exit 0 and the
implementation passes all gates.