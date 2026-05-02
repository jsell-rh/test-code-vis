---
task_id: task-022
round: 2
role: verifier
verdict: fail
---
# Review Report — task-022 (Orthogonal Independence)

Branch: hyperloop/task-022
Spec: specs/visualization/orthogonal-independence.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed

---

## CHECK SYNC

```
OK: All check scripts from main are present and content-identical in working tree (62 checked).
```

Check scripts synced from `origin/main` (b10f564) before all checks were run.

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

---

## REBASE CHECK

```
OK: Branch 'hyperloop/task-022' is rebased onto origin/main (b10f564).
```

Branch is rebased onto current `origin/main`. No rebase action required.

---

## TEST SUITE COUNT

```
OK: _run_suite() count on branch (21) >= origin/main (20).
```

---

## run-all-checks.sh COMPLETE OUTPUT (summary — exit codes only)

```
check-aggregate-edge-impl.sh                        [EXIT 0]
check-assigned-spec-in-scope.sh                     [EXIT 0]  (SKIP)
check-banned-task-ids-closed.sh                     [EXIT 0]  (SKIP)
check-branch-forked-from-main.sh                    [EXIT 0]
check-branch-has-commits.sh                         [EXIT 0]  (256 commits above main)
check-branch-has-impl-files.sh                      [EXIT 0]  (6 non-.hyperloop/ files changed)
check-checks-in-sync.sh                             [EXIT 0]  (62 checks in sync)
check-circular-position-y-axis.sh                   [EXIT 0]
check-clamp-boundary-tests.sh                       [EXIT 0]
check-commit-trailer-task-ref.sh                    [EXIT 0]
check-compute-functions-called-from-entry-point.sh  [EXIT 0]
check-cycle-gate.sh                                 [EXIT 0]
check-directional-signchain-comments.sh             [EXIT 0]
check-extractor-cli-tested.sh                       [EXIT 0]
check-extractor-stdlib-only.sh                      [EXIT 0]
check-fail-report-classification.sh                 [EXIT 0]  (SKIP)
check-gdscript-only-test.sh                         [EXIT 0]
check-godot-no-script-errors.sh                     [EXIT 0]
check-individual-edge-weight.sh                     [EXIT 1 — FAIL]
check-kartograph-integration-test.sh                [EXIT 0]
check-layout-radius-bound.sh                        [EXIT 0]
check-lod-level-tests.sh                            [EXIT 0]
check-lod-opacity-animation.sh                      [EXIT 0]
check-main-local-vs-remote.sh                       [EXIT 0]
check-main-not-diverged.sh                          [EXIT 0]
check-new-modules-wired.sh                          [EXIT 0]
check-no-duplicate-toplevel-functions.sh            [EXIT 0]
check-no-gdscript-duplicate-functions.sh            [EXIT 0]
check-nondirectional-movement-assertions.sh         [EXIT 0]
check-no-prohibited-tasks-open.sh                   [EXIT 0]  (SKIP)
check-not-in-scope.sh                               [EXIT 0]
check-no-zero-commit-reattempt.sh                   [EXIT 0]
check-pass-report-no-raw-fail-lines.sh              [EXIT 0]
check-pipeline-wiring.sh                            [EXIT 0]  (SKIP)
check-preloaded-gdscript-files.sh                   [EXIT 0]  (48 preloads resolve)
check-prescribed-fixes-applied.sh                   [EXIT 0]  (SKIP)
check-prohibited-branches-deleted.sh                [EXIT 0]  (SKIP)
check-pytest-passes.sh                              [EXIT 0]  (252 passed)
check-racf-prior-cycle.sh                           [EXIT 0]
check-racf-remediation.sh                           [EXIT 0]
check-rebased-onto-main.sh                          [EXIT 0]
check-relative-position-tests.sh                    [EXIT 0]
check-report-scope-section.sh                       [EXIT 0]
check-retry-not-scope-prohibited.sh                 [EXIT 0]
check-ruff-format.sh                                [EXIT 0]
check-run-tests-suite-count.sh                      [EXIT 0]
check-scope-report-not-falsified.sh                 [EXIT 0]
check-script-skip-on-no-args.sh                     [EXIT 0]
check-spec-ref-staleness.sh                         [EXIT 0]  (no drift on orthogonal-independence spec)
check-spec-ref-valid.sh                             [EXIT 0]  (9 Spec-Refs checked; 0 unresolvable)
check-state-branch-prohibited-tasks.sh              [EXIT 0]
check-sync-divergence-impact.sh                     [EXIT 0]
check-task-ref-report-not-falsified.sh              [EXIT 0]
check-tscn-no-dangling-references.sh                [EXIT 0]
check-typeddict-fields-extractor-tested.sh          [EXIT 0]
check-worker-result-clean.sh                        [EXIT 0]
extractor-lint.sh                                   [EXIT 0]
godot-compile.sh                                    [EXIT 0]
godot-fileaccess-tested.sh                          [EXIT 0]
godot-label3d.sh                                    [EXIT 0]
godot-tests.sh                                      [EXIT 0]  (243 passed, 0 failed)
```

61 of 62 checks passed. One failed: `check-individual-edge-weight.sh`.

---

## FAILING CHECK — check-individual-edge-weight.sh (BLOCKING)

Full check output:

```
FAIL [Gate 1]: build_dependency_edges() does not emit 'weight' on
  individual cross_context / internal edges.

  The spec SHALL: 'each edge carries the import count (number of individual
  import statements between the pair).'

  Individual edge construction found at:
    463:        {"source": src, "target": tgt, "type": etype}
  but the 'weight' key is absent from those dicts.

  Required fix in build_dependency_edges():
    1. Replace the raw_edges set with a dict[tuple, int] that accumulates
       import count per (source_id, target_id, etype) triple:
         raw_edge_count: dict[tuple[str,str,str], int] = {}
         raw_edge_count[key] = raw_edge_count.get(key, 0) + 1
    2. Emit weight on each individual edge:
         {'source': src, 'target': tgt, 'type': etype, 'weight': count}

FAIL [Gate 2]: No test in extractor/tests/test_extractor.py asserts 'weight' on a
  cross_context or internal edge.

  test_aggregate_edge_has_weight covers aggregate edges only.
  A separate test is required, e.g.:

    def test_cross_context_edge_has_weight(self, src: Path) -> None:
        """Every cross_context edge carries a weight field (import count)."""
        edges = build_dependency_edges(src, nodes)
        cc_edges = [e for e in edges if e['type'] == 'cross_context']
        assert cc_edges, 'Expected at least one cross_context edge'
        for e in cc_edges:
            assert 'weight' in e, f'cross_context edge missing weight: {e}'
            assert e['weight'] >= 1, f'weight must be >= 1: {e}'

[EXIT 1 — FAIL]: Individual edge weight check failed. See details above.
```

### Root Cause Analysis

**This failure is pre-existing and was NOT introduced by task-022.**

Timeline:
- task-022 implementation commit (`a2fc520e`) was made at **2026-05-01 23:58:18 -04:00**
- `check-individual-edge-weight.sh` was added to main in commit `ad7a7d7c`
  ("fix(process): enforce all-variants field coverage") at **2026-05-02 02:33:06 -04:00**
- The branch was subsequently rebased onto main (b10f564) which brought in the new check

**The check was added 2.5 hours AFTER the implementation commit.** This is a post-submit
race condition: the implementer committed before the check existed. The rebase brought in
the check, which now surfaces a pre-existing gap in `build_dependency_edges()` (introduced
in task-003, commit `d0db6021`). Task-022 did NOT modify `build_dependency_edges()`.

**check-sync-divergence-impact.sh exited 0** — no DIVERGENT scripts. The script does not
catch post-submit race conditions for checks added to main after the implementation commit
but brought in by a subsequent rebase.

### Scope Assessment

The failing requirement — "each edge carries the import count" — is from
`specs/extraction/code-extraction.spec.md`, NOT from the task-022 assigned spec
(`specs/visualization/orthogonal-independence.spec.md`). The orthogonal-independence spec
contains no requirement about edge weight fields on individual edges.

**However, the check fails on the current branch regardless of cause.** The automated
suite is blocking, and the implementer must address this to obtain a PASS.

### Required Fix

The implementer must add `weight` to individual edge construction in `build_dependency_edges()`
and add a test asserting `weight` on `cross_context` or `internal` edges:

**extractor/extractor.py** — replace the raw_edges set with a weight-accumulating dict,
then emit `'weight'` on each individual edge (see check output above for exact pattern).

**extractor/tests/test_extractor.py** — add `test_cross_context_edge_has_weight()` (or
similar) asserting that each `cross_context` edge has a `weight >= 1`.

After making these changes, sync the checks and rerun:
```sh
git checkout origin/main -- .hyperloop/checks/
bash .hyperloop/checks/check-individual-edge-weight.sh
bash .hyperloop/checks/run-all-checks.sh
```

Commit message template:
```
fix(extraction): emit weight on individual cross_context and internal edges

build_dependency_edges() now accumulates per-pair import counts and embeds
the weight field on every individual edge (cross_context and internal),
matching the contract already implemented for aggregate edges.

Fixes check-individual-edge-weight.sh Gate 1 and Gate 2.

Task-Ref: task-022
Spec-Ref: specs/visualization/orthogonal-independence.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed
```

---

## COMMIT TRAILERS

- Spec-Ref: `specs/visualization/orthogonal-independence.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed` — resolves ✓
- Task-Ref: `task-022` — present on implementation commit ✓

---

## SPEC-DRIFT CHECK

```
OK (no drift): specs/visualization/orthogonal-independence.spec.md is identical
at Spec-Ref (7b9391479f56416ec06f248e0321b956bdb5f8ed) and HEAD.
```

No drift on the assigned spec. Drift detected on other specs (understanding-modes,
index, godot-application, nfr) is from previous tasks; none affect task-022 scoring.

---

## THEN-CLAUSE COVERAGE TABLE (task-022 spec — all COVERED)

### Requirement: Independence Detection

| THEN-clause | Status | Covering tests |
|---|---|---|
| {A,B} and {C,D} identified as independent groups | COVERED | `test_connected_modules_share_group`, `test_isolated_module_has_own_group` (pytest) |
| Each module carries its group identifier in the scene graph | COVERED | `test_independence_group_format`, `test_build_scene_graph_assigns_independence_groups` (pytest); `test_module_nodes_carry_independence_group` (GDScript) |
| Fully connected context → single group | COVERED | `test_connected_modules_share_group` (pytest) |
| No independence separation applied for single group | COVERED | `test_single_group_positions_unchanged` (pytest) |

### Requirement: Spatial Separation of Independent Groups

| THEN-clause | Status | Covering tests |
|---|---|---|
| Groups occupy distinct spatial regions | COVERED | `test_two_groups_have_distinct_positions` (pytest — centroid distance > threshold); `test_independent_groups_have_distinct_positions_in_scene_graph` (GDScript) |
| Visible gap separates groups | COVERED | `test_independent_groups_are_angularly_separated` (pytest); `test_independent_groups_are_angularly_separated_in_scene` (GDScript) |
| Modules within each group remain close (coupling-aware layout applies within groups) | COVERED | `test_modules_within_group_remain_close` (pytest); `test_modules_in_same_group_are_closer_than_cross_group` (GDScript) |
| Nodes animate smoothly to new positions on data change | COVERED | `test_smooth_regrouping_animates_position_on_reload` (GDScript — anchor identity preserved; Tween path architecturally wired, headless-untestable for timing) |
| Transition preserves spatial continuity (slide not jump) | COVERED | Same test — anchor identity preservation is the testable proxy |

### Requirement: Independence as Queryable Property

| THEN-clause | Status | Covering tests |
|---|---|---|
| Modules in other independence groups highlighted | COVERED | `test_independent_peers_are_highlighted` (GDScript — asserts INDEPENDENT_COLOR on MeshInstance3D, not just dict key) |
| Modules in A's own group distinguished as co-dependent | COVERED | `test_codependent_modules_distinguished` (GDScript — asserts CODEPENDENT_COLOR on mesh node) |
| Transition between default and highlighted states is animated | COVERED | `test_independence_highlight_transition_animates_opacity` (GDScript — color differs from default; Tween modulate.a path wired for in-tree use; PASS-WITH-NOTE: animation timing is headless-untestable) |
| Bounded contexts with no transitive dependency highlighted as fully independent | COVERED | `test_cross_context_independent_bcs_highlighted` (GDScript — billing BC receives BC_INDEPENDENT_COLOR) |
| Highlight animates from selected module outward | COVERED | Implementation uses `tween_property(anchor, "modulate:a", 1.0, ...)` in-tree; headless test verifies color application; architecture is correct (PASS-WITH-NOTE: animation timing headless-untestable) |

**All task-022 THEN-clauses: COVERED.**

---

## ONREADY NULL-GUARD AUDIT

`independence_overlay.gd` has no `@onready` variables. The `apply_independence_highlight()`
function operates on `anchors` (a plain Dictionary passed as argument) and `_graph` (set
during `build_from_graph()`). Null-guards at lines 84 and 131 are on dictionary lookups
(`anchors.get(node_id) as Node3D`) — safe, not @onready short-circuits. No test paths are
gated on an @onready null-guard.

---

## IMPLEMENTATION QUALITY NOTES

**Extractor:**
- `compute_independence_groups()` uses Union-Find (iterative BFS from each module,
  merging components via transitive internal edges). Correct algorithm.
- `apply_independence_spatial_layout()` uses angular sector allocation with 15° inter-group
  gap, intra-group spread capped at 30°, proportional arc allocation. Positions stored as
  local offsets (relative to parent BC origin), matching the `compute_layout()` contract.
  All type hints present. Ruff passes.
- Wired into `build_scene_graph()` at step 6b, after `compute_independence_groups()`.

**Godot:**
- `independence_overlay.gd` implements all color roles (INDEPENDENT, CODEPENDENT, SELECTED,
  BC_INDEPENDENT). Tween modulate.a used for in-tree animation; synchronous direct assignment
  for headless tests.
- Cross-context reachability via reverse BFS from selected BC — finds all BCs that transitively
  receive imports from the selected module's context. Architecturally correct.
- `apply_independence_for()` public API wired into `main.gd` for test access.
- 13 GDScript tests in `test_orthogonal_independence.gd`, registered in `run_tests.gd`.
- No dangling scene references. No duplicate functions. Godot compiles clean.

---

## VERDICT

**FAIL**

The sole blocking issue is `check-individual-edge-weight.sh` (EXIT non-zero).

**Root cause:** `build_dependency_edges()` emits `weight` only on aggregate edges; individual
`cross_context` and `internal` edges lack the field. This is a pre-existing gap from task-003
that task-022 did not introduce or modify. The check was added to main 2.5 hours after the
task-022 implementation commit and surfaced during rebase.

**Required action:** Fix `build_dependency_edges()` to accumulate per-pair import counts and
emit `'weight'` on each individual edge. Add a test asserting `weight` on at least one
`cross_context` or `internal` edge. See the Required Fix section above for exact changes.

**All task-022 spec requirements are fully implemented and tested.** The implementation
is of high quality and correctly satisfies every THEN-clause in
`specs/visualization/orthogonal-independence.spec.md`. Once the individual edge weight
fix is committed, a re-review should PASS with no remaining issues.