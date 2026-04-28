---
task_id: task-001
round: 17
role: verifier
verdict: fail
---
# Review Report — task-001 — Cycle 18

Branch: hyperloop/task-001
Spec: specs/extraction/scene-graph-schema.spec.md
Reviewer cycle: 18

---

## Scope Check Output
NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  godot/scripts/understanding_overlay.gd  (origin: a2f9d139 feat(core): godot: evaluation mode — coupling and centrality visualization (#108))
  These are informational only and do NOT count as a FAIL for this branch.
OK: No prohibited (not-in-scope) features detected.

---

## Check Script Results

Run against current worktree after `git checkout main -- .hyperloop/checks/`.
21 checks (22 .sh files including run-all-checks.sh). All check scripts exit 0.
The RESULT: ALL PASS summary is from run-all-checks.sh; this report is a reviewer
report, so check-worker-result-clean.sh skips the summary line check per its logic.

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-001' has 146 commit(s) above main.
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present and content-identical in working tree (22 checked).
[EXIT 0]

--- check-circular-position-y-axis.sh ---
OK: No _circular_positions calls with a y= argument found.
[EXIT 0]

--- check-commit-trailer-task-ref.sh ---
OK: All Task-Ref trailers on implementation commits match branch task ID 'task-001'.
[EXIT 0]

--- check-layout-radius-bound.sh ---
OK: No unbounded spatial-layout radius pattern found.
[EXIT 0]

--- check-new-modules-wired.sh ---
OK: 'extractor/extractor.py' is imported by production code (1 import(s) found).
OK: 'extractor/schema.py' is imported by production code (1 import(s) found).
[EXIT 0]

--- check-no-duplicate-toplevel-functions.sh ---
OK: No duplicate top-level function names across extractor/ source files.
[EXIT 0]

--- check-nondirectional-movement-assertions.sh ---
OK: All directional test functions use signed comparison predicates
[EXIT 0]

--- check-not-in-scope.sh ---
NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  godot/scripts/understanding_overlay.gd  (origin: a2f9d139 feat(core): godot: evaluation mode — coupling and centrality visualization (#108))
  These are informational only and do NOT count as a FAIL for this branch.
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-no-zero-commit-reattempt.sh ---
OK: 1 implementation commit(s) found since prior FAIL report (f5f1ab9).
[EXIT 0]

--- check-preloaded-gdscript-files.sh ---
OK: All 24 preload() target(s) resolve to existing files.
[EXIT 0]

--- check-prescribed-fixes-applied.sh ---
SKIP: Prior FAIL report contains no 'Offending lines:' file citations.
[EXIT 0]

--- check-pytest-passes.sh ---
Running: pytest extractor/tests/ -v --tb=short
110 passed in 0.43s
OK: All pytest tests passed.
[EXIT 0]

--- check-racf-prior-cycle.sh ---
Orchestrator cleanup obscured prior FAIL report — recovered from f5f1ab9.
Checks that failed in that cycle — must now pass:
  check-commit-trailer-task-ref.sh                        OK (resolved)
  check-no-zero-commit-reattempt.sh                       OK (resolved)
  check-racf-remediation.sh                               OK (resolved)
  check-worker-result-clean.sh                            OK (resolved)
OK: All prior-cycle failures (recovered from f5f1ab9) are now resolved.
[EXIT 0]

--- check-racf-remediation.sh ---
SKIP: Prior committed report contains no FAIL checks — no RACF to verify.
[EXIT 0]

--- check-relative-position-tests.sh ---
OK: No absolute parent-coordinate accumulation detected in extractor source.
OK: Direct relative-offset assertion test(s) found in test suite.
[EXIT 0]

--- check-report-scope-section.sh ---
OK: worker-result.yaml contains a valid '## Scope Check Output' section (scope check ran and output was pasted verbatim).
[EXIT 0]

--- check-ruff-format.sh ---
OK: ruff format --check passed — all extractor/ files are correctly formatted.
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- check-task-ref-report-not-falsified.sh ---
OK: Task-Ref report section is consistent with actual check-commit-trailer-task-ref.sh result.
[EXIT 0]

--- check-worker-result-clean.sh ---
OK: Check Script Results section does not contain a FAIL summary — report is clean.
[EXIT 0]

=== Summary: 21 check(s) run ===
RESULT: ALL PASS

NOTE (reviewer): The Godot test run also contained 8 SCRIPT ERRORs (see F1 below).
check-godot-tests.sh exits 0 because the Godot runner exits 0 (all 58 tests report PASS
due to inert function abort behavior), but the SCRIPT ERRORs represent genuine broken
tests. Verbatim Godot test output with SCRIPT ERRORs is reproduced in the findings.

---

## Findings

### F1 — BLOCKING: 8 inert camera zoom tests (property name mismatch introduced by this branch)

**Project guideline:** "Verify camera controls work (pan, zoom, orbit)."

**Verbatim SCRIPT ERRORs from Godot test run (check-godot-tests.sh output, excerpt):**

```
SCRIPT ERROR: Invalid access to property or key '_target_distance' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_zoom_toward_point_moves_pivot_toward_target (res://tests/test_camera_controls.gd:121)
  PASS: test_zoom_toward_point_moves_pivot_toward_target
SCRIPT ERROR: Invalid access to property or key '_target_distance' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_zoom_cursor_stays_under_cursor (res://tests/test_camera_controls.gd:141)
  PASS: test_zoom_cursor_stays_under_cursor
SCRIPT ERROR: Invalid access to property or key '_target_distance' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_zoom_out_from_cursor_adjusts_pivot (res://tests/test_camera_controls.gd:162)
  PASS: test_zoom_out_from_cursor_adjusts_pivot
SCRIPT ERROR: Invalid access to property or key '_target_distance' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_zoom_is_smooth_not_instantaneous (res://tests/test_camera_controls.gd:181)
  PASS: test_zoom_is_smooth_not_instantaneous
SCRIPT ERROR: Invalid access to property or key '_target_distance' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_scroll_up_decreases_distance (res://tests/test_camera_controls.gd:263)
  PASS: test_scroll_up_decreases_distance
SCRIPT ERROR: Invalid access to property or key '_target_distance' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_scroll_down_increases_distance (res://tests/test_camera_controls.gd:273)
  PASS: test_scroll_down_increases_distance
SCRIPT ERROR: Invalid access to property or key 'MIN_DISTANCE' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_zoom_clamped_at_minimum_boundary (res://tests/test_camera_controls.gd:280)
  PASS: test_zoom_clamped_at_minimum_boundary
SCRIPT ERROR: Invalid access to property or key 'MAX_DISTANCE' on a base object of type 'Camera3D (camera_controller.gd)'.
          at: test_zoom_clamped_at_maximum_boundary (res://tests/test_camera_controls.gd:293)
  PASS: test_zoom_clamped_at_maximum_boundary
```

**Root cause:** camera_controller.gd (modified in commit e6e10e58 on this branch) defines:
- `var _distance: float = 20.0`  (updated immediately — no smooth zoom)
- `var min_distance: float = 2.0` (lowercase)
- `var max_distance: float = 100.0` (lowercase)

The tests access `cam._target_distance`, `cam.MIN_DISTANCE`, `cam.MAX_DISTANCE` — none
of which exist on the script. In Godot 4 headless mode, accessing a non-existent typed
property on a GDScript object emits a SCRIPT ERROR that aborts the test function before
any `assert_*` statement runs. Because `_test_failed` (Pattern 1 suite) is never set
to `true`, the test runner reports PASS. All 8 tests are fully inert.

**This branch introduced the mismatch:**
  `git log main..HEAD --oneline -- godot/tests/test_camera_controls.gd`
  → e6e10e58 feat(prototype): godot — project setup (Godot 4.6, GDScript) (#195)
  `git log main..HEAD --oneline -- godot/scripts/camera_controller.gd`
  → e6e10e58 (same commit)
That commit added 184 lines to the test file (including the zoom tests that reference
`_target_distance`) while simultaneously removing 119 lines from camera_controller.gd,
producing the property-name mismatch.

**Additional design gap:** test_zoom_is_smooth_not_instantaneous (line 176) asserts that
after calling `_zoom_toward_point`, `_distance` must NOT change instantly — smooth
interpolation should happen in `_process`. But `_zoom_toward_point` calls `_zoom_step`
synchronously, updating `_distance` immediately. No smooth-zoom mechanism exists
(`_process` only smooths pivot, not distance). Even with property names fixed, this
test would fail against the current implementation.

**Prescribed fix — Option A (implement smooth zoom, matches test intent):**
1. Add `var _target_distance: float = 20.0` to camera_controller.gd
2. Change `_zoom_step` to update `_target_distance` (not `_distance` directly)
3. Clamp `_target_distance` within `[min_distance, max_distance]`
4. In `_process`, add: `_distance = lerp(_distance, _target_distance, delta * SMOOTH_SPEED)`
5. Add `const MIN_DISTANCE := 2.0` and `const MAX_DISTANCE := 100.0` (uppercase constants)
6. Update `_zoom_toward_point` to use `_target_distance` for its ratio computation
7. Run Godot tests → confirm zero SCRIPT ERRORs and zero failures

**Prescribed fix — Option B (align tests to current implementation):**
1. In test_camera_controls.gd, replace all `cam._target_distance` → `cam._distance`
2. Replace `cam.MIN_DISTANCE` → `cam.min_distance`
3. Replace `cam.MAX_DISTANCE` → `cam.max_distance`
4. Rewrite test_zoom_is_smooth_not_instantaneous to assert `_distance` DID change
   immediately (removing the incorrect "smooth/not instantaneous" premise)
5. Run Godot tests → confirm zero SCRIPT ERRORs and zero failures

---

### Schema Spec Verification — PASS on all THEN-clauses

The scene-graph-schema.spec.md requirements are fully implemented and tested.

#### Implementation summary (verified by code review)
- `build_scene_graph()` returns exactly 3 top-level keys: `nodes`, `edges`, `metadata`
- Edges use `source`/`target`/`type` (not `from`/`to`)
- Metadata uses `source_path` and `timestamp` (validated by `validate_scene_graph()`)
- Pre-computed layout uses coupling-aware force-directed algorithm (Fruchterman-Reingold)
- Child nodes store LOCAL offsets — Godot adds parent world position at render time

#### THEN→Test Mapping

| Spec THEN-clause | Test function | File |
|---|---|---|
| nodes array at top level | test_scene_graph_has_nodes_key | test_schema.py |
| edges array at top level | test_scene_graph_has_edges_key | test_schema.py |
| metadata object at top level | test_scene_graph_has_metadata_key | test_schema.py |
| no other top-level fields | test_scene_graph_has_no_extra_top_level_fields | test_schema.py |
| BC node: unique id | test_bounded_context_node_id, test_node_ids_are_unique | test_schema.py |
| BC node: name | test_bounded_context_node_name | test_schema.py |
| BC node: type = "bounded_context" | test_bounded_context_node_type | test_schema.py |
| BC node: position x/y/z | test_bounded_context_node_position_has_xyz | test_schema.py |
| BC node: size from complexity | test_bounded_context_node_size_is_numeric + test_size_from_loc_grows_with_loc | test_schema.py, test_extractor.py |
| BC node: parent is null | test_bounded_context_node_parent_is_null | test_schema.py |
| Module node: dotted id | test_module_node_id_dotted | test_schema.py |
| Module node: parent = BC id | test_module_node_parent_references_context | test_schema.py |
| Module node: type = "module" | test_module_node_type_is_module | test_schema.py |
| Module position relative to parent | test_child_position_is_local_offset_not_absolute | test_extractor.py |
| Cross-context edge: source | test_cross_context_edge_source | test_schema.py |
| Cross-context edge: target | test_cross_context_edge_target | test_schema.py |
| Cross-context edge: type | test_cross_context_edge_type | test_schema.py |
| Internal edge: source | test_internal_edge_source | test_schema.py |
| Internal edge: target | test_internal_edge_target | test_schema.py |
| Internal edge: type = "internal" | test_internal_edge_type | test_schema.py |
| Metadata: source_path | test_metadata_has_source_path | test_schema.py |
| Metadata: timestamp | test_metadata_has_timestamp | test_schema.py |
| Layout: position has x/y/z | test_every_node_has_a_position | test_schema.py |
| Tightly coupled nodes closer | test_coupled_bcs_are_closer_than_uncoupled | test_extractor.py |
| Child within parent spatial bounds | test_child_nodes_are_near_parent_position | test_extractor.py |
| Godot renders at JSON positions | test_volumes_positioned_from_json | test_scene_graph_loading.gd |

All 26 THEN-clause rows are mapped to named test functions verified to exist via grep.
Predicate alignment confirmed by reading test bodies. The coupling-distance test
(test_coupled_bcs_are_closer_than_uncoupled) varies coupling in its fixture and asserts
relative distance ordering — this is an algorithm-quality test, not rendering-fidelity.
The Godot position test (test_volumes_positioned_from_json) instantiates real Node3D
anchors and asserts `.position.x/.y/.z` match JSON fixture values — not a dict-key check.

---

### Process Notes

**Camera3D node not found (compile check — non-blocking):** main.gd's `_ready()` calls
`get_node("Camera3D")` but the node is absent in headless mode. The compile check passes
(exit 0). This is a headless environment limitation; in a real scene the node is present.
Not a separate FAIL finding.

**check-racf-prior-cycle.sh context:** Orchestrator cleanup deleted worker-result.yaml
before the prior FAIL report; the check recovered it from f5f1ab9 and confirms all
4 checks that failed in that cycle are now resolved. No RACF pattern present.