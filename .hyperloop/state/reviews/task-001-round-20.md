---
task_id: task-001
round: 20
role: verifier
verdict: fail
---
## Task: task-001 — Scene Graph Schema
**Spec:** specs/extraction/scene-graph-schema.spec.md
**Branch:** hyperloop/task-001
**Date:** 2026-04-26

Synced `.hyperloop/checks/` from `main` before running all checks (per review guidelines).
Skeleton created before running any checks (per review guidelines).

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

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
OK: Branch 'hyperloop/task-001' has 20 commit(s) above main.
[EXIT 0]

--- check-checkpoint-commit-is-empty.sh ---
OK: Checkpoint commit 'chore: begin task-001' is empty (no file changes) — correct use of --allow-empty
[EXIT 0]

--- check-checkpoint-commit-is-first.sh ---
OK: First (oldest) commit on branch is the checkpoint commit — 'chore: begin task-001'
[EXIT 0]

--- check-checkpoint-commit.sh ---
OK: Checkpoint commit found — 'chore: begin task-001'
[EXIT 0]

--- check-checkpoint-task-matches-branch.sh ---
OK: Checkpoint task-id 'task-001' matches branch 'hyperloop/task-001'
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

--- check-combined-rewrite-guide.sh ---
OK: No combined rewrite condition detected on branch 'hyperloop/task-001'.
[EXIT 0]

--- check-compound-coverage-not-falsified.sh ---
OK: check-compound-then-clause-coverage.sh exits 0 — no cross-validation needed.
[EXIT 0]

--- check-compound-then-clause-coverage.sh ---
SKIP: No compound THEN-clauses (containing 'and') found in THEN→test mapping.
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

--- check-docstring-arrow-placement.sh ---
OK: No docstring-only arrow placements detected in 13 direction test(s).
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
      This check only applies to tasks that implement the LLM→view-spec pipeline.
[EXIT 0]

--- check-racf-prior-cycle.sh ---
Orchestrator cleanup obscured prior FAIL report — recovered from 5eeda4b.
To inspect: git show 5eeda4b:.hyperloop/worker-result.yaml

Checks that failed in that cycle — must now pass:

  check-racf-guard-skeleton.sh                            SKIP (script not found — may have been renamed)

OK: All prior-cycle failures (recovered from 5eeda4b) are now resolved.
[EXIT 0]

--- check-racf-remediation.sh ---
SKIP: Prior committed report contains no FAIL checks — no RACF to verify.
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
[result depends on mapping table content — see THEN→test mapping below]
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
[EXIT 0]

=== Summary: 40 check(s) run ===
EXIT: non-zero (check-new-modules-wired.sh and check-relative-position-tests.sh failed)
```

---

## THEN→Test Mapping

| THEN-clause | Test(s) cited | Verdict |
|---|---|---|
| THEN it contains a `nodes` array, an `edges` array, and a `metadata` object | test_scene_graph_has_nodes_key, test_scene_graph_has_edges_key, test_scene_graph_has_metadata_key | COVERED |
| AND no other top-level fields are present | test_scene_graph_has_no_extra_top_level_fields | COVERED |
| THEN it has a unique `id` (e.g. "iam") | test_bounded_context_node_id | COVERED |
| AND a `name` (e.g. "IAM") | test_bounded_context_node_name | COVERED |
| AND a `type` field indicating its level (e.g. "bounded_context") | test_bounded_context_node_type | COVERED |
| AND a `position` object with `x`, `y`, `z` coordinates | test_bounded_context_node_position_has_xyz, test_bounded_context_node_position_values_are_numeric | COVERED |
| AND a `size` value derived from its complexity metric | test_bounded_context_node_size_is_numeric, test_size_from_loc_grows_with_loc | COVERED |
| AND `parent` is null (top-level node) | test_bounded_context_node_parent_is_null | COVERED |
| THEN it has a unique `id` (e.g. "iam.domain") | test_module_node_id_dotted | COVERED |
| AND a `parent` field referencing its containing node's id (e.g. "iam") | test_module_node_parent_references_context | COVERED |
| AND a `type` field indicating its level (e.g. "module") | test_module_node_type_is_module | COVERED |
| AND `position` coordinates relative to its parent | test_child_nodes_are_near_parent_position | FAIL — wrong predicate: proximity test passes for both absolute and relative storage; extractor.py:232-234 stores px+pos[0], py+pos[1], pz+pos[2] (absolute world coordinates, not relative offsets). See F1, F3. |
| THEN it has a `source` field (e.g. "graph") | test_cross_context_edge_source | COVERED |
| AND a `target` field (e.g. "shared_kernel") | test_cross_context_edge_target | COVERED |
| AND a `type` field (e.g. "cross_context") | test_cross_context_edge_type | COVERED |
| THEN it has a `source` field (e.g. "iam.application") | test_internal_edge_source | COVERED |
| AND a `target` field (e.g. "iam.domain") | test_internal_edge_target | COVERED |
| AND a `type` field (e.g. "internal") | test_internal_edge_type | COVERED |
| THEN the metadata contains the source codebase path | test_metadata_has_source_path | COVERED |
| AND the timestamp of extraction | test_metadata_has_timestamp, test_metadata_timestamp_is_str | COVERED |
| THEN each node's `position` field contains x, y, z coordinates | test_every_node_has_position, test_every_node_has_a_position | COVERED |
| AND tightly coupled nodes have smaller distances between them | test_coupled_bcs_are_closer_than_uncoupled | COVERED — algorithm-quality test varies coupling fixture and asserts relative distance. Uses production compute_layout path. |
| AND child nodes are positioned within the spatial bounds of their parent | test_child_nodes_are_near_parent_position | FAIL — same predicate problem as relative-position row above: proximity check passes regardless of whether stored value is local offset or absolute world coordinate. See F1, F3. |
| AND the Godot application renders nodes at these positions without recomputing layout | test_anchor_positions_match_json (godot/tests/test_scene_graph_loading.gd) | COVERED — Godot reads position from JSON directly (main.gd treats it as local offset); no layout re-computation occurs. Note: the bug is in the extractor producing wrong (absolute) values, not in the Godot rendering path. |

---

## Findings

### F1 — Re-attempt compliance failure: check-relative-position-tests.sh (BLOCKING)

`check-relative-position-tests.sh` failed in cycles 2, 3, and 4 of this task
(commits `f40d1f96`, `ddf20c71`, `f65c7245`) with an identical prescribed fix:

> Fix `extractor.py::compute_layout()` lines 231-234 to store only the local offset:
> `child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}`

**The fix was not applied.** The offending lines are unchanged:

```python
# extractor/extractor.py:230-235
for child, pos in zip(children, mod_positions):
    child["position"] = {
        "x": px + pos[0],   # ← absolute: parent_world_x + local_offset
        "y": py + pos[1],   # ← absolute: parent_world_y + local_offset
        "z": pz + pos[2],   # ← absolute: parent_world_z + local_offset
    }
```

This causes a double-offset rendering defect: `main.gd::_resolve_world_pos` treats
the JSON position as a local offset and adds the parent's world position, so child
nodes are placed at `2 × parent_world_pos + local_offset` instead of
`parent_world_pos + local_offset`. Children appear outside parent volumes.

**This is a re-attempt compliance failure in the third consecutive cycle.**
The implementer did not follow the prescribed fix from the prior round.

### F2 — Re-attempt compliance failure: check-new-modules-wired.sh (BLOCKING)

`check-new-modules-wired.sh` failed in cycles 3 and 4 (`ddf20c71`, `f65c7245`) with
the same prescribed fix: wire `extractor/layout.py` into production or delete it.

**The fix was not applied.** `extractor/layout.py` remains committed but is never
imported by any non-test Python file. Confirmed:

```
$ grep -rn "from extractor.layout\|import layout" extractor/ --include="*.py" | grep -v test_
(no output)
```

The dead module also contains its own copy of the absolute-coordinate bug — even if
wired in, it would not fix F1:

```python
# extractor/layout.py (dead code)
pos[child["id"]] = [
    parent_pos[0] + math.cos(angle) * offset_r,   # absolute, not relative
    parent_pos[1] + math.sin(angle) * offset_r,
]
```

Tests in `test_layout.py` exercise `extractor.layout.compute_layout` — a function
never called in production — providing zero behavioral assurance about the live
code path in `extractor.extractor.compute_layout`.

### F3 — No relative-offset assertion test (BLOCKING)

Prescribed in every prior FAIL cycle. Required test must:
1. Place a parent BC at a **non-zero** world position (e.g., `"iam"` at `x=10.0`).
2. Assert `child["position"]["x"] == local_offset_x` (exact value, not proximity).
3. Optionally assert `child["position"]["x"] != parent_x + local_offset_x`.

No such test exists. The only child-position tests are proximity-based
(`test_child_nodes_are_near_parent_position` passes when offset is small regardless
of whether the stored value is relative or absolute).

The required test must exercise the **production code path** in
`extractor.extractor.compute_layout`, not the dead-code `extractor.layout.compute_layout`.

### Note: check-racf-prior-cycle.sh recovered from wrong branch

`check-racf-prior-cycle.sh` recovered a prior FAIL report from commit `5eeda4b`
(which belongs to `task-007`, not `hyperloop/task-001`). It found only a missing
`check-racf-guard-skeleton.sh` script as the prior FAIL — not the real failures
from this branch's prior cycles. The RACF check script's git-history walk crosses
branch boundaries, causing it to surface the wrong commit.

The actual prior FAIL cycles on this branch (`f40d1f96`, `ddf20c71`, `f65c7245`)
prescribed fixes for F1, F2, F3 — all of which remain unresolved. This is a
process-mechanism limitation in the RACF check, not a fault of the implementer's
reporting; however, the underlying FAIL findings stand independently.

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
| Node Schema | Module node inside bounded context (id, parent, type) | COVERED |
| Node Schema | Module node — position relative to parent | FAIL |
| Edge Schema | Cross-context dependency edge | COVERED |
| Edge Schema | Internal dependency edge | COVERED |
| Metadata | Extraction metadata | COVERED |
| Pre-Computed Layout | Layout in JSON (xyz present) | COVERED |
| Pre-Computed Layout | Tightly coupled nodes closer | COVERED |
| Pre-Computed Layout | Child nodes within parent spatial bounds | FAIL |
| Pre-Computed Layout | Godot renders without recomputing layout | COVERED |

**Overall verdict: FAIL** — Three blocking issues remain (F1, F2, F3), all prescribed in prior cycles.

### Required Fix Path (unchanged from prior cycles)

**Recommended — Option B (minimal):**
1. In `extractor/extractor.py::compute_layout`, change lines 232-234 to:
   ```python
   child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}
   ```
2. Delete `extractor/layout.py` and `extractor/tests/test_layout.py` (dead code with same bug).
3. In `extractor/tests/test_extractor.py`, add a test (in `TestLayout`) that:
   - Places parent BC at `x=10.0` (non-zero world position)
   - Calls `compute_layout(nodes)` (production path in `extractor.extractor`)
   - Asserts `child["position"]["x"] == local_offset_x` (exact, not proximity)
   - Optionally asserts `child["position"]["x"] != 10.0 + local_offset_x`