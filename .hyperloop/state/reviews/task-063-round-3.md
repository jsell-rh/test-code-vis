---
task_id: task-063
round: 3
role: verifier
verdict: fail
---
# Review: task-063 — Scene-Graph Schema Extractor-Level Tests (Round 3)

Branch: hyperloop/task-063
Implementation commits: baf3a6f8, 5284f78c
Spec-Ref: specs/extraction/scene-graph-schema.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1 and @7b9391479f56416ec06f248e0321b956bdb5f8ed (no drift — both resolve OK)
Task-Ref: task-063 (correct on both commits)

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Check Sync

```
OK: All check scripts from main are present and content-identical in working tree (63 checked).
```

63 checks confirmed in sync. No FAST-FIX classification needed.

---

## Rebase Check (BLOCKING FAIL)

```
FAIL: Branch 'hyperloop/task-063' is NOT rebased onto origin/main.

  Fork point (merge-base): 53b1865
  origin/main HEAD:        452593e
  Commits on main not in branch: 4

  RISK: Merging this branch as-is would REVERT all 4 commit(s)
  that main added after 53b1865. Inspect what would be lost:
    git log 53b1865..origin/main --oneline
```

Commits on main that are absent from this branch:
```
452593ee feat(core): schema — define `metrics` object (raw `loc` integer) on node entries (#213)
c6a13580 feat(core): add import-count weight to individual dependency edges (#238)
058f1eb7 chore(intake): ninth review — same five specs, no new tasks (2026-05-02)
20461a84 feat(extractor): add symbol table extraction and node symbols schema field (#234)
```

Protocol: "If [check-rebased-onto-main.sh] exits non-zero, issue FAIL immediately."

Verdict: FAIL. The branch has not been rebased onto main. Further implementation review
is secondary to this blocking issue, but documented below for completeness.

---

## Test Suite Count Check

```
OK: _run_suite() count on branch (21) >= origin/main (20).
```

The Godot _run_suite count passes. However, this check covers only GDScript suites — NOT
Python pytest regression. Python test regression is documented separately below.

---

## Python Test Regression (BLOCKING)

Origin/main runs 264 pytest tests. This branch runs 254 pytest tests — a regression of
exactly 10 tests. Confirmed by running extractor-lint.sh on both versions.

The branch diff against origin/main shows 6 test functions removed from
extractor/tests/test_extractor.py that exist on origin/main:

Removed (3 tests from task-040 / commit c6a13580):
  - test_cross_context_edge_has_weight
  - test_internal_edge_has_weight
  - test_cross_context_weight_value_is_nonzero

Removed (3 tests from task-023 / commit 20461a84):
  - test_betweenness_centrality_computed_for_bridge_node
  - test_betweenness_centrality_zero_for_non_bridge_in_cycle
  - test_compute_betweenness_centrality_direct

The remaining 4 missing tests are attributable to other additions on main not in this branch.

The removed tests are not intentional deletions — they were never present at the branch's
fork point (53b1865). Main added them in subsequent commits. Because the branch has not
been rebased, these tests are silently absent from the branch's test suite.

---

## Implementation Divergence

The branch's `build_dependency_edges()` uses a two-structure approach (raw_edges set +
raw_edge_weight dict) while origin/main's version (established by task-023, commit
20461a84) uses a single raw_edge_count dict. Both emit `weight` on individual edges, but
the implementations diverge in one edge case:

- Branch: for cross-context edges, only increments raw_edge_weight when
  `node["type"] == "module"`. A cross-context import found via BC-level rglob but not a
  module scan would yield `weight=1` (via the `.get(..., 1)` fallback default) rather
  than the accumulated count.
- origin/main: increments raw_edge_count unconditionally on all cross-context edge
  discoveries.

This divergence will need to be resolved during rebase conflict resolution. Recommend
keeping main's approach (single raw_edge_count dict, unconditional increment) as it is
the authoritative implementation and avoids the fallback-default edge case.

The branch also lacks the `_compute_betweenness_centrality()` wrapper function that
origin/main (commit 20461a84) added. The branch has the underlying `_compute_betweenness()`
helper but not the public wrapper. This difference causes the three removed tests above.

---

## All-Checks Summary

```
=== Summary: 62 check(s) run ===
RESULT: FAIL — one or more checks exited non-zero

Failing check:
  check-rebased-onto-main.sh: FAIL (branch not rebased onto origin/main)
```

All other checks exit 0:
  check-aggregate-edge-impl.sh:               EXIT 0
  check-assigned-spec-in-scope.sh:            EXIT 0
  check-banned-task-ids-closed.sh:            EXIT 0
  check-branch-forked-from-main.sh:           EXIT 0
  check-branch-has-commits.sh:               EXIT 0 (2 commits above main)
  check-branch-has-impl-files.sh:             EXIT 0
  check-checks-in-sync.sh:                   EXIT 0 (63 checks, content-identical)
  check-circular-position-y-axis.sh:          EXIT 0
  check-clamp-boundary-tests.sh:             EXIT 0
  check-commit-trailer-task-ref.sh:           EXIT 0
  check-compute-functions-called-from-entry-point.sh: EXIT 0
  check-cycle-gate.sh:                        EXIT 0
  check-directional-signchain-comments.sh:    EXIT 0
  check-extractor-cli-tested.sh:              EXIT 0
  check-extractor-stdlib-only.sh:             EXIT 0
  check-fail-report-classification.sh:        EXIT 0
  check-gdscript-only-test.sh:               EXIT 0
  check-godot-no-script-errors.sh:            EXIT 0
  check-individual-edge-weight.sh:            EXIT 0
  check-kartograph-integration-test.sh:       EXIT 0
  check-layout-radius-bound.sh:               EXIT 0
  check-lod-level-tests.sh:                  EXIT 0
  check-lod-opacity-animation.sh:             EXIT 0
  check-main-local-vs-remote.sh:              EXIT 0
  check-main-not-diverged.sh:                EXIT 0
  check-new-modules-wired.sh:                EXIT 0
  check-no-duplicate-toplevel-functions.sh:   EXIT 0
  check-no-gdscript-duplicate-functions.sh:   EXIT 0
  check-nondirectional-movement-assertions.sh: EXIT 0
  check-no-prohibited-tasks-open.sh:          EXIT 0
  check-not-in-scope.sh:                     EXIT 0
  check-no-vacuous-iteration.sh:             EXIT 0
  check-no-zero-commit-reattempt.sh:          EXIT 0
  check-pass-report-no-raw-fail-lines.sh:     EXIT 0
  check-pipeline-wiring.sh:                  EXIT 0
  check-preloaded-gdscript-files.sh:          EXIT 0
  check-prescribed-fixes-applied.sh:          EXIT 0
  check-prohibited-branches-deleted.sh:       EXIT 0
  check-racf-prior-cycle.sh:                  EXIT 0
  check-rebased-onto-main.sh:                EXIT 1 — FAIL
  check-report-scope-section.sh:             EXIT 0
  check-retry-not-scope-prohibited.sh:        EXIT 0
  check-ruff-format.sh:                      EXIT 0
  check-run-tests-suite-count.sh:            EXIT 0 (21 >= 20)
  check-scope-report-not-falsified.sh:        EXIT 0
  check-script-skip-on-no-args.sh:           EXIT 0
  check-spec-ref-staleness.sh:               EXIT 0
  check-spec-ref-valid.sh:                   EXIT 0
  check-state-branch-prohibited-tasks.sh:     EXIT 0
  check-sync-divergence-impact.sh:            EXIT 0
  check-task-ref-report-not-falsified.sh:     EXIT 0
  check-tscn-no-dangling-references.sh:       EXIT 0
  check-typeddict-fields-extractor-tested.sh: EXIT 0
  check-worker-result-clean.sh:              EXIT 0
  extractor-lint.sh:                         EXIT 0 (254 tests pass)
  godot-compile.sh:                          EXIT 0
  godot-fileaccess-tested.sh:                EXIT 0
  godot-label3d.sh:                          EXIT 0
  godot-tests.sh:                            EXIT 0
```

Note: check-individual-edge-weight.sh now exits 0 because the fix commit (5284f78c)
correctly adds weight to individual edges. That was the sole blocker in Round 2.

---

## Spec Coverage (committed spec at Spec-Ref — no drift from HEAD)

| Requirement / Scenario                                | Status   | Notes |
|-------------------------------------------------------|----------|-------|
| Schema Structure: exactly 4 top-level keys            | COVERED  | test_build_scene_graph_has_exactly_four_top_level_keys |
| Node: bounded context fields (id, name, type, pos, size, parent=null) | COVERED | pre-existing tests |
| Node: module node fields + parent ref + relative position | COVERED | pre-existing tests |
| Node: independence_group field                        | COVERED  | test_independence_group_format + test_build_scene_graph_assigns_independence_groups |
| Edge: cross-context source/target/type               | COVERED  | pre-existing + test_cross_context_edge_direction_encodes_importer_to_imported |
| Edge: internal source/target/type                    | COVERED  | pre-existing + test_internal_edge_distinguishable_from_cross_context |
| Weighted edge: individual weight present and >= 1    | COVERED  | test_individual_cross_context_edges_have_weight + test_individual_internal_edges_have_weight |
| Weighted edge: aggregate weight=N (exact count)      | COVERED  | test_aggregate_edge_weight_equals_module_import_count |
| Metadata: source path + timestamp                    | COVERED  | test_metadata_has_source_path + test_metadata_has_timestamp |
| Pre-Computed Layout: positions in JSON               | COVERED  | pre-existing layout tests |
| Cluster: id, members, context, aggregate_metrics     | COVERED  | test_coupled_modules_form_cluster + test_cluster_aggregate_metrics_keys |
| Cluster: empty array when no coupling                | COVERED  | test_no_clusters_when_no_coupling |
| Cascade Depth: depth on affected nodes               | COVERED  | Pre-existing; NotRequired field in TypedDict |

All spec requirements are covered by the task-063 implementation. The FAIL is entirely
due to the missing rebase, not a spec coverage gap.

---

## Required Fix

The sole required fix is a rebase. No new code needs to be written.

### Step 1 — Rebase

```
git fetch origin
git rebase origin/main
```

### Step 2 — Resolve conflict in extractor/extractor.py

The rebase will conflict in `build_dependency_edges()`. During conflict resolution:
- KEEP main's `raw_edge_count: dict[tuple[str, str, EdgeType], int]` approach (do not
  reintroduce the separate `raw_edges` set + `raw_edge_weight` dict from the branch).
- KEEP the `weight: count` emission from main's version.
- KEEP any task-063-specific changes to docstrings that improve clarity (optional).
- Do NOT restore the separate `raw_edge_weight` dict or the `.get(..., 1)` fallback.
- KEEP main's `all_imports: list[str]` (changed from `set` in commit 20461a84).

### Step 3 — Verify no tests were dropped

After rebasing, run:
```
bash .hyperloop/checks/extractor-lint.sh
```
The test count must be >= 264 (origin/main count). If it is less, tests from main
were dropped during conflict resolution. Restore any missing tests from:
  - task-040 (c6a13580): test_cross_context_edge_has_weight, test_internal_edge_has_weight,
    test_cross_context_weight_value_is_nonzero
  - task-023 (20461a84): test_betweenness_centrality_computed_for_bridge_node,
    test_betweenness_centrality_zero_for_non_bridge_in_cycle,
    test_compute_betweenness_centrality_direct

The task-063 tests (test_individual_cross_context_edges_have_weight, etc.) may overlap
with some of the tests from task-040 — in that case, keep both sets or merge them so
that all assertions are preserved.

### Step 4 — Run all checks

```
bash .hyperloop/checks/run-all-checks.sh
```

All checks must pass. No implementation changes to the task-063 logic are required —
the spec coverage is correct and complete.

### Commit message template

```
chore(task-063): rebase onto main and resolve extractor.py conflict

The branch was 4 commits behind origin/main (20461a84, 058f1eb7, c6a13580,
452593e). Resolved conflict in build_dependency_edges() by keeping main's
raw_edge_count dict approach. Retained all tests added by task-023 and
task-040 alongside task-063's coverage additions.

Spec-Ref: specs/extraction/scene-graph-schema.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
Task-Ref: task-063
```