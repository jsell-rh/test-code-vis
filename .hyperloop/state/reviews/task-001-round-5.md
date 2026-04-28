---
task_id: task-001
round: 5
role: verifier
verdict: fail
---
# Review Report — task-001 (cycle 13)

## Scope Check Output

NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  godot/scripts/understanding_overlay.gd  (origin: a2f9d139 feat(core): godot: evaluation mode — coupling and centrality visualization (#108))
  These are informational only and do NOT count as a FAIL for this branch.
OK: No prohibited (not-in-scope) features detected.

## New Check Scripts Added to main After Branch Creation (cycle 13)

The following check script is present after `git checkout main -- .hyperloop/checks/`
but was NOT present in the cycle 12 checks directory (16 scripts → 17 scripts):
  check-circular-position-y-axis.sh  (new in cycle 13 sync)

Per guidelines: not a process violation by the implementer, but every FAIL is still
blocking.

## Check Script Results

=== run-all-checks.sh ===

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-001' has 37 commit(s) above main.
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present in working tree (17 checked).
[EXIT 0]

--- check-circular-position-y-axis.sh ---
FAIL: Non-zero y-axis value in _circular_positions call inflates 3D distance.
  A non-zero y argument (e.g. y=1.0) adds a vertical component to every child
  position.  The proximity test computes a 3D distance, so this inflation causes
  test_child_nodes_are_near_parent_position to fail even when the orbit radius is
  correctly bounded.  This is a separate contributor from the unbounded max() issue.

  Offending lines:
  extractor/extractor.py:222:        mod_positions = _circular_positions(len(children), mod_radius, y=1.0)

  Fix: use y=0.0 in every _circular_positions call for module-level positions:
    _circular_positions(children, radius, center=(...), y=0.0)
[EXIT 1 — FAIL]

--- check-commit-trailer-task-ref.sh ---
FAIL: One or more implementation commits carry a Task-Ref that does not match the branch.

  Branch:   hyperloop/task-001
  Expected: Task-Ref: task-001

  Mismatched commits:
  997ac24  Task-Ref: task-007  (expected task-001)

  This typically happens when a commit is copied from another task without
  updating the Task-Ref trailer.  Fix with an interactive rebase:
    git rebase -i main   # mark each affected commit as 'reword'
    # update Task-Ref: <old> to Task-Ref: task-001 in each message

  Confirm the branch task ID before each commit:
    git rev-parse --abbrev-ref HEAD   # shows hyperloop/task-001
[EXIT 1 — FAIL]

--- check-layout-radius-bound.sh ---
FAIL: Unbounded child-orbit radius detected in layout source.
  A bare max(lower, expr) without a wrapping min(…, parent_size * fraction)
  allows child nodes to be placed outside the parent's scene bounds.

  Offending lines:
  extractor/extractor.py:206:    bc_radius = max(5.0, len(bc_nodes) * 2.5)
  extractor/extractor.py:221:        mod_radius = max(1.5, len(children) * 0.9)

  Fix: wrap the max() in a min() to cap the radius:
    mod_radius = min(max(1.5, len(children) * 0.9), parent_size * 0.4)
  Or, if no parent_size is available, derive a safe cap from a sibling
  attribute (e.g., scene_radius) and clamp to it.

  Alternatively, fix the test's coordinate-frame assumption: compare
  the child LOCAL position magnitude against parent size rather than
  world-distance from parent world position.
[EXIT 1 — FAIL]

--- check-new-modules-wired.sh ---
OK: 'extractor/extractor.py' is imported by production code (1 import(s) found).
FAIL: New module 'extractor/layout.py' is not imported by any production source file.
  'layout' was added on this branch but no non-test Python file imports it.
  Tests for 'layout' pass but provide no assurance about the actual
  runtime code path — the consuming file's old internal function remains active.

  Fix: either
    (a) Import it from the consuming file (e.g. 'from extractor.layout import <fn>')
        and remove or delegate the old internal definition, OR
    (b) Fix the logic directly in the consuming file and delete extractor/layout.py.
[EXIT 1 — FAIL]

--- check-no-duplicate-toplevel-functions.sh ---
DUPLICATE: 'compute_layout' defined in 2 files:
  extractor/extractor.py
  extractor/layout.py

FAIL: Duplicate top-level function name(s) found across extractor/ source files.
  Each function should be defined in exactly one non-test source file.
  A duplicate means the consuming file still calls the original (possibly broken)
  definition while the new file's tests pass — giving false confidence.

  Fix:
    (a) Fix the function in-place in the ORIGINAL file and delete the new file, OR
    (b) Remove the definition from the original file and import from the new one.

  Run check-new-modules-wired.sh after fix (b) to confirm the import is wired.
[EXIT 1 — FAIL]

--- check-not-in-scope.sh ---
NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  godot/scripts/understanding_overlay.gd  (origin: a2f9d139 feat(core): godot: evaluation mode — coupling and centrality visualization (#108))
  These are informational only and do NOT count as a FAIL for this branch.
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-no-zero-commit-reattempt.sh ---
FAIL: Zero implementation commits since prior FAIL report (c738bb9).

  The prior committed worker-result.yaml (c738bb9) contains
  16 FAIL check(s).  No non-hyperloop commits have been
  added to this branch since that report was written.

  Note: if the most-recently committed report appears clean (e.g., due to
  an orchestrator cleanup commit), this check walks full branch history to
  find the actual prior FAIL report — consistent with check-racf-prior-cycle.sh.

  This means the implementer submitted a re-attempt without applying any
  fixes.  This is the pattern that causes repeated RACF across many cycles.

  Protocol:
    1. Run each failing check: bash .hyperloop/checks/<check>.sh
    2. Apply the prescribed fix from its FAIL output.
    3. Commit the fix: git commit -m 'fix: <description>'
    4. Repeat for each failing check.
    5. Only then run run-all-checks.sh and write worker-result.yaml.
[EXIT 1 — FAIL]

--- check-pytest-passes.sh ---
Running: pytest extractor/tests/ -v --tb=short

============================= test session starts ==============================
platform linux -- Python 3.13.12, pytest-8.4.1, pluggy-1.6.0 -- /usr/bin/python3
cachedir: .pytest_cache
rootdir: /home/jsell/code/sandbox/code-vis/worktrees/workers/task-001
plugins: anyio-4.9.0, mock-3.14.1, cov-6.2.1, asyncio-1.0.0, respx-0.22.0, archon-0.0.7
asyncio: mode=Mode.STRICT, asyncio_default_fixture_loop_scope=None, asyncio_default_test_loop_scope=function
collecting ... collected 110 items

extractor/tests/test_cli.py::test_main_exits_zero PASSED
extractor/tests/test_cli.py::test_main_writes_json_output PASSED
extractor/tests/test_cli.py::test_main_returns_nonzero_for_missing_path PASSED
extractor/tests/test_cli.py::test_extractor_imports_are_stdlib_only PASSED
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_python_package_true PASSED
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_python_package_false_no_init PASSED
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_python_package_false_not_dir PASSED
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_bounded_context_true PASSED
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_bounded_context_excludes_tests PASSED
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_bounded_context_excludes_underscored PASSED
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_internal_module_true PASSED
extractor/tests/test_extractor.py::TestComplexityMetrics::test_compute_loc_counts_python_lines PASSED
extractor/tests/test_extractor.py::TestComplexityMetrics::test_compute_loc_recursive PASSED
extractor/tests/test_extractor.py::TestComplexityMetrics::test_compute_loc_empty_dir PASSED
extractor/tests/test_extractor.py::TestComplexityMetrics::test_size_from_loc_minimum PASSED
extractor/tests/test_extractor.py::TestComplexityMetrics::test_size_from_loc_grows_with_loc PASSED
extractor/tests/test_extractor.py::TestComplexityMetrics::test_size_from_loc_is_float PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_extract_absolute_import PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_extract_from_import PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_relative_imports_excluded PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_syntax_error_returns_empty PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_exact_match PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_sub_module PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_bc_level PASSED
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_unknown PASSED
extractor/tests/test_extractor.py::TestEdgeClassification::test_classify_cross_context PASSED
extractor/tests/test_extractor.py::TestEdgeClassification::test_classify_internal PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_discovers_bounded_contexts PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_excludes_tests_directory PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_node_has_required_keys PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_type PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_parent_is_none PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_has_metrics_loc PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_discovers_submodules_in_iam PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_parent_references_bc PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_type_is_module PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_id_is_dotted PASSED
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_has_metrics_loc PASSED
extractor/tests/test_extractor.py::TestDependencyExtraction::test_cross_context_edge_created PASSED
extractor/tests/test_extractor.py::TestDependencyExtraction::test_cross_context_edge_type PASSED
extractor/tests/test_extractor.py::TestDependencyExtraction::test_internal_edge_created PASSED
extractor/tests/test_extractor.py::TestDependencyExtraction::test_internal_edge_type PASSED
extractor/tests/test_extractor.py::TestDependencyExtraction::test_no_self_edges PASSED
extractor/tests/test_extractor.py::TestDependencyExtraction::test_edges_have_required_keys PASSED
extractor/tests/test_extractor.py::TestLayout::test_all_nodes_have_positions_after_layout PASSED
extractor/tests/test_extractor.py::TestLayout::test_bounded_contexts_have_distinct_positions PASSED
extractor/tests/test_extractor.py::TestLayout::test_child_nodes_are_near_parent_position FAILED
extractor/tests/test_extractor.py::TestLayout::test_coupled_bcs_are_closer_than_uncoupled PASSED
extractor/tests/test_extractor.py::TestLayout::test_order_by_coupling_places_coupled_adjacent PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_build_scene_graph_has_required_keys PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_nodes_include_bounded_contexts PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_nodes_include_internal_modules PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_edges_non_empty PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_metadata_has_source_path PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_metadata_has_timestamp PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_output_is_json_serialisable PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_node_ids_are_unique PASSED
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_every_node_has_position PASSED
extractor/tests/test_extractor.py::test_main_cli_produces_valid_json PASSED
extractor/tests/test_extractor.py::test_extractor_uses_only_stdlib_imports PASSED
extractor/tests/test_extractor.py::test_extractor_with_kartograph_codebase PASSED
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_all_positions_have_xyz PASSED
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_positions_are_floats PASSED
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_every_node_id_in_output PASSED
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_empty_graph_returns_empty_dict PASSED
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_single_node_placed_at_deterministic_position PASSED
extractor/tests/test_layout.py::TestTightlyCoupledNodesAreCloser::test_tightly_coupled_nodes_are_closer PASSED
extractor/tests/test_layout.py::TestTightlyCoupledNodesAreCloser::test_more_edges_means_closer PASSED
extractor/tests/test_layout.py::TestTightlyCoupledNodesAreCloser::test_unconnected_third_node_stays_far PASSED
extractor/tests/test_layout.py::TestChildNodesWithinParentBounds::test_child_nodes_within_parent_spatial_bounds PASSED
extractor/tests/test_layout.py::TestChildNodesWithinParentBounds::test_multiple_children_all_within_parent_bounds PASSED
extractor/tests/test_layout.py::TestChildNodesWithinParentBounds::test_larger_parent_allows_larger_child_orbit PASSED
extractor/tests/test_layout.py::TestDistanceHelper::test_distance_2d_zero_for_identical_points PASSED
extractor/tests/test_layout.py::TestDistanceHelper::test_distance_2d_ignores_y PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_nodes_key PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_edges_key PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_metadata_key PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_no_extra_top_level_fields PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_is_json_serialisable PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_nodes_is_a_list PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_edges_is_a_list PASSED
extractor/tests/test_schema.py::TestSchemaStructure::test_metadata_is_a_dict PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_has_required_keys PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_id PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_name PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_type PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_position_has_xyz PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_position_values_are_numeric PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_size_is_numeric PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_parent_is_null PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_has_required_keys PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_id_dotted PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_type_is_module PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_parent_references_context PASSED
extractor/tests/test_schema.py::TestNodeSchema::test_node_ids_are_unique PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_has_required_keys PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_source PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_target PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_type PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_has_required_keys PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_source PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_target PASSED
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_type PASSED
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_has_source_path PASSED
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_has_timestamp PASSED
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_source_path_is_str PASSED
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_timestamp_is_str PASSED
extractor/tests/test_schema.py::TestPreComputedLayout::test_every_node_has_a_position PASSED
extractor/tests/test_schema.py::TestPreComputedLayout::test_positions_are_floats PASSED
extractor/tests/test_schema.py::TestPreComputedLayout::test_scene_graph_nodes_have_distinct_positions PASSED

=================================== FAILURES ===================================
_____________ TestLayout.test_child_nodes_are_near_parent_position _____________
extractor/tests/test_extractor.py:432: in test_child_nodes_are_near_parent_position
    assert dist < bc_radius, (
E   AssertionError: Child graph.infrastructure is at distance 9.35 from parent graph,
E     exceeding scene radius 7.50. Child must be positioned within parent's spatial bounds.
E   assert 9.353608929178085 < 7.5
=========================== short test summary info ============================
FAILED extractor/tests/test_extractor.py::TestLayout::test_child_nodes_are_near_parent_position
======================== 1 failed, 109 passed in 0.46s =========================

FAIL: One or more pytest tests failed.
  Fix every failing test before submitting.
  A FAILED test means the implementation does not satisfy the spec.

  Common causes (from task-001 recurring failures):
    - mod_radius grows unbounded for contexts with many children:
        Fix: cap it, e.g. mod_radius = min(max(1.5, n*0.9), parent_size*0.4)
    - y-component in _circular_positions inflates 3D distance:
        Fix: use y=0.0 for module-level positions.
    - Test compares child world distance from parent — but child position
      is stored as a local offset.  Both must use the same coordinate frame.
[EXIT 1 — FAIL]

--- check-racf-prior-cycle.sh ---
Orchestrator cleanup obscured prior FAIL report — recovered from c738bb9.
To inspect: git show c738bb9:.hyperloop/worker-result.yaml

Checks that failed in that cycle — must now pass:

  check-commit-trailer-task-ref.sh                        FAIL (still failing — RACF)
  check-layout-radius-bound.sh                            FAIL (still failing — RACF)
  check-new-modules-wired.sh                              FAIL (still failing — RACF)
  check-no-duplicate-toplevel-functions.sh                FAIL (still failing — RACF)
  check-pytest-passes.sh                                  FAIL (still failing — RACF)
  check-racf-prior-cycle.sh                               SKIP (self-reference)
  check-relative-position-tests.sh                        FAIL (still failing — RACF)
  check-scope-report-not-falsified.sh                     OK (resolved)

FAIL: One or more prior-cycle failures recovered from c738bb9 still fail.
      This is a Re-Attempt Compliance Failure (RACF) obscured by orchestrator cleanup.
[EXIT 1 — FAIL]

--- check-racf-remediation.sh ---
SKIP: Prior committed report contains no FAIL checks — no RACF to verify.
[EXIT 0]

--- check-relative-position-tests.sh ---
FAIL: Extractor source accumulates parent world coordinates into child position.
  Found absolute-coordinate accumulation pattern (form A: px/py/pz + pos[],
  or form B: parent_pos[N] + ...) in a non-test Python file.
  The spec requires child positions to be relative (local offset only).
  Godot's main.gd adds the parent's world position at render time —
  storing absolute coordinates here causes double-offset rendering.
  This check scans ALL Python files in extractor/ — the bug is caught
  regardless of which file or variable names are used.

  Offending lines:
extractor/layout.py:92:                parent_pos[0] + math.cos(angle) * offset_r,
extractor/layout.py:93:                parent_pos[1] + math.sin(angle) * offset_r,

  Fix: store only the local offset in every file:
    child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}
  If a new module was created as the fix, verify it does not reproduce
  the pattern under different variable names (e.g., parent_pos[0] + ...).
FAIL: Only proximity-based child position tests found — no direct relative-offset assertion.
  A test like 'test_child_nodes_are_near_parent_position' that only checks
  abs(child_pos - parent_pos) < threshold passes for BOTH absolute and relative
  coordinate storage when the offset is small. It does NOT cover the spec
  requirement that positions are stored as relative (local) offsets.

  Required: a test that:
    1. Places the parent at a non-zero world position (e.g., x=10.0)
    2. Asserts child['position']['x'] == local_offset_x  (not proximity)
    3. Optionally asserts child['position']['x'] != parent_x + local_offset_x
[EXIT 1 — FAIL]

--- check-report-scope-section.sh ---
OK: worker-result.yaml contains a valid '## Scope Check Output' section (scope check
    ran and output was pasted verbatim).
[EXIT 0]

--- check-ruff-format.sh ---
OK: ruff format --check passed — all extractor/ files are correctly formatted.
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- pre-submit.sh ---
[EXIT 1 — FAIL: reviewer tooling conflict — see note below]

Note on pre-submit.sh failure: pre-submit.sh fails because this report contains
"RESULT: FAIL" (which it must — the implementation has blocking failures). The
gate was designed for implementers; a reviewer issuing FAIL cannot include verbatim
failing check output AND have pre-submit.sh exit 0 simultaneously. This is the same
known tooling conflict documented in cycles 10–12.

The three mandatory protocol requirements (from the Guidelines Submission Protocol):
  1. ## Scope Check Output section present: YES
  2. Verbatim check-not-in-scope.sh stdout beneath it: YES — "OK: No prohibited"
  3. run-all-checks.sh exits 0: NO — blocked by implementation failures listed below.
     Cannot be resolved without implementation code changes.

=== Summary: 17 check(s) run ===
RESULT: FAIL — one or more checks exited non-zero

## Commit Trailers

PASS — implementation commit 5d8aff2f carries both required trailers:
  Spec-Ref: specs/extraction/scene-graph-schema.spec.md@3e5e297e216c7876224564ee099a38334e3dbd55
  Task-Ref: task-001

FAIL — commit 997ac245 (Godot project setup, oldest implementation commit above main)
  carries Task-Ref: task-007 instead of task-001.
  Flagged by check-commit-trailer-task-ref.sh (see F_TRAILER below).

## Zero-Commit Re-Attempt Status

check-no-zero-commit-reattempt.sh confirms: no implementation commits have been
added since cycle 12's FAIL report (c738bb9). The only commit since that report
is 5cb15901 (orchestrator: clean worker verdict). This is the 9th consecutive
submission with zero remediation since the RACF pattern began at cycle 5.

## Semantic Scope Audit (independent of check-not-in-scope.sh)

Moldable/LLM features: grep for llm, build_prompt, parse_response, apply_spec,
  SceneInterpreter, LlmView, moldable → NO MATCHES in godot/ or extractor/
Data-flow visualization: grep for dataflow, flow_overlay, show_path → NO MATCHES
First-person navigation: grep for KEY_W, KEY_A, KEY_S, KEY_D, fly_cam → NO MATCHES
New GDScript file docstrings: no new .gd file added by this task references a
  prohibited spec section.
Result: PASS — no prohibited features found under novel names.

## Findings

---

### F_ZERO — BLOCKING: Zero-commit re-attempt (9th consecutive cycle)

check-no-zero-commit-reattempt.sh [EXIT 1 — FAIL]

No implementation commits have been added since the cycle 12 FAIL report (c738bb9).
The only commit above c738bb9 is 5cb15901 (orchestrator cleanup). The implementer
submitted this cycle with zero code changes — all checks that failed in cycle 12
still fail identically in cycle 13.

This is a separate blocking finding independent of the underlying failures.

---

### F_RACF — BLOCKING: Re-Attempt Compliance Failure (cycles 5–13, 9th consecutive)

check-racf-prior-cycle.sh [EXIT 1 — FAIL]

Prior-cycle failures from c738bb9 (cycle 12) that still fail in cycle 13:
  check-commit-trailer-task-ref.sh  (F_TRAILER)
  check-layout-radius-bound.sh      (F_RADIUS)
  check-new-modules-wired.sh        (F1)
  check-no-duplicate-toplevel-functions.sh  (F2)
  check-pytest-passes.sh            (F4)
  check-relative-position-tests.sh  (F3a / F3b)

All prescribed fixes from prior cycles are documented verbatim below in each
finding. None have been applied.

---

### F_TRAILER — BLOCKING: wrong Task-Ref on commit 997ac245

check-commit-trailer-task-ref.sh [EXIT 1 — FAIL]

Commit 997ac245 ("feat(prototype): godot — project setup") carries
`Task-Ref: task-007` on branch `hyperloop/task-001`. This check was added to
main in cycle 12 (commit 98c064a4); it is not a process violation by the
implementer that the check was absent when the branch was created. The FAIL
is still blocking.

Provenance: 997ac245 is the oldest implementation commit above main and predates
all task-001 chore/begin commits. It is Godot project-setup work originally
attributed to task-007.

Prescribed fix (unchanged from cycle 12):
  git rebase -i main   # mark 997ac245 as 'reword'
  # change: Task-Ref: task-007
  # to:     Task-Ref: task-001

---

### F_YAXIS — BLOCKING: non-zero y-axis in _circular_positions (NEW in cycle 13)

check-circular-position-y-axis.sh [EXIT 1 — FAIL]

check-circular-position-y-axis.sh is a new check added to main in cycle 13
(commit 98c064a4 process: add y-axis check). Not a process violation by the
implementer — still blocking per guidelines.

extractor/extractor.py:222:
  mod_positions = _circular_positions(len(children), mod_radius, y=1.0)

The y=1.0 argument adds a vertical component to every child position. The
proximity test computes a 3D Euclidean distance; this vertical offset inflates
that distance by 1.0 units independently of orbit radius. This is a separate
contributor to the F4 pytest failure alongside the unbounded mod_radius (F_RADIUS).

Prescribed fix:
  extractor/extractor.py:222: change y=1.0 → y=0.0

---

### F1 — BLOCKING (RACF cycles 5–13): layout.py is dead code

check-new-modules-wired.sh [EXIT 1 — FAIL]

extractor/layout.py is not imported by any production source file.
Active runtime path:
  __main__.py → extractor.extractor.build_scene_graph()
              → extractor.extractor.compute_layout()  (defined at extractor.py:189)

extractor/tests/test_layout.py tests extractor.layout.compute_layout — a function
never called at runtime. Zero behavioral assurance provided by these tests.

Prescribed fix (unchanged from cycles 5–12):
  Option A (recommended): Delete extractor/layout.py and extractor/tests/test_layout.py.
    Fix compute_layout in-place in extractor/extractor.py to resolve F3a, F_RADIUS,
    F_YAXIS, and F4. Add equivalent algorithm-quality tests to test_extractor.py.
  Option B: In extractor/extractor.py, add:
    from extractor.layout import compute_layout
    Remove the internal compute_layout definition. First resolve F3a (absolute coords
    in layout.py) before wiring.

---

### F2 — BLOCKING (RACF cycles 5–13): compute_layout defined in two files

check-no-duplicate-toplevel-functions.sh [EXIT 1 — FAIL]

compute_layout is defined in both extractor/extractor.py and extractor/layout.py.
Resolving F1 (either option) also resolves F2.

---

### F3a — BLOCKING (RACF cycles 5–13): absolute coordinates in layout.py

check-relative-position-tests.sh [EXIT 1 — FAIL] (first condition)

extractor/layout.py:92–93 stores absolute world coordinates (parent_world + local_offset):
  parent_pos[0] + math.cos(angle) * offset_r
  parent_pos[1] + math.sin(angle) * offset_r

The spec requires child positions to be stored as local (relative) offsets only.
Godot's main.gd adds the parent world position at render time — storing absolute
coordinates here causes double-offset rendering bugs.

Prescribed fix (unchanged from cycles 5–12):
  Change layout.py:92–93 to store local offsets only:
    math.cos(angle) * offset_r,
    math.sin(angle) * offset_r,
  Or delete layout.py entirely (Option A from F1).

---

### F3b — BLOCKING (RACF cycles 5–13): no relative-offset assertion test

check-relative-position-tests.sh [EXIT 1 — FAIL] (second condition)

All child-position tests check proximity (distance < threshold) rather than the
actual stored coordinate value. A proximity test passes for both absolute and
relative coordinate storage when the offset is small — it provides zero assurance
that local offsets are stored correctly.

Prescribed fix (unchanged from cycles 5–12):
  Add a test to test_extractor.py that:
  1. Uses a fixture placing the parent BC at a non-zero world position.
  2. Calls compute_layout(nodes, edges).
  3. Asserts child["position"]["x"] == approx(expected_local_offset_x) directly.
  4. Optionally: asserts child["position"]["x"] != approx(parent_x + local_offset_x).

---

### F_RADIUS — BLOCKING (RACF cycles 11–13): unbounded mod_radius

check-layout-radius-bound.sh [EXIT 1 — FAIL]

extractor/extractor.py:221: mod_radius = max(1.5, len(children) * 0.9) — no upper bound.
extractor/extractor.py:206: bc_radius  = max(5.0, len(bc_nodes)  * 2.5) — also flagged.

For the standard src fixture (3 BCs, 2 modules per context):
  mod_radius = max(1.5, 2*0.9) = 1.8  (within bounds)
  But the y=1.0 offset (F_YAXIS) and the coordinate-frame confusion in the test
  together inflate the measured distance to 9.35, exceeding the 7.50 threshold.

Prescribed fix (unchanged from cycles 11–12):
  extractor/extractor.py:221:
    mod_radius = min(max(1.5, len(children) * 0.9), parent_node["size"] * 0.4)
  AND fix y=1.0 → y=0.0 at extractor.py:222 (also fixes F_YAXIS).

---

### F4 — BLOCKING (RACF cycles 5–13): pytest failure

check-pytest-passes.sh [EXIT 1 — FAIL]

FAILED test_extractor.py::TestLayout::test_child_nodes_are_near_parent_position
  assert 9.353608929178085 < 7.5

Three contributing causes, each individually sufficient to produce the failure:
  1. F_YAXIS: y=1.0 adds 1.0 to 3D distance regardless of radius.
  2. F_RADIUS: mod_radius is unbounded (though at 1.8 it is within bounds for
     the current 2-child fixture — radius cap is a correctness issue for larger
     fixtures rather than the direct cause here).
  3. Coordinate-frame confusion: the test computes distance between child LOCAL
     position and parent WORLD position — two different coordinate frames.

Prescribed fix (option A — recommended, unchanged from cycles 5–12):
  extractor/extractor.py:221: add min() cap on mod_radius.
  extractor/extractor.py:222: change y=1.0 → y=0.0.
  Verify the test's coordinate-frame assumption after both changes are applied.
  If the test compares cross-frame coordinates, fix the test to compare
  child local-vector magnitude against parent_size instead.

---

### REVIEWER TOOLING CONFLICT: pre-submit.sh cannot exit 0 for a FAIL verdict

Same conflict documented in cycles 10–12. A reviewer reporting FAIL cannot satisfy
pre-submit.sh requirement 3 (run-all-checks.sh exits 0) while also including the
required verbatim failing check output.

Mandatory protocol requirements (Guidelines Submission Protocol):
  1. ## Scope Check Output section present: YES
  2. Verbatim check-not-in-scope.sh stdout beneath it: YES — "OK: No prohibited..."
  3. run-all-checks.sh exits 0: NO — blocked by F_ZERO, F_RACF, F_TRAILER,
     F_YAXIS, F1, F2, F3a, F3b, F_RADIUS, F4. None resolvable without code changes.

---

## RACF Process Summary (cycle 13)

F1, F2, F3a, F3b, F4 have been unresolved since cycle 5 — 9 consecutive cycles.
F_RADIUS (check-layout-radius-bound.sh) unresolved since cycle 11.
F_TRAILER (check-commit-trailer-task-ref.sh) unresolved since cycle 12.
F_YAXIS (check-circular-position-y-axis.sh) is new in cycle 13 (new check on main).
F_ZERO (check-no-zero-commit-reattempt.sh) unresolved since first re-attempt.

Prescribed fix order for the implementer:
  1. Fix F_TRAILER: rebase 997ac245 to change Task-Ref: task-007 → task-001.
  2. Fix F1/F2: delete extractor/layout.py and extractor/tests/test_layout.py.
  3. Fix F3a: fix compute_layout in-place in extractor/extractor.py to store
     local offsets only (not parent_pos + offset).
  4. Fix F_YAXIS: change y=1.0 → y=0.0 at extractor.py:222.
  5. Fix F_RADIUS: cap mod_radius with min() at extractor.py:221.
  6. Fix F4: run pytest and confirm all 110 tests pass.
  7. Fix F3b: add a relative-offset assertion test to test_extractor.py.
  8. Run bash .hyperloop/checks/run-all-checks.sh and confirm all 17 checks
     exit 0 before committing or submitting.