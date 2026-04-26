---
task_id: task-001
round: 11
role: verifier
verdict: fail
---
## Task: task-001 — Scene Graph Schema
**Spec:** specs/extraction/scene-graph-schema.spec.md
**Branch:** hyperloop/task-001
**Date:** 2026-04-25

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
| AND `position` coordinates relative to its parent | test_child_nodes_are_near_parent_position, test_child_nodes_within_parent_spatial_bounds | **FAIL — WRONG PREDICATE: both are proximity tests; production code stores absolute world coordinates (see F1, F2, F3)** |
| THEN it has a `source` field (e.g. "graph") | test_cross_context_edge_source | PASS |
| AND a `target` field (e.g. "shared_kernel") | test_cross_context_edge_target, test_cross_context_edge_has_required_keys | PASS |
| AND a `type` field (e.g. "cross_context") | test_cross_context_edge_type, test_cross_context_edge_has_required_keys | PASS |
| THEN it has a `source` field (e.g. "iam.application") | test_internal_edge_source | PASS |
| AND a `target` field (e.g. "iam.domain") | test_internal_edge_target, test_internal_edge_has_required_keys | PASS |
| AND a `type` field (e.g. "internal") | test_internal_edge_type, test_internal_edge_has_required_keys | PASS |
| THEN the metadata contains the source codebase path | test_metadata_has_source_path | PASS |
| AND the timestamp of extraction | test_metadata_has_timestamp, test_metadata_timestamp_is_str | PASS |
| THEN each node's `position` field contains x, y, z coordinates | test_all_positions_have_xyz | PASS |
| AND tightly coupled nodes have smaller distances between them | test_tightly_coupled_nodes_are_closer, test_coupled_bcs_are_closer_than_uncoupled | PASS |
| AND child nodes are positioned within the spatial bounds of their parent | test_child_nodes_within_parent_spatial_bounds, test_child_nodes_are_near_parent_position | **FAIL — wrong-predicate (proximity only); production path uses broken extractor.py compute_layout (see F1, F2)** |
| AND the Godot application renders nodes at these positions without recomputing layout | test_node_rendered_at_json_position, test_every_node_has_position | PASS |

---

## Findings

### F1 (BLOCKING): Child module node positions stored as absolute world coordinates, not relative to parent

**Spec THEN-clause:** "AND `position` coordinates relative to its parent"
**Schema docstring:** `Position` field comment says "Coordinates are relative to the parent node."

**Location:** `extractor/extractor.py` lines 229–234:

```python
px, py, pz = bc_pos_map.get(parent_id, (0.0, 0.0, 0.0))
for child, pos in zip(children, mod_positions):
    child["position"] = {
        "x": px + pos[0],   # BUG: stores absolute world coordinate
        "y": py + pos[1],
        "z": pz + pos[2],
    }
```

`px`, `py`, `pz` are the parent bounded context's world-space coordinates. Adding them to the local `pos` offset stores an **absolute world position** in the child's `position` field. Godot's `main.gd` then adds the parent's world position on top again at render time (treating the JSON value as a local offset), causing a **double-offset** that places children far outside their parent's bounds.

**Fix:** Store only the local offset:
```python
child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}
```

---

### F2 (BLOCKING): Attempted fix in `layout.py` is dead code — not wired into `build_scene_graph()`

The implementation added `extractor/layout.py` with a correct `compute_layout()` that returns relative positions. However, `extractor/extractor.py::build_scene_graph()` calls its own internal `compute_layout()` (the broken one), not the new `layout.py::compute_layout()`. The new module is never imported or called from the main extraction pipeline.

Evidence: `extractor.py` imports only from `extractor.schema` (line 14). `build_scene_graph()` calls `compute_layout(nodes, edges)` at line ~259, which resolves to the same-file function that stores absolute coordinates.

The tests in `test_layout.py` cover the CORRECT but UNUSED `layout.py` module. They provide no assurance about the actual code path used at runtime.

**Fix:** Either (a) replace `extractor.py::compute_layout()` with a call to `from extractor.layout import compute_layout`, OR (b) fix the absolute-coordinate bug directly in `extractor.py::compute_layout()` and delete the dead `layout.py` duplicate.

---

### F3 (BLOCKING): THEN→test mapping for "position coordinates relative to its parent" uses wrong predicate

**Mapped test:** `test_child_nodes_are_near_parent_position` (extractor/tests/test_extractor.py:406)

**Test predicate:**
```python
dist = math.sqrt((cx - px)**2 + (cy - py)**2 + (cz - pz)**2)
assert dist < bc_radius
```

This is a **proximity test** — it checks only that the child is within `bc_radius` of the parent. It does NOT assert that the stored `position` value is a local offset. The test passes even when `extractor.py` stores absolute world coordinates, as long as the absolute coordinates happen to be close enough to the parent (which they are: the offset_r is small relative to bc_radius).

**Requirement for a valid test:**
1. Place parent at a non-zero world position (e.g., x=10.0, not x=0.0)
2. Assert `child["position"]["x"] == local_offset_x` (direct equality, not proximity)
3. Implicitly or explicitly assert `child["position"]["x"] != parent_x + local_offset_x`

Neither `test_child_nodes_are_near_parent_position` nor any test in `test_layout.py` satisfies these criteria. The "near parent" test is the canonical wrong-predicate trap for relative-coordinate contracts.

---

### F4 (PROCESS NOTE — not a violation): `check-relative-position-tests.sh` absent before reviewer sync

The check `check-relative-position-tests.sh` was added to `main` at 23:15:46 (`d13c9ea8`), after the implementation commits at 21:25:59 (`3fb5db74`) and 21:29:00 (`169c9b26`). Similarly, agent overlay improvements containing guidance for coordinate frame contracts were added to `main` after the branch was committed.

Per review guidelines: "If check scripts are absent from the worktree before your sync and were added to `main` AFTER the branch was committed, this is NOT a process violation by the implementer — record it as a process note." This finding is documented as a process note, not a violation.

However, per the same guidelines: "every FAIL those scripts produce is still blocking." The check now fails (after sync from main) and is blocking.

---

## Check Script Results

Synced `.hyperloop/checks/` from `main` before running (per review guidelines).
`check-relative-position-tests.sh` was absent from the worktree before sync — it was
added to main at 23:15:46 (`d13c9ea8`), after the implementation commits at 21:25:59.
This is a process note (not a violation); the FAIL it produces is still blocking.

```
=== run-all-checks.sh (after git checkout main -- .hyperloop/checks/) ===

--- check-branch-adds-source-files.sh ---     [EXIT 0]
--- check-branch-has-commits.sh ---           [EXIT 0]
--- check-checkpoint-commit.sh ---            [EXIT 0]
--- check-checks-in-sync.sh ---               [EXIT 0]  (after reviewer sync)
--- check-clamp-boundary-tests.sh ---         [EXIT 0]
--- check-compound-coverage-not-falsified.sh ---  [EXIT 0]
--- check-compound-then-clause-coverage.sh ---    [EXIT 0]
--- check-coordinator-calls-pipeline.sh ---   [EXIT 0]  (SKIP: no pipeline consumer)
--- check-desktop-platform-tested.sh ---      [EXIT 0]
--- check-direction-test-derivations.sh ---   [EXIT 0]  (13/13 pass)
--- check-end-to-end-integration-test.sh ---  [EXIT 0]  (SKIP: no pipeline stages)
--- check-extractor-cli-tested.sh ---         [EXIT 0]
--- check-extractor-stdlib-only.sh ---        [EXIT 0]
--- check-gdscript-only-test.sh ---           [EXIT 0]
--- check-gdscript-test-bool-return.sh ---    [EXIT 0]  (9 suites, no inert tests)
--- check-kartograph-integration-test.sh ---  [EXIT 0]
--- check-no-state-files-committed.sh ---     [EXIT 0]
--- check-not-in-scope.sh ---                 [EXIT 0]
--- check-not-on-main.sh ---                  [EXIT 0]
--- check-pan-grab-model-comments.sh ---      [EXIT 0]
--- check-pipeline-wiring.sh ---              [EXIT 0]
--- check-reflects-mapping-consistency.sh --- [EXIT 0]

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

--- check-report-scope-section.sh ---         [EXIT 0]
--- check-scope-report-not-falsified.sh ---   [EXIT 0]
--- check-then-test-mapping.sh ---            [EXIT 0]  (34 tests verified)
--- extractor-lint.sh ---                     [EXIT 0]  (123 Python tests pass)
--- godot-compile.sh ---                      [EXIT 0]
--- godot-fileaccess-tested.sh ---            [EXIT 0]
--- godot-label3d.sh ---                      [EXIT 0]
--- godot-tests.sh ---                        [EXIT 0]  (GDScript behavioral tests passed)

=== Summary: 32 check(s) run ===
RESULT: FAIL — check-relative-position-tests.sh exits 1
```

---

## Commit Trailers

Both `Spec-Ref` and `Task-Ref` trailers are present on implementation commits:
- `Spec-Ref: specs/extraction/scene-graph-schema.spec.md@3e5e297e216c7876224564ee099a38334e3dbd55`
- `Task-Ref: task-001`

✓ Trailers present.