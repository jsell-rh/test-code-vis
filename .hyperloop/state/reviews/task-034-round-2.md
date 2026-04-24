---
task_id: task-034
round: 2
role: verifier
verdict: fail
---
## Independent Reviewer Verdict — task-034: Prototype Scope Specification

Branch: `hyperloop/task-034`
Reviewer date: 2026-04-24

---

## run-all-checks.sh Output (verbatim, synced from main first)

```
=== run-all-checks.sh ===

--- check-branch-adds-source-files.sh ---
OK: Branch adds/modifies 10 source file(s) outside .hyperloop/:
  extractor/extractor.py
  extractor/tests/test_extractor.py
  extractor/tests/test_kartograph_integration.py
  godot/data/scene_graph.json
  godot/scripts/lod_manager.gd
  godot/scripts/main.gd
  godot/tests/run_tests.gd
  godot/tests/test_camera_controls.gd
  godot/tests/test_dependency_rendering.gd
  godot/tests/test_ux_polish.gd
[EXIT 0]

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-034' has 42 commit(s) above main.
[EXIT 0]

--- check-checks-in-sync.sh ---
OK: All check scripts from main are present in this worktree
[EXIT 0]

--- check-clamp-boundary-tests.sh ---
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_target_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_distance' clamped in camera_controller.gd — boundary assertion found in test_camera_controls.gd
OK: '_theta' clamped in camera_controller.gd — boundary assertion found in test_ux_polish.gd
OK: All 4 clamped variable(s) have boundary-asserting tests
[EXIT 0]

--- check-compound-then-clause-coverage.sh ---
OK: 'Godot app loads and renders scene' cites 2 test(s) for compound clause.
OK: 'pan, zoom, and rotate the view' cites 3 test(s) for compound clause.
OK: 'smoothly transition between overview and detail' cites 2 test(s) for compound clause.
OK: All 3 compound THEN-clause(s) cite multiple tests.
[EXIT 0]

--- check-coordinator-calls-pipeline.sh ---
SKIP: No pipeline consumer method (apply_spec / render_spec / etc.) found in godot/scripts/.
      This check only applies to tasks that implement a view-spec consumer.
[EXIT 0]

--- check-direction-test-derivations.sh ---
OK: godot/tests/test_camera_controls.gd :: test_orbit_horizontal_drag_changes_phi — derivation comment found.
OK: godot/tests/test_camera_controls.gd :: test_orbit_vertical_drag_changes_theta — derivation comment found.
OK: godot/tests/test_dependency_rendering.gd :: test_direction_indicator_cone_created — derivation comment found.
OK: godot/tests/test_dependency_rendering.gd :: test_direction_cone_near_target — derivation comment found.
OK: godot/tests/test_scene_graph_loader.gd :: test_edge_direction_preserved_source_to_target — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_right_increases_pivot_x — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_left_decreases_pivot_x — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_drag_direction_matches_view_movement — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_zoom_toward_cursor_shifts_pivot_toward_cursor — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_proportional_to_drag_speed — derivation comment found.
OK: All 10 direction/sign-convention test(s) contain derivation comments.
[EXIT 0]

--- check-end-to-end-integration-test.sh ---
SKIP: Both a pipeline producer and consumer must exist for this check to apply.
      Producer (build_prompt / parse_response) found: none
      Consumer (apply_spec / render_spec) found: none
[EXIT 0]

--- check-extractor-cli-tested.sh ---
OK: A test calls main() from the extractor CLI entry point.
[EXIT 0]

--- check-extractor-stdlib-only.sh ---
OK: A test using sys.stdlib_module_names to verify stdlib-only imports found.
[EXIT 0]

--- check-gdscript-only-test.sh ---
OK: DirAccess iteration test found — 'all scripts use GDScript' constraint is exercised
[EXIT 0]

--- check-gdscript-test-bool-return.sh ---
OK: No inert bool-returning test functions found in Pattern-1 suites (4 suite(s) checked)
[EXIT 0]

--- check-kartograph-integration-test.sh ---
OK: Integration test referencing kartograph codebase with expected-context assertions found.
[EXIT 0]

--- check-not-in-scope.sh ---
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-pipeline-wiring.sh ---
SKIP: No parse_response / parse_view_spec function found in godot/scripts/.
      This check only applies to tasks that implement the LLM→view-spec pipeline.
[EXIT 0]

--- check-report-scope-section.sh ---
OK: worker-result.yaml contains a valid '## Scope Check Output' section.
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- check-then-test-mapping.sh ---
OK: 'test_anchor_positions_match_json' found in codebase
OK: 'test_coupled_bcs_are_closer_than_uncoupled' found in codebase
OK: 'test_direction_indicator_cone_created' found in codebase
OK: 'test_edge_line_mesh_created' found in codebase
OK: 'test_far_distance_shows_only_bounded_contexts' found in codebase
OK: 'test_kartograph_integration_bounded_contexts' found in codebase
OK: 'test_labels_are_billboard_and_readable' found in codebase
OK: 'test_lmb_pan_moves_pivot' found in codebase
OK: 'test_main_writes_json_output' found in codebase
OK: 'test_mesh_sizes_proportional_to_metric' found in codebase
OK: 'test_module_parented_inside_context' found in codebase
OK: 'test_near_distance_shows_all_nodes' found in codebase
OK: 'test_near_distance_shows_internal_edges_as_fine_detail' found in codebase
OK: 'test_orbit_horizontal_drag_changes_phi' found in codebase
OK: 'test_scroll_up_decreases_distance' found in codebase
OK: 'test_volumes_created_for_each_node' found in codebase
OK: 'test_zoom_is_interpolated_not_instantaneous' found in codebase
OK: All 17 mapped test function(s) verified in codebase
[EXIT 0]

--- extractor-lint.sh ---
Linting extractor...
All checks passed!
9 files already formatted
Running extractor tests...
96 passed in 0.76s
Extractor checks passed.
[EXIT 0]

--- godot-compile.sh ---
Compiling Godot project...
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org
Godot project compiles successfully.
[EXIT 0]

--- godot-fileaccess-tested.sh ---
Found FileAccess.open() in 1 production script file(s).
OK: FileAccess.open() is exercised in 2 test file(s).
[EXIT 0]

--- godot-label3d.sh ---
PASS: All Label3D nodes have billboard and pixel_size set and tested.
[EXIT 0]

--- godot-tests.sh ---
Results: 95 passed, 0 failed
[EXIT 0]

=== Summary: 23 check(s) run ===
RESULT: ALL PASS
```

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

Independent semantic audit: no `llm`, `build_prompt`, `parse_response`, `apply_spec`,
`conformance`, `simulation`, `evaluation_mode`, `data_flow`, `first_person`,
`spec_extract`, or `moldable` artifacts found anywhere in `extractor/` or `godot/`.

---

## Commit Trailers

Spec-Ref and Task-Ref trailers are present on all implementation commits. PASS.

---

## FAIL Finding: Wrong-Predicate Mapping — "position reflects coupling relationships"

**THEN-clause (Abstract Visual Language scenario):**
> "its position reflects its coupling relationships"

**Worker's cited test:** `test_anchor_positions_match_json`

**Test body (godot/tests/test_scene_graph_loading.gd:88–100):**
```gdscript
func test_anchor_positions_match_json() -> bool:
    var main_node: Node3D = MainScript.new()
    main_node.build_from_graph(_make_fixture())
    var ctx_anchor: Node3D = main_node._anchors.get("ctx1")
    var mod_anchor: Node3D = main_node._anchors.get("mod1")
    ...
    var ctx_ok := ctx_anchor.position.is_equal_approx(Vector3(0.0, 0.0, 0.0))
    var mod_ok := mod_anchor.position.is_equal_approx(Vector3(2.0, 0.0, 2.0))
    return ctx_ok and mod_ok
```

**Why this is wrong-predicate:** This is a rendering-fidelity test. It loads pre-computed
fixture positions and verifies they appear unchanged in the scene tree. It passes even if
the extractor computed random positions. The guideline is explicit: "A rendering-fidelity
test — which loads pre-computed values and asserts they appear unchanged in the scene — does
NOT cover this THEN-clause. It passes even if the computation is random, so it provides
zero assurance about the algorithm."

The THEN-clause says "position reflects its coupling relationships" — this is an "X reflects
Y" clause requiring an algorithm-quality test: one whose **fixture VARIES coupling** and
whose **assert checks relative position output**.

**Required test:** `test_coupled_bcs_are_closer_than_uncoupled`
(extractor/tests/test_extractor.py:435) — this test DOES vary coupling in its fixture
(auth↔shared_kernel coupled, billing uncoupled) and asserts
`dist("auth","shared_kernel") < dist("auth","billing")`. This is the algorithm-quality test
the THEN-clause requires.

**Note on duplication with prior fix:** The worker correctly fixed "relative positions
reflect their coupling (tightly coupled contexts are closer together)" (Top-Down View
scenario) to cite `test_coupled_bcs_are_closer_than_uncoupled`. However, the companion
THEN-clause "position reflects its coupling relationships" (Abstract Visual Language
scenario) was **not** updated — it still maps to the rendering-fidelity test. Both
THEN-clauses name "position reflects coupling" and both require the algorithm-quality test.

**Required fix:** In the THEN→test mapping, change the row
`| position reflects coupling relationships | test_anchor_positions_match_json | ...`
to cite `test_coupled_bcs_are_closer_than_uncoupled` (the same test already correctly
mapped to the companion Top-Down View clause).

---

## All Other THEN-Clauses: PASS

Every other THEN→test mapping was independently verified:

| THEN-clause | Cited test | Reviewer verdict |
|---|---|---|
| kartograph's structure visualized in 3D | test_volumes_created_for_each_node | PASS — anchors populated ✓ |
| visualization reflects actual structure | test_kartograph_integration_bounded_contexts | PASS — iam/graph/shared_kernel asserted ✓ |
| JSON scene graph produced | test_main_writes_json_output | PASS — CLI writes valid JSON ✓ |
| Godot loads and renders scene | test_volumes_created_for_each_node + test_anchor_positions_match_json | PASS — compound, 2 tests ✓ |
| all bounded contexts visible as volumes | test_volumes_created_for_each_node | PASS — _anchors populated ✓ |
| relative positions reflect coupling (Top-Down) | test_coupled_bcs_are_closer_than_uncoupled | PASS — varies coupling, asserts dist(auth,sk) < dist(auth,billing) ✓ |
| **position reflects coupling relationships (Vis. Rep.)** | **test_anchor_positions_match_json** | **FAIL — rendering-fidelity test, wrong predicate** |
| dependencies visible as connections | test_edge_line_mesh_created | PASS — ImmediateMesh found ✓ |
| internal layers become visible | test_near_distance_shows_all_nodes | PASS — mod_anchor.visible == true at NEAR ✓ |
| internal dependencies shown | test_near_distance_shows_internal_edges_as_fine_detail | PASS — internal edges visible at NEAR ✓ |
| relative sizes of modules visible | test_mesh_sizes_proportional_to_metric | PASS — ratio asserted to 0.001 ✓ |
| appears as labeled geometric volume | test_labels_are_billboard_and_readable | PASS — billboard + pixel_size + no_depth_test ✓ |
| size reflects complexity | test_mesh_sizes_proportional_to_metric | PASS — size=9/size=3 ratio == 3.0 ✓ |
| containment shown by nesting | test_module_parented_inside_context | PASS — mod_anchor.get_parent() == ctx_anchor ✓ |
| module name visible | test_labels_are_billboard_and_readable | PASS ✓ |
| label readable at zoom level | test_labels_are_billboard_and_readable | PASS — billboard_enabled + pixel_size > 0 ✓ |
| line/connection drawn | test_edge_line_mesh_created | PASS — ImmediateMesh ✓ |
| direction of dependency discernible | test_direction_indicator_cone_created | PASS — CylinderMesh top_radius=0 (arrowhead cone) ✓ |
| pan, zoom, and rotate | test_lmb_pan_moves_pivot + test_scroll_up_decreases_distance + test_orbit_horizontal_drag_changes_phi | PASS — compound, 3 tests ✓ |
| smooth overview/detail transition | test_zoom_is_interpolated_not_instantaneous + test_far_distance_shows_only_bounded_contexts | PASS — compound, 2 tests ✓ |
| conformance NOT implemented | check-not-in-scope.sh | PASS ✓ |
| evaluation NOT implemented | check-not-in-scope.sh | PASS ✓ |
| simulation NOT implemented | check-not-in-scope.sh | PASS ✓ |
| data flow NOT implemented | check-not-in-scope.sh | PASS ✓ |
| moldable views NOT implemented | check-not-in-scope.sh | PASS ✓ |
| spec extraction NOT implemented | check-not-in-scope.sh | PASS ✓ |
| first-person navigation NOT implemented | check-not-in-scope.sh | PASS ✓ |

---

## Implementation Quality (non-blocking notes)

- `main.gd._ready()` is fully implemented (FileAccess, JSON parse, build_from_graph, LOD).
  Not a stub.
- Arrowhead cones use `CylinderMesh` with `top_radius=0` — satisfies "direction visually
  indicated" with an explicit rendering element (cone). PASS.
- Label3D nodes have `billboard = BILLBOARD_ENABLED`, `pixel_size = 0.012`,
  `no_depth_test = true`. PASS.
- Containment implemented via scene-tree parenting (module anchor is child of context anchor).
  PASS.
- `ERROR: Condition "!is_inside_tree()"` messages in test output are benign headless
  artifacts (camera not attached to scene tree during unit tests); all 95 GDScript tests
  report PASS.
- `test_coupled_bcs_are_closer_than_uncoupled` is correctly implemented as an
  algorithm-quality test (varies coupling fixture, asserts relative output). The only issue
  is it is not cited for the second "position reflects coupling" THEN-clause.

---

## Summary

**FAIL — one blocking finding.**

All 23 automated checks pass. 95 GDScript tests pass. 96 Python tests pass. Scope is clean.
The implementation is solid. The single blocking issue is a wrong-predicate THEN→test
mapping:

- The "position reflects its coupling relationships" THEN-clause (Abstract Visual Language
  scenario) is mapped to `test_anchor_positions_match_json`, a rendering-fidelity test that
  cannot prove the algorithm. It must be mapped to `test_coupled_bcs_are_closer_than_uncoupled`.

**Actionable fix (one line change):** In the THEN→test mapping table, change:
```
| position reflects coupling relationships | test_anchor_positions_match_json | ...
```
to:
```
| position reflects coupling relationships | test_coupled_bcs_are_closer_than_uncoupled | PASS — fixture varies coupling; asserts dist(auth,shared_kernel) < dist(auth,billing) |
```

No code changes required — the test already exists and is correct. Only the mapping
documentation needs updating.