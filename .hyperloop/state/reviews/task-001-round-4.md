---
task_id: task-001
round: 4
role: verifier
verdict: fail
---
## Scope Check Output

NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  godot/scripts/understanding_overlay.gd  (origin: a2f9d139 feat(core): godot: evaluation mode — coupling and centrality visualization (#108))
  These are informational only and do NOT count as a FAIL for this branch.
OK: No prohibited (not-in-scope) features detected.

## New Check Scripts Added to main After Branch Creation (cycle 12)

The following check scripts are present after `git checkout main -- .hyperloop/checks/`
but were NOT present in the cycle 11 checks directory on the branch:
  check-checks-in-sync.sh        (new in cycle 12 sync)
  check-commit-trailer-task-ref.sh  (new in cycle 12 sync)

Per guidelines: not a process violation by the implementer, but every FAIL is still
blocking.

## Check Script Results

=== run-all-checks.sh ===

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-001' has 35 commit(s) above main.
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present in working tree (16 checked).
[EXIT 0]

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
SKIP: Prior committed report contains no FAIL checks — no zero-commit re-attempt possible.
[EXIT 0]

--- check-pytest-passes.sh ---
Running: pytest extractor/tests/ -v --tb=short

============================= test session starts ==============================
platform linux -- Python 3.13.12, pytest-8.4.1, pluggy-1.6.0 -- /usr/bin/python3
cachedir: .pytest_cache
rootdir: /home/jsell/code/sandbox/code-vis/worktrees/workers/task-001
plugins: anyio-4.9.0, mock-3.14.1, cov-6.2.1, asyncio-1.0.0, respx-0.22.0, archon-0.0.7
asyncio: mode=Mode.STRICT, asyncio_default_fixture_loop_scope=None, asyncio_default_test_loop_scope=function
collecting ... collected 110 items

extractor/tests/test_cli.py::test_main_exits_zero PASSED                 [  0%]
extractor/tests/test_cli.py::test_main_writes_json_output PASSED         [  1%]
extractor/tests/test_cli.py::test_main_returns_nonzero_for_missing_path PASSED [  2%]
extractor/tests/test_cli.py::test_extractor_imports_are_stdlib_only PASSED [  3%]
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_python_package_true PASSED [  4%]
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_python_package_false_no_init PASSED [  5%]
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_python_package_false_not_dir PASSED [  6%]
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_bounded_context_true PASSED [  7%]
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_bounded_context_excludes_tests PASSED [  8%]
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_bounded_context_excludes_underscored PASSED [  9%]
extractor/tests/test_extractor.py::TestFilesystemPredicates::test_is_internal_module_true PASSED [ 10%]
extractor/tests/test_extractor.py::TestComplexityMetrics::test_compute_loc_counts_python_lines PASSED [ 10%]
extractor/tests/test_extractor.py::TestComplexityMetrics::test_compute_loc_recursive PASSED [ 11%]
extractor/tests/test_extractor.py::TestComplexityMetrics::test_compute_loc_empty_dir PASSED [ 12%]
extractor/tests/test_extractor.py::TestComplexityMetrics::test_size_from_loc_minimum PASSED [ 13%]
extractor/tests/test_extractor.py::TestComplexityMetrics::test_size_from_loc_grows_with_loc PASSED [ 14%]
extractor/tests/test_extractor.py::TestComplexityMetrics::test_size_from_loc_is_float PASSED [ 15%]
extractor/tests/test_extractor.py::TestImportExtraction::test_extract_absolute_import PASSED [ 16%]
extractor/tests/test_extractor.py::TestImportExtraction::test_extract_from_import PASSED [ 17%]
extractor/tests/test_extractor.py::TestImportExtraction::test_relative_imports_excluded PASSED [ 18%]
extractor/tests/test_extractor.py::TestImportExtraction::test_syntax_error_returns_empty PASSED [ 19%]
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_exact_match PASSED [ 20%]
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_sub_module PASSED [ 20%]
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_bc_level PASSED [ 21%]
extractor/tests/test_extractor.py::TestImportExtraction::test_get_target_node_id_unknown PASSED [ 22%]
extractor/tests/test_extractor.py::TestEdgeClassification::test_classify_cross_context PASSED [ 23%]
extractor/tests/test_extractor.py::TestEdgeClassification::test_classify_internal PASSED [ 24%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_discovers_bounded_contexts PASSED [ 25%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_excludes_tests_directory PASSED [ 26%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_node_has_required_keys PASSED [ 27%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_type PASSED [ 28%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_parent_is_none PASSED [ 29%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_bounded_context_has_metrics_loc PASSED [ 30%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_discovers_submodules_in_iam PASSED [ 30%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_parent_references_bc PASSED [ 31%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_type_is_module PASSED [ 32%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_id_is_dotted PASSED [ 33%]
extractor/tests/test_extractor.py::TestModuleDiscovery::test_submodule_has_metrics_loc PASSED [ 34%]
extractor/tests/test_extractor.py::TestDependencyExtraction::test_cross_context_edge_created PASSED [ 35%]
extractor/tests/test_extractor.py::TestDependencyExtraction::test_cross_context_edge_type PASSED [ 36%]
extractor/tests/test_extractor.py::TestDependencyExtraction::test_internal_edge_created PASSED [ 37%]
extractor/tests/test_extractor.py::TestDependencyExtraction::test_internal_edge_type PASSED [ 38%]
extractor/tests/test_extractor.py::TestDependencyExtraction::test_no_self_edges PASSED [ 39%]
extractor/tests/test_extractor.py::TestDependencyExtraction::test_edges_have_required_keys PASSED [ 40%]
extractor/tests/test_extractor.py::TestLayout::test_all_nodes_have_positions_after_layout PASSED [ 40%]
extractor/tests/test_extractor.py::TestLayout::test_bounded_contexts_have_distinct_positions PASSED [ 41%]
extractor/tests/test_extractor.py::TestLayout::test_child_nodes_are_near_parent_position FAILED [ 42%]
extractor/tests/test_extractor.py::TestLayout::test_coupled_bcs_are_closer_than_uncoupled PASSED [ 43%]
extractor/tests/test_extractor.py::TestLayout::test_order_by_coupling_places_coupled_adjacent PASSED [ 44%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_build_scene_graph_has_required_keys PASSED [ 45%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_nodes_include_bounded_contexts PASSED [ 46%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_nodes_include_internal_modules PASSED [ 47%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_edges_non_empty PASSED [ 48%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_metadata_has_source_path PASSED [ 49%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_metadata_has_timestamp PASSED [ 50%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_output_is_json_serialisable PASSED [ 50%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_node_ids_are_unique PASSED [ 51%]
extractor/tests/test_extractor.py::TestSceneGraphOutput::test_every_node_has_position PASSED [ 52%]
extractor/tests/test_extractor.py::test_main_cli_produces_valid_json PASSED [ 53%]
extractor/tests/test_extractor.py::test_extractor_uses_only_stdlib_imports PASSED [ 54%]
extractor/tests/test_extractor.py::test_extractor_with_kartograph_codebase PASSED [ 55%]
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_all_positions_have_xyz PASSED [ 56%]
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_positions_are_floats PASSED [ 57%]
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_every_node_id_in_output PASSED [ 58%]
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_empty_graph_returns_empty_dict PASSED [ 59%]
extractor/tests/test_layout.py::TestAllPositionsHaveXYZ::test_single_node_placed_at_deterministic_position PASSED [ 60%]
extractor/tests/test_layout.py::TestTightlyCoupledNodesAreCloser::test_tightly_coupled_nodes_are_closer PASSED [ 60%]
extractor/tests/test_layout.py::TestTightlyCoupledNodesAreCloser::test_more_edges_means_closer PASSED [ 61%]
extractor/tests/test_layout.py::TestTightlyCoupledNodesAreCloser::test_unconnected_third_node_stays_far PASSED [ 62%]
extractor/tests/test_layout.py::TestChildNodesWithinParentBounds::test_child_nodes_within_parent_spatial_bounds PASSED [ 63%]
extractor/tests/test_layout.py::TestChildNodesWithinParentBounds::test_multiple_children_all_within_parent_bounds PASSED [ 64%]
extractor/tests/test_layout.py::TestChildNodesWithinParentBounds::test_larger_parent_allows_larger_child_orbit PASSED [ 65%]
extractor/tests/test_layout.py::TestDistanceHelper::test_distance_2d_zero_for_identical_points PASSED [ 66%]
extractor/tests/test_layout.py::TestDistanceHelper::test_distance_2d_ignores_y PASSED [ 67%]
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_nodes_key PASSED [ 68%]
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_edges_key PASSED [ 69%]
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_metadata_key PASSED [ 70%]
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_no_extra_top_level_fields PASSED [ 70%]
extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_is_json_serialisable PASSED [ 71%]
extractor/tests/test_schema.py::TestSchemaStructure::test_nodes_is_a_list PASSED [ 72%]
extractor/tests/test_schema.py::TestSchemaStructure::test_edges_is_a_list PASSED [ 73%]
extractor/tests/test_schema.py::TestSchemaStructure::test_metadata_is_a_dict PASSED [ 74%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_has_required_keys PASSED [ 75%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_id PASSED [ 76%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_name PASSED [ 77%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_type PASSED [ 78%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_position_has_xyz PASSED [ 79%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_position_values_are_numeric PASSED [ 80%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_size_is_numeric PASSED [ 80%]
extractor/tests/test_schema.py::TestNodeSchema::test_bounded_context_node_parent_is_null PASSED [ 81%]
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_has_required_keys PASSED [ 82%]
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_id_dotted PASSED [ 83%]
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_type_is_module PASSED [ 84%]
extractor/tests/test_schema.py::TestNodeSchema::test_module_node_parent_references_context PASSED [ 85%]
extractor/tests/test_schema.py::TestNodeSchema::test_node_ids_are_unique PASSED [ 86%]
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_has_required_keys PASSED [ 87%]
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_source PASSED [ 88%]
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_target PASSED [ 89%]
extractor/tests/test_schema.py::TestEdgeSchema::test_cross_context_edge_type PASSED [ 90%]
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_has_required_keys PASSED [ 90%]
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_source PASSED [ 91%]
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_target PASSED [ 92%]
extractor/tests/test_schema.py::TestEdgeSchema::test_internal_edge_type PASSED [ 93%]
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_has_source_path PASSED [ 94%]
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_has_timestamp PASSED [ 95%]
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_source_path_is_str PASSED [ 96%]
extractor/tests/test_schema.py::TestMetadataSchema::test_metadata_timestamp_is_str PASSED [ 97%]
extractor/tests/test_schema.py::TestPreComputedLayout::test_every_node_has_a_position PASSED [ 98%]
extractor/tests/test_schema.py::TestPreComputedLayout::test_positions_are_floats PASSED [ 99%]
extractor/tests/test_schema.py::TestPreComputedLayout::test_scene_graph_nodes_have_distinct_positions PASSED [100%]

=================================== FAILURES ===================================
_____________ TestLayout.test_child_nodes_are_near_parent_position _____________
extractor/tests/test_extractor.py:432: in test_child_nodes_are_near_parent_position
    assert dist < bc_radius, (
E   AssertionError: Child graph.infrastructure is at distance 9.35 from parent graph,
E     exceeding scene radius 7.50. Child must be positioned within parent's spatial bounds.
E   assert 9.353608929178085 < 7.5
=========================== short test summary info ============================
FAILED extractor/tests/test_extractor.py::TestLayout::test_child_nodes_are_near_parent_position
======================== 1 failed, 109 passed in 0.42s =========================

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
Orchestrator cleanup obscured prior FAIL report — recovered from eb37c48.
To inspect: git show eb37c48:.hyperloop/worker-result.yaml

Checks that failed in that cycle — must now pass:

  check-layout-radius-bound.sh                            FAIL (still failing — RACF)
  check-new-modules-wired.sh                              FAIL (still failing — RACF)
  check-no-duplicate-toplevel-functions.sh                FAIL (still failing — RACF)
  check-pytest-passes.sh                                  FAIL (still failing — RACF)
  check-racf-prior-cycle.sh                               SKIP (self-reference)
  check-relative-position-tests.sh                        FAIL (still failing — RACF)
  check-scope-report-not-falsified.sh                     OK (resolved)

FAIL: One or more prior-cycle failures recovered from eb37c48 still fail.
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
known tooling conflict documented in cycles 10 and 11.

The three mandatory protocol requirements (from the Guidelines Submission Protocol):
  1. ## Scope Check Output section present: YES
  2. Verbatim check-not-in-scope.sh stdout beneath it: YES — "OK: No prohibited"
  3. run-all-checks.sh exits 0: NO — blocked by implementation failures below.
     Cannot be resolved without implementation code changes.

=== Summary: 16 check(s) run ===
RESULT: FAIL — one or more checks exited non-zero

## Commit Trailers

PASS — implementation commit 5d8aff2f carries both required trailers:
  Spec-Ref: specs/extraction/scene-graph-schema.spec.md@3e5e297e216c7876224564ee099a38334e3dbd55
  Task-Ref: task-001

FAIL — commit 997ac245 (Godot project setup, oldest commit above main) carries
  Task-Ref: task-007 instead of task-001. Flagged by new check-commit-trailer-task-ref.sh
  (see F_TRAILER below).

## Semantic Scope Audit (independent of check-not-in-scope.sh)

Moldable/LLM features: grep for llm, build_prompt, parse_response, apply_spec,
  SceneInterpreter, LlmView, moldable → NO MATCHES in godot/ or extractor/
Data-flow visualization: grep for dataflow, flow_overlay, FlowOverlay, show_path,
  flow_path, clear_path → NO MATCHES
First-person navigation: grep for KEY_W, KEY_A, KEY_S, KEY_D, fly_cam,
  first_person in godot/ → NO MATCHES
New GDScript file docstrings: no new .gd file added by this task references a
  prohibited spec section.
Result: PASS — no prohibited features found under novel names.

## THEN→Test Mapping (cycle 12 — independent verification)

All test function names verified by reading test files. Predicate alignment verified
by reading actual assert statements, not just test names.

| # | THEN-clause | Test function | File | Status |
|---|-------------|---------------|------|--------|
| T1a | top-level has nodes, edges, metadata | test_build_scene_graph_has_required_keys | test_extractor.py:522 | COVERED — `in` checks on all three keys |
| T1b | no other top-level fields present | test_scene_graph_has_no_extra_top_level_fields | test_schema.py:90 | COVERED — `set(graph.keys()) == {"nodes","edges","metadata"}` |
| T2a | BC node has unique id | test_node_ids_are_unique | test_extractor.py:562 | COVERED |
| T2b | BC node has name | test_bounded_context_node_has_required_keys | test_extractor.py:240 | COVERED |
| T2c | BC node has type "bounded_context" | test_bounded_context_type | test_extractor.py:247 | COVERED |
| T2d | BC node has position x/y/z | test_all_nodes_have_positions_after_layout + test_every_node_has_position | test_extractor.py:391,567 | COVERED |
| T2e | BC node has size from complexity | test_bounded_context_has_metrics_loc + test_size_from_loc_grows_with_loc | test_extractor.py:257,159 | COVERED |
| T2f | BC node parent is null | test_bounded_context_parent_is_none | test_extractor.py:252 | COVERED |
| T3a | module node has dotted unique id | test_submodule_id_is_dotted | test_extractor.py:280 | COVERED |
| T3b | module node has parent reference | test_submodule_parent_references_bc | test_extractor.py:270 | COVERED |
| T3c | module node has type "module" | test_submodule_type_is_module | test_extractor.py:275 | COVERED |
| T3d | module node position relative to parent | (none — no test asserts child local offset vs non-zero parent world position) | — | FAIL — check-relative-position-tests.sh second condition |
| T4a | cross-context edge has source/target | test_cross_context_edge_created | test_extractor.py:298 | COVERED |
| T4b | cross-context edge has type "cross_context" | test_cross_context_edge_type | test_extractor.py:309 | COVERED |
| T5a | internal edge has source/target | test_internal_edge_created | test_extractor.py:322 | COVERED |
| T5b | internal edge has type "internal" | test_internal_edge_type | test_extractor.py:332 | COVERED |
| T6a | metadata has source codebase path | test_metadata_has_source_path | test_extractor.py:545 | COVERED |
| T6b | metadata has timestamp | test_metadata_has_timestamp | test_extractor.py:550 | COVERED |
| T7a | layout positions have x/y/z | test_all_nodes_have_positions_after_layout | test_extractor.py:391 | COVERED |
| T7b | coupled nodes closer | test_coupled_bcs_are_closer_than_uncoupled | test_extractor.py:438 | COVERED — algorithm-quality: varies coupling, asserts relative distance |
| T7c | child nodes within parent spatial bounds | test_child_nodes_are_near_parent_position | test_extractor.py:407 | FAIL — pytest exits 1 (9.35 > 7.50). Root cause: coordinate-frame confusion |
| T7d | Godot renders at positions without recomputing | test_no_layout_recomputed_in_godot | test_node_renderer.gd:116 | COVERED — asserts node.position.{x,y,z} == JSON values exactly |

Failing THEN-clauses: T3d, T7c.

## Root Cause Analysis: T7c Failure (coordinate-frame confusion — independently derived)

Reproduced manually with the exact src fixture (graph, iam, shared_kernel BCs):

  extractor.py compute_layout:
    - BC "graph" assigned WORLD position (7.5, 0, 0)         ← absolute
    - "graph.infrastructure" assigned LOCAL offset (-1.8, 1.0, 0.0) ← relative to origin

  test_child_nodes_are_near_parent_position:
    px, py, pz = node_pos["graph"]           # = (7.5, 0.0, 0.0) — WORLD
    cx, cy, cz = node_pos["graph.infrastructure"]  # = (-1.8, 1.0, 0.0) — LOCAL OFFSET
    dist = sqrt((-1.8-7.5)^2 + (1.0-0)^2 + 0^2)
          = sqrt(86.49 + 1.0)
          = 9.35  → fails threshold 7.50

  The test is computing distance between two values in different coordinate frames.
  The correct containment check is: |child_local_vector| <= mod_radius <= parent_size.

  Additional contributor: _circular_positions(…, y=1.0) at extractor.py:222 adds
  a non-zero y component (+1.0) to module positions, inflating 3D distance by 1.0.
  check-pytest-passes.sh diagnostic: "Fix: use y=0.0 for module-level positions."

  Fix options (any one resolves F4):
    Option A: Change extractor.py:222 y=1.0 → y=0.0, AND cap mod_radius:
              mod_radius = min(max(1.5, len(children)*0.9), parent_node["size"]*0.4)
              Then the test's cross-frame distance is small enough to pass threshold.
    Option B: Fix the test to compare child position LOCAL magnitude:
              local_mag = sqrt(cx^2 + cy^2 + cz^2)
              assert local_mag <= parent_size * some_fraction
    Option C: Store child WORLD positions (parent_world + local offset) in extractor.py.
              Then parent and child are in the same coordinate frame in the test.
              Requires corresponding change in Godot main.gd to NOT add parent pos again.

## Findings

---

### F_TRAILER — BLOCKING (NEW in cycle 12): wrong Task-Ref on commit 997ac245

check-commit-trailer-task-ref.sh [EXIT 1 — FAIL]

Commit 997ac245 ("feat(prototype): godot — project setup") carries `Task-Ref: task-007`
on branch `hyperloop/task-001`. The check's own comment explicitly identifies this
commit SHA as the observed failure pattern.

Provenance: 997ac245 is the OLDEST commit above main on this branch. `git log main..HEAD
--oneline` confirms it predates all `chore: begin task-001` commits. It is the Godot
project setup work originally attributed to task-007, placed on the branch before
task-001 implementation began.

check-commit-trailer-task-ref.sh was added to main AFTER this branch was created —
not a process violation by the implementer. The FAIL is still blocking per guidelines.

Fix: git rebase -i main, mark 997ac245 as 'reword', change Task-Ref: task-007 to
Task-Ref: task-001.

---

### F1 — RACF (cycles 5-12, 8th consecutive cycle): layout.py is dead code

check-new-modules-wired.sh [EXIT 1 — FAIL]

extractor/layout.py added in 5d8aff2f is not imported by any production source file.
Active runtime path:
  __main__.py → extractor.extractor.build_scene_graph() → extractor.extractor.compute_layout()
  (defined at extractor/extractor.py:189)

extractor/tests/test_layout.py tests extractor.layout.compute_layout — a function
that is never called at runtime. Zero behavioral assurance.

Fix:
  Option A: Delete extractor/layout.py and extractor/tests/test_layout.py.
            Fix compute_layout in extractor.py in-place to match layout.py's
            spring-force algorithm quality. Add equivalent tests to test_extractor.py.
  Option B: In extractor/extractor.py, replace the internal compute_layout definition
            with: from extractor.layout import compute_layout
            First resolve F3a (absolute coords in layout.py) and reconcile signatures:
              extractor.py:  compute_layout(nodes, edges=None) -> None  (mutates in-place)
              layout.py:     compute_layout(nodes, edges) -> dict[str, Position]

No implementation commit since 5d8aff2f (Apr 25, 2026). 8 consecutive FAIL cycles.

---

### F2 — RACF (cycles 5-12, 8th consecutive cycle): compute_layout in two files

check-no-duplicate-toplevel-functions.sh [EXIT 1 — FAIL]

compute_layout defined in both extractor/extractor.py and extractor/layout.py.
Resolving F1 (either option) also resolves F2.

---

### F3a — RACF (cycles 5-12, 8th consecutive cycle): absolute coordinates in layout.py

check-relative-position-tests.sh [EXIT 1 — FAIL] (first condition)

layout.py:92-93 stores absolute (parent_world + local_offset) coordinates:
  parent_pos[0] + math.cos(angle) * offset_r
  parent_pos[1] + math.sin(angle) * offset_r

extractor.py:223's comment explicitly warns against this exact pattern and correctly
stores only local offsets. The bug lives only in the dead layout.py module but the
check scans all Python files.

Fix: Delete layout.py (Option A), or fix before wiring (Option B):
  pos[child["id"]] = [
      math.cos(angle) * offset_r,   # local x offset only
      math.sin(angle) * offset_r,   # local z offset only
  ]

---

### F3b — RACF (cycles 5-12, 8th consecutive cycle): no relative-offset assertion test

check-relative-position-tests.sh [EXIT 1 — FAIL] (second condition)

All child-position tests are proximity-based (distance < threshold) or suffer from
the coordinate-frame confusion documented in T7c root cause analysis. No test asserts
`child["position"]["x"] == approx(local_offset_x)` with parent at non-zero world x.

Required test addition to test_extractor.py:
  1. Drive a fixture that reliably places parent BC at non-zero world position x.
     (For single-BC fixture: bc_radius = max(5.0, 1*2.5) = 5.0; BC at (5.0, 0, 0).)
  2. Call compute_layout(nodes, edges).
  3. Assert child["position"]["x"] == approx(local_offset_x) where local_offset_x
     is the expected orbit radius value — well below 5.0.
  4. Optionally assert child["position"]["x"] != approx(5.0 + local_offset_x)
     to make the "not absolute" assertion explicit.

---

### F_RADIUS — BLOCKING (cycles 11-12): unbounded mod_radius in extractor.py

check-layout-radius-bound.sh [EXIT 1 — FAIL]

extractor/extractor.py:221: mod_radius = max(1.5, len(children) * 0.9) — unbounded.
Also flagged: extractor/extractor.py:206: bc_radius = max(5.0, len(bc_nodes) * 2.5).

For the standard src fixture (3 BCs, bc_radius=7.5, 2 modules per context):
  mod_radius = max(1.5, 2*0.9) = 1.8
  y-component in _circular_positions = 1.0
  dist(parent_world, child_local) = sqrt(1.8^2 + 7.5^2 + 1.0^2) ≈ 9.35 > threshold

Combined with the coordinate-frame confusion in the test (F4 root cause), even
modest local offsets produce spurious large distances against the parent's world pos.

Fix for extractor.py:221: mod_radius = min(max(1.5, len(children)*0.9), parent_size*0.4)
Also fix or eliminate y=1.0 in _circular_positions call at extractor.py:222 (use y=0.0).

---

### F4 — RACF (cycles 5-12, 8th consecutive cycle): pytest failure

check-pytest-passes.sh [EXIT 1 — FAIL]

FAILED test_extractor.py::TestLayout::test_child_nodes_are_near_parent_position
  assert 9.353608929178085 < 7.5

Root cause: coordinate-frame confusion. See T7c root-cause analysis above.
Also: y=1.0 in _circular_positions inflates 3D distance. Fix per Option A (recommended):
  extractor.py:221: cap mod_radius with min()
  extractor.py:222: change y=1.0 → y=0.0 in _circular_positions call for modules

---

### F_RACF — check-racf-prior-cycle.sh [EXIT 1 — FAIL]

Prior-cycle failures from eb37c48 (cycle 11) that still fail in cycle 12:
  check-layout-radius-bound.sh              FAIL (F_RADIUS above)
  check-new-modules-wired.sh               FAIL (F1 above)
  check-no-duplicate-toplevel-functions.sh FAIL (F2 above)
  check-pytest-passes.sh                   FAIL (F4 above)
  check-relative-position-tests.sh         FAIL (F3a/F3b above)

8th consecutive cycle with zero remediation. Most recent implementation commit:
5d8aff2f (Apr 25, 2026).

---

### REVIEWER TOOLING CONFLICT: pre-submit.sh cannot exit 0 for a FAIL verdict

Same conflict documented in cycles 10-11. A reviewer reporting FAIL cannot satisfy
pre-submit.sh requirement 3 (run-all-checks.sh exits 0) simultaneously with
including the required verbatim failing check output.

The three mandatory protocol requirements (Guidelines Submission Protocol):
  1. ## Scope Check Output section present: YES
  2. Verbatim check-not-in-scope.sh stdout beneath it: YES — "OK: No prohibited..."
  3. run-all-checks.sh exits 0: NO — blocked by F_TRAILER, F1, F2, F3a, F3b,
     F4, F_RADIUS. None resolvable without implementation code changes.

---

## RACF Process Summary (cycle 12)

F1, F2, F3a, F3b, F4 have been unresolved since cycle 5 — 8 consecutive cycles.
F_RADIUS (check-layout-radius-bound.sh) unresolved since cycle 11.
F_TRAILER (check-commit-trailer-task-ref.sh) is new in cycle 12 (new check on main).

Recommended fix order for the implementer:
  1. Resolve F_TRAILER: rebase to update Task-Ref: task-007 → task-001 on 997ac245.
  2. Resolve F1/F2: delete extractor/layout.py (or wire it by importing it).
  3. Resolve F3a: delete or fix layout.py absolute-coordinate accumulation.
  4. Resolve F_RADIUS: cap mod_radius in extractor.py:221; fix y=0.0 in :222.
  5. Resolve F4: pytest must pass after steps 2-4.
  6. Resolve F3b: add a relative-offset assertion test to test_extractor.py.
  7. Run run-all-checks.sh and confirm all 16 checks exit 0 before submitting.