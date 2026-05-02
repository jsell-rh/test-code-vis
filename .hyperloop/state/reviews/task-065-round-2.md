---
task_id: task-065
round: 2
role: spec-reviewer
verdict: fail
---
# Spec Alignment Review: task-065 — Orthogonal Independence Visualization

## Executive Summary

The **spec implementation is complete**: every SHALL/MUST requirement in
`specs/visualization/orthogonal-independence.spec.md` is implemented in code and
covered by tests. The previous blocking finding (missing smooth-regrouping test)
has been resolved by commit `fb1c133c`. However, the branch has **two process
violations** that prevent a PASS verdict — both are rebase/check-sync failures, not
spec gaps.

---

## Process Violations (Blocking)

### 1. Branch not rebased onto origin/main — EXIT 1

```
FAIL: Branch 'hyperloop/task-065' is NOT rebased onto origin/main.

  Fork point (merge-base): 814d2f9
  origin/main HEAD:        7f08e1d
  Commits on main not in branch: 3

  9cd81e6a feat(extractor): add weight to individual cross_context and internal edges (#241)
  f9e3c9e8 process: add rebase-before-fixes and supersession note rules
  7f08e1d8 feat(extraction): extractor — edge weight annotation and aggregate cross-context edge emission (#230)
```

The previous review explicitly listed the rebase conflict in `extractor/extractor.py`
as a mandatory first step. The implementer added the missing test (correct) but did
not rebase. Merging as-is would REVERT all 3 commits above.

**Fix:** `git fetch origin main:main && git rebase origin/main`
Resolve any conflicts by keeping main's additions (the `theirs` side) and applying
task-065 changes on top. Then run `check-run-tests-suite-count.sh` and
`run-all-checks.sh`.

### 2. Missing check script — EXIT 1

```
FAIL: 1 check script(s) present on main are missing from this working tree:
  check-reposition-function-has-tween.sh
```

**Note for implementer:** Manual simulation confirms this check would EXIT 0 on this
branch — `main.gd` introduces no `_reposition_`, `_reroute_`, `_relocate_`, or
`_slide_` functions, so the script would emit:

```
OK: No repositioning/rerouting functions found in branch-modified godot/scripts/ files.
```

This is not a spec gap; it is a process violation (check was not synced from main
before committing fixes). The check is still blocking per protocol.

**Fix:** After the rebase, run:
```
git checkout origin/main -- .hyperloop/checks/
bash .hyperloop/checks/check-checks-in-sync.sh   # must exit 0
bash .hyperloop/checks/run-all-checks.sh
```

---

## Spec Requirement Coverage

Spec file: `specs/visualization/orthogonal-independence.spec.md`
Spec-Ref hash `7a839cc3` is identical at HEAD — no spec drift.

### Requirement: Independence Detection — COVERED

| THEN-clause | Implementation | Test(s) | Status |
|---|---|---|---|
| {A,B} and {C,D} identified as independent groups | `compute_independence_groups()` Union-Find per BC | `test_connected_modules_share_group`, `test_isolated_module_has_own_group` | COVERED |
| Each module carries `independence_group` in scene graph | `node["independence_group"] = f"{context_id}:{index}"` | `test_independence_group_format`, `test_build_scene_graph_assigns_independence_groups`, `test_module_node_has_independence_group` (GDScript) | COVERED |
| Fully connected context → single group | Union-Find produces single root → single index | `test_connected_modules_share_group` (all share same group) | COVERED |
| No independence separation for single group | `apply_independence_spatial_layout()` exits early when `len(groups) <= 1` | `test_single_group_positions_unchanged` | COVERED |

### Requirement: Spatial Separation of Independent Groups — COVERED

#### Scenario: Visual gap between independent groups

| THEN-clause | Implementation | Test(s) | Status |
|---|---|---|---|
| Groups occupy distinct spatial regions | Sector layout in `apply_independence_spatial_layout()` | `test_two_groups_have_distinct_positions`, `test_build_scene_graph_spatially_separates_independent_groups` | COVERED |
| Visible gap separates groups | 75% of each slice is gap (`_SECTOR_FRACTION = 0.25`) | `test_independent_groups_are_angularly_separated` (>5° gap asserted) | COVERED |
| Modules within each group remain close (max intra < min inter) | Compact arc per group (25% of slice) | `test_modules_within_group_remain_close` | COVERED |

#### Scenario: Smooth regrouping on data change

| THEN-clause | Implementation | Test(s) | Status |
|---|---|---|---|
| Nodes animate to new positions on reload | `build_from_graph()` detects `is_reload`, calls `_animate_node_to_position()`; headless: `anchor.position = new_pos`; in-tree: `Tween.tween_property(anchor, "position", new_pos, 0.5)` | `test_smooth_regrouping_updates_anchor_positions()` — calls `build_from_graph()` twice, asserts anchor identity preserved AND position changed | COVERED |
| Transition preserves spatial continuity (slide not jump) | `Tween.tween_property` when `is_inside_tree()` | UNTESTABLE in headless — architecturally correct; Tween branch confirmed present | PASS-WITH-NOTE |

**The previous FAIL is resolved.** `test_smooth_regrouping_updates_anchor_positions()`
(commit `fb1c133c`, `godot/tests/test_independence_highlight.gd`) exercises the exact
Given/When/Then conditions: initial build, fixture positions shifted, second build,
anchor identity preserved, position updated. 241 Godot tests pass (0 failures).

### Requirement: Independence as Queryable Property — COVERED

#### Scenario: Selecting a module shows its independent peers

| THEN-clause | Implementation | Test(s) | Status |
|---|---|---|---|
| Other-group modules highlighted with `INDEPENDENT_PEER_COLOR` | `highlight_independence()` assigns `INDEPENDENT_PEER_COLOR` to different-group anchors | `test_other_group_modules_highlighted_as_independent_peers`, `test_highlight_independence_covers_selected_nodes_complement` | COVERED |
| Own-group modules highlighted with `CODEPENDENT_COLOR` | `highlight_independence()` assigns `CODEPENDENT_COLOR` to same-group anchors | `test_own_group_modules_highlighted_as_codependent` | COVERED |
| Colors are visually distinct | `CODEPENDENT_COLOR != INDEPENDENT_PEER_COLOR` (static constants) | `test_codependent_and_independent_colors_are_visually_distinct` | COVERED |
| Transition animated smoothly | `_animate_mesh_color()` uses Tween in-tree, direct in headless | `test_highlight_changes_module_color_from_default`, `test_clear_independence_highlight_restores_original_colors` | COVERED |

#### Scenario: Cross-context independence

| THEN-clause | Implementation | Test(s) | Status |
|---|---|---|---|
| Contexts with no transitive dependency highlighted | `_compute_context_independence()` BFS forward+reverse; `_highlight_cross_context_independence()` applies color | `test_compute_context_independence_finds_isolated_contexts`, `test_independent_context_receives_highlight_color` | COVERED |
| Dependent contexts NOT highlighted | BFS excludes reachable contexts | `test_dependent_context_is_not_independent` | COVERED |
| selected_context excluded from its own independent set | Explicit `ctx == selected_context: continue` guard | `test_compute_context_independence_finds_isolated_contexts` (checks `not ("ctx_a" in independent)`) | COVERED |
| Clear restores context colors | `clear_independence_highlight()` restores `_independence_original_colors` | `test_clear_restores_context_highlight` | COVERED |
| Highlight animates from selected module outward | Delay increment (`delay += 0.05`) per node in `highlight_independence()` and `_highlight_cross_context_independence()` | UNTESTABLE in headless — architecturally correct | PASS-WITH-NOTE |

---

## Test Suite Counts

- GDScript behavioral tests: **241 PASS, 0 FAIL**
- Python pytest: **254 passed**
- `check-run-tests-suite-count.sh`: OK (21 >= 20)

---

## Required Actions (both required before re-review)

1. **Rebase onto origin/main:**
   ```
   git fetch origin main:main
   git rebase origin/main
   # Resolve extractor/extractor.py conflict: keep main's edge-weight additions,
   # reapply task-065's independence layout call on top.
   bash .hyperloop/checks/check-run-tests-suite-count.sh
   ```

2. **Sync check scripts from main:**
   ```
   git checkout origin/main -- .hyperloop/checks/
   bash .hyperloop/checks/check-checks-in-sync.sh   # must exit 0
   bash .hyperloop/checks/run-all-checks.sh          # must be ALL PASS
   ```

No code or test changes are needed — the spec is fully implemented and tested.