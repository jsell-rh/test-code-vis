---
task_id: task-019
round: 0
role: verifier
verdict: fail
---
## Scope Check Output
OK: No prohibited (not-in-scope) features detected.

## Check Sync
OK: All check scripts from main are present and content-identical in working tree (60 checked).

## run-all-checks.sh Summary

All checks pass except one:

- **check-aggregate-edge-impl.sh**: EXIT 0
- **check-branch-forked-from-main.sh**: EXIT 0
- **check-branch-has-commits.sh**: EXIT 0 (2 commits above main)
- **check-branch-has-impl-files.sh**: EXIT 0 (4 non-.hyperloop/ files changed)
- **check-checks-in-sync.sh**: EXIT 0
- **check-clamp-boundary-tests.sh**: EXIT 0
- **check-commit-trailer-task-ref.sh**: EXIT 0
- **check-compute-functions-called-from-entry-point.sh**: EXIT 0 (all 7 compute_*() called)
- **check-gdscript-only-test.sh**: EXIT 0
- **check-godot-no-script-errors.sh**: EXIT 0
- **check-lod-level-tests.sh**: EXIT 0 (Near/Medium/Far all covered)
- **check-lod-opacity-animation.sh**: EXIT 0 (Tween/modulate.a present; pre-existing .visible toggle noted as pre-existing gap)
- **check-main-local-vs-remote.sh**: EXIT 1 — ORCHESTRATOR CONFIGURATION (local main ahead of origin/main; implementer cannot resolve; fix is `git push origin main` from main worktree)
- **check-no-gdscript-duplicate-functions.sh**: EXIT 0
- **check-not-in-scope.sh**: EXIT 0
- **check-no-zero-commit-reattempt.sh**: EXIT 0
- **check-pytest-passes.sh**: EXIT 0 (204 passed)
- **check-racf-prior-cycle.sh**: EXIT 0
- **check-rebased-onto-main.sh**: EXIT 0
- **check-run-tests-suite-count.sh**: EXIT 0 (branch=20, main=19)
- **check-spec-ref-staleness.sh**: EXIT 0 (no drift — spec identical at Spec-Ref and HEAD)
- **check-sync-divergence-impact.sh**: EXIT 0
- **check-tscn-no-dangling-references.sh**: EXIT 0
- **check-typeddict-fields-extractor-tested.sh**: EXIT 0
- **godot-compile.sh**: EXIT 0
- **godot-tests.sh**: EXIT 0 (199 passed, 0 failed)
- All other checks: EXIT 0

The single automated failure (check-main-local-vs-remote.sh) is an **ORCHESTRATOR CONFIGURATION** issue. Local main (5d78527) is ahead of origin/main (c39079c). This requires `git push origin main` from the main worktree — not an implementer fix. This failure would be classified FAST-FIX if it were the only issue, but the implementation has genuine gaps described below.

## Mandatory Check Outputs (verbatim)

### check-rebased-onto-main.sh
OK: Branch 'hyperloop/task-019' is rebased onto origin/main (c39079c).

### check-run-tests-suite-count.sh
OK: _run_suite() count on branch (20) >= origin/main (19).

### check-spec-ref-staleness.sh
OK (no drift): specs/visualization/spatial-structure.spec.md is identical at Spec-Ref (7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.

### check-sync-divergence-impact.sh
OK: No stale check scripts found — check-checks-in-sync.sh should pass.

### check-lod-opacity-animation.sh
NOTE: godot/scripts/lod_manager.gd (pre-existing on main) uses binary .visible toggle without opacity animation — this is a pre-existing spec gap, not attributed to this branch.
OK: Branch LOD files include Tween/modulate.a opacity animation.

### check-aggregate-edge-impl.sh
OK: Aggregate-edge implementation found.
  godot/scripts/main.gd
  godot/scripts/scene_graph_loader.gd

### check-tscn-no-dangling-references.sh
OK: All [ext_resource] paths in .tscn files resolve to existing files.

### check-no-gdscript-duplicate-functions.sh
OK: No duplicate top-level function names in changed GDScript files.

### check-branch-has-impl-files.sh
OK: Branch 'hyperloop/task-019' has implementation commits (4 non-.hyperloop/ file(s) changed).

### check-compute-functions-called-from-entry-point.sh
OK: compute_cascade_depth(), compute_clusters(), compute_independence_groups(),
    compute_layout(), compute_loc(), compute_structural_significance(),
    compute_ubiquitous_flags() — all called from extractor/extractor.py.

### check-typeddict-fields-extractor-tested.sh
OK: All Literal type values have coverage in test_extractor.py.

### check-lod-level-tests.sh
OK: All LOD levels (Near / Medium / Far) have behavioral test coverage.

## Onready Null-Guard Audit

`build_from_graph()` in main.gd applies cluster hints BEFORE calling `_frame_camera()`.
The cluster_manager operations (`_cluster_manager.init()`, `_cluster_manager.apply_cluster_hints()`)
do not depend on `_camera` (the @onready guard lives in `_frame_camera()` at line 528:
`if _world_positions.is_empty() or _camera == null: return`). The cluster hint code path
is NOT gated by the camera null-guard. Tests exercising `build_from_graph()` correctly
reach and exercise the cluster hint logic. No null-guard short-circuit issue for
cluster-related THEN-clauses.

## Spec-Ref Staleness

Spec is identical at Spec-Ref hash (7a839cc) and HEAD. No spec drift detected.
All THEN-clauses below were present in the spec the implementer worked against.

## Requirement Coverage

### Scenario: Pre-computed cluster suggestions

| THEN-clause | Status | Evidence |
|---|---|---|
| "suggested clusters are indicated visually (subtle shared tint)" | COVERED | `apply_cluster_hints()` adds translucent BoxMesh (`HINT_TINT_ALPHA=0.22`) to each member. Tests: `test_cluster_hint_adds_child_to_member_anchors`, `test_cluster_hint_material_is_translucent` verify MeshInstance3D with alpha < 1.0. |
| "the human can accept a suggestion to collapse, or ignore it" | COVERED | Hints are purely visual; no action is taken. Test: `test_cluster_members_remain_visible_after_hint_applied` confirms members stay visible. |
| "suggestions never auto-collapse — the human always initiates" | COVERED | `build_from_graph()` calls `apply_cluster_hints()` only — `collapse_cluster()` is never called automatically. Same test confirms. |

### Scenario: Collapsing a cluster

| THEN-clause | Status | Evidence |
|---|---|---|
| "modules animate together, converging smoothly into a single supernode" | PASS-WITH-NOTE | Tween-based position animation implemented in `collapse_cluster()` (line 183: `tween.tween_property(anchor, "position", target_pos, ANIM_DURATION)`). Architecture is correct. In headless tests the Tween path is not exercised (supernode not in scene tree → tween is null → immediate hide). Test `test_collapse_creates_supernode` verifies supernode is returned. Animation correctness is architecturally sound but un-testable in headless environment. |
| "the supernode displays aggregate metrics (total LOC, combined in-degree, combined out-degree)" | COVERED | `_create_supernode()` creates Label3D with format `"LOC:%d  in:%d  out:%d"`. Test `test_supernode_label_contains_aggregate_metrics` asserts text contains "250" or "LOC". Note: test does not separately assert in-degree and out-degree values, but implementation always includes them in the format string. |
| "edges that formerly entered or left any member of the cluster are re-routed to the supernode" | MISSING | Neither `cluster_manager.gd` nor `main.gd` contains any code to modify, redirect, or rebuild edge renderings (_lod_edge_entries, _path_edge_entries) when collapse occurs. Grep for "re-route", "reroute", "edge.*supernode", "supernode.*edge" in both files returns zero matches (only comments). No test function covers this THEN-clause. |
| "edge re-routing animates smoothly — endpoints slide to the supernode rather than jumping" | MISSING | Consequential on above: since no edge re-routing exists, animated re-routing also does not exist. No implementation, no test. |

### Scenario: Expanding a supernode

| THEN-clause | Status | Evidence |
|---|---|---|
| "the supernode smoothly expands back into its constituent modules" | PARTIAL | Supernode fade-out via Tween IS implemented (`tween.tween_property(mat, "albedo_color:a", 0.0, ANIM_DURATION)`). Members' visibility IS restored (`anchor.visible = true`). However, "expanding back" implies members animate outward (see next clause). Visibility restoration without position animation only partially satisfies this clause. |
| "modules animate outward to their original positions" | PARTIAL | `expand_cluster()` restores visibility (`anchor.visible = true`) but contains NO Tween call for member position animation. The code comment at line 281 explicitly acknowledges this: "For a full implementation, store original positions in _collapse_state before collapsing so expansion is deterministic." Original positions are NOT stored in _collapse_state during collapse (only centroid, supernode, members). Test `test_expand_restores_member_visibility` only asserts `anchor.visible` — it does not verify positions animate outward. |
| "edges re-route back to their original endpoints with smooth animation" | MISSING | No edge re-routing in `expand_cluster()`. No test for this clause. Same root gap as collapse-side edge re-routing. |

### Scenario: Nested collapsing

| THEN-clause | Status | Evidence |
|---|---|---|
| "only the selected cluster collapses" | COVERED | Test `test_independent_cluster_collapse` collapses svc:cluster_0, asserts svc.mod_c and svc.mod_d (cluster_1 members) remain visible. Test `test_two_clusters_collapse_independently` verifies two supernodes are distinct. |
| "uncollapsed modules remain in place, with their edges updated if any pointed to the now-collapsed cluster" | PARTIAL | Visibility of uncollapsed members is verified. "Edges updated" is not implemented — same root gap as the Collapsing scenario edge re-routing. |

## Root Cause Summary

The implementation correctly handles the visual/structural aspects of cluster collapse and expand (supernode creation, tinting, state tracking, Label3D with metrics, independence of clusters), but is missing the **edge re-routing** feature entirely. The spec requires four explicit edge re-routing clauses across two scenarios:

1. Collapse: edges re-routed TO supernode (MISSING — implementation + test)
2. Collapse: re-routing animates smoothly (MISSING — implementation + test)
3. Expand: edges re-route BACK to original endpoints with smooth animation (MISSING — implementation + test)
4. Nested: edges of uncollapsed modules updated when neighbor collapses (MISSING — same gap)

Additionally, the expand animation for member position restoration (outward to original positions) is PARTIAL — visibility is restored but no position Tween is coded, and original positions are not captured during collapse.

## What the Implementer Must Do

1. **Store original positions during collapse**: In `collapse_cluster()`, before animating member anchors, save each anchor's `position` into `_collapse_state[cluster_id]` (e.g., `"original_positions": { member_id: Vector3 }`).

2. **Animate member positions back during expand**: In `expand_cluster()`, after restoring visibility, add `tween.tween_property(anchor, "position", original_pos, ANIM_DURATION)` for each member using the stored positions.

3. **Implement edge re-routing during collapse**: In `collapse_cluster()`, iterate `_path_edge_entries` (or equivalent) in main.gd and move the endpoint of any edge whose source or target is a cluster member so it points to the supernode's position. Apply this with Tween if in scene tree.

4. **Implement edge re-routing during expand**: In `expand_cluster()`, restore edge endpoints to their original positions with smooth Tween animation.

5. **Add tests for edge re-routing**: Write GDScript tests that:
   - Build a graph with edges between cluster members and non-cluster nodes
   - Collapse the cluster and assert the edge's endpoint (or the visual's position) reaches the supernode location
   - Expand and assert the edge endpoint returns to the original node position

6. **Fix the check-main-local-vs-remote.sh failure**: This requires the orchestrator to run `git push origin main` from the main worktree. No implementer action needed here.