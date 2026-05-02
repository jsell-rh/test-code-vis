---
task_id: task-063
round: 1
role: verifier
verdict: fail
---
# Review: task-063 — Scene-Graph Schema Extractor-Level Tests

Branch: hyperloop/task-063
Implementation commit: 4fa985ee (test(task-063): add extractor-level coverage for scene-graph schema spec)
Spec-Ref: specs/extraction/scene-graph-schema.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed (resolves OK, no drift)
Task-Ref: task-063 (correct on implementation commit)

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Check-Sync Status

Ran `git checkout main -- .hyperloop/checks/` (twice — a race-condition caused the
first sync to show two stale scripts mid-run). Second sync confirmed clean:

  check-checks-in-sync.sh: OK — 61 scripts present and content-identical.
  check-sync-divergence-impact.sh: EXIT 0 — No DIVERGENT cases.

The two scripts that appeared stale (`check-branch-forked-from-main.sh` and
`check-commit-trailer-task-ref.sh`) produce the same failure output with both the
stale and current versions. This is not a FAST-FIX on those checks — they fail on
their own merits (see below).

---

## Rebase Check

check-rebased-onto-main.sh: SKIP — Cannot compute merge-base between HEAD and
origin/main. This repo has a parallel-history structure (a historical "reset"
commit created divergent trees with different hashes for the same logical content).
The check is architecturally unable to fire in this environment.

However, the assignment explicitly records: "PR not mergeable — rebase failed
(conflicts in: extractor/tests/test_extractor.py)". The conflict source is
identified below.

---

## Test Suite Count Check

check-run-tests-suite-count.sh: EXIT 1 — FAIL

  origin/main: 20 _run_suite() registrations
  This branch: 19 _run_suite() registrations
  Missing:     _run_suite(preload("res://tests/test_godot_app_spec.gd").new())

  test_godot_app_spec.gd was added to main by commit cf00f6d4
  ("feat(prototype): godot — dependency line rendering") at 2026-05-02 01:20:17.
  The task-063 implementation commit is dated 2026-05-01 22:52:37 — approximately
  2.5 hours earlier. The implementer could not have known about this file when they
  submitted.

  This is a RACE-CONDITION on the suite registration. The mandated fix is a rebase,
  which will automatically pick up the missing file and its run_tests.gd entry.

---

## run-all-checks.sh Summary (after second sync)

All 60 checks executed; failing checks:

  check-branch-forked-from-main.sh    EXIT 1 — see note below
  check-commit-trailer-task-ref.sh    EXIT 1 — see note below
  check-run-tests-suite-count.sh      EXIT 1 — primary FAIL driver (see above)
  check-spec-ref-valid.sh             EXIT 1 — see note below

All other 56 checks: EXIT 0.

### Notes on structural false positives

This repo has a parallel-history structure: a "reset" commit bifurcated the tree
into two divergent lineages with the same logical changes but different commit
hashes. As a result, git cannot compute a merge-base between HEAD and origin/main,
and checks that compare "commits on this branch" against "origin/main" see the
entire branch ancestry as "above main."

check-branch-forked-from-main.sh and check-commit-trailer-task-ref.sh: Both flag
~48 commits from the parallel history (Task-Ref: task-001 through task-075, etc.)
as "foreign trailer commits made on this branch." These are NOT commits the
task-063 implementer made — they are pre-existing commits in the branch's ancestry
with different hashes from their origin/main counterparts. The actual task-063
commit (4fa985ee) correctly carries Task-Ref: task-063. These two failures are
structural false positives caused by the parallel history, not genuine task-063
violations.

check-spec-ref-valid.sh: Fails on 13 unresolvable Spec-Refs across those same
historical parallel-history commits (commits from other tasks whose Spec-Ref hashes
don't exist in this repo's object store). The task-063 commit's own Spec-Ref
(specs/extraction/scene-graph-schema.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed)
resolves correctly. This is also a structural false positive.

---

## Spec Coverage (committed spec at 7b9391479f)

The spec at the Spec-Ref hash is identical to HEAD — no spec drift on the
scene-graph-schema spec itself.

| Requirement / Scenario                   | Status  | Notes                                              |
|------------------------------------------|---------|----------------------------------------------------|
| Schema Structure: exactly 4 top-level keys| COVERED | task-063 adds test_build_scene_graph_has_exactly_four_top_level_keys |
| Node: bounded context fields              | COVERED | pre-existing tests (id, name, type, position, size, parent=null) |
| Node: module node fields + parent ref     | COVERED | pre-existing tests (id, parent, type, position relative to parent) |
| Node: independence_group field            | COVERED | pre-existing test_independence_group_format + test_build_scene_graph_assigns_independence_groups |
| Edge: cross-context source/target/type    | COVERED | pre-existing tests                                 |
| Edge: internal source/target/type         | COVERED | pre-existing tests                                 |
| Weighted edge: individual weight omitted  | COVERED | task-063 adds test_individual_cross_context_edges_have_no_weight_field + test_individual_internal_edges_have_no_weight_field |
| Weighted edge: aggregate weight=N         | COVERED | task-063 adds test_aggregate_edge_weight_equals_module_import_count (src_weighted fixture with weight=2) |
| Metadata: source path + timestamp         | COVERED | pre-existing test_metadata_has_source_path + test_metadata_has_timestamp |
| Pre-Computed Layout: positions in JSON    | COVERED | pre-existing layout tests                          |
| Cluster: id, members, context, aggregate_metrics | COVERED | pre-existing test_coupled_modules_form_cluster + test_cluster_aggregate_metrics_keys |
| Cluster: empty array when no coupling     | COVERED | pre-existing test_no_clusters_when_no_coupling     |
| Cascade Depth: depth=1,2 on affected nodes| COVERED | pre-existing tests (added by prior task); simulation mode is excluded from prototype scope per prototype-scope.spec.md §Not In Scope — the depth field exists as NotRequired in the TypedDict |

All 238 pytest tests pass. ruff format and lint pass.

---

## Implementation Quality

The four spec-targeted tests added by task-063 are well-written:

1. test_build_scene_graph_has_exactly_four_top_level_keys: uses set equality
   (`== {"nodes", "edges", "metadata", "clusters"}`) — correctly catches both
   missing AND extra fields.

2. test_individual_cross_context_edges_have_no_weight_field: iterates all
   cross_context edges, asserts `"weight" not in e`. Requires at least one
   cross_context edge (asserted). Correct.

3. test_individual_internal_edges_have_no_weight_field: same pattern for internal
   edges. Correct.

4. test_aggregate_edge_weight_equals_module_import_count: introduces src_weighted
   fixture with iam.domain and iam.application both importing shared_kernel. Asserts
   aggregate edge iam→shared_kernel has weight=2. Directly maps to the spec example
   ("context A has 12 individual import statements … weight: 12"). Correct.

---

## Rebase Conflict Root Cause

The conflict noted in the assignment ("conflicts in: extractor/tests/test_extractor.py")
arises from the parallel-history structure:

  Branch commit 0190669a (feat: extractor — JSON scene graph output writer) and main
  commit 45a4dca8 (same logical feature, different hash) BOTH modify test_extractor.py.
  When git tries to replay 0190669a on top of main (which already has 45a4dca8),
  it sees conflicting changes to the same file.

  The task-063 changes (232 lines appended to test_extractor.py) are at the END of
  the file. During conflict resolution, the implementer should:
    - Accept main's version of all pre-existing test content
    - Preserve the 4 new task-063 test classes (TestSchemaTopLevelStructure,
      TestWeightedEdge, plus the bonus tests test_bounded_context_nodes_have_metrics_with_loc,
      test_cross_context_edge_direction_encodes_importer_to_imported,
      test_internal_edge_distinguishable_from_cross_context)
    - Then run pytest to confirm all 238+ tests pass

---

## Verdict: FAIL

Primary driver: check-run-tests-suite-count.sh — branch has 19 _run_suite()
registrations; main has 20. Missing test_godot_app_spec.gd was added to main
after this branch was submitted (RACE-CONDITION), but the check mandates FAIL
and a rebase is required.

Secondary structural failures (check-branch-forked-from-main.sh,
check-commit-trailer-task-ref.sh, check-spec-ref-valid.sh) are false positives
caused by the parallel-history repo structure and will resolve automatically
when the branch is rebased onto main.

## Required Fix

1. Rebase onto main:
     git rebase main
   Resolve the conflict in extractor/tests/test_extractor.py as described above.
   After rebase, run_tests.gd will automatically include the test_godot_app_spec.gd
   registration and pytest will pick up the full 238+ test suite.

2. Sync check scripts:
     git checkout main -- .hyperloop/checks/

3. Commit message template:
     chore(sync): rebase onto main, resolve test_extractor.py conflict

     Task-Ref: task-063
     Spec-Ref: specs/extraction/scene-graph-schema.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed

No implementation changes are required — all spec requirements are correctly
implemented and tested.