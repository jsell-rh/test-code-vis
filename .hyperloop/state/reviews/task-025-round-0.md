---
task_id: task-025
round: 0
role: verifier
verdict: fail
---
# Task-025 Review — Port Primitive & Tint Primitive

## Mandatory Pre-Review Steps

### Check Sync
```
OK: All check scripts from main are present and content-identical in working tree (61 checked).
```

### Scope Check Output
```
OK: No prohibited (not-in-scope) features detected.
```

### Rebase Check (MANDATORY — FAIL TRIGGER)
```
FAIL: Branch 'hyperloop/task-025' is NOT rebased onto origin/main.

  Fork point (merge-base): 45a4dca
  origin/main HEAD:        61c9117
  Commits on main not in branch: 1

  RISK: Merging this branch as-is would REVERT all 1 commit(s)
  that main added after 45a4dca. Inspect what would be lost:
    git log 45a4dca..origin/main --oneline

  Fix:
    git fetch origin main:main
    git rebase origin/main
    # During conflict resolution:
    #   KEEP all functions/files main added (the incoming 'theirs' side).
    #   Apply your changes ON TOP — never choose 'ours' to discard main work.
    # After rebase completes:
    bash .hyperloop/checks/check-run-tests-suite-count.sh   # guard against suite regression
    bash .hyperloop/checks/run-all-checks.sh
```

**The guidelines require an immediate FAIL when check-rebased-onto-main.sh exits non-zero.**
No implementation quality review is performed until the rebase is resolved.

### Missing Main Commit Analysis

The one commit on main that the branch is missing is:

```
61c9117a chore(tasks): intake visual-primitives gaps — type topology extraction and Node renderer
```

That commit modifies three files:
- `.hyperloop/state/tasks/task-034.md` — added (state branch only, no impact on tests)
- `.hyperloop/state/tasks/task-035.md` — added (state branch only, no impact on tests)
- `extractor/tests/test_extractor.py` — **deleted 89 lines** (3 test functions intentionally removed from main)

The three deleted tests are:
1. `test_bounded_context_nodes_have_metrics_with_loc`
2. `test_cross_context_edge_direction_encodes_importer_to_imported`
3. `test_internal_edge_distinguishable_from_cross_context`

Because the branch forked before this deletion, it still carries those 89 lines. Merging the branch as-is would reintroduce tests that main deliberately removed. This is a substantive impact — not a benign race condition.

### Test Suite Count Check
```
OK: _run_suite() count on branch (19) >= origin/main (19).
```
Suite count is fine. After rebasing (which drops the 89 deleted lines), the count should remain 19.

---

## run-all-checks.sh Summary (all checks except rebase)

| Check | Result |
|---|---|
| check-aggregate-edge-impl.sh | EXIT 0 |
| check-assigned-spec-in-scope.sh | EXIT 0 (SKIP — manual) |
| check-banned-task-ids-closed.sh | EXIT 0 |
| check-branch-forked-from-main.sh | EXIT 0 |
| check-branch-has-commits.sh | EXIT 0 |
| check-branch-has-impl-files.sh | EXIT 0 |
| check-checks-in-sync.sh | EXIT 0 |
| check-circular-position-y-axis.sh | EXIT 0 |
| check-clamp-boundary-tests.sh | EXIT 0 |
| check-commit-trailer-task-ref.sh | EXIT 0 |
| check-compute-functions-called-from-entry-point.sh | EXIT 0 |
| check-cycle-gate.sh | EXIT 0 |
| check-directional-signchain-comments.sh | EXIT 0 |
| check-extractor-cli-tested.sh | EXIT 0 |
| check-extractor-stdlib-only.sh | EXIT 0 |
| check-fail-report-classification.sh | EXIT 0 |
| check-gdscript-only-test.sh | EXIT 0 |
| check-godot-no-script-errors.sh | EXIT 0 |
| check-kartograph-integration-test.sh | EXIT 0 |
| check-layout-radius-bound.sh | EXIT 0 |
| check-lod-level-tests.sh | EXIT 0 |
| check-lod-opacity-animation.sh | EXIT 0 |
| check-main-local-vs-remote.sh | EXIT 0 |
| check-main-not-diverged.sh | EXIT 0 |
| check-new-modules-wired.sh | EXIT 0 |
| check-no-duplicate-toplevel-functions.sh | EXIT 0 |
| check-no-gdscript-duplicate-functions.sh | EXIT 0 |
| check-nondirectional-movement-assertions.sh | EXIT 0 |
| check-no-prohibited-tasks-open.sh | EXIT 0 |
| check-not-in-scope.sh | EXIT 0 |
| check-no-zero-commit-reattempt.sh | EXIT 0 |
| check-pass-report-no-raw-fail-lines.sh | EXIT 0 |
| check-pipeline-wiring.sh | EXIT 0 |
| check-preloaded-gdscript-files.sh | EXIT 0 |
| check-prescribed-fixes-applied.sh | EXIT 0 |
| check-prohibited-branches-deleted.sh | EXIT 0 |
| check-pytest-passes.sh | EXIT 0 |
| check-racf-prior-cycle.sh | EXIT 0 |
| check-racf-remediation.sh | EXIT 0 |
| **check-rebased-onto-main.sh** | **EXIT 1 — FAIL** |
| check-relative-position-tests.sh | EXIT 0 |
| check-report-scope-section.sh | EXIT 0 |
| check-retry-not-scope-prohibited.sh | EXIT 0 |
| check-ruff-format.sh | EXIT 0 |
| check-run-tests-suite-count.sh | EXIT 0 |
| check-scope-report-not-falsified.sh | EXIT 0 |
| check-script-skip-on-no-args.sh | EXIT 0 |
| check-spec-ref-staleness.sh | EXIT 0 |
| check-spec-ref-valid.sh | EXIT 0 |
| check-state-branch-prohibited-tasks.sh | EXIT 0 |
| check-sync-divergence-impact.sh | EXIT 0 |
| check-task-ref-report-not-falsified.sh | EXIT 0 |
| check-tscn-no-dangling-references.sh | EXIT 0 |
| check-typeddict-fields-extractor-tested.sh | EXIT 0 |
| check-worker-result-clean.sh | EXIT 0 |
| extractor-lint.sh | EXIT 0 |
| godot-compile.sh | EXIT 0 |
| godot-fileaccess-tested.sh | EXIT 0 |
| godot-label3d.sh | EXIT 0 |
| godot-tests.sh | EXIT 0 |

**One check fails: check-rebased-onto-main.sh.**

---

## Test Results (informational — not applicable to verdict until rebase resolved)

- pytest: 234 passed
- Godot behavioral tests: 230 passed (19 suites)
- Commit trailers: Spec-Ref and Task-Ref present on both implementation commits.

---

## Verdict: FAIL

**Single failure driver: check-rebased-onto-main.sh exits 1.**

The branch is not rebased onto origin/main. The missing main commit (61c9117a)
deleted 89 lines from `extractor/tests/test_extractor.py` (3 test functions).
Because the branch lacks that commit, merging it would restore those deleted tests,
reverting an intentional main change. This is a substantive impact.

### Required Fix

```bash
git fetch origin
git rebase origin/main
# When resolving extractor/tests/test_extractor.py conflict:
#   KEEP the main version (which removes the 3 deleted test functions).
#   Apply the branch's task-025 changes ON TOP.
bash .hyperloop/checks/check-run-tests-suite-count.sh
bash .hyperloop/checks/run-all-checks.sh
```

No implementation changes needed — the implementation quality looks correct.
The rebase is a one-command fix.