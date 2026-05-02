---
task_id: task-027
round: 2
role: verifier
verdict: fail
---
## Scope Check Output
OK: No prohibited (not-in-scope) features detected.

---

## Check Summary

All 68 checks, with exit codes:

| Check | Exit |
|---|---|
| check-aggregate-edge-impl.sh | 0 |
| check-assigned-spec-in-scope.sh | 0 |
| check-banned-task-ids-closed.sh | 0 |
| check-branch-forked-from-main.sh | 0 |
| check-branch-has-commits.sh | 0 |
| check-branch-has-impl-files.sh | 0 |
| check-checks-in-sync.sh | 0 |
| check-circular-position-y-axis.sh | 0 |
| check-clamp-boundary-tests.sh | 0 |
| check-commit-trailer-task-ref.sh | 0 |
| check-compute-functions-called-from-entry-point.sh | 0 |
| check-cycle-gate.sh | 0 |
| check-deliverable-component.sh | 0 |
| check-directional-signchain-comments.sh | 0 |
| check-edge-rerouting-wired.sh | 0 |
| check-extractor-cli-tested.sh | 0 |
| check-extractor-stdlib-only.sh | 0 |
| check-fail-report-classification.sh | 0 |
| check-gdscript-only-test.sh | 0 |
| check-godot-no-script-errors.sh | 0 |
| check-highlight-function-has-tween.sh | 0 |
| check-individual-edge-weight.sh | 0 |
| check-kartograph-integration-test.sh | 0 |
| check-layout-radius-bound.sh | 0 |
| check-lod-level-tests.sh | 0 |
| check-lod-opacity-animation.sh | 0 |
| check-main-local-vs-remote.sh | 1 — ORCHESTRATOR CONFIGURATION |
| check-main-not-diverged.sh | 1 — ORCHESTRATOR CONFIGURATION |
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
| check-pytest-test-count.sh | 0 (SKIP — origin/main count unavailable) |
| check-racf-prior-cycle.sh | 0 |
| check-racf-remediation.sh | 0 |
| check-rebased-onto-main.sh | 1 — FAIL |
| check-relative-position-tests.sh | 0 |
| check-report-scope-section.sh | 0 |
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

Failing checks: check-rebased-onto-main.sh (EXIT 1), check-main-local-vs-remote.sh
(ORCHESTRATOR), check-main-not-diverged.sh (ORCHESTRATOR).

---

## Mandatory Individual Checks

### check-rebased-onto-main.sh

```
FAIL: Branch 'hyperloop/task-027' is NOT rebased onto origin/main.
  Fork point (merge-base): 814d2f9
  origin/main HEAD:        9cd81e6
  Commits on main not in branch: 1
```

Missing commit on origin/main:

```
9cd81e6a feat(extractor): add weight to individual cross_context and internal edges (#241)
         Task-Ref: task-067
         Spec-Ref: specs/visualization/spatial-structure.spec.md
```

This commit touches `extractor/extractor.py` and `extractor/tests/test_extractor.py` — the
SAME files this branch modifies. This is NOT a process-only advance. The REBASE-ONLY FAIL
classification does NOT apply.

### check-run-tests-suite-count.sh

```
OK: _run_suite() count on branch (20) >= origin/main (20).
```

### check-spec-ref-matches-task.sh

```
OK: Spec-Ref path 'specs/core/visual-primitives.spec.md' matches task definition spec_ref.
```

### check-spec-ref-staleness.sh

```
OK (no drift): specs/core/visual-primitives.spec.md is identical at Spec-Ref and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

### check-main-local-vs-remote.sh / check-main-not-diverged.sh

Both fail because local main is ahead of origin/main — an ORCHESTRATOR CONFIGURATION
error, not an implementer error. The check scripts explicitly label this as such and
instruct verifiers to classify as ORCHESTRATOR CONFIGURATION. However, origin/main
advanced during this review (task-067 merged PR #241), causing the check-rebased-onto-main.sh
to also fail for a substantive reason. These ORCHESTRATOR checks are noted but are not
the primary FAIL driver.

---

## Spec Requirements Coverage

Reviewed against committed spec: specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959
(No spec drift — spec at Spec-Ref is identical to HEAD.)

### Extractor Requirements

| Requirement | Scenario | THEN-clause | Implementation | Test | Status |
|---|---|---|---|---|---|
| Module Graph | Import-based edges | each edge carries the import count | build_dependency_edges() now uses raw_edge_count dict; weight field on all individual edges | test_cross_context_edge_has_weight, test_internal_edge_has_weight | COVERED |
| Module Graph | Import-based edges | edges A->B and A->C are emitted | build_dependency_edges() produces edges | test_cross_context_edge_created, test_internal_edge_created | COVERED (pre-existing) |
| Ubiquitous Dependency Detection | Standard library suppression | logging flagged as ubiquitous | detect_ubiquitous_dependencies() in build_scene_graph() | TestUbiquitousDependencyDetection suite | COVERED (pre-existing on main) |
| Ubiquitous Dependency Detection | Standard library suppression | edges marked ubiquitous: true | edge["ubiquitous"] = True in detect_ubiquitous_dependencies() | test_build_scene_graph_flags_ubiquitous_edges | COVERED (pre-existing on main) |
| Ubiquitous Dependency Detection | Threshold | flagged when exceeds threshold | threshold parameter in detect_ubiquitous_dependencies() | test_threshold_controls_detection | COVERED (pre-existing on main) |
| Ubiquitous Dependency Detection | Threshold | threshold recorded in metadata | metadata['ubiquitous_threshold'] | test_build_scene_graph_records_ubiquity_threshold | COVERED (pre-existing on main) |

### Godot-side requirements (Weighted edge rendering)

The Weighted edge THEN-clause "visual thickness is proportional to weight" is a renderer
requirement (Godot side). This branch is extractor-only. The Godot side is a separate task.
Not scored here.

---

## Implementation Quality Assessment

**What the branch does:** Replaces `raw_edges: set[tuple]` with `raw_edge_count: dict[tuple, int]`
in `build_dependency_edges()`, so individual cross_context and internal edges carry a `weight`
field (the accumulated import count). Two tests verify this for both edge types.

**Code quality:** Clean, correct, passes ruff lint and format, 249/249 tests pass.

**Subtle difference vs. task-067 (now on main):** task-027's implementation ignores BC-level
cross_context scans entirely (no fallback). task-067's implementation registers a weight=1
fallback from BC-level scans if no module-level scan has already seen the edge. For kartograph
(which has submodules), both produce identical results. For flat BCs with no submodule nodes,
task-027 would drop those cross_context edges while task-067 would emit them with weight=1.
task-067's version is more complete.

**Tests:** Both new tests (test_cross_context_edge_has_weight, test_internal_edge_has_weight)
use non-empty assertions before iteration — no vacuous coverage.

---

## FAIL #1 — Not Rebased onto origin/main (BLOCKING)

check-rebased-onto-main.sh exits non-zero. The missing commit (task-067, PR #241) implements
the SAME feature as this branch — adding weight to individual cross_context and internal edges.
origin/main is now ahead of this branch by that commit, and a direct rebase will produce
conflicts in build_dependency_edges() and the test file.

**Orchestrator note:** Since task-067 has already merged the same feature to main, task-027's
implementation is substantively superseded. The orchestrator should evaluate whether task-027
needs any additional work or can be closed. All spec requirements covered by this task
(individual edge weight, ubiquitous detection) are now fully implemented and tested on main.

**Required fix if the task proceeds:**

```
git fetch origin main:main
git rebase origin/main
# Resolve conflicts in extractor/extractor.py and extractor/tests/test_extractor.py.
# Task-067's version of build_dependency_edges() is already on main; accept it (theirs)
# for those sections. Drop the duplicate tests from this branch — they already exist
# on main from task-067. Verify: bash .hyperloop/checks/check-run-tests-suite-count.sh
bash .hyperloop/checks/run-all-checks.sh
```

## ORCHESTRATOR CONFIGURATION

check-main-local-vs-remote.sh and check-main-not-diverged.sh fail because local main is
ahead of origin/main. These are ORCHESTRATOR errors (orchestrator committed to local main
without pushing). The implementer cannot resolve this. Required action: orchestrator runs
`git push origin main` from the main worktree.