---
task_id: task-075
round: 2
role: verifier
verdict: fail
---
# Code Review — hyperloop/task-075
# Spec: specs/core/visual-primitives.spec.md
# Reviewer: Claude Sonnet 4.6 (automated)
# Date: 2026-05-01

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Rebase Check Output

```
FAIL: Branch 'hyperloop/task-075' is NOT rebased onto origin/main.

  Fork point (merge-base): db76c82
  origin/main HEAD:        d3360db
  Commits on main not in branch: 3

  RISK: Merging this branch as-is would REVERT all 3 commit(s)
  that main added after db76c82. Inspect what would be lost:
    git log db76c82..origin/main --oneline

  Fix:
    git fetch origin main:main
    git rebase origin/main
    # During conflict resolution:
    #   KEEP all functions/files main added (the incoming 'theirs' side).
    #   Apply your changes ON TOP — never choose 'ours' to discard main work.
    # After rebase completes:
    bash .hyperloop/checks/check-run-tests-suite-count.sh   # guard against suite regression
    bash .hyperloop/checks/run-all-checks.sh
```

Commits on origin/main NOT present in this branch:
```
d3360db5 feat(schema): add depth field validation to validate_scene_graph (#217)
751ab608 feat(prototype): godot — node volume rendering (boxes at schema positions) (#220)
b37b6863 feat(core): schema — structural significance fields on nodes (#218)
```

---

## Checks Sync Output

Before running checks, check-checks-in-sync.sh detected that two scripts present on main
were missing from the working tree:
  - check-rebased-onto-main.sh
  - check-run-tests-suite-count.sh

check-sync-divergence-impact.sh confirmed that check-rebased-onto-main.sh is SUBSTANTIVE:
main's version exits non-zero (FAIL) for this branch, meaning the implementer's prior
check runs concealed this rebase failure.

After the reviewer synced checks from main:
```
OK: All check scripts from main are present and content-identical in working tree (54 checked).
```

---

## run-all-checks.sh Output (54 checks)

```
=== run-all-checks.sh ===

--- check-aggregate-edge-impl.sh ---
OK: Aggregate-edge implementation found.
  godot/scripts/lod_manager.gd
  godot/scripts/main.gd
[EXIT 0]

--- check-assigned-spec-in-scope.sh ---
SKIP: No spec path provided — run manually at Step 0.
[EXIT 0]

--- check-branch-forked-from-main.sh ---
OK: No inherited foreign-task commits detected on 'hyperloop/task-075'.
[EXIT 0]

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-075' has 7 commit(s) above main.
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present and content-identical in working tree (52 checked).
[EXIT 0]

--- check-circular-position-y-axis.sh ---
OK: All _circular_positions calls use y=0.0 (no non-zero y detected).
[EXIT 0]

--- check-clamp-boundary-tests.sh ---
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_target_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_theta' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: All 4 clamped variable(s) have boundary-asserting tests
[EXIT 0]

--- check-commit-trailer-task-ref.sh ---
OK: All Task-Ref trailers on implementation commits match branch task ID 'task-075'.
[EXIT 0]

--- check-compute-functions-called-from-entry-point.sh ---
Entry point file: extractor/extractor.py
OK: compute_cascade_depth() is called from extractor/extractor.py
OK: compute_clusters() is called from extractor/extractor.py
OK: compute_independence_groups() is called from extractor/extractor.py
OK: compute_layout() is called from extractor/extractor.py
OK: compute_loc() is called from extractor/extractor.py
OK: compute_structural_significance() is called from extractor/extractor.py
[EXIT 0]

--- check-cycle-gate.sh ---
RESULT: No prohibited specs detected in task queue.
EXIT 0 — Task queue is clean. Proceed with assignment.
RESULT: CYCLE-START GATE PASSED.
EXIT 0 — Gate passed. Proceed.
[EXIT 0]

--- check-directional-signchain-comments.sh ---
OK: All directional calculation lines have sign-chain derivation comments (→)
[EXIT 0]

--- check-extractor-cli-tested.sh ---
OK: A test calls main() from the extractor CLI entry point.
[EXIT 0]

--- check-extractor-stdlib-only.sh ---
OK: A test using sys.stdlib_module_names to verify stdlib-only imports found.
[EXIT 0]

--- check-fail-report-classification.sh ---
SKIP: no fail-report path provided — nothing to classify.
[EXIT 0]

--- check-gdscript-only-test.sh ---
OK: DirAccess iteration test found — 'all scripts use GDScript' constraint is exercised
[EXIT 0]

--- check-godot-no-script-errors.sh ---
(188 PASS results; 0 FAIL results — full output omitted for brevity)
GDScript behavioral tests passed.
[EXIT 0]

--- check-kartograph-integration-test.sh ---
[EXIT 0]

--- check-layout-radius-bound.sh ---
[EXIT 0]

--- check-lod-level-tests.sh ---
OK: 'Near (full detail)' LOD level test found.
OK: 'Medium (module structure)' LOD level test found.
OK: 'Far (aggregate edges / bounded context)' LOD level test found.
OK: All LOD levels (Near / Medium / Far) have behavioral test coverage.
[EXIT 0]

--- check-lod-opacity-animation.sh ---
OK: Branch LOD files include Tween/modulate.a opacity animation.
[EXIT 0]

--- check-main-local-vs-remote.sh ---
[EXIT 0]

--- check-new-modules-wired.sh ---
[EXIT 0]

--- check-no-duplicate-toplevel-functions.sh ---
[EXIT 0]

--- check-nondirectional-movement-assertions.sh ---
[EXIT 0]

--- check-no-prohibited-tasks-open.sh ---
[EXIT 0]

--- check-not-in-scope.sh ---
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-no-zero-commit-reattempt.sh ---
[EXIT 0]

--- check-pipeline-wiring.sh ---
[EXIT 0]

--- check-preloaded-gdscript-files.sh ---
[EXIT 0]

--- check-prescribed-fixes-applied.sh ---
[EXIT 0]

--- check-prohibited-branches-deleted.sh ---
[EXIT 0]

--- check-pytest-passes.sh ---
[EXIT 0]

--- check-racf-prior-cycle.sh ---
[EXIT 0]

--- check-racf-remediation.sh ---
[EXIT 0]

--- check-rebased-onto-main.sh ---
FAIL: Branch 'hyperloop/task-075' is NOT rebased onto origin/main.
  Fork point (merge-base): db76c82
  origin/main HEAD:        d3360db
  Commits on main not in branch: 3
  RISK: Merging this branch as-is would REVERT all 3 commits main added after db76c82.
[EXIT 1 — FAIL]

--- check-relative-position-tests.sh ---
[EXIT 0]

--- check-report-scope-section.sh ---
[EXIT 0]

--- check-retry-not-scope-prohibited.sh ---
[EXIT 0]

--- check-ruff-format.sh ---
[EXIT 0]

--- check-run-tests-suite-count.sh ---
OK: _run_suite() count on branch (18) >= origin/main (18).
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
[EXIT 0]

--- check-script-skip-on-no-args.sh ---
[EXIT 0]

--- check-spec-ref-staleness.sh ---
OK (no drift): specs/core/visual-primitives.spec.md is identical at Spec-Ref
  (67df14bc9137e80de5a60d12dad7f77c7d995959) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
[EXIT 0]

--- check-spec-ref-valid.sh ---
[EXIT 0]

--- check-sync-divergence-impact.sh ---
[EXIT 0]

--- check-task-ref-report-not-falsified.sh ---
[EXIT 0]

--- check-tscn-no-dangling-references.sh ---
OK: All [ext_resource] paths in .tscn files resolve to existing files.
[EXIT 0]

--- check-typeddict-fields-extractor-tested.sh ---
OK: All Literal type values have coverage in test_extractor.py.
[EXIT 0]

--- check-worker-result-clean.sh ---
[EXIT 0]

--- extractor-lint.sh ---
[EXIT 0]

--- godot-compile.sh ---
[EXIT 0]

--- godot-fileaccess-tested.sh ---
[EXIT 0]

--- godot-label3d.sh ---
[EXIT 0]

--- godot-tests.sh ---
GDScript behavioral tests passed.
[EXIT 0]

=== Summary: 54 check(s) run ===
RESULT: FAIL — one or more checks exited non-zero
```

---

## Mandatory Specific Checks

### check-run-tests-suite-count.sh
```
OK: _run_suite() count on branch (18) >= origin/main (18).
```

### check-compute-functions-called-from-entry-point.sh
```
Entry point file: extractor/extractor.py
OK: compute_cascade_depth() is called from extractor/extractor.py
OK: compute_clusters() is called from extractor/extractor.py
OK: compute_independence_groups() is called from extractor/extractor.py
OK: compute_layout() is called from extractor/extractor.py
OK: compute_loc() is called from extractor/extractor.py
OK: compute_structural_significance() is called from extractor/extractor.py
```

### check-typeddict-fields-extractor-tested.sh
```
OK: All Literal type values have coverage in test_extractor.py.
```

### check-lod-opacity-animation.sh
```
OK: Branch LOD files include Tween/modulate.a opacity animation.
```

### check-aggregate-edge-impl.sh
```
OK: Aggregate-edge implementation found.
  godot/scripts/lod_manager.gd
  godot/scripts/main.gd
```

### check-tscn-no-dangling-references.sh
```
OK: All [ext_resource] paths in .tscn files resolve to existing files.
```

### check-lod-level-tests.sh
```
LOD/visualization files modified by this branch:
  godot/scripts/lod_manager.gd
  godot/scripts/main.gd
OK: 'Near (full detail)' LOD level test found. godot/tests/test_spatial_structure.gd
OK: 'Medium (module structure)' LOD level test found. godot/tests/test_spatial_structure.gd
OK: 'Far (aggregate edges / bounded context)' LOD level test found. godot/tests/test_spatial_structure.gd
OK: All LOD levels (Near / Medium / Far) have behavioral test coverage.
```

### check-spec-ref-staleness.sh
```
OK (no drift): specs/core/visual-primitives.spec.md is identical at Spec-Ref
  (67df14bc9137e80de5a60d12dad7f77c7d995959) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

---

## Test Suite Results

### Python (pytest)
194 passed, 0 failed (extractor/tests/)

### GDScript (Godot headless)
188 passed, 0 failed (godot/tests/)

---

## FAIL Items Verification (Prior Reviewer Findings)

The prior reviewer identified 7 FAIL items and 3 PARTIAL items. All were addressed by
the implementer in commit 5124bdee ("fix(task-075): resolve all 7 FAIL and 3 PARTIAL
findings from spec-alignment review"). Review of implementation confirms:

### FAIL-1: Edge visual thickness — mesh width, not color brightness
STATUS: FIXED
- `godot/scripts/main.gd` `_create_edge()` computes
  `radius = clampf(BASE_RADIUS * (1.0 + float(weight) / 10.0), BASE_RADIUS, BASE_RADIUS * 4.0)`
- CylinderMesh top_radius/bottom_radius set to this radius value
- Test: `test_edge_thickness_proportional_to_weight()` in test_spatial_structure.gd asserts
  weight-12 cylinder radius > weight-1 cylinder radius

### FAIL-2: Edge type line style — dashed/dotted lines, not color
STATUS: FIXED
- `_edge_line_style()` returns "solid" / "dashed" / "dotted" based on edge type
- Solid = direct_call, dynamic_call; Dashed = cross_context, internal, aggregate;
  Dotted = inherits, has_a
- `set_meta("line_style", ...)` on each edge body for testability
- Tests: `test_direct_call_edge_has_solid_style()`, `test_import_edge_has_dashed_style()`,
  `test_inherits_edge_has_dotted_style()` in test_spatial_structure.gd

### FAIL-3: Ubiquitous edges suppressed — `_create_edge()` checks `ubiquitous` flag
STATUS: FIXED
- `_create_edge()` reads `is_ubiquitous = ed.get("ubiquitous", false)`
- Ubiquitous edges: `body.visible = false`, tracked in `_ubiquitous_edge_visuals`
- Test: `test_ubiquitous_edge_suppressed_by_default()` in test_spatial_structure.gd

### FAIL-4: Power rail toggle — keyboard toggle for ubiquitous edges
STATUS: FIXED
- `toggle_ubiquitous_edges()` function with Tween-based fade
- `_unhandled_input()` handles `KEY_T` → `toggle_ubiquitous_edges()`
- Test: `test_ubiquitous_edge_toggle_shows_then_hides()` in test_spatial_structure.gd

### FAIL-5: Container membrane permeability — alpha varies with public/private ratio
STATUS: FIXED
- `alpha = clampf(1.0 - public_ratio, 0.05, 0.55)` computed from `symbols` field
- More public symbols → lower alpha (porous); fewer public → higher alpha (opaque)
- Test: `test_membrane_permeability_reflects_public_private_ratio()` in test_spatial_structure.gd

### FAIL-6: Entry-point nodes as landmarks — `compute_structural_significance()` checks `in_degree==0`
STATUS: FIXED
- `is_entry_point = ind == 0 and outd > 1` → `node["is_landmark"] = True`
- Test: `test_entry_point_is_marked_landmark()` in extractor/tests/test_extractor.py

### FAIL-7: Dynamic call param_name — edge carries param_name
STATUS: FIXED
- `has_dynamic` changed from `set[str]` to `dict[str, str]`
- Dynamic call edge emitted with `"param_name": has_dynamic[src]`
- Test: `test_dynamic_call_edge_carries_param_name()` in extractor/tests/test_extractor.py

### PARTIAL-A: param_name field — FIXED (see FAIL-7)
### PARTIAL-B: bridge landmark test — FIXED (`test_bridge_is_marked_landmark` added)
### PARTIAL-C: badge vocabulary — FIXED (`test_badge_vocabulary_stateful`, `test_badge_vocabulary_deprecated` added)

---

## Rebase Conflict Check

No merge conflict markers (`<<<<<<<`, `>>>>>>>`, `=======`) found in the 5 flagged files:
- extractor/extractor.py
- extractor/schema.py
- extractor/tests/test_extractor.py
- godot/tests/run_tests.gd
- godot/tests/test_visual_primitives.gd

The files themselves are clean; however, the branch has NOT been rebased onto origin/main,
which has added 3 commits since the fork point (db76c82). The missing commits are:

- d3360db5 feat(schema): add depth field validation to validate_scene_graph (#217)
- 751ab608 feat(prototype): godot — node volume rendering (boxes at schema positions) (#220)
- b37b6863 feat(core): schema — structural significance fields on nodes (#218)

Merging without rebasing would REVERT these 3 commits from main.

---

## Check Sync Violation

The implementer's latest commit ("chore(task-075): sync checks from main + write final
PASS verdict") claimed all 52 checks passed. However, at submission time, two checks
(`check-rebased-onto-main.sh` and `check-run-tests-suite-count.sh`) had been added to
main but were NOT present on the branch. The implementer did not sync these new scripts,
causing the rebase failure to be invisible to their run-all-checks.sh run.

`check-sync-divergence-impact.sh` classifies `check-rebased-onto-main.sh` as SUBSTANTIVE
DIVERGENT: main's version exits non-zero for this branch.

---

## Requirement Status Table

| Requirement                               | Status    | Evidence                                       |
|-------------------------------------------|-----------|------------------------------------------------|
| Scope Nesting Extraction                  | COVERED   | extractor, schema, tests                       |
| Module Graph Extraction                   | COVERED   | extractor, tests                               |
| Symbol Table Extraction                   | COVERED   | extract_symbols(), schema.SymbolInfo           |
| Type Topology Extraction                  | COVERED   | extract_type_topology(), inherits/has_a edges  |
| Call Graph Extraction (direct)            | COVERED   | extract_call_graph(), direct_call edges        |
| Call Graph Extraction (dynamic+param_name)| COVERED   | dynamic_call edges carry param_name            |
| Call frequency annotation (weight)        | COVERED   | edge weight field, tests                       |
| Data Flow Spine Extraction                | MISSING   | Explicitly NOT in scope (spec §prototype-scope)|
| Structural Significance (hub, bridge)     | COVERED   | compute_structural_significance(), tests       |
| Structural Significance (entry-point)     | COVERED   | is_entry_point check, is_landmark=True         |
| Ubiquitous Dependency Detection           | COVERED   | detect_ubiquitous_dependencies(), tests        |
| Container Primitive (membrane)            | COVERED   | alpha from public_ratio, test                  |
| Node Primitive (badges)                   | COVERED   | visual_primitives.gd, 8 badge types, tests     |
| Edge Primitive (thickness by weight)      | COVERED   | CylinderMesh radius, test                      |
| Edge Primitive (line style by type)       | COVERED   | solid/dashed/dotted, tests                     |
| Edge Primitive (ubiquitous suppression)   | COVERED   | is_ubiquitous check, hidden by default         |
| Power Rail Notation                       | COVERED   | _ubiquitous_edge_visuals, KEY_T toggle         |
| Landmark Primitive (hub/bridge)           | COVERED   | visual_primitives.gd, TorusMesh ring, tests    |
| Landmark Primitive (entry-point)          | COVERED   | is_landmark=True, is_entry_point logic         |
| LOD Near/Medium/Far                       | COVERED   | lod_manager.gd, tests                          |
| LOD opacity animation (Tween)             | COVERED   | _transition_visible() with Tween               |
| Aggregate edges at FAR                    | COVERED   | lod_manager.gd, test                           |
| Branch rebased onto origin/main           | MISSING   | check-rebased-onto-main.sh exits 1 (FAIL)      |

---

## Blocking Issues (FAIL Drivers)

1. **REBASE-FAIL**: `check-rebased-onto-main.sh` exits 1.
   Branch fork point is db76c82; origin/main HEAD is d3360db.
   Three commits on main (structural-significance fields, node volume rendering, depth
   field validation) are absent from this branch. Merging as-is would REVERT them.

   This is the sole blocking issue. All 7 prior FAIL items and 3 PARTIAL items have been
   correctly addressed with implementation and test coverage.

---

## Verdict Rationale

The implementation quality is high. All 7 FAIL items and 3 PARTIAL items from the prior
review have been fully addressed with correct implementation and behavioral test coverage.
194 Python tests and 188 GDScript tests all pass. No conflict markers. No spec drift.
No out-of-scope features. No duplicate functions.

However, the branch is NOT rebased onto the current tip of origin/main. Three commits
merged to main after the branch was created are absent. The mandatory protocol (Step 3)
states: "If this exits non-zero, FAIL immediately." check-rebased-onto-main.sh exits 1.

Additionally, the implementer's check-sync omission (two new check scripts missing from
their run) means their claimed "52/52 checks pass" was inaccurate — the rebase failure
was invisible to their run. This is a process violation under the re-attempt protocol.

The fix is straightforward: rebase onto origin/main, resolve any conflicts by keeping
main's additions, re-run the test suites (all should pass), re-run run-all-checks.sh,
and resubmit.

**Verdict: FAIL**
**Blocking: REBASE-FAIL (branch not rebased onto origin/main; 3 main commits absent)**