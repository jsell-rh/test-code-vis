---
task_id: task-001
round: 21
role: verifier
verdict: fail
---
## Task: task-001 — Scene Graph Schema
**Spec:** specs/extraction/scene-graph-schema.spec.md
**Branch:** hyperloop/task-001
**Date:** 2026-04-26

Independent spec-alignment review. Synced `.hyperloop/checks/` from `main` before
running any checks (per review guidelines). Checks were added to `main` after the
task branch was created; this is a process-mechanism note, not a violation by
the implementer — but all FAILs from those checks are still blocking.

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## THEN→Test Mapping

| THEN-clause | Test(s) cited | Verdict |
|---|---|---|
| THEN it contains a `nodes` array, an `edges` array, and a `metadata` object | test_scene_graph_has_nodes_key, test_scene_graph_has_edges_key, test_scene_graph_has_metadata_key | PASS |
| AND no other top-level fields are present | test_scene_graph_has_no_extra_top_level_fields | PASS |
| THEN it has a unique `id` (e.g. "iam") | test_bounded_context_node_id | PASS |
| AND a `name` (e.g. "IAM") | test_bounded_context_node_name | PASS |
| AND a `type` field indicating its level (e.g. "bounded_context") | test_bounded_context_node_type | PASS |
| AND a `position` object with `x`, `y`, `z` coordinates | test_bounded_context_node_position_has_xyz | PASS |
| AND a `size` value derived from its complexity metric | test_bounded_context_node_size_is_numeric | PASS |
| AND `parent` is null (top-level node) | test_bounded_context_node_parent_is_null | PASS |
| THEN it has a unique `id` (e.g. "iam.domain") | test_module_node_id_dotted | PASS |
| AND a `parent` field referencing its containing node's id (e.g. "iam") | test_module_node_parent_references_context | PASS |
| AND a `type` field indicating its level (e.g. "module") | test_module_node_type_is_module | PASS |
| AND `position` coordinates relative to its parent | test_child_nodes_are_near_parent_position | FAIL — proximity test only; extractor.py:232-234 stores absolute world coordinates (see F1) |
| THEN it has a `source` field (e.g. "graph") | test_cross_context_edge_source | PASS |
| AND a `target` field (e.g. "shared_kernel") | test_cross_context_edge_target | PASS |
| AND a `type` field (e.g. "cross_context") | test_cross_context_edge_type | PASS |
| THEN it has a `source` field (e.g. "iam.application") | test_internal_edge_source | PASS |
| AND a `target` field (e.g. "iam.domain") | test_internal_edge_target | PASS |
| AND a `type` field (e.g. "internal") | test_internal_edge_type | PASS |
| THEN the metadata contains the source codebase path | test_metadata_has_source_path | PASS |
| AND the timestamp of extraction | test_metadata_has_timestamp | PASS |
| THEN each node's `position` field contains x, y, z coordinates | test_all_nodes_have_positions_after_layout | PASS |
| AND tightly coupled nodes have smaller distances between them | test_coupled_bcs_are_closer_than_uncoupled | PASS |
| AND child nodes are positioned within the spatial bounds of their parent | test_child_nodes_are_near_parent_position | FAIL — proximity test only; no relative-offset assertion (see F1, F3) |
| AND the Godot application renders nodes at these positions without recomputing layout | test_no_layout_recomputed_in_godot, test_anchor_positions_match_json | PASS |

---

## Commit Trailers

Implementation commit `3fb5db74` has both required trailers:

```
Spec-Ref: specs/extraction/scene-graph-schema.spec.md@3e5e297e216c7876224564ee099a38334e3dbd55
Task-Ref: task-001
```

✓ Trailers present.

---

## Findings

### F1 — Absolute child coordinates in extractor.py (BLOCKING, RACF)

`check-relative-position-tests.sh` exits 1. `extractor/extractor.py` lines 232-234
accumulate the parent's world position into each child's position field:

```python
child["position"] = {
    "x": px + pos[0],   # absolute: parent world x + local offset
    "y": py + pos[1],   # absolute: parent world y + local offset
    "z": pz + pos[2],   # absolute: parent world z + local offset
}
```

The spec requires "AND `position` coordinates relative to its parent." Absolute
coordinates cause Godot's `main.gd` to double-offset children (it adds the parent's
world position at render time on top of the already-absolute value).

**Prescribed fix (same as prior cycle):** change lines 232-234 to:
```python
child["position"] = {"x": pos[0], "y": pos[1], "z": pos[2]}
```

This is a **re-attempt compliance failure**: the prior cycle's verifier (f65c724)
prescribed this exact fix. The implementer instead created `extractor/layout.py`
with a different algorithm — but that module is dead code (see F2), and `layout.py`
contains the same absolute-coordinate bug in its own lines 91-93.

---

### F2 — Dead-code module: extractor/layout.py not wired into production (BLOCKING, RACF)

`check-new-modules-wired.sh` exits 1. The implementation commit (`3fb5db74`) added
`extractor/layout.py` and `extractor/tests/test_layout.py`, but no production source
file imports `layout`. Verified:

```
$ grep -rn "from extractor.layout\|import layout" extractor/ --include="*.py" | grep -v test_
(no output)
```

`extractor.py` imports only from `extractor.schema` and stdlib. It has its own
`compute_layout()` function (lines 189-240) which is what the production code path
calls. The tests in `test_layout.py` pass — they exercise `extractor.layout.compute_layout`
— but that function is never invoked at runtime. Those passing tests provide **zero
assurance** about the actual pipeline output.

Additionally, `layout.py`'s own child-position calculation also stores absolute
world coordinates (lines 91-93: `parent_pos[0] + math.cos(angle) * offset_r`), so
even if it were wired in, F1 would still be present.

This is a **re-attempt compliance failure**: the prior cycle's verifier (f65c724)
identified this exact pattern and prescribed either (a) wire `layout.py` into
`extractor.py` and fix the bug, or (b) fix the bug directly in `extractor.py` and
delete `layout.py`. Neither option was applied.

**Prescribed fix:** choose one:
- **(a) Wire the module:** update `extractor.py::compute_layout` to call
  `from extractor.layout import compute_layout as _layout` and return its result,
  after fixing the absolute-coords bug in `layout.py`.
- **(b) Fix in-place:** fix `extractor.py::compute_layout` directly (see F1 fix),
  delete `extractor/layout.py` (dead code), and delete `extractor/tests/test_layout.py`
  (or migrate its tests to exercise `extractor.extractor.compute_layout`).

---

### F3 — No relative-offset assertion test (BLOCKING, RACF)

`check-relative-position-tests.sh` exits 1 on the "relative-offset test" sub-check.
`test_child_nodes_are_near_parent_position` (test_extractor.py:406) only checks
`dist(child, parent) < bc_radius` — a proximity check. This assertion passes for
BOTH absolute and relative coordinate storage when the offset is small, so it
provides no evidence that the spec's "relative" requirement is satisfied.

A correct relative-offset test must:
1. Call `compute_layout` on a parent BC placed at a **non-zero** world position.
2. Assert `child["position"]["x"] == local_offset_x` (not `parent_x + local_offset_x`).
3. Optionally assert `child["position"]["x"] != parent_x + local_offset_x`.

This test must exercise the **production code path** in `extractor.extractor.compute_layout`,
not the dead-code `extractor.layout.compute_layout`.

This is also a **re-attempt compliance failure**: the prior cycle prescribed this
exact test in its F3 finding. The implementer added `test_layout.py::TestChildNodesWithinParentBounds`
(which tests dead code) instead of adding the required test to `test_extractor.py`.

---

### RACF Summary

Prior cycle report: `f65c724` (recovered from git history by `check-racf-prior-cycle.sh`;
the orchestrator's cleanup commit deleted the content from the HEAD version).

Checks that failed in `f65c724` and still fail now:
- `check-new-modules-wired.sh` — RACF (F2 above)
- `check-relative-position-tests.sh` — RACF (F1 + F3 above)

The implementer's response to the prior cycle was to add `extractor/layout.py` —
a new module with a corrected algorithm but the same absolute-coords bug, never wired
into production. This produced two new issues (dead code + duplicated bug) without
resolving either prior-cycle FAIL.

---

## Check Script Results

(Abbreviated: checks that exit 0 are listed by name only; FAILs shown in full.)

```
=== run-all-checks.sh ===

--- check-branch-adds-source-files.sh --- [EXIT 0]
--- check-branch-has-commits.sh --- [EXIT 0]
--- check-checkpoint-commit-is-empty.sh --- [EXIT 0]
--- check-checkpoint-commit-is-first.sh --- [EXIT 0]
--- check-checkpoint-commit.sh --- [EXIT 0]
--- check-checkpoint-task-matches-branch.sh --- [EXIT 0]
--- check-checks-in-sync.sh --- [EXIT 0]
--- check-clamp-boundary-tests.sh --- [EXIT 0]
--- check-combined-rewrite-guide.sh --- [EXIT 0]
--- check-compound-coverage-not-falsified.sh --- [EXIT 0]
--- check-compound-then-clause-coverage.sh --- [EXIT 0]  (SKIP: no compound THEN-clauses in mapping)
--- check-coordinator-calls-pipeline.sh --- [EXIT 0]  (SKIP)
--- check-desktop-platform-tested.sh --- [EXIT 0]
--- check-direction-test-derivations.sh --- [EXIT 0]
--- check-docstring-arrow-placement.sh --- [EXIT 0]
--- check-end-to-end-integration-test.sh --- [EXIT 0]  (SKIP)
--- check-extractor-cli-tested.sh --- [EXIT 0]
--- check-extractor-stdlib-only.sh --- [EXIT 0]
--- check-gdscript-only-test.sh --- [EXIT 0]
--- check-gdscript-test-bool-return.sh --- [EXIT 0]
--- check-kartograph-integration-test.sh --- [EXIT 0]

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

--- check-no-state-files-committed.sh --- [EXIT 0]
--- check-not-in-scope.sh --- [EXIT 0]
--- check-not-on-main.sh --- [EXIT 0]
--- check-pan-grab-model-comments.sh --- [EXIT 0]
--- check-pipeline-wiring.sh --- [EXIT 0]  (SKIP)

--- check-racf-prior-cycle.sh ---
Orchestrator cleanup obscured prior FAIL report — recovered from f65c724.
To inspect: git show f65c724:.hyperloop/worker-result.yaml

Checks that failed in that cycle — must now pass:

  check-new-modules-wired.sh                              FAIL (still failing — RACF)
  check-relative-position-tests.sh                        FAIL (still failing — RACF)

FAIL: One or more prior-cycle failures recovered from f65c724 still fail.
      This is a Re-Attempt Compliance Failure (RACF) obscured by orchestrator cleanup.
[EXIT 1 — FAIL]

--- check-racf-remediation.sh --- [EXIT 0]  (SKIP: prior report cleaned by orchestrator)

--- check-reflects-mapping-consistency.sh --- [EXIT 0]  (SKIP)

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
[EXIT 1 — FAIL]

--- check-report-scope-section.sh --- [EXIT 0]
--- check-scope-report-not-falsified.sh --- [EXIT 0]
--- check-then-test-mapping.sh --- [EXIT 0]
--- extractor-lint.sh --- [EXIT 0]  (123 pytest tests passed)
--- godot-compile.sh --- [EXIT 0]
--- godot-fileaccess-tested.sh --- [EXIT 0]
--- godot-label3d.sh --- [EXIT 0]
--- godot-tests.sh --- [EXIT 0]  (150 GDScript tests passed)
```

RESULT: FAIL — 3 checks exited non-zero (check-new-modules-wired.sh,
         check-racf-prior-cycle.sh, check-relative-position-tests.sh)

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
| Pre-Computed Layout | xyz in each position | COVERED |
| Pre-Computed Layout | Tightly coupled nodes closer | COVERED |
| Pre-Computed Layout | Child nodes within parent bounds | FAIL |
| Pre-Computed Layout | Godot renders without recomputing | COVERED |

**Overall verdict: FAIL** — Three blocking issues (F1, F2, F3), all RACF.

The fix path is unchanged from the prior cycle:

**Option A (recommended):** Fix `extractor.py::compute_layout` lines 232-234 to store
relative offsets (`{"x": pos[0], "y": pos[1], "z": pos[2]}`), delete
`extractor/layout.py` (dead code with the same bug), and add a relative-offset
assertion test in `extractor/tests/test_extractor.py` (parent at non-zero world
position; assert child position == local offset, not parent + offset).

**Option B:** Wire `extractor/layout.py` into `extractor/extractor.py` (remove or
delegate the duplicate internal `compute_layout`), fix the absolute-coords bug in
`layout.py`, and add the relative-offset test to `test_layout.py` (with a parent
at non-zero world position).