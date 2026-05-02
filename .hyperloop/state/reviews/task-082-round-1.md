---
task_id: task-082
round: 1
role: verifier
verdict: fail
---
# Review — task-082 — Extractor: structural significance (hub, bridge, peripheral, community)

## Scope Check Output

NOTE: Pre-existing prohibited spec-extraction code in extractor/extractor.py (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
NOTE: Pre-existing prohibited spec-extraction tests in extractor/tests/ (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
OK: No prohibited (not-in-scope) features detected.

---

## Check Sync

check-checks-in-sync.sh:
OK: All check scripts from main are present and content-identical in working tree (71 checked).
EXIT 0

---

## run-all-checks.sh Summary

All 71 checks ran. Five checks exited non-zero:

| Check | Exit | Classification |
|---|---|---|
| check-class-test-count.sh | FAIL | Rebase regression — implementer |
| check-main-local-vs-remote.sh | FAIL | Orchestrator configuration |
| check-main-not-diverged.sh | FAIL | Orchestrator configuration |
| check-rebased-onto-main.sh | FAIL | Standard rebase fail — implementer |
| check-run-tests-suite-count.sh | FAIL | Rebase regression — implementer |
| All other 66 checks | EXIT 0 | — |

**check-main-local-vs-remote.sh / check-main-not-diverged.sh — ORCHESTRATOR CONFIGURATION:**
Local main (3573ae32) is 4 commits ahead and 1 commit behind origin/main (354babde). All 4 extra
local commits touch only `.hyperloop/` process files. The 1 missing origin/main commit is the
Port Primitive renderer (PR #240, task-038). Fix is `git merge origin/main && git push origin main`
on the main worktree — not the implementer's responsibility. These two failures are excluded from
the FAIL verdict against the implementer.

---

## Rebase Check

```
check-rebased-onto-main.sh:
FAIL: Branch 'hyperloop/task-082' is NOT rebased onto origin/main.

  Fork point (merge-base): 51d1aaf5b5155d7b445963deaca2b7e6a5c5dcc8
  origin/main HEAD:        354babdecdfb2101cddb9cb09ead7dcea15d7edf
  Commits on main not in branch: 1

  RISK: Merging this branch as-is would REVERT all 1 commit(s)
  that main added after 51d1aaf.
EXIT: 1
```

Missing commits (git log 51d1aaf..origin/main --oneline):
```
354babde feat(godot): render Port primitives on Container membrane (public symbol interface points) (#240)
```

**Classification: STANDARD REBASE FAIL.**
Commit 354babde (task-038, PR #240) touches implementation files:
- `godot/scripts/port_renderer.gd` (316 lines, new file — canonical Port Primitive renderer)
- `godot/scripts/main.gd` (95 lines added — wires port_renderer.gd)
- `godot/tests/run_tests.gd` (adds test_port_renderer.gd suite registration)
- `godot/tests/test_port_renderer.gd` (802 lines, new file — behavioral tests)
- `extractor/tests/test_extractor.py` (120 lines added — 2 new test functions)

This is NOT a process-only advance. The missing commit implements the same feature
(Port Primitive rendering) as branch commit 92a2b9c6.

**FEATURE-SUPERSESSION:**
ORCHESTRATOR NOTE: Commit 354babde (task-038, PR #240) on origin/main implements overlapping
functionality with this branch's commit 92a2b9c6. Both implement Port Primitive rendering in Godot.
After the implementer rebases and resolves conflicts, evaluate:
1. Whether the branch's render_ports() in visual_primitives.gd is still needed alongside task-038's
   port_renderer.gd, or should the branch's Port Primitive Godot work be dropped in favor of the
   canonical task-038 implementation.
2. Whether the branch's structural significance test (commit 55310831) is the full deliverable for
   task-082, given that compute_structural_significance() already existed on origin/main at the
   fork point (51d1aaf).
Conflict regions: `godot/scripts/main.gd` (both sides added Port Primitive wiring in different styles);
`extractor/tests/test_extractor.py` (task-038 added 120 lines that include the 2 missing tests).

---

## Test Suite Counts

```
check-run-tests-suite-count.sh:
FAIL: Branch has fewer _run_suite() registrations than origin/main.
  origin/main: 22 _run_suite() call(s)
  This branch: 21 _run_suite() call(s)
  Missing:     1 suite(s)
EXIT: 1

Missing suite identified via diff:
  _run_suite(preload("res://tests/test_port_renderer.gd").new())
  — added by 354babde (task-038, PR #240) to godot/tests/run_tests.gd
```

```
check-pytest-test-count.sh:
OK: Python test count on branch (8) >= origin/main (8).
EXIT: 0
```

```
check-class-test-count.sh:
FAIL: Branch has fewer all-test functions (class-method-inclusive) than origin/main.
  origin/main: 266 'def test_' occurrence(s) in extractor/tests/
  This branch: 265 'def test_' occurrence(s) in extractor/tests/
  Missing:     1 test(s)
EXIT: 1
```

Detail — tests on origin/main absent from branch (both added by 354babde, task-038, in
extractor/tests/test_extractor.py):
1. test_cross_context_edge_weight_accumulates_for_multiple_imports
2. test_internal_edge_weight_accumulates_for_multiple_imports

Tests on branch but NOT on origin/main (new in this branch, added by commit 55310831):
1. test_betweenness_centrality_is_float_not_bool

Net: -2 (from main) + 1 (new) = -1. check-class-test-count.sh fails (265 vs 266).
This is a rebase regression. No commit on this branch documents intentional scope-correct
test removal with the phrase "intentional and scope-correct — not a rebase regression."

---

## Commit Trailers

Branch commits (3 above origin/main):

| Commit | Subject | Task-Ref | Spec-Ref |
|---|---|---|---|
| 5aaead06 | fix(visual-primitives): add missing badge vocabulary tests | task-082 PRESENT | visual-primitives@67df14bc PRESENT |
| 55310831 | feat(extractor): structural significance hub/bridge/peripheral/community | task-082 PRESENT | visual-primitives@67df14bc PRESENT |
| 92a2b9c6 | feat(visual-primitives): implement Port Primitive renderer in Godot | task-082 PRESENT | visual-primitives@67df14bc PRESENT |

Spec-Ref hash (67df14bc) vs task definition hash (82d048ec): `git diff 82d048ec 67df14bc`
produces zero output — spec content is identical at both hashes. No discrepancy.

---

## Spec-Ref / Spec-Section Audit

check-spec-ref-matches-task.sh: SKIP (task file not found in working-tree .hyperloop/state/ — state
managed on hyperloop/state branch). Task definition read from local file: title confirms
"Extractor — structural significance (hub, bridge, peripheral, community)".
Assigned spec section: §Requirement: Structural Significance Extraction.

check-spec-ref-staleness.sh:
OK (no drift): specs/core/visual-primitives.spec.md is identical at Spec-Ref
(67df14bc9137e80de5a60d12dad7f77c7d995959) and HEAD.
SUMMARY: No spec drift detected.

**Spec Section vs Task Title Audit:**
Task title: "Extractor — structural significance (hub, bridge, peripheral, community)"
Assigned section: §Requirement: Structural Significance Extraction

Branch deliverables:
- Commit 92a2b9c6: Godot Port Primitive renderer (§Requirement: Port Primitive — DIFFERENT section)
- Commit 55310831: 1 test added to test_extractor.py for structural significance (correct section)
- Commit 5aaead06: Badge vocabulary tests (§Requirement: Badge Primitive — DIFFERENT section)

The branch implements two wrong-section features (Port Primitive + Badge vocabulary) alongside
a thin contribution to the assigned section (1 additional test). However, see the pre-existing
implementation note below.

---

## Structural Significance — Pre-Existing Implementation Assessment

compute_structural_significance() was verified present at the fork point (51d1aaf):

```
git show 51d1aaf:extractor/extractor.py | grep "def compute_structural_significance"
→ def compute_structural_significance(nodes: list[Node], edges: list[Edge]) -> None:
```

The function implements all four assigned scenarios:
- Hub detection: in_degree counted, is_hub flagged
- Bridge detection: betweenness_centrality (float, via _compute_betweenness returning dict[str, float]),
  is_bridge flagged, is_landmark set
- Peripheral detection: in_degree==0 and out_degree<=1 → is_peripheral flagged
- Community detection: community_id assigned (union-find), community_drift flagged for cross-context components

Tests for all four scenarios were pre-existing on origin/main at the fork point. The branch's commit
55310831 adds one new test (test_betweenness_centrality_is_float_not_bool) to enforce that
betweenness_centrality stores a numeric float rather than a boolean. This is the branch's sole
substantive contribution to the assigned task.

check-compute-functions-called-from-entry-point.sh confirms compute_structural_significance() is
called from build_scene_graph().

ORCHESTRATOR NOTE: The assigned Python extractor work for task-082 appears to have been completed
by a prior task before this branch was created. The branch's structural significance contribution
is one additional type-guard test. Evaluate whether this constitutes sufficient task completion,
or whether task-082 should be closed as superseded by the pre-existing implementation.

---

## Requirements Coverage Table

Spec: specs/core/visual-primitives.spec.md (§Requirement: Structural Significance Extraction)
at Spec-Ref 67df14bc.

| Scenario | THEN-clause | Status | Evidence |
|---|---|---|---|
| Hub detection | Module annotated with high in-degree, flagged as hub | COVERED (pre-existing on main) | test_hub_node_flagged_with_high_in_degree, test_in_degree_counts_incoming_edges, test_hub_detection_high_in_degree — all present on branch and origin/main |
| Bridge detection | Module annotated with betweenness centrality score, flagged as bridge | COVERED (pre-existing on main) | test_bridge_node_flagged_as_articulation_point, test_betweenness_centrality_computed, test_betweenness_centrality_is_float_not_bool (NEW by branch) |
| Peripheral detection | Module annotated as peripheral, candidate for de-emphasis | COVERED (pre-existing on main) | test_peripheral_node_flagged, test_peripheral_detection |
| Community detection | Each module annotated with community_id | COVERED (pre-existing on main) | test_community_ids_assigned_to_all_nodes, test_community_id_assigned_to_modules |
| Community detection | Detected communities compared to package structure | COVERED (pre-existing on main) | test_community_drift_detected_for_cross_context_component, test_no_community_drift_within_single_context |
| Community detection | community_drift flagged | COVERED (pre-existing on main) | test_community_drift_detected_for_cross_context_component |
| Landmark derivation | Hubs, bridges, entry points become landmarks | COVERED (pre-existing on main) | test_hub_is_marked_landmark, test_bridge_is_marked_landmark, test_entry_point_is_marked_landmark |

All §Structural Significance Extraction scenarios are COVERED — by pre-existing code and tests on
origin/main. The branch does not remove any of this coverage.

---

## Findings Summary

### Blocking (Implementer Must Resolve)

1. **check-rebased-onto-main.sh FAIL** — STANDARD REBASE FAIL.
   Commit 354babde (task-038, PR #240) on origin/main touches implementation files across
   godot/ and extractor/tests/. Branch must be rebased. Conflicts expected in
   `godot/scripts/main.gd` (Port Primitive wiring) and `extractor/tests/test_extractor.py`.

2. **check-run-tests-suite-count.sh FAIL** — 21 vs 22 _run_suite() calls.
   Missing: `_run_suite(preload("res://tests/test_port_renderer.gd").new())`.
   Added by 354babde. Must be preserved from main during rebase.

3. **check-class-test-count.sh FAIL** — 265 vs 266 all-inclusive Python tests.
   Missing 2 tests added by 354babde (task-038):
   - test_cross_context_edge_weight_accumulates_for_multiple_imports
   - test_internal_edge_weight_accumulates_for_multiple_imports
   Not documented as intentional. Must be preserved from main during rebase.

### Non-Blocking (ORCHESTRATOR CONFIGURATION)

4. check-main-local-vs-remote.sh / check-main-not-diverged.sh — local main has diverged
   from origin/main. Fix: `git merge origin/main && git push origin main` on main worktree.
   Implementer cannot resolve this.

---

## Required Actions for Next Attempt

```
git fetch origin main:main
git rebase origin/main
```

During conflict resolution:
- `godot/scripts/main.gd`: Keep task-038's port_renderer.gd wiring from main (the `theirs` side)
  for Port Primitive wiring. The branch's render_ports() calls in visual_primitives.gd may be
  dropped (task-038's port_renderer.gd is the canonical implementation now on main). Apply
  only the structural significance work (if any) on top.
- `extractor/tests/test_extractor.py`: Preserve the 2 tests added by task-038
  (test_cross_context_edge_weight_accumulates_for_multiple_imports and
  test_internal_edge_weight_accumulates_for_multiple_imports). Keep the branch's new test
  (test_betweenness_centrality_is_float_not_bool) as well.
- `godot/tests/run_tests.gd`: Accept main's version (adds test_port_renderer.gd suite).

After rebase:
```
bash .hyperloop/checks/check-run-tests-suite-count.sh   # must exit 0
bash .hyperloop/checks/check-class-test-count.sh        # must exit 0
bash .hyperloop/checks/check-rebased-onto-main.sh       # must exit 0
bash .hyperloop/checks/run-all-checks.sh
```