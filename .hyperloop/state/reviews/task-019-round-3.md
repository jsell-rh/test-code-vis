---
task_id: task-019
round: 3
role: verifier
verdict: fail
---
# Code Review — task-019 (hyperloop/task-019)
# Spec: specs/visualization/spatial-structure.spec.md § Cluster Collapsing

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

## Check Sync

```
OK: All check scripts from main are present and content-identical in working tree (61 checked).
```

(Synced via `git fetch origin && git checkout origin/main -- .hyperloop/checks/` before any other checks.)

## check-rebased-onto-main.sh

**RACE-CONDITION FAST-FIX.**  When I first ran this check the branch was fully rebased onto
origin/main (d567556). During my implementation review a new intake commit `50e9a92b` landed
on main. The check now exits non-zero because of that post-review arrival. The missing commit
touches only `.hyperloop/state/` files; the branch touches only `godot/scripts/cluster_manager.gd`,
`godot/scripts/main.gd`, `godot/tests/run_tests.gd`, and `godot/tests/test_cluster_collapsing.gd` —
zero file overlap, no conflicts expected.

Per protocol the verdict is still FAIL and a rebase commit is required. The implementer's
original rebase was correct; this is a race, not a genuine implementation gap.

Missing commit: `50e9a92b chore(intake): re-review 5 modified specs — no new tasks, blobs still unchanged`

Fix (one command, no conflicts):
```
git fetch origin main:main
git rebase origin/main
git checkout origin/main -- .hyperloop/checks/
bash .hyperloop/checks/check-rebased-onto-main.sh   # must exit 0
bash .hyperloop/checks/run-all-checks.sh
```

Commit message template:
```
chore(process): rebase onto origin/main (50e9a92b)

Task-Ref: task-019
Spec-Ref: specs/visualization/spatial-structure.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed
```

## check-run-tests-suite-count.sh

```
OK: _run_suite() count on branch (21) >= origin/main (20).
```

Branch is ahead — no suite regression.

## check-spec-ref-staleness.sh

```
OK (no drift): specs/visualization/spatial-structure.spec.md is identical at
Spec-Ref (7b9391479f56416ec06f248e0321b956bdb5f8ed) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

The authoritative spec the implementer worked against is unchanged.

## run-all-checks.sh Summary

61 checks run. Two exit non-zero:

| Check | Result | Classification |
|---|---|---|
| check-rebased-onto-main.sh | FAIL | RACE-CONDITION FAST-FIX (see above) |
| check-spec-ref-valid.sh | FAIL | PRE-EXISTING (see below) |
| All other 59 checks | EXIT 0 | — |

### check-spec-ref-valid.sh — Pre-Existing Systemic Failure

The check fails because historical intake-chore commits on this branch
(e.g. `dffd4d1c Task-Ref: intake`, `46c58adc Task-Ref: intake`) carry
Spec-Refs without the required `path@hash` form. These commits predate
the task-019 implementation by days.

The three task-019 implementation commits (26e3555f, 777fec8e, f177109a)
all carry valid Spec-Refs:
`specs/visualization/spatial-structure.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed`
— that reference resolves correctly.

This is a systemic branch hygiene issue inherited from intake commits;
it predates task-019 and was apparently also present at the prior cycle's
fork point. The check correctly detects it, but it does not reflect a
failure introduced by the current implementer.

**Action for orchestrator:** update `check-spec-ref-valid.sh` to skip
commits whose `Task-Ref` is `intake` (parallel to the existing `process-improvement`
exclusion), or amend/squash the malformed intake commits on the branch. This
does not block the current task-019 review but will recur on future cycles.

## Spec-Drift Summary

`check-spec-ref-staleness.sh` reports drift in several other spec files
(`understanding-modes.spec.md`, `nfr.spec.md`, etc.) relative to their
Spec-Refs in non-task-019 commits. None of these affect the spatial-structure
spec. No SPEC-DRIFT items apply to task-019's scope. **Not a FAIL driver.**

---

## Implementation Quality Review

### Files Changed (vs origin/main)

- `godot/scripts/cluster_manager.gd` (new, 550 lines)
- `godot/scripts/main.gd` (modified)
- `godot/tests/test_cluster_collapsing.gd` (new, 904 lines)
- `godot/tests/run_tests.gd` (modified — wired new test suite)

### Godot Test Results

255 tests run, 0 failures. All cluster-collapsing tests pass:

```
[test_cluster_collapsing.gd]
  PASS: test_cluster_hint_adds_child_to_member_anchors
  PASS: test_non_cluster_member_has_no_cluster_hint
  PASS: test_cluster_hint_material_is_translucent
  PASS: test_cluster_members_remain_visible_after_hint_applied
  PASS: test_collapse_creates_supernode
  PASS: test_supernode_has_mesh_instance
  PASS: test_supernode_label_contains_aggregate_metrics
  PASS: test_supernode_label_billboard_and_pixel_size
  PASS: test_collapse_state_is_tracked
  PASS: test_collapse_unknown_cluster_returns_null
  PASS: test_expand_restores_member_visibility
  PASS: test_expand_updates_collapse_state
  PASS: test_expand_not_collapsed_returns_false
  PASS: test_independent_cluster_collapse
  PASS: test_two_clusters_collapse_independently
  PASS: test_cluster_manager_apply_hints_direct
  PASS: test_cluster_manager_hints_idempotent
  PASS: test_cluster_manager_is_collapsed_unknown
  PASS: test_cluster_manager_collapse_empty_members
  PASS: test_collapse_reroutes_boundary_edge_to_centroid
  PASS: test_collapse_hides_internal_edges_between_cluster_members
  PASS: test_expand_restores_edge_endpoints
  PASS: test_expand_restores_internal_edge_visibility
  PASS: test_expand_restores_member_positions
  PASS: test_original_positions_captured_before_collapse
```

### @onready Null-Guard Audit

`main.gd` has `@onready var _camera: Camera3D = $Camera3D` with guards at
lines 235 and 889. The cluster collapse/expand code paths do NOT call
`_frame_camera()` and do NOT depend on `_camera`. None of the
`test_cluster_collapsing.gd` tests require camera injection. The null-guard
issue does not affect this task's THEN-clauses.

---

## THEN-Clause Coverage Table

Spec: `specs/visualization/spatial-structure.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed`

### Scenario: Pre-computed cluster suggestions

| # | THEN-clause | Status | Test(s) |
|---|---|---|---|
| S1 | Suggested clusters indicated visually (subtle shared tint) | COVERED | test_cluster_hint_adds_child_to_member_anchors, test_cluster_hint_material_is_translucent |
| S2 | Human can accept suggestion to collapse, or ignore it | COVERED | collapse_cluster() API is human-initiated; test_cluster_members_remain_visible_after_hint_applied confirms no auto-collapse |
| S3 | Suggestions never auto-collapse | COVERED | test_cluster_members_remain_visible_after_hint_applied asserts members visible after hint applied |

### Scenario: Collapsing a cluster

| # | THEN-clause | Status | Test(s) |
|---|---|---|---|
| C1 | Modules animate together, converging smoothly into a single supernode | COVERED | test_collapse_creates_supernode, test_supernode_has_mesh_instance; Tween used in scene-tree mode, immediate in headless |
| C2 | Supernode displays aggregate metrics (total LOC, combined in/out-degree) | COVERED | test_supernode_label_contains_aggregate_metrics asserts LOC "250" in label text |
| C3 | Supernode Label3D billboard=ENABLED and pixel_size>0 | COVERED | test_supernode_label_billboard_and_pixel_size |
| C4 | Edges formerly entering/leaving any cluster member are re-routed to supernode | COVERED | test_collapse_reroutes_boundary_edge_to_centroid (to_pos moves to centroid (0,0,0)); test_collapse_hides_internal_edges_between_cluster_members |
| **C5** | **Edge re-routing animates smoothly — endpoints slide rather than jumping** | **PARTIAL** | **No test asserts animation. Implementation uses ImmediateMesh immediate rebuild (endpoints jump, do not slide). See findings below.** |

### Scenario: Expanding a supernode

| # | THEN-clause | Status | Test(s) |
|---|---|---|---|
| E1 | Supernode smoothly expands back into constituent modules | COVERED | test_expand_restores_member_visibility |
| E2 | Modules animate outward to their original positions | COVERED | test_expand_restores_member_positions (headless immediate restore to stored original_positions; Tween in scene-tree mode) |
| E3 | Internal edge visibility restored on expand | COVERED | test_expand_restores_internal_edge_visibility |
| **E4** | **Edges re-route back to their original endpoints with smooth animation** | **PARTIAL** | **test_expand_restores_edge_endpoints verifies final position is correct. No test asserts animation. Same ImmediateMesh immediate rebuild — no smooth slide. See findings below.** |

### Scenario: Nested collapsing

| # | THEN-clause | Status | Test(s) |
|---|---|---|---|
| N1 | Only the selected cluster collapses | COVERED | test_independent_cluster_collapse: cluster_1 members remain visible when cluster_0 collapsed |
| N2 | Uncollapsed modules remain in place | COVERED | test_independent_cluster_collapse, test_two_clusters_collapse_independently |
| N3 | Uncollapsed modules' edges updated if they pointed to collapsed cluster | COVERED | _reroute_edges_for_collapse() checks all _path_edge_entries for member_set membership; test_collapse_reroutes_boundary_edge_to_centroid verifies cross-boundary rerouting works regardless of cluster context |

---

## Findings

### FAIL-1: Edge Re-routing Not Animated (C5 + E4) — PARTIAL

**Spec:**
- Collapse: "AND edge re-routing animates smoothly — endpoints slide to the supernode rather than jumping"
- Expand: "AND edges re-route back to their original endpoints with smooth animation"

**Implementation:** `cluster_manager.gd:_reroute_edges_for_collapse()` and
`_restore_edges_for_expand()` call `_rebuild_line_mesh()` or `_reposition_arrow()`
which immediately creates a new ImmediateMesh and assigns it. The code comment
explicitly acknowledges this:

> "NOTE: ImmediateMesh vertices are immutable after surface_end(), so rerouting
> rebuilds the mesh with updated endpoint positions. Tween-based per-frame
> interpolation of mesh geometry is architecturally infeasible with ImmediateMesh —
> the endpoint is updated immediately in both headless and scene-tree modes."

The result: edge endpoints jump to the supernode position rather than sliding. Module
nodes DO animate smoothly (Tween-based position change), but edges do not.

**No test asserts animation.** The existing tests (`test_collapse_reroutes_boundary_edge_to_centroid`,
`test_expand_restores_edge_endpoints`) verify only the final position stored in
`_path_edge_entries`, not whether the visual transitioned smoothly.

**To fix:**
1. Replace or supplement `_rebuild_line_mesh()` with a `_process`-based lerp approach:
   store `from_pos`, `to_pos`, `target_from`, `target_to` per edge entry and
   interpolate them each frame using `lerp()`, rebuilding the ImmediateMesh each
   frame until the target is reached. This achieves the "slide" effect without
   requiring a shader.
2. Alternatively, use `ArrayMesh` (mutable) or a shader to avoid per-frame
   full ImmediateMesh reconstruction.
3. Add a test that verifies the animation is in progress by checking that a
   mid-animation mesh exists and that position transitions over time (or that
   a Tween/timer is active). In headless this is hard; at minimum document the
   architectural constraint and mark as PASS-WITH-NOTE with the orchestrator's
   agreement.

---

## What the Implementer Must Do

1. **Rebase** (trivial, no conflicts):
   ```bash
   git fetch origin main:main
   git rebase origin/main
   git checkout origin/main -- .hyperloop/checks/
   bash .hyperloop/checks/check-rebased-onto-main.sh  # must exit 0
   bash .hyperloop/checks/run-all-checks.sh
   ```
   Commit message:
   ```
   chore(process): rebase onto origin/main (50e9a92b)

   Task-Ref: task-019
   Spec-Ref: specs/visualization/spatial-structure.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed
   ```

2. **Implement edge endpoint animation** for both collapse (C5) and expand (E4):
   - Edge lines and arrowheads must slide to their new positions, not jump.
   - A `_process`-based lerp rebuilding ImmediateMesh each frame is acceptable.
   - Add a test that, at minimum, verifies animation state (mid-flight position
     is between start and end) or that the approach is architecturally sound
     (if headless testing of animation is infeasible, document the constraint
     and seek orchestrator sign-off on PASS-WITH-NOTE for this specific clause).

**The implementation is otherwise high-quality.** Edge rerouting logic is correct
(boundary edges redirect to centroid, internal edges hidden, restoration works,
original positions captured). All 25 cluster-collapsing tests pass. The pre-computed
suggestion hints, idempotency, nested collapse independence, and supernode metrics
are all implemented and tested correctly.