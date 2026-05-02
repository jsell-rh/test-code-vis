---
task_id: task-108
round: 13
role: spec-reviewer
verdict: fail
---
## Review: task-108 (tenth round)

Spec: specs/visualization/spatial-structure.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed
Branch: hyperloop/task-108 (260 commits above main, fork point cf17449)

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

---

## Run-All-Checks Summary

| Check | Exit | Notes |
|---|---|---|
| check-checks-in-sync.sh | 0 | All 61 scripts present and identical |
| check-rebased-onto-main.sh | 1 — FAIL | Branch fork point cf17449, main HEAD 82e9d5c |
| check-report-scope-section.sh | 1 — FAIL | Previous worker-result.yaml (c343b0a) lacked section |
| check-spec-ref-valid.sh | 1 — FAIL | Intake commits have bare path Spec-Refs (pre-existing, fixed in main@82e9d5c3) |
| All other checks | 0 | Pass |

Godot tests: 235 passed, 0 failed.
Pytest: 247 passed, 0 failed.

---

## BLOCKING: Check Failures

### check-rebased-onto-main.sh

```
FAIL: Branch 'hyperloop/task-108' is NOT rebased onto origin/main.

  Fork point (merge-base): cf17449
  origin/main HEAD:        82e9d5c
  Commits on main not in branch: 1
```

Main gained one commit after the branch's fork point:
```
82e9d5c fix(process): skip intake commits in check-spec-ref-valid; add ImmediateMesh animation constraint
```

This commit:
1. Fixes `check-spec-ref-valid.sh` to skip `Task-Ref: intake` commits (which carry bare
   spec paths without `@hash` suffixes by convention). Without this fix, every branch
   with intake history produces false FAIL lines from check-spec-ref-valid.sh.
2. Adds an implementer-overlay section on ImmediateMesh animation constraints.

### check-spec-ref-valid.sh

The check script on the branch (old version, pre-fix) incorrectly flags intake commits
whose Spec-Refs are plain paths without `@hash` suffixes:

```
FAIL: Spec-Ref 'specs/core/system-purpose.spec.md' is not in 'path@hash' form.
FAIL: Spec-Ref 'specs/visualization/spatial-structure.spec.md' is not in 'path@hash' form.
... (and others)
```

All failing refs belong to `Task-Ref: intake` commits — pre-existing history on main,
not added by the task-108 implementer. The 5 task-108 implementation commits all have
correct `path@hash` Spec-Refs pointing to `7b9391479f56416ec06f248e0321b956bdb5f8ed`.

After rebasing onto main@82e9d5c3 (which carries the fixed check-spec-ref-valid.sh),
this check will pass automatically.

### check-report-scope-section.sh

The check recovered the previous worker-result.yaml from commit c343b0a, which belonged
to a different task (task-024/moldable-views) and lacked a `## Scope Check Output`
section. This round's worker-result.yaml (the current file) includes the required
section. After a new commit lands a rebase, the check-report-scope-section.sh will
read this file and pass.

---

## Spec-Drift Check

```
OK (no drift): specs/visualization/spatial-structure.spec.md is identical at
Spec-Ref (7b9391479f56416ec06f248e0321b956bdb5f8ed) and HEAD.
```

No spec drift detected.

---

## Spec Implementation: Requirement-by-Requirement

### Requirement: 3D Interactive Navigation

**Status: COVERED**

Implementation:
- `godot/scripts/camera_controller.gd` — orbit camera with zoom (scroll wheel),
  orbit (right-mouse drag), and pan (left-mouse drag).
- `godot/scripts/main.gd` — `build_from_graph()` creates 3D scene from JSON.

Tests in `godot/tests/test_spatial_structure.gd`:
- `test_camera_supports_zoom_in()` — signed assertion: new_distance < initial_distance ✓
- `test_camera_supports_zoom_out()` — signed assertion: new_distance > initial_distance ✓
- `test_camera_supports_orbit()` — signed assertion: phi changes on drag ✓
- `test_camera_get_distance_returns_current_distance()` — LOD integration ✓
- `test_spatial_layout_creates_node_per_structural_element()` — all 4 nodes exist ✓

Note: "first person" navigation is out of prototype scope per prototype-scope.spec.md.
The orbit camera is the prototype's navigation mechanism. The test file explicitly
documents this at lines 28-30.

`check-nondirectional-movement-assertions.sh`: EXIT 0 — all directional tests use
signed predicates.
`check-directional-signchain-comments.sh`: EXIT 0 — inline derivation comments present.

---

### Requirement: Structure as Persistent Geography

**Status: COVERED**

Implementation:
- `godot/scripts/main.gd` — `_create_volume()` places each node at its JSON position;
  modules parented to their bounded_context anchor.
- `godot/scripts/visual_primitives.gd` — context: translucent `Color(0.25,0.45,0.85,0.18)`;
  module: opaque `Color(0.35,0.70,0.40,1.0)`.

Tests:
- `test_distinct_contexts_occupy_distinct_regions()` — two BCs at distinct positions ✓
- `test_context_boundary_is_visually_distinct_translucent()` — alpha < 1.0, TRANSPARENCY_ALPHA ✓
- `test_module_boundary_is_opaque()` — alpha >= 1.0 ✓
- `test_containment_expressed_as_scene_tree_parenting()` — module parent == context anchor ✓
- `test_dependency_expressed_as_visible_connection()` — EdgeLine child exists ✓

`check-relative-position-tests.sh`: EXIT 0
`check-circular-position-y-axis.sh`: EXIT 0

---

### Requirement: Scale Through Zoom

#### Scenario: Far — bounded context architecture

**Status: COVERED**

Implementation:
- `godot/scripts/lod_manager.gd` → `_apply_far()` — shows only `bounded_context` and
  `spec` nodes; hides all individual edges; shows `aggregate` edges.
- `godot/scripts/aggregate_edge_renderer.gd` — `build_aggregate_edges()` groups
  cross-context edges by context pair, producing one MeshInstance3D per pair.
  Weight (opacity) ∝ edge count. `show_edges()` / `hide_edges()` use Tween on
  `albedo_color:a` when in scene tree; direct assignment in headless tests.

Tests:
- `test_far_distance_shows_only_bounded_contexts()` — ctx visible, module hidden ✓
- `test_far_distance_hides_all_edges()` — cross_context and internal hidden ✓
- `test_far_distance_shows_aggregate_edges()` — aggregate visible at FAR ✓
- `test_aggregate_edges_one_per_context_pair()` — 3 edges → 2 aggregate entries ✓
- `test_aggregate_edge_count_matches_edges_between_pair()` — count=2 for ctx_a→ctx_b ✓
- `test_aggregate_edges_visible_after_far_lod_transition()` — visible after FAR ✓
- `test_individual_edges_hidden_at_far_lod_in_aggregate_fixture()` — individual hidden ✓

`check-aggregate-edge-impl.sh`: EXIT 0
`check-lod-level-tests.sh` (Far): OK

#### Scenario: Medium — module structure within contexts

**Status: COVERED (opacity animation via `_transition_visible()` which calls Tween)**

Implementation:
- `godot/scripts/lod_manager.gd` → `_apply_medium()` calls `_transition_visible()` for
  each node and edge. `_transition_visible()` uses `Tween.tween_property(node,
  "modulate:a", ...)` when inside the scene tree; direct `.visible` assignment in
  headless tests.
- Pre-existing gap note: The `lod_manager.gd` file was pre-existing on main with binary
  `.visible` toggle. The task-108 branch added `_transition_visible()` with Tween-based
  animation. `check-lod-opacity-animation.sh` confirms: "Branch LOD files include
  Tween/modulate.a opacity animation."

Tests:
- `test_medium_distance_shows_modules()` — ctx and module visible at mid-distance ✓
- `test_medium_distance_shows_cross_context_edges_only()` — cross_context visible,
  internal hidden ✓
- `test_lod_integration_far_hides_modules_in_built_scene()` — end-to-end integration ✓

`check-lod-level-tests.sh` (Medium): OK

Spec sub-clause "aggregate cross-context edges smoothly dissolve into their constituent
module-level edges": The branch implements this by hiding aggregate edges at MEDIUM
(via `_update_aggregate_visibility(1)`) and showing individual cross-context edges.
The smooth part uses Tween in `hide_edges()`. Covered by
`test_aggregate_edges_hidden_after_medium_lod_transition()`.

#### Scenario: Near — full detail

**Status: COVERED**

Implementation: `lod_manager.gd` → `_apply_near()` — all nodes visible, all non-aggregate
edges visible.

Tests:
- `test_near_distance_shows_all_nodes()` ✓
- `test_near_distance_shows_internal_edges_as_fine_detail()` ✓

`check-lod-level-tests.sh` (Near): OK

#### Scenario: Smooth transitions between levels

**Status: COVERED**

Implementation: `lod_manager.gd` → `_transition_visible()` — Tween on `modulate:a`.
`aggregate_edge_renderer.gd` → `show_edges()` / `hide_edges()` — Tween on
`albedo_color:a`.

`check-lod-opacity-animation.sh`: "Branch LOD files include Tween/modulate.a opacity
animation." EXIT 0.

---

### Requirement: Cluster Collapsing

**Status: OUT OF PROTOTYPE SCOPE**

Per `specs/prototype/prototype-scope.spec.md`, cluster collapsing is not in prototype scope.
Not evaluated. `check-not-in-scope.sh` EXIT 0 confirms no prohibited features were
detected on this branch.

---

## Commit Trailers

All 5 task-108 implementation commits carry:
```
Spec-Ref: specs/visualization/spatial-structure.spec.md@7b9391479f56416ec06f248e0321b956bdb5f8ed
Task-Ref: task-108
```

`check-commit-trailer-task-ref.sh`: EXIT 0.
`check-spec-ref-staleness.sh`: EXIT 0 (no spec drift at Spec-Ref hash).

---

## Required Fix: Rebase onto main

The implementation is spec-complete. The only required action is a rebase:

```sh
# Step 1: Fetch and rebase
git fetch origin main:main
git rebase origin/main   # or: git rebase main

# Step 2: Confirm tests still pass
bash .hyperloop/checks/check-run-tests-suite-count.sh
bash .hyperloop/checks/run-all-checks.sh

# Step 3: Push
git push --force-with-lease origin hyperloop/task-108
```

After rebasing:
- `check-rebased-onto-main.sh` → EXIT 0 (fork point will equal main HEAD)
- `check-spec-ref-valid.sh` → EXIT 0 (intake commits now skipped by the updated script)
- `check-report-scope-section.sh` → EXIT 0 (this file contains the required section)

No implementation changes are needed.