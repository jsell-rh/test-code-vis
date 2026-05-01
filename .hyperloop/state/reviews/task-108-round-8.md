---
task_id: task-108
round: 8
role: verifier
verdict: fail
---
## Review: task-108 (eighth round)

Spec: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
Branch: hyperloop/task-108 (3 commits above fork point db76c822; fork point is NOT current main)

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

Round-7 blocking issue (understanding_overlay.gd prohibited mode names) is resolved — the
stale branch version is now attributed to a pre-existing file on main, not to this branch.

---

## Check-Sync Status

```
OK: All check scripts from main are present and content-identical in working tree (52 checked).
```

Synced from origin/main before starting the review. Divergence impact:

```
OK (identical output): check-compute-functions-called-from-entry-point.sh
OK (identical output): check-typeddict-fields-extractor-tested.sh
=== FAST-FIX: All stale scripts produce identical output ===
```

Two scripts were stale on branch but produce identical output — FAST-FIX only, no
implementation impact. Sync commit still required but no real divergence.

---

## run-all-checks.sh Output

All 51 checks exit 0. RESULT: ALL PASS.

| Check | Exit |
|---|---|
| check-aggregate-edge-impl.sh | 0 ✓ |
| check-assigned-spec-in-scope.sh | 0 (SKIP) |
| check-branch-forked-from-main.sh | 0 ✓ |
| check-branch-has-commits.sh | 0 ✓ |
| check-checks-in-sync.sh | 0 ✓ |
| check-circular-position-y-axis.sh | 0 ✓ |
| check-clamp-boundary-tests.sh | 0 ✓ |
| check-commit-trailer-task-ref.sh | 0 ✓ |
| check-compute-functions-called-from-entry-point.sh | 0 ✓ |
| check-cycle-gate.sh | 0 ✓ |
| check-directional-signchain-comments.sh | 0 ✓ |
| check-extractor-cli-tested.sh | 0 ✓ |
| check-extractor-stdlib-only.sh | 0 ✓ |
| check-fail-report-classification.sh | 0 (SKIP) |
| check-gdscript-only-test.sh | 0 ✓ |
| check-godot-no-script-errors.sh | 0 ✓ |
| check-kartograph-integration-test.sh | 0 ✓ |
| check-layout-radius-bound.sh | 0 ✓ |
| check-lod-level-tests.sh | 0 ✓ |
| check-lod-opacity-animation.sh | 0 ✓ |
| check-main-local-vs-remote.sh | 0 ✓ |
| check-new-modules-wired.sh | 0 ✓ |
| check-no-duplicate-toplevel-functions.sh | 0 ✓ |
| check-nondirectional-movement-assertions.sh | 0 ✓ |
| check-no-prohibited-tasks-open.sh | 0 (SKIP) |
| check-not-in-scope.sh | 0 ✓ |
| check-no-zero-commit-reattempt.sh | 0 (SKIP) |
| check-pipeline-wiring.sh | 0 (SKIP) |
| check-preloaded-gdscript-files.sh | 0 ✓ |
| check-prescribed-fixes-applied.sh | 0 (SKIP — no prior FAIL report in branch) |
| check-pytest-passes.sh | 0 ✓ |
| check-racf-prior-cycle.sh | 0 (SKIP) |
| check-racf-remediation.sh | 0 (SKIP) |
| check-relative-position-tests.sh | 0 ✓ |
| check-report-scope-section.sh | 0 ✓ |
| check-retry-not-scope-prohibited.sh | 0 (SKIP) |
| check-ruff-format.sh | 0 ✓ |
| check-scope-report-not-falsified.sh | 0 ✓ |
| check-script-skip-on-no-args.sh | 0 ✓ |
| check-spec-ref-staleness.sh | 0 ✓ |
| check-spec-ref-valid.sh | 0 ✓ |
| check-sync-divergence-impact.sh | 0 (FAST-FIX) |
| check-task-ref-report-not-falsified.sh | 0 ✓ |
| check-tscn-no-dangling-references.sh | 0 ✓ |
| check-typeddict-fields-extractor-tested.sh | 0 ✓ |
| check-worker-result-clean.sh | 0 ✓ |
| extractor-lint.sh | 0 ✓ |
| godot-compile.sh | 0 ✓ |
| godot-fileaccess-tested.sh | 0 ✓ |
| godot-label3d.sh | 0 ✓ |
| godot-tests.sh | 0 ✓ (161 passed, 0 failed) |

---

## check-compute-functions-called-from-entry-point.sh

```
OK: compute_cascade_depth() is called from extractor/extractor.py
OK: compute_clusters() is called from extractor/extractor.py
OK: compute_independence_groups() is called from extractor/extractor.py
OK: compute_layout() is called from extractor/extractor.py
OK: compute_loc() is called from extractor/extractor.py
```

---

## check-typeddict-fields-extractor-tested.sh

```
OK: "aggregate" — covered in test_extractor.py (3 occurrence(s))
OK: "bounded_context" — covered in test_extractor.py (9 occurrence(s))
OK: "cross_context" — covered in test_extractor.py (3 occurrence(s))
OK: "internal" — covered in test_extractor.py (5 occurrence(s))
OK: "module" — covered in test_extractor.py (8 occurrence(s))
OK: "spec" — covered in test_extractor.py (8 occurrence(s))
OK: All Literal type values have coverage in test_extractor.py.
```

---

## check-lod-opacity-animation.sh

```
NOTE: godot/scripts/lod_manager.gd (pre-existing on main) uses binary .visible toggle without
  opacity animation — this is a pre-existing spec gap, not attributed to this branch.
OK: Branch LOD files include Tween/modulate.a opacity animation.
```

---

## check-lod-level-tests.sh

```
OK: 'Near (full detail)' LOD level test found.
OK: 'Medium (module structure)' LOD level test found.
OK: 'Far (aggregate edges / bounded context)' LOD level test found.
OK: All LOD levels (Near / Medium / Far) have behavioral test coverage.
```

---

## Spec-Ref Staleness

```
OK (no drift): specs/visualization/spatial-structure.spec.md is identical at
Spec-Ref (7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

---

## BLOCKING ISSUE — Branch Not Rebased; Task-074 Work Regressed

### Root Cause

The branch forked from main at `db76c822`. After the branch was created, main advanced
with commit `b37b6863` ("feat(core): schema — structural significance fields on nodes (#218)",
Task-Ref: task-074). The branch's 3 commits do NOT include a rebase onto that commit.

The prior review (round 7) explicitly required:
> "You MUST run `git rebase main` and resolve these conflicts before doing any other work."

The branch has NOT been rebased. The fork point is still `db76c822`, which is one commit
behind current main (`b37b6863`).

### Regression: Files Modified by Both Branches

As a result, the branch's diff against origin/main shows it REMOVES the following code
that task-074 added to main:

**extractor/extractor.py** — branch diff shows `-def compute_structural_significance()`:
- `compute_structural_significance()` is deleted from the branch's version of the extractor.
- `compute_ubiquitous_flags()` is also deleted.
- These are task-074's hub/bridge/peripheral/community detection functions.

**extractor/schema.py** — branch diff shows removal of TypedDict fields:
- `in_degree`, `out_degree`, `is_hub`, `is_bridge`, `is_peripheral`,
  `community_id`, `community_drift` fields deleted from the `Node` TypedDict.
- These are schema fields for structural significance that Godot consumes.

**godot/tests/run_tests.gd** — branch has 17 `_run_suite` calls; main has 18:
- `_run_suite(preload("res://tests/test_visual_primitives.gd").new())` is MISSING.
- The branch replaced the task-074 registration line with a comment about task-108.
- `test_visual_primitives.gd` does not exist on this branch.

**Net effect**: Merging this branch as-is would revert task-074's completed and merged work,
dropping structural significance extraction from the extractor and its test coverage from the
test suite. The 161 passing tests on this branch appear clean only because
`test_visual_primitives.gd` (which covers task-074's requirements) is absent.

### Verification

```
git merge-base HEAD origin/main
# → db76c822  (fork point — NOT current main b37b6863)

git show b37b6863 --name-only | head -10
# → extractor/extractor.py, extractor/schema.py, extractor/tests/test_extractor.py,
#   godot/scripts/main.gd, godot/tests/run_tests.gd, godot/tests/test_visual_primitives.gd

ls godot/tests/test_visual_primitives.gd
# → No such file or directory

grep "_run_suite" godot/tests/run_tests.gd | wc -l
# → 17  (main has 18)
```

---

## Task-108 Implementation Quality (informational — would PASS if rebase resolved)

The actual task-108 work is solid:
- `aggregate_edge_renderer.gd`: groups cross-context edges by (src_ctx, tgt_ctx) pair;
  renders one gold ImmediateMesh per pair; opacity proportional to count (clamped 0.35–1.0);
  uses Tween on `albedo_color:a` for animated fade when in scene tree, direct assignment in
  headless mode.
- `main.gd`: wires `_agg_renderer.build_aggregate_edges()` from `build_from_graph()`;
  `_update_lod()` detects LOD level changes; `_update_aggregate_visibility()` shows
  aggregates at FAR (lod_level=0), hides at MEDIUM/NEAR.
- 5 behavioral tests in `test_spatial_structure.gd` cover: one-aggregate-per-context-pair,
  count correctness, visible at FAR, hidden at MEDIUM, individual edges hidden at FAR.
- Commit trailers: all 3 commits have Spec-Ref and Task-Ref. ✓
- No dangling TSCN references (third commit fixes the dangling first_person_camera_controller). ✓

---

## Requirement-by-Requirement Table

| Scenario | Status | Notes |
|---|---|---|
| 3D Interactive Navigation — First-person exploration | COVERED | Orbit camera; orbit, zoom, pan tested |
| Structure as Persistent Geography — Structural elements | COVERED | Anchors, positions, containment, translucency all tested |
| Scale Through Zoom — Far (aggregate edges) | COVERED | aggregate_edge_renderer.gd; weight proportional to count; behavioral tests confirmed |
| Scale Through Zoom — Medium (module fade) | PRE-EXISTING GAP | Binary .visible in lod_manager.gd; pre-existing, not this branch's remit |
| Scale Through Zoom — Near (full detail) | COVERED | _apply_near(); dedicated behavioral tests |
| Smooth transitions — aggregate edges | COVERED | Tween on albedo_color:a |
| Smooth transitions — individual edges (lod_manager) | PRE-EXISTING GAP | Binary .visible via lod_manager.gd; pre-existing |
| Cluster Collapsing (all 4 scenarios) | OUT OF PROTOTYPE SCOPE | Not evaluated |

All task-108 spec requirements that are in scope are COVERED. The FAIL is entirely due to
the missing rebase, not to any deficiency in the task-108 implementation itself.

---

## Required Fix

```sh
# Step 1: Rebase onto current main and resolve conflicts
git rebase origin/main

# During conflict resolution in godot/tests/run_tests.gd:
#   KEEP the task-074 line:
#     _run_suite(preload("res://tests/test_visual_primitives.gd").new())
#   AND remove the task-108 comment placeholder (test_spatial_structure.gd
#   is already registered under task-014 above, so no new line needed for task-108)

# During conflict resolution in extractor/extractor.py:
#   KEEP compute_structural_significance() and compute_ubiquitous_flags() from main.
#   Apply this branch's changes on top.

# During conflict resolution in extractor/schema.py:
#   KEEP the TypedDict fields (in_degree, out_degree, is_hub, is_bridge,
#   is_peripheral, community_id, community_drift) from main.

# During conflict resolution in godot/scripts/main.gd:
#   Reconcile task-074's landmark/power-rail changes with task-108's aggregate
#   edge renderer wiring.

# Step 2: After rebase completes
git add .hyperloop/checks/   # sync check scripts from main (already in working tree)
bash .hyperloop/checks/run-all-checks.sh   # verify all checks pass

# Step 3: Commit (the rebase will have re-applied the 3 branch commits)
# If checks require a separate sync commit:
git commit -m "chore(checks): sync check scripts from main after rebase (task-108)

Spec-Ref: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
Task-Ref: task-108"
```

After a clean rebase with correct conflict resolution, all checks are expected to pass and
the task-108 work will be complete.