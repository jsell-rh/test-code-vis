---
task_id: task-065
round: 4
role: spec-reviewer
verdict: fail
---
## Scope Check Output

```
NOTE: Pre-existing prohibited spec-extraction code in extractor/extractor.py (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
NOTE: Pre-existing prohibited spec-extraction tests in extractor/tests/ (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
OK: No prohibited (not-in-scope) features detected.
```

Exit code: 0 (PASS — the previous false positive is now fixed; check-not-in-scope.sh uses branch
attribution and correctly identifies the spec-extraction code as pre-existing on main.)

## Summary

FAIL on two genuine blocking checks. All spec requirements for
`specs/visualization/orthogonal-independence.spec.md` are implemented and largely tested,
but 3 tests were dropped during conflict resolution with task-243 (commit e6bfa2f2 on main),
and the branch remains un-rebased onto origin/main.

## Blocking Failures

### 1. check-rebased-onto-main.sh — FAIL (GENUINE, third consecutive cycle)

```
FAIL: Branch 'hyperloop/task-065' is NOT rebased onto origin/main.
  Fork point (merge-base): 9a83afd
  origin/main HEAD:        a6367113
  Commits on main not in branch: 8
```

The previous two review cycles both required this rebase. It has still not been done.
The branch forks from `9a83afdb` (unchanged from last review at `7f08e1d`; note: an additional
commit was added to the branch — the ruff-format commit — but no rebase was performed).

### 2. check-checks-in-sync.sh — FAIL

```
FAIL: 1 check script(s) present on main are missing from this working tree:
  check-class-test-count.sh
```

`check-class-test-count.sh` was added to main after this branch's fork point. The re-attempt
protocol (Sync Point 0) requires syncing check scripts from main before any other work.
This was not done.

### 3. check-class-test-count.sh (missing from branch, would FAIL if run)

Running the check fetched from main reveals the branch has **3 fewer all-inclusive test
functions** than origin/main (branch: 261, main: 264, delta: −3).

Root cause — rebase regression: Commit `e6bfa2f2` on main ("independence group: spatial
rendering and group tinting", a different task, task-243) added 8 tests to
`extractor/tests/test_extractor.py`. When the implementer attempted prior conflict
resolution, 5 of those tests were dropped and only 2 replacements were added:

Tests DROPPED (on main, missing from branch):
- `test_fully_connected_context_is_single_group` — directly tests spec scenario "Fully
  connected context" (cycle A→B→C→A → all in one group). **No equivalent exists on the
  branch** (see spec coverage gap below).
- `test_each_module_carries_group_id_in_scene_graph` — tests `build_scene_graph()` output
  contains `independence_group` on module nodes. The branch's
  `test_build_scene_graph_assigns_independence_groups` covers the same predicate; this
  particular dropped test is compensated.
- `test_cross_context_edge_has_weight` (one of two class-level duplicates dropped)
- `test_internal_edge_has_weight` (one of two class-level duplicates dropped)
- `test_cross_context_edge_weight_counts_imports`

Tests ADDED to branch (not on main):
- `test_modules_within_group_remain_close` (NEW — covers spec)
- `test_single_group_positions_unchanged` (NEW — covers spec)

Net: −5 dropped + 2 added = −3 tests.

### 4. check-main-local-vs-remote.sh — FAIL (ORCHESTRATOR ERROR, non-blocking for implementer)

```
FAIL (ORCHESTRATOR): local main (fad87d0d) is AHEAD of origin/main (a6367113).
```

The check script itself classifies this as an orchestrator configuration error:
"Implementers cannot resolve this — 'git fetch origin main:main' cannot rewind local main."
This failure is NOT attributed to the implementer and does NOT block a pass by itself.

## Spec Requirements Coverage

| Requirement | Scenario | Implementation | Test | Status |
|---|---|---|---|---|
| Independence Detection: identify independent groups | Two independent clusters | `compute_independence_groups()` — union-find on internal edges per BC | `test_connected_modules_share_group`, `test_isolated_module_has_own_group` | COVERED |
| Independence Detection: identify independent groups | Fully connected context → single group | Same `compute_independence_groups()` — cycle detection via union-find | `test_single_group_positions_unchanged` covers spatial no-op; **NO explicit test asserts a cycle produces exactly one group** | PARTIAL |
| Independence Detection: module carries group identifier | Module nodes carry `independence_group` field | `node["independence_group"] = f"{context_id}:{root_to_index[root]}"` at line 564 | `test_build_scene_graph_assigns_independence_groups`, `test_independence_group_format` | COVERED |
| Spatial Separation: visible gap between independent groups | Visual gap between groups | `apply_independence_spatial_layout()` — angular sector placement (25% sector / 75% gap) | `test_two_groups_have_distinct_positions`, `test_independent_groups_are_angularly_separated`, `test_build_scene_graph_spatially_separates_independent_groups` | COVERED |
| Spatial Separation: modules within each group remain close | Coupling-aware intra-group layout | Sector fraction ensures cross-group > intra-group distance | `test_modules_within_group_remain_close` | COVERED |
| Spatial Separation: smooth regrouping on data change | Animate to new positions | `build_from_graph()` updates anchor positions via `_animate_node_to_position()` | `test_smooth_regrouping_updates_anchor_positions` (GDScript, line 419) | COVERED |
| Independence as Queryable: highlight independent peers | Selecting module shows its complement | `highlight_independence(node_id)` — INDEPENDENT_PEER_COLOR for other groups | 10 behavioral tests in `test_independence_highlight.gd` | COVERED |
| Independence as Queryable: co-dependent visual distinction | A's own group shown as co-dependent | `CODEPENDENT_COLOR` (amber) applied to same-group modules | `test_own_group_modules_highlighted_as_codependent`, `test_codependent_and_independent_colors_are_visually_distinct` | COVERED |
| Independence as Queryable: highlight transition animated | Smooth animated transition | `_animate_mesh_color()` uses `create_tween()`; check-highlight-function-has-tween passes | check-highlight-function-has-tween.sh: OK | COVERED |
| Independence as Queryable: cross-context independence | Unaffected BCs highlighted | `_compute_context_independence()` BFS + `_highlight_cross_context_independence()` | `test_compute_context_independence_finds_isolated_contexts`, `test_dependent_context_is_not_independent`, `test_independent_context_receives_highlight_color` | COVERED |
| Independence as Queryable: cross-context highlight animates outward | Radial delay from module | Delay parameter in highlight call radiates outward | `test_independence_highlight.gd` animation delay tests | COVERED |

### Spec Coverage Gap

**PARTIAL — Scenario: Fully connected context** (`SHALL`):

The spec requires:
> GIVEN a bounded context where every module transitively depends on every other
> WHEN independence analysis runs
> THEN the entire context is a single group
> AND no independence separation is applied

- The second THEN-clause (no spatial separation) is covered by `test_single_group_positions_unchanged`.
- The first THEN-clause (entire context IS a single group) is NOT explicitly tested. The dropped
  test `test_fully_connected_context_is_single_group` (from main's e6bfa2f2) used a 3-node cycle
  (A→B→C→A) and asserted `len(set(groups.values())) == 1`. The branch has no equivalent.
- `test_connected_modules_share_group` tests that two directly-connected modules share a group,
  which is a weaker predicate (does not test a fully-connected many-node context).

## Non-Blocking Observations

- All 261 Python tests pass (`check-pytest-passes.sh`: OK).
- All 21 Godot behavioral test suites pass (`godot-tests.sh`: OK).
- `check-not-in-scope.sh` now exits 0 (fixed — the previous false positive is resolved).
- `check-nondirectional-movement-assertions.sh`: OK — all directional tests use signed predicates.
- `check-directional-signchain-comments.sh`: OK — all sign-chain derivation comments present.
- `check-spec-ref-staleness.sh`: OK — no spec drift detected.
- Commit trailers: All Task-Ref trailers present on implementation commits; 4 of 5 have Spec-Ref
  (the ruff format commit is a style-only fix-up and acceptable without Spec-Ref).
- `check-reposition-function-has-tween.sh`: OK.
- `check-highlight-function-has-tween.sh`: OK.

## Required Actions (in order)

1. **Sync Point 0** (mandatory before all else):
   ```
   git fetch origin main:main
   git checkout origin/main -- .hyperloop/checks/
   bash .hyperloop/checks/check-checks-in-sync.sh   # must exit 0
   ```

2. **Rebase**:
   ```
   git rebase origin/main
   ```
   During conflict resolution for `extractor/tests/test_extractor.py`:
   - KEEP all tests that main added (e6bfa2f2). Specifically, preserve:
     - `test_fully_connected_context_is_single_group` (3-node cycle → single group)
     - `test_each_module_carries_group_id_in_scene_graph` (scene-graph module field)
     - The extra `test_cross_context_edge_has_weight` (class-level duplicate in pre-independence class)
     - The extra `test_internal_edge_has_weight` (class-level duplicate)
     - `test_cross_context_edge_weight_counts_imports`
   - ALSO keep the branch's renamed/added tests (they are not in conflict).

3. **Verify checks pass**:
   ```
   bash .hyperloop/checks/check-run-tests-suite-count.sh   # guard against Godot regression
   bash .hyperloop/checks/check-class-test-count.sh        # must exit 0 (all-test count >= main)
   bash .hyperloop/checks/run-all-checks.sh                # must exit 0 (check-main-local-vs-remote
                                                           # ORCHESTRATOR failure is pre-existing and
                                                           # is not an implementer error)
   ```

4. Push rebased branch.