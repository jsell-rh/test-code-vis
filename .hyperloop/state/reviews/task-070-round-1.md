---
task_id: task-070
round: 1
role: verifier
verdict: fail
---
# Review — task-070 — Orthogonal Independence Visualization (Round 2 / Fix Attempt)

## Pre-flight

### Check Sync
`git fetch origin main` completed. `git checkout origin/main -- .hyperloop/checks/` succeeded.
`check-checks-in-sync.sh` → OK: All 68 check scripts present and content-identical.

### check-main-local-vs-remote.sh → FAIL (worktree artifact, see below)
Local main (4e35b6ae) ≠ origin/main (9cd81e6a). This divergence is a worktree
artifact: main is checked out in the parent tree so `git fetch origin main:main`
was rejected. `check-sync-divergence-impact.sh` → OK (no stale scripts): all 68
scripts in the working tree match origin/main content. No implementation impact.

### check-rebased-onto-main.sh → **FAIL** (substantive)

```
FAIL: Branch 'hyperloop/task-070' is NOT rebased onto origin/main.

  Fork point (merge-base): 814d2f9
  origin/main HEAD:        9cd81e6
  Commits on main not in branch: 1

  Fix:
    git fetch origin main:main
    git rebase origin/main
    bash .hyperloop/checks/check-run-tests-suite-count.sh
    bash .hyperloop/checks/run-all-checks.sh
```

Missing commit: `9cd81e6a feat(extractor): add weight to individual cross_context and
internal edges (#241)` — Task-Ref: task-067

Files touched by missing commit:
  - `extractor/extractor.py` — changes `raw_edges` set to `raw_edge_count` dict;
    adds `weight` field to every individual cross_context and internal edge.
  - `extractor/tests/test_extractor.py` — adds tests for the weight field.

**Classification: STANDARD REBASE FAIL** — the missing commit touches
implementation files (`extractor/`), not only `.hyperloop/state/` or process
files. This is NOT a process-only race condition. The implementer must rebase
and resolve the conflict in `extractor/extractor.py`.

The conflict arises because this branch also modifies `extractor/extractor.py`
(adding `compute_independence_groups()` and related logic). The rebased version
must preserve BOTH the task-067 weight field changes (incoming `--theirs` side
on the `raw_edge_count` refactor) AND the task-070 independence-groups logic
(this branch's additions). These changes are in different function regions and
should resolve cleanly once the implementer understands both sides.

---

## Scope Check Output
OK: No prohibited (not-in-scope) features detected.

---

## run-all-checks.sh Output (summary)

Exit code: 1. Failing checks:
- check-main-local-vs-remote.sh: FAIL (DIVERGED) — worktree artifact, benign (see above)
- check-rebased-onto-main.sh: FAIL — branch not rebased onto origin/main (substantive)

All other checks: PASS. Key passing checks:
- check-not-in-scope.sh: OK
- check-branch-has-impl-files.sh: OK (5 non-.hyperloop/ files changed)
- check-commit-trailer-task-ref.sh: OK (Task-Ref: task-070 present)
- check-compute-functions-called-from-entry-point.sh: OK (7 compute_* called)
- check-highlight-function-has-tween.sh: OK (create_tween present in independence_controller.gd / independence_query.gd)
- check-no-gdscript-duplicate-functions.sh: OK
- check-tscn-no-dangling-references.sh: OK
- check-godot-no-script-errors.sh: OK — zero test failures, zero SCRIPT ERRORs
  (NOTE: runtime "ERROR: The tweened property 'modulate:a' does not exist in
  object Node3D" lines appear in the output but originate from pre-existing
  lod_manager.gd and main.gd code — not from independence_query.gd. The check
  correctly filters these as renderer memory-leak messages, not SCRIPT ERRORs.)
- check-no-vacuous-iteration.sh: OK
- check-typeddict-fields-extractor-tested.sh: OK
- check-run-tests-suite-count.sh: OK (21 suites ≥ 20 on origin/main)
- check-pytest-test-count.sh: SKIP (origin/main has 0 extractor tests to compare)
- Ruff lint: All checks passed. Ruff format: 8 files already formatted.
- check-lod-opacity-animation.sh: Not applicable (branch does not modify LOD files)
- check-lod-level-tests.sh: Not applicable
- check-aggregate-edge-impl.sh: Not applicable
- check-edge-rerouting-wired.sh: Not applicable (no collapse/expand code)

---

## Deliverable Verification

Files changed on branch (git diff --name-only main..HEAD):
- extractor/extractor.py (+158/-31)
- extractor/tests/test_extractor.py (+332)
- godot/scripts/independence_query.gd (+261 original + 102 fix = 363 net)
- godot/tests/run_tests.gd (+7)
- godot/tests/test_orthogonal_independence.gd (+498 original + 117 fix = 615 net)
- .hyperloop/state/intake-2026-05-02.md (process only)
- .hyperloop/state/resolved-specs.json (process only)

Both Python extractor and Godot components delivered. ✓

Commits:
- aeb9c111 feat(task-070): implement orthogonal independence visualization
- 33a19d07 fix(task-070): add Tween animation and BFS-staggered outward highlight

---

## Spec-Drift Detection

check-spec-ref-staleness.sh → OK (no drift):
specs/visualization/orthogonal-independence.spec.md is identical at
Spec-Ref (7a839cc3) and HEAD. All THEN-clauses scored below are present
in the committed spec.

check-spec-ref-matches-task.sh → SKIP (task-070.md not in tasks directory).
Spec-Ref trailer: `specs/visualization/orthogonal-independence.spec.md@7a839cc34dd8...` ✓

---

## Prior FAIL Findings — Resolution Status

### Finding 1 (prior): _apply_node_color() had no Tween → RESOLVED ✓

Fix commit adds `is_inside_tree()` branch to `_apply_node_color()`:
- Inside scene tree: `create_tween()` → `tween_property(mesh,
  "material_override:albedo_color", color, 0.3)` — correct 3D animation path
  (NOT modulate:a which requires CanvasItem — the impl correctly uses the
  MeshInstance3D material albedo_color channel)
- Outside tree (headless/tests): instant `mat.albedo_color = color`

check-highlight-function-has-tween.sh confirms `create_tween` is present.
Test `test_independence_highlight_animated` verifies headless path applies
correct color at full opacity. PASS-WITH-NOTE: Tween path is architecturally
correct; untestable in headless CI.

### Finding 2 (prior): apply_context_independence_highlight() no BFS propagation → RESOLVED ✓

Fix commit adds `_compute_context_hop_distances()` (BFS from selected context
via undirected adjacency) and uses staggered Tween delays:
  `delay = hop_distances.get(ctx_id, 0) * 0.15  # 0.15 s per hop`
- Inside scene tree: per-context Tween with `tween_interval(delay)` then
  `tween_property(mesh, "material_override:albedo_color", CONTEXT_INDEPENDENT_COLOR, 0.3)`
- Outside tree: instant `_apply_node_color(anchor, CONTEXT_INDEPENDENT_COLOR)`

New tests:
- `test_compute_context_hop_distances_correct` — verifies BFS distances
  (origin=0, direct neighbour=1, transitive=2) from a 3-context fixture
- `test_context_highlight_headless_colors_all_independent` — verifies the
  instant-path colors all independent contexts cyan in headless mode

Architecture is correct. PASS-WITH-NOTE: staggered Tween timing is
untestable in headless CI; the BFS computation itself is verified.

---

## THEN-Clause Coverage Audit (post-fix)

### Requirement: Independence Detection

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| {A,B}/{C,D} identified as independent groups | COVERED | test_two_independent_clusters_identified (pytest) |
| each module carries group identifier in scene graph | COVERED | test_each_module_carries_group_id_in_scene_graph (pytest) + test_independence_group_preserved_on_node (GDScript) |
| fully connected context is single group | COVERED | test_fully_connected_context_is_single_group (pytest) |
| no independence separation applied (single group) | COVERED | single-group triggers single-circle layout in compute_layout() |

### Requirement: Spatial Separation of Independent Groups

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| groups occupy distinct spatial regions | COVERED | test_independent_groups_spatially_separated_in_scene (GDScript) — asserts cross_dist > within_dist |
| visible gap separates groups | COVERED | same test (cross_dist > within_dist guarantees gap) |
| modules within each group remain close | COVERED | same test verifies intra-group distances < inter-group distances |
| nodes animate smoothly to new positions (reload) | PASS-WITH-NOTE | test_smooth_regrouping_preserves_spatial_continuity (GDScript) — two build_from_graph calls, position asserted; Tween path untestable in headless |
| transition preserves spatial continuity (slide not jump) | COVERED | same test — asserts anchor object is REUSED (same Node3D object), position.x = new value |

### Requirement: Independence as Queryable Property

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| modules in other groups highlighted | COVERED | test_independent_modules_highlighted (GDScript) — asserts INDEPENDENT_COLOR on group-1 modules |
| A's own group visually distinguished as co-dependent | COVERED | test_codependent_modules_distinguished (GDScript) — asserts CODEPENDENT_COLOR on group-0 peers |
| transition animated smoothly (module highlight) | PASS-WITH-NOTE | test_independence_highlight_animated (GDScript) — verifies headless path; Tween exists in is_inside_tree() branch |
| cross-context independent peers highlighted | COVERED | test_cross_context_independence_highlighted (GDScript) — context_z gets CONTEXT_INDEPENDENT_COLOR; context_y (transitive dep) does NOT |
| highlight animates in from selected module outward | PASS-WITH-NOTE | BFS impl in _compute_context_hop_distances() + staggered tween_interval(delay) — architecture correct; test_compute_context_hop_distances_correct verifies BFS; headless timing untestable |

---

## Required Fix

The ONLY required action is a rebase onto origin/main and conflict resolution
in extractor/extractor.py.

### What to keep from origin/main (task-067):
The incoming commit refactors `raw_edges: set` → `raw_edge_count: dict` and adds
`"weight": count` to every individual edge dict. Keep this refactoring intact.

### What to keep from this branch (task-070):
The independence-groups logic: `compute_independence_groups()`, its call at
line ~1776, and the `"independence_group"` field assignment. These are in
different functions from the task-067 weight changes and should resolve cleanly.

### Fix commands:
```
git fetch origin main:main   # only works if main is not checked out locally;
                              # alternatively: git fetch origin
git rebase origin/main
# Resolve extractor/extractor.py: keep BOTH the raw_edge_count weight refactor
# from task-067 AND the independence_groups additions from task-070.
# After resolving:
git add extractor/extractor.py
git rebase --continue
bash .hyperloop/checks/check-run-tests-suite-count.sh
bash .hyperloop/checks/run-all-checks.sh
```

No changes to Godot files or tests are needed — all implementation issues
from the prior FAIL are fully resolved.

---

## Summary

| Item | Result |
|------|--------|
| check-rebased-onto-main.sh | FAIL — missing task-067 commit (implementation files) |
| check-main-local-vs-remote.sh | FAIL — worktree artifact (benign, check-sync-divergence-impact OK) |
| All other 66 checks | PASS |
| Finding 1 (prior): no Tween on module highlight | RESOLVED — PASS-WITH-NOTE |
| Finding 2 (prior): no BFS outward animation | RESOLVED — PASS-WITH-NOTE |
| All THEN-clauses (committed spec) | COVERED or PASS-WITH-NOTE |
| Commit trailers (Spec-Ref + Task-Ref) | PRESENT |

**Verdict: FAIL**

Sole reason: the branch is not rebased onto origin/main. The missing commit
(9cd81e6a, task-067) touches extractor/extractor.py and
extractor/tests/test_extractor.py — implementation files — so this is a
standard FAIL, not a process-only race. The implementation is otherwise
correct and complete; no implementation changes are needed beyond the rebase
conflict resolution.