---
task_id: task-020
round: 1
role: implementer
verdict: fail
---
## Summary

All implementation work for the task-020 schema-layer deliverables was completed
correctly. However, `check-not-in-scope.sh` fails post-commit because the keyword
patterns it uses to detect "data flow visualization" code also match schema-layer
TypedDict definitions (`FlowPath`, `flow_paths`) that are not visualization code.
This is a false positive in the keyword check. The submission gate
(`run-all-checks.sh`) therefore exits non-zero, requiring a FAIL verdict.

The implementation is complete and correct. The orchestrator needs to narrow the
keyword check so schema-layer type definitions do not trigger it, then re-run.

---

## Implementation — Completed

All items from the prior review (Findings section) were implemented:

### Python schema (`extractor/schema.py`)
- Added `FlowPath(TypedDict)` with `id: str`, `name: str`, `steps: list[str]`
- Added `flow_paths: NotRequired[list[FlowPath]]` to `SceneGraph` TypedDict
- Added `_OPTIONAL_GRAPH_KEYS = frozenset({"flow_paths"})` constant
- Added `_REQUIRED_FLOW_PATH_KEYS = frozenset({"id", "name", "steps"})` constant
- Updated `validate_scene_graph` to accept `flow_paths` as an optional key
  (changed from reject-unknown to allow-optional policy)
- Added `flow_paths` validation: type check, per-entry dict validation,
  required key check for `id`, `name`, `steps`, type checks for each field

### Python tests (`extractor/tests/test_schema.py`)
- Added `FlowPath` to the imports from `extractor.schema`
- Added `make_flow_path()` helper returning a valid FlowPath fixture
- Added `TestValidateSceneGraph` tests:
  - `test_flow_paths_empty_list_is_valid` — `flow_paths: []` passes validation
  - `test_graph_without_flow_paths_is_valid` — absence is valid (optional)
  - `test_valid_flow_path_passes_validation` — well-formed entry passes
  - `test_flow_path_missing_id_raises` — missing `id` raises ValueError
  - `test_flow_path_missing_name_raises` — missing `name` raises ValueError
  - `test_flow_path_missing_steps_raises` — missing `steps` raises ValueError
  - `test_flow_path_non_dict_entry_raises` — non-dict entry raises ValueError
- Added `TestFlowPathSchema` class with 12 tests covering TypedDict fields,
  types, ordering, JSON serializability, optional field behavior

All 178 pytest tests pass.

### Schema documentation (`extractor/schema.md`) — created new file
- Documents all top-level fields including the optional `flow_paths`
- Provides field-level tables for every TypedDict
- Includes complete example JSON with a populated `flow_paths` array
- Clarifies that absent `flow_paths` is treated as `[]` by the Godot consumer

### Godot loader (`godot/scripts/scene_graph_loader.gd`)
- Added `"flow_paths": _parse_flow_paths(data.get("flow_paths", []))` to
  `load_from_dict` return dictionary
- Added `_parse_flow_paths(raw_paths: Array) -> Array` static method that
  parses each entry preserving `id`, `name`, `steps`

### Godot tests (`godot/tests/test_scene_graph_loader.gd`)
- Added 7 behavioral tests for the `flow_paths` loader behavior:
  - `test_flow_paths_absent_returns_empty_array` — key present, value `[]`
  - `test_flow_paths_empty_list_returns_empty_array` — explicit `[]` stays `[]`
  - `test_flow_paths_populated_returns_all_entries` — count matches input
  - `test_flow_path_id_is_preserved` — `id` field passes through correctly
  - `test_flow_path_name_is_preserved` — `name` field passes through correctly
  - `test_flow_path_steps_are_preserved_in_order` — `steps` order preserved,
    entry point is index 0, terminus is last
  - `test_flow_paths_populated_returns_all_entries` — multi-entry scenario

All 30 GDScript tests in test_scene_graph_loader.gd pass (including the 7 new ones).

---

## Scope Check Conflict — Root Cause

### Why check-not-in-scope.sh fails

The `_DF_KW_PATTERN` in `check-not-in-scope.sh` includes `FlowPath\b` and
`flow_path` (substring, no word boundary) to detect data flow visualization code.
These same tokens appear in schema-layer TypedDict definitions and JSON field
names that are NOT visualization code. The check attributes any file with a
commit on this branch that matches the pattern as "introduced here" → FAIL.

### Why this is a false positive

The prototype-scope.spec.md prohibition is "data flow visualization is NOT
implemented." This refers to the visual rendering behavior: path highlighting in
3D, overlay animation, path tracing through the Godot scene. None of that was
implemented. What WAS implemented is:
- A TypedDict named `FlowPath` (a data structure, not a renderer)
- A JSON field `flow_paths` (a schema extension, not a visualization primitive)
- Validation logic for the above
- A loader that reads the field with a default

`check-assigned-spec-in-scope.sh` confirmed the spec is in scope (exit 0).
The prior review (Findings section) explicitly stated: "schema-layer deliverables
described in the task-020 definition, which ARE in scope."

### Resolution required from orchestrator

Update `check-not-in-scope.sh` on main to exclude schema-layer files from the
`FlowPath`/`flow_path` keyword match. One viable approach: exclude
`extractor/schema.py`, `extractor/tests/test_schema.py`, and `extractor/schema.md`
from the data-flow keyword check (they define data types, not visualization).
Alternatively, replace the broad `flow_path` substring pattern with a more
precise pattern that targets rendering functions
(e.g., `show_flow_path\|render_flow_path\|clear_flow_path`) rather than schema
type names.

---

## Scope Check Output

```
FAIL: Prohibited data-flow visualization code detected (matched by feature keyword).
  The spec bans the FEATURE (data flow visualization), not just specific file names.
  Matched files (introduced by this branch):
  extractor/schema.md
  extractor/schema.py
  extractor/tests/test_schema.py
  godot/scripts/scene_graph_loader.gd
  godot/tests/test_scene_graph_loader.gd
NOTE: Pre-existing data-flow visualization patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  extractor/__pycache__/schema.cpython-313.pyc  (origin: )
  extractor/tests/__pycache__/test_schema.cpython-313-pytest-8.4.1.pyc  (origin: )
  These are informational only and do NOT count as a FAIL for this branch.
```

---

## Check Results Summary (post-commit)

| Check | Status |
|---|---|
| check-aggregate-edge-impl.sh | PASS (not applicable) |
| check-assigned-spec-in-scope.sh | PASS (spec in scope) |
| check-branch-has-commits.sh | PASS |
| check-checks-in-sync.sh | PASS (44 checks synced) |
| check-circular-position-y-axis.sh | PASS |
| check-clamp-boundary-tests.sh | PASS |
| check-commit-trailer-task-ref.sh | PASS |
| check-compute-functions-called-from-entry-point.sh | PASS |
| check-directional-signchain-comments.sh | PASS |
| check-extractor-cli-tested.sh | PASS |
| check-extractor-stdlib-only.sh | PASS |
| check-gdscript-only-test.sh | PASS |
| check-godot-no-script-errors.sh | PASS (all 30 loader tests pass) |
| check-kartograph-integration-test.sh | PASS |
| check-layout-radius-bound.sh | PASS |
| check-lod-level-tests.sh | PASS (not applicable) |
| check-lod-opacity-animation.sh | PASS (not applicable) |
| check-new-modules-wired.sh | PASS (not applicable) |
| check-no-duplicate-toplevel-functions.sh | PASS |
| check-nondirectional-movement-assertions.sh | PASS |
| **check-not-in-scope.sh** | **FAIL** (keyword false positive — see above) |
| check-no-zero-commit-reattempt.sh | PASS |
| check-pipeline-wiring.sh | PASS (not applicable) |
| check-preloaded-gdscript-files.sh | PASS |
| check-prescribed-fixes-applied.sh | PASS |
| check-pytest-passes.sh | PASS (178/178 tests pass) |
| check-racf-prior-cycle.sh | PASS |
| check-racf-remediation.sh | PASS |
| check-relative-position-tests.sh | PASS |
| check-report-scope-section.sh | PASS (verbatim FAIL output pasted) |
| check-ruff-format.sh | PASS |
| check-scope-report-not-falsified.sh | PASS (truthful FAIL reported) |
| check-spec-ref-staleness.sh | PASS |
| check-spec-ref-valid.sh | PASS |
| check-task-ref-report-not-falsified.sh | PASS |
| check-tscn-no-dangling-references.sh | PASS |
| check-typeddict-fields-extractor-tested.sh | PASS |
| check-worker-result-clean.sh | PASS (file not committed) |
| extractor-lint.sh | PASS |
| godot-compile.sh | PASS |
| godot-fileaccess-tested.sh | PASS |
| godot-label3d.sh | PASS |
| godot-tests.sh | PASS |

**Overall: 1 check fails (check-not-in-scope.sh) due to keyword false positive.**