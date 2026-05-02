---
task_id: task-027
round: 3
role: verifier
verdict: fail
---
## Scope Check Output
OK: No prohibited (not-in-scope) features detected.

---

## Full Check Summary Table

| Check | Exit Code |
|-------|-----------|
| check-aggregate-edge-impl.sh | 0 (N/A — no LOD/viz files) |
| check-assigned-spec-in-scope.sh | 0 (SKIP — no spec path provided) |
| check-banned-task-ids-closed.sh | 0 (SKIP — orchestrator gate) |
| check-branch-forked-from-main.sh | 0 |
| check-branch-has-commits.sh | 0 |
| check-branch-has-impl-files.sh | 0 |
| check-checks-in-sync.sh | 0 |
| check-circular-position-y-axis.sh | 0 |
| check-clamp-boundary-tests.sh | 0 |
| check-commit-trailer-task-ref.sh | 0 |
| check-compute-functions-called-from-entry-point.sh | 0 |
| check-cycle-gate.sh | 0 (WARN task-108 — orchestrator note only) |
| check-deliverable-component.sh | 0 (SKIP) |
| check-directional-signchain-comments.sh | 0 |
| check-edge-rerouting-wired.sh | 0 (SKIP) |
| check-extractor-cli-tested.sh | 0 |
| check-extractor-stdlib-only.sh | 0 |
| check-fail-report-classification.sh | 0 (SKIP) |
| check-gdscript-only-test.sh | 0 |
| check-godot-no-script-errors.sh | 0 |
| check-highlight-function-has-tween.sh | 0 |
| check-individual-edge-weight.sh | 0 |
| check-kartograph-integration-test.sh | 0 |
| check-layout-radius-bound.sh | 0 |
| check-lod-level-tests.sh | 0 |
| check-lod-opacity-animation.sh | 0 |
| check-main-local-vs-remote.sh | 0 |
| check-main-not-diverged.sh | 0 |
| check-new-modules-wired.sh | 0 |
| check-no-duplicate-toplevel-functions.sh | 0 |
| check-no-gdscript-duplicate-functions.sh | 0 |
| check-nondirectional-movement-assertions.sh | 0 |
| check-no-prohibited-tasks-open.sh | 0 |
| check-not-in-scope.sh | 0 |
| check-no-vacuous-iteration.sh | 0 |
| check-no-zero-commit-reattempt.sh | 0 |
| check-pass-report-no-raw-fail-lines.sh | 0 |
| check-pipeline-wiring.sh | 0 |
| check-preloaded-gdscript-files.sh | 0 |
| check-prescribed-fixes-applied.sh | 0 |
| check-prohibited-branches-deleted.sh | 0 |
| check-pytest-passes.sh | 0 |
| check-pytest-test-count.sh | 0 (SKIP — origin/main baseline was 0) |
| check-racf-prior-cycle.sh | 0 |
| check-racf-remediation.sh | 0 |
| check-rebased-onto-main.sh | **1 — FAIL** |
| check-relative-position-tests.sh | 0 |
| check-report-scope-section.sh | 0 |
| check-reposition-function-has-tween.sh | 0 |
| check-retry-not-scope-prohibited.sh | 0 |
| check-ruff-format.sh | 0 |
| check-run-tests-suite-count.sh | 0 |
| check-scope-report-not-falsified.sh | 0 |
| check-script-skip-on-no-args.sh | 0 |
| check-spec-ref-matches-task.sh | 0 |
| check-spec-ref-staleness.sh | 0 |
| check-spec-ref-valid.sh | 0 |
| check-state-branch-prohibited-tasks.sh | 0 |
| check-sync-divergence-impact.sh | 0 |
| check-task-ref-report-not-falsified.sh | 0 |
| check-tscn-no-dangling-references.sh | 0 |
| check-typeddict-fields-extractor-tested.sh | 0 |
| check-worker-result-clean.sh | 0 |
| extractor-lint.sh | 0 |
| godot-compile.sh | 0 |
| godot-fileaccess-tested.sh | 0 |
| godot-label3d.sh | 0 |
| godot-tests.sh | 0 |

**Overall: 1 FAIL (check-rebased-onto-main.sh)**

---

## Mandatory Individual Check Outputs (verbatim)

### check-rebased-onto-main.sh
```
FAIL: Branch 'hyperloop/task-027' is NOT rebased onto origin/main.

  Fork point (merge-base): f9e3c9e
  origin/main HEAD:        7f08e1d
  Commits on main not in branch: 1

  RISK: Merging this branch as-is would REVERT all 1 commit(s)
  that main added after f9e3c9e. Inspect what would be lost:
    git log f9e3c9e..origin/main --oneline

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

### check-run-tests-suite-count.sh
```
OK: _run_suite() count on branch (20) >= origin/main (20).
```

### check-pytest-test-count.sh
```
SKIP: origin/main has 0 test functions in extractor/tests/ — nothing to compare.
```

### check-spec-ref-matches-task.sh
```
OK: Spec-Ref path 'specs/core/visual-primitives.spec.md' matches task definition spec_ref.
```

### check-spec-ref-staleness.sh
```
OK (no drift): specs/core/visual-primitives.spec.md is identical at Spec-Ref
(67df14bc9137e80de5a60d12dad7f77c7d995959) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

### check-sync-divergence-impact.sh
```
OK: No stale check scripts found — check-checks-in-sync.sh should pass.
    (If check-checks-in-sync.sh still exits non-zero, re-run it.)
```

### check-branch-has-impl-files.sh
```
OK: Branch 'hyperloop/task-027' has implementation commits (2 non-.hyperloop/ file(s) changed).
```

---

## Missing Commits from main (Step 9 analysis)

```
7f08e1d8 feat(extraction): extractor — edge weight annotation and aggregate cross-context edge emission (#230)
```

Files touched by the missing main commit:
- extractor/extractor.py
- extractor/schema.md
- extractor/tests/test_extractor.py

These ARE implementation files. This is NOT a rebase-only fail.

The missing commit (task-063) implements "edge weight annotation and aggregate cross-context edge emission"
using the same files (`extractor/extractor.py`, `extractor/tests/test_extractor.py`) that this branch modifies.

Merging task-027 as-is would:
1. Delete extractor/schema.md (150 lines) added by task-063.
2. Remove 5 tests added by task-063 (TestWeightedEdge class with 3 tests, plus
   test_bounded_context_nodes_have_metrics_with_loc and
   test_cross_context_edge_direction_encodes_importer_to_imported).
3. Revert implementation details from task-063's `build_dependency_edges()`.

---

## ORCHESTRATOR NOTE: Feature Supersession

Task-027 as committed implements weight on individual cross_context and internal edges
(Spec-Ref: visual-primitives.spec.md §Weighted edge scenario). Task-063 on main
(commit 7f08e1d8) implements the same feature — "edge weight annotation and aggregate
cross-context edge emission" — and is already merged.

The branch effectively REPLACES main's implementation with an alternate approach
(raw_edge_count dict instead of raw_edges set + raw_edge_weight dict) that is
functionally equivalent but loses the extra tests task-063 added.

The task-027 definition (task file) actually prescribes a DIFFERENT feature:
"ubiquitous dependency detection and edge ubiquitous flag" per its task title and
pr_description. The branch commit does NOT implement ubiquitous detection — it
implements edge weights, which task-063 already delivered on main.

This is a FEATURE-SUPERSESSION failure: the primary feature targeted by this
branch's commit (individual edge weights) has already been implemented on main
by task-063. The task-027 canonical assignment (ubiquitous detection) is NOT
implemented at all.

---

## Requirements Coverage Table

The task-027 task definition (visual-primitives.spec.md §Ubiquitous Dependency Detection)
requires:

| Requirement | Status | Notes |
|-------------|--------|-------|
| MUST identify dependencies imported by a large fraction of modules | MISSING | Not implemented |
| MUST flag ubiquitous dependencies (default threshold: >50% of modules) | MISSING | Not implemented |
| Ubiquitous edges present in scene graph but marked `ubiquitous: true` | MISSING | Not implemented |
| Threshold recorded in extraction metadata | MISSING | Not implemented |
| compute_ubiquitous_flags() called from entry point | COVERED | Function exists on main (pre-existing); branch does not touch it |
| Edge `ubiquitous: true` annotation | MISSING | Not implemented |
| Metadata `ubiquitous_deps` section | MISSING | Not implemented |

SPEC-DRIFT note: The branch implements "weighted edge" (individual edge weight fields)
per a different section of visual-primitives.spec.md. That feature has already
been superseded on main by task-063. The Spec-Ref SHA in the commit (67df14bc...)
matches a §Weighted edge scenario, NOT §Ubiquitous Dependency Detection.

---

## Implementation Quality Notes

The code committed on this branch (raw_edge_count dict approach) is clean and
functionally correct for the individual edge weight problem:
- Uses a single dict accumulator instead of separate set + weight dict.
- Correctly guards against double-counting by distinguishing BC-level vs module-level
  scans for cross_context edges.
- Uses max(count, 1) to ensure a minimum weight of 1.
- Two new tests (test_cross_context_edge_has_weight, test_internal_edge_has_weight)
  assert presence of weight field and int type >= 1. Not vacuous.

However:
- The branch deletes extractor/schema.md (150 lines of documentation) that main added.
- The branch removes 5 tests that main added via task-063 (TestWeightedEdge class with
  aggregate weight test, plus two integration-level tests).
- Test count: branch has 153 test functions; main has 158. Net regression of 5 tests.

---

## FAIL Reasons

1. PRIMARY: check-rebased-onto-main.sh exits 1. The missing commit (7f08e1d8, task-063)
   touches implementation files (extractor/extractor.py, extractor/tests/test_extractor.py,
   extractor/schema.md). This is a STANDARD REBASE FAIL with FEATURE-SUPERSESSION.

2. WRONG FEATURE: The branch implements individual edge weights (already delivered by
   task-063 on main). The task-027 assignment is ubiquitous dependency detection — not
   implemented at all.

3. TEST REGRESSION: Merging this branch would delete 5 tests added by task-063 and remove
   extractor/schema.md. Net test count drops from 158 (main) to 153 (branch).