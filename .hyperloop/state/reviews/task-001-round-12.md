---
task_id: task-001
round: 12
role: verifier
verdict: fail
---
## Task: task-001 — Scene Graph Schema
**Spec:** specs/extraction/scene-graph-schema.spec.md
**Branch:** hyperloop/task-001
**Date:** 2026-04-26

Synced `.hyperloop/checks/` from `main` before running (per review guidelines).

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## THEN→Test Mapping

| THEN-clause | Test(s) cited | Verdict |
|---|---|---|
| THEN it contains a `nodes` array, an `edges` array, and a `metadata` object | test_scene_graph_has_nodes_key, test_scene_graph_has_edges_key, test_scene_graph_has_metadata_key | PASS |
| AND no other top-level fields are present | test_scene_graph_has_no_extra_top_level_fields, test_scene_graph_is_json_serialisable | PASS |
| THEN it has a unique `id` (e.g. "iam") | test_bounded_context_node_id | PASS |
| AND a `name` (e.g. "IAM") | test_bounded_context_node_name, test_bounded_context_node_has_required_keys | PASS |
| AND a `type` field indicating its level (e.g. "bounded_context") | test_bounded_context_node_type, test_bounded_context_node_has_required_keys | PASS |
| AND a `position` object with `x`, `y`, `z` coordinates | test_bounded_context_node_position_has_xyz, test_bounded_context_node_position_values_are_numeric | PASS |
| AND a `size` value derived from its complexity metric | test_bounded_context_node_size_is_numeric, test_bounded_context_node_has_required_keys | PASS |
| AND `parent` is null (top-level node) | test_bounded_context_node_parent_is_null, test_bounded_context_node_has_required_keys | PASS |
| THEN it has a unique `id` (e.g. "iam.domain") | test_module_node_id_dotted | PASS |
| AND a `parent` field referencing its containing node's id (e.g. "iam") | test_module_node_parent_references_context, test_module_node_has_required_keys | PASS |
| AND a `type` field indicating its level (e.g. "module") | test_module_node_type_is_module, test_module_node_has_required_keys | PASS |
| AND `position` coordinates relative to its parent | test_child_nodes_are_near_parent_position, test_child_nodes_within_parent_spatial_bounds | **FAIL — wrong predicate: both are proximity tests; extractor.py:232-234 stores absolute world coordinates (see F1, F3)** |
| THEN it has a `source` field (e.g. "graph") | test_cross_context_edge_source | PASS |
| AND a `target` field (e.g. "shared_kernel") | test_cross_context_edge_target, test_cross_context_edge_has_required_keys | PASS |
| AND a `type` field (e.g. "cross_context") | test_cross_context_edge_type, test_cross_context_edge_has_required_keys | PASS |
| THEN it has a `source` field (e.g. "iam.application") | test_internal_edge_source | PASS |
| AND a `target` field (e.g. "iam.domain") | test_internal_edge_target, test_internal_edge_has_required_keys | PASS |
| AND a `type` field (e.g. "internal") | test_internal_edge_type, test_internal_edge_has_required_keys | PASS |
| THEN the metadata contains the source codebase path | test_metadata_has_source_path | PASS |
| AND the timestamp of extraction | test_metadata_has_timestamp, test_metadata_timestamp_is_str | PASS |
| THEN each node's `position` field contains x, y, z coordinates | test_all_positions_have_xyz, test_every_node_has_position | PASS |
| AND tightly coupled nodes have smaller distances between them | test_tightly_coupled_nodes_are_closer, test_coupled_bcs_are_closer_than_uncoupled | PASS |
| AND child nodes are positioned within the spatial bounds of their parent | test_child_nodes_within_parent_spatial_bounds, test_child_nodes_are_near_parent_position | **FAIL — proximity tests only; extractor.py stores absolute coords (see F1, F2, F3)** |
| AND the Godot application renders nodes at these positions without recomputing layout | test_anchor_positions_match_json, test_every_node_has_position | PASS |

---

## Check Script Results

```
=== run-all-checks.sh ===

--- check-branch-adds-source-files.sh ---
OK: Branch adds/modifies 2 source file(s) outside .hyperloop/:
  extractor/layout.py
  extractor/tests/test_layout.py
[EXIT 0]

--- check-branch-has-commits.sh ---
OK: Branch 'hyperloop/task-001' has 18 commit(s) above main.
[EXIT 0]

--- check-checkpoint-commit.sh ---
OK: Checkpoint commit found — 'chore: begin task-001'
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

--- check-compound-coverage-not-falsified.sh ---
OK: check-compound-then-clause-coverage.sh exits 0 — no cross-validation needed.
[EXIT 0]

--- check-compound-then-clause-coverage.sh ---
OK: 'THEN it contains a `nodes` array, an `edges` array, and a `metadata` object' cites 3 test(s) for compound clause.
OK: 'AND no other top-level fields are present' cites 2 test(s) for compound clause.
OK: 'AND a `name` (e.g. IAM)' cites 2 test(s) for compound clause.
OK: 'AND a `type` field indicating its level (e.g. bounded_context)' cites 2 test(s) for compound clause.
OK: 'AND a `position` object with `x`, `y`, `z` coordinates' cites 2 test(s) for compound clause.
OK: 'AND a `size` value derived from its complexity metric' cites 2 test(s) for compound clause.
OK: 'AND `parent` is null (top-level node)' cites 2 test(s) for compound clause.
OK: 'AND a `parent` field referencing its containing' cites 2 test(s) for compound clause.
OK: 'AND a `type` field indicating its level (e.g. module)' cites 2 test(s) for compound clause.
OK: 'AND `position` coordinates relative to its parent' cites 2 test(s) for compound clause.
OK: 'AND a `target` field (e.g. shared_kernel)' cites 2 test(s) for compound clause.
OK: 'AND a `type` field (e.g. cross_context)' cites 2 test(s) for compound clause.
OK: 'AND a `target` field (e.g. iam.domain)' cites 2 test(s) for compound clause.
OK: 'AND a `type` field (e.g. internal)' cites 2 test(s) for compound clause.
OK: 'AND the timestamp of extraction' cites 2 test(s) for compound clause.
OK: 'AND tightly coupled nodes have smaller distances between them' cites 2 test(s) for compound clause.
OK: 'AND child nodes are positioned within the spatial bounds of their parent' cites 2 test(s) for compound clause.
OK: 'AND the Godot application renders nodes at these positions without recomputing layout' cites 2 test(s) for compound clause.
OK: All 18 compound THEN-clause(s) cite multiple tests.
[EXIT 0]

--- check-coordinator-calls-pipeline.sh ---
SKIP: No pipeline consumer method (apply_spec / render_spec / etc.) found in godot/scripts/.
      This check only applies to tasks that implement a view-spec consumer.
[EXIT 0]

--- check-desktop-platform-tested.sh ---
INFO: Desktop/native-platform constraint detected in spec(s):
  specs/prototype/nfr.spec.md
OK: OS.has_feature() test(s) found covering desktop-platform constraint:
  godot/tests/test_desktop_platform.gd
[EXIT 0]

--- check-direction-test-derivations.sh ---
OK: godot/tests/test_camera_controls.gd :: test_orbit_horizontal_drag_changes_phi — derivation comment found.
OK: godot/tests/test_camera_controls.gd :: test_orbit_vertical_drag_changes_theta — derivation comment found.
OK: godot/tests/test_dependency_rendering.gd :: test_direction_indicator_cone_created — derivation comment found.
OK: godot/tests/test_dependency_rendering.gd :: test_direction_cone_near_target — derivation comment found.
OK: godot/tests/test_scene_graph_loader.gd :: test_edge_direction_preserved_source_to_target — derivation comment found.
OK: godot/tests/test_system_purpose.gd :: test_dependency_direction_is_encoded_in_edges — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_right_decreases_pivot_x — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_left_increases_pivot_x — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_drag_direction_matches_view_movement — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_down_decreases_pivot_z — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_up_increases_pivot_z — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_zoom_toward_cursor_shifts_pivot_toward_cursor — derivation comment found.
OK: godot/tests/test_ux_polish.gd :: test_pan_proportional_to_drag_speed — derivation comment found.
OK: All 13 direction/sign-convention test(s) contain derivation comments.
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
OK: No inert bool-returning test functions found in Pattern-1 suites (9 suite(s) checked)
[EXIT 0]

--- check-kartograph-integration-test.sh ---
OK: Integration test referencing kartograph codebase with expected-context assertions found.
[EXIT 0]

--- check-new-modules-wired.sh ---
FAIL: New module 'extractor/layout.py' is not imported by any production source file.
  'layout' was added on this branch but no non-test Python file imports it.
  Tests for 'layout' pass but provide no assurance about the actual
  runtime code path — the consuming file's old internal function remains active.

  Fix: either
    (a) Import it from the consuming file (e.g. 'from extractor.layout import <fn>')
        and remove or delegate the old internal definition, OR
    (b) Fix the logic directly in the consuming file and delete extractor/layout.py.
[EXIT 1 — FAIL]

--- check-no-state-files-committed.sh ---
OK: No .hyperloop/state/ files committed on branch 'hyperloop/task-001'.
[EXIT 0]

--- check-not-in-scope.sh ---
OK: No prohibited (not-in-scope) features detected.
[EXIT 0]

--- check-not-on-main.sh ---
OK: Current branch is 'hyperloop/task-001' (not main)
[EXIT 0]

--- check-pan-grab-model-comments.sh ---
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_right_decreases_pivot_x — user-visible-outcome language found in derivation.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_left_increases_pivot_x — user-visible-outcome language found in derivation.
OK: godot/tests/test_ux_polish.gd :: test_drag_direction_matches_view_movement — user-visible-outcome language found in derivation.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_down_decreases_pivot_z — user-visible-outcome language found in derivation.
OK: godot/tests/test_ux_polish.gd :: test_pan_drag_up_increases_pivot_z — user-visible-outcome language found in derivation.
OK: All 5 pan/drag direction test(s) contain user-visible-outcome derivation language.
[EXIT 0]

--- check-pipeline-wiring.sh ---
SKIP: No parse_response / parse_view_spec function found in godot/scripts/.
[EXIT 0]

--- check-reflects-mapping-consistency.sh ---
SKIP: No 'reflect(s)' THEN-clauses found in mapping table.
[EXIT 0]

--- check-relative-position-tests.sh ---
FAIL: Extractor source accumulates parent world coordinates into child position.
  Found pattern: px/py/pz (parent world pos) added to child['position'].
  The spec requires child positions to be relative (local offset only).
  Godot's main.gd adds the parent's world position at render time —
  storing absolute coordinates here causes double-offset rendering.

  Offending lines:
extractor/extractor.py:232:                "x": px + pos[0],
extractor/extractor.py:233:                "y": py + pos[1],
extractor/extractor.py:234:                "z": pz + pos[2],

  Fix: store only the local offset:
    child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}
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
[EXIT 0]

--- check-scope-report-not-falsified.sh ---
OK: Scope report section is consistent with actual check-not-in-scope.sh result.
[EXIT 0]

--- check-then-test-mapping.sh ---
OK: All 35 mapped test function(s) verified in codebase
[EXIT 0]

--- extractor-lint.sh ---
[EXIT 0]

--- godot-compile.sh ---
[EXIT 0]

--- godot-fileaccess-tested.sh ---
OK: FileAccess.open() is exercised in 3 test file(s).
[EXIT 0]

--- godot-label3d.sh ---
[EXIT 0]

--- godot-tests.sh ---
GDScript behavioral tests passed.
[EXIT 0]

--- pre-submit.sh ---
=== pre-submit.sh: final submission gate ===
--- check-report-scope-section.sh ---             [EXIT 0  OK]
--- check-scope-report-not-falsified.sh ---       [EXIT 0  OK]
--- check-branch-has-commits.sh ---               [EXIT 0  OK]
--- Summary ---
OK: All pre-submit checks passed. You may now write your verdict.
[EXIT 0]

=== Summary: 33 check(s) run ===
RESULT: FAIL — one or more checks exited non-zero
```

---

## Findings

### F1 — Re-attempt compliance failure: check-relative-position-tests.sh (BLOCKING)

`check-relative-position-tests.sh` failed in cycle 2 (commit `f40d1f96`) with a
prescribed fix:

> Fix `extractor.py::compute_layout()` to store local offsets (not absolute world
> coordinates) for module nodes, and add a test that verifies the stored position
> is the relative offset.

That fix was **not applied**. `extractor/extractor.py:232-234` still reads:

```python
child["position"] = {
    "x": px + pos[0],
    "y": py + pos[1],
    "z": pz + pos[2],
}
```

The same check fails again in this cycle with the same offending lines. This is a
re-attempt compliance failure: the implementer did not follow the prescribed fix from
the prior round.

### F2 — Dead-code module: extractor/layout.py is not wired into production (BLOCKING)

`check-new-modules-wired.sh` exits 1. The implementation commit (`3fb5db74`) added
`extractor/layout.py` and `extractor/tests/test_layout.py`, but no production source
file imports `layout`. Confirmed:

```
$ grep -rn "from extractor.layout\|import layout" extractor/ --include="*.py" | grep -v test_
(no output)
```

The production runtime continues to call `extractor.extractor.compute_layout()` (the
old internal function at line 189). The tests in `test_layout.py` pass — they exercise
`extractor.layout.compute_layout` — but that function is never called in production.
Those passing tests provide **zero assurance** about the actual runtime behaviour.

Additionally, `layout.py`'s own child-position calculation also stores absolute
world coordinates:

```python
pos[child["id"]] = [
    parent_pos[0] + math.cos(angle) * offset_r,   # absolute, not relative
    parent_pos[1] + math.sin(angle) * offset_r,
]
```

So even if the module were wired in, the same absolute-coordinates bug would be present.

### F3 — No relative-offset assertion test (BLOCKING, same as prior cycle)

`check-relative-position-tests.sh` also flags that only proximity-based tests exist.
`test_layout.py::TestChildNodesWithinParentBounds::test_child_nodes_within_parent_spatial_bounds`
checks `dist(parent, child) <= parent_size`, which passes regardless of whether the
stored value is the local offset or the absolute world position (when the offset is
small). `test_extractor.py::TestLayout::test_child_nodes_are_near_parent_position`
has the same issue.

The required test (unchanged from the prior cycle's prescribed fix):
1. Place a parent BC at a **non-zero** world position (e.g., `"iam"` at `x=10.0`).
2. Assert `child["position"]["x"] == local_offset_x` (not `parent_x + local_offset_x`).
3. Optionally assert `child["position"]["x"] != parent_x + local_offset_x`.

This test must exercise the **production code path** (`extractor.extractor.compute_layout`),
not the dead-code `extractor.layout.compute_layout`.

---

## Commit Trailers

Implementation commit `3fb5db74` has both required trailers:

```
Spec-Ref: specs/extraction/scene-graph-schema.spec.md@3e5e297e216c7876224564ee099a38334e3dbd55
Task-Ref: task-001
```

✓ Trailers present.

---

## Summary

| Requirement | Scenario | Status |
|---|---|---|
| Schema Structure | Top-level structure | COVERED |
| Node Schema | Bounded context node | COVERED |
| Node Schema | Module node (relative position) | FAIL |
| Edge Schema | Cross-context dependency edge | COVERED |
| Edge Schema | Internal dependency edge | COVERED |
| Metadata | Extraction metadata | COVERED |
| Pre-Computed Layout | Layout in JSON (xyz present) | COVERED |
| Pre-Computed Layout | Tightly coupled nodes closer | COVERED |
| Pre-Computed Layout | Child nodes within parent bounds | FAIL |
| Pre-Computed Layout | Godot renders without recomputing | COVERED |

**Overall verdict: FAIL** — Three blocking issues remain (F1, F2, F3).

**Fix path:**

Option A (recommended — minimal change):
- In `extractor/extractor.py::compute_layout`, change lines 231-234 to:
  `child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}`
- Delete `extractor/layout.py` (dead code, also has the same bug).
- In `extractor/tests/test_extractor.py`, add a test that places a parent BC at a
  non-zero world position (e.g., `"iam"` at `x=10.0`) and asserts
  `child["position"]["x"] == local_offset_x` (not proximity, not absolute).

Option B:
- Wire `extractor/layout.py` into `extractor/extractor.py`, fix the absolute-position
  bug in `layout.py`, add the relative-offset assertion test to `test_layout.py`, and
  remove or delegate the duplicate internal `compute_layout` in `extractor.py`.