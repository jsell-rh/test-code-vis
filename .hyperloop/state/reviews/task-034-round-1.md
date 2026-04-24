---
task_id: task-034
round: 1
role: verifier
verdict: fail
---
## Code Review: task-034 — Prototype Scope Specification

Branch: hyperloop/task-034
Reviewer: independent code reviewer
Review date: 2026-04-24

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## run-all-checks.sh Output

```
=== run-all-checks.sh ===

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-034' has 22 commit(s) above main.
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

--- check-coordinator-calls-pipeline.sh ---
SKIP: No pipeline consumer method (apply_spec / render_spec / etc.) found in godot/scripts/.
      This check only applies to tasks that implement a view-spec consumer.
[EXIT 0]

--- check-direction-test-derivations.sh ---
OK: All 10 direction/sign-convention test(s) contain derivation comments.
[EXIT 0]

--- check-end-to-end-integration-test.sh ---
SKIP: Both a pipeline producer and consumer must exist for this check to apply.
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
[EXIT 0]

--- check-report-scope-section.sh ---
OK: worker-result.yaml contains a valid '## Scope Check Output' section.
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- extractor-lint.sh ---
All checks passed!
9 files already formatted
95 passed in 0.41s
Extractor checks passed.
[EXIT 0]

--- godot-compile.sh ---
Godot Engine v4.6.2.stable.official.71f334935
Godot project compiles successfully.
[EXIT 0]

--- godot-fileaccess-tested.sh ---
OK: FileAccess.open() is exercised in 2 test file(s).
[EXIT 0]

--- godot-label3d.sh ---
PASS: All Label3D nodes have billboard and pixel_size set and tested.
[EXIT 0]

--- godot-tests.sh ---
Found 11 GDScript test file(s) in godot/tests/.
Results: 95 passed, 0 failed
GDScript behavioral tests passed.
[EXIT 0]

=== Summary: 20 check(s) run ===
RESULT: ALL PASS
```

---

## Findings

### FAIL-1: Fabricated test name — `test_kartograph_extraction_produces_bounded_contexts`

The worker's THEN→test mapping asserts:
> THEN kartograph's structure is visualized in 3D space
> → `test_kartograph_integration.py::test_kartograph_extraction_produces_bounded_contexts`

**Verification:** `grep -rn "test_kartograph_extraction_produces_bounded_contexts" extractor/ godot/` → **zero results**.

The function does not exist. The actual function in `extractor/tests/test_kartograph_integration.py` is
`test_kartograph_integration_bounded_contexts`. Per review guidelines, a fabricated test name in the
THEN→test mapping is an automatic FAIL, regardless of whether a differently-named test covers the
same behavior.

**Action required:** Correct the THEN→test mapping to reference
`test_kartograph_integration.py::test_kartograph_integration_bounded_contexts`.

---

### FAIL-2: Fabricated test name — `test_kartograph_extraction_produces_modules`

The worker's THEN→test mapping asserts:
> AND the visualization reflects the actual structure of the codebase
> → `test_kartograph_integration.py::test_kartograph_extraction_produces_modules`

**Verification:** `grep -rn "test_kartograph_extraction_produces_modules" extractor/ godot/` → **zero results**.

The function does not exist anywhere in the codebase. Furthermore, the only kartograph integration
test (`test_kartograph_integration_bounded_contexts`) does not verify module nodes — it only checks
for three bounded-context IDs (`iam`, `graph`, `shared_kernel`). There is no test that verifies the
extractor produces module-level nodes from the kartograph codebase.

**Action required:** Either (a) add a function `test_kartograph_extraction_produces_modules` that
invokes `main()` against the kartograph source and asserts module nodes are present in the output
JSON, or (b) document why the "actual structure" THEN-clause is satisfied by the bounded-context
test alone and update the mapping to the correct function name.

---

### FAIL-3: Fabricated test name — `test_main_produces_output_file`

The worker's THEN→test mapping asserts:
> THEN a JSON scene graph file is produced
> → `test_cli.py::test_main_produces_output_file`

**Verification:** `grep -rn "test_main_produces_output_file" extractor/ godot/` → **zero results**.

The function does not exist. The actual function in `extractor/tests/test_cli.py` that verifies file
production is `test_main_writes_json_output`. This is a fabricated name — the THEN-clause IS
covered by the real function, but the mapping name is wrong.

**Action required:** Correct the THEN→test mapping to reference
`test_cli.py::test_main_writes_json_output`.

---

## Passing Checks (for completeness)

All 20 automated checks pass. The underlying implementation is sound:

- `main.gd._ready()` is not an empty stub — it loads JSON via FileAccess, calls `build_from_graph()`, and applies LOD.
- Test bodies for all other THEN-clauses were read and verified to match their predicates:
  - `test_volumes_created_for_each_node` — asserts `_anchors.has("ctx1")` and `_anchors.has("mod1")` ✓
  - `test_labels_are_billboard_and_readable` — asserts `billboard == BILLBOARD_ENABLED` and `pixel_size > 0.0` ✓
  - `test_direction_indicator_cone_created` — asserts `CylinderMesh.top_radius == 0.0` (explicit arrowhead) ✓
  - `test_module_parented_inside_context` — asserts `mod_anchor.get_parent() == ctx_anchor` ✓
  - `test_large_module_has_bigger_mesh` — asserts `large_mesh.size.x > small_mesh.size.x` ✓
  - Camera/orbit/pan/zoom tests verify the correct sign conventions with derivation comments ✓
- No Pattern-1 suites contain inert bool-returning test functions ✓
- No prohibited features (moldable views, data flow, conformance, etc.) ✓
- Commit trailers present: `Spec-Ref` and `Task-Ref` on implementation commits ✓

---

## Summary

Three test function names in the THEN→test mapping are fabricated (not present in any test file).
Two of these (FAIL-1 and FAIL-3) are simple renames — the underlying behavior IS tested under a
different name. FAIL-2 identifies a genuine gap: no integration test verifies module-level node
extraction from the kartograph codebase.

The implementation itself is correct and all automated checks pass. These findings require only
small corrections to the mapping (FAIL-1, FAIL-3) and one new test function (FAIL-2).

Spec-Ref: specs/prototype/prototype-scope.spec.md@12e8314c64416c10c5268a9d0f3ec54edb221c07
Task-Ref: task-034