---
task_id: task-020
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-020 (Extend JSON schema for flow paths)

**Branch:** hyperloop/task-020
**Spec:** specs/visualization/data-flow.spec.md
**Task scope:** Schema-layer foundation for flow paths (FlowPath TypedDict, validator update, Godot loader default, schema doc). Full visualization behavior is out of prototype scope per specs/prototype/prototype-scope.spec.md.

---

## Prototype Scope Note

`specs/prototype/prototype-scope.spec.md` explicitly excludes "data flow visualization" from the prototype. Therefore the THEN-clauses in the data-flow.spec.md scenarios (lights up paths, de-emphasizes, renders as spatial path) are NOT required at this stage. This review evaluates only the concrete schema-layer deliverables described in the task-020 definition, which ARE in scope.

---

## Requirement: Flow is On-Demand (SHALL) — schema layer deliverable

Task-020 scope: add `flow_paths: []` as an optional top-level array; add `FlowPath` TypedDict with `id`, `name`, `steps`.

### STATUS: MISSING

**Implementation:**
- `extractor/schema.py` — no `FlowPath` TypedDict exists anywhere in the file.
- `SceneGraph` TypedDict (lines 140-151) contains only `nodes`, `edges`, `metadata`, `clusters`. No `flow_paths` field.
- `_REQUIRED_GRAPH_KEYS` (line 164) = `{"nodes", "edges", "metadata", "clusters"}` — does not include `flow_paths`.
- `validate_scene_graph` (lines 175-273) actively rejects extra top-level keys (lines 197-201): `if extra: raise ValueError(f"Scene graph has unexpected top-level key(s): {sorted(extra)}")`. A JSON file containing `"flow_paths"` would raise `ValueError` rather than being accepted as valid.

**Tests:**
- `test_schema.py::TestSchemaStructure::test_scene_graph_has_no_extra_top_level_fields` (line 117) asserts `set(graph.keys()) == {"nodes", "edges", "metadata", "clusters"}` — this test actively contradicts the task requirement that `flow_paths` be a valid optional key.
- `test_schema.py::TestValidateSceneGraph::test_extra_top_level_key_raises` (line 495) confirms the validator rejects unknown keys. No test for `flow_paths` being accepted.
- No `TestFlowPath` or equivalent test class exists.

**What is needed:**
1. Add `FlowPath(TypedDict)` with fields: `id: str`, `name: str`, `steps: list[str]`.
2. Add `flow_paths: NotRequired[list[FlowPath]]` to `SceneGraph`.
3. Update `_REQUIRED_GRAPH_KEYS` to `_VALID_GRAPH_KEYS` (or equivalent) so `flow_paths` is allowed as an optional key — the extra-key check must be changed from a reject-unknown policy to allow `flow_paths`.
4. Add flow path validation logic in `validate_scene_graph` that, when `flow_paths` is present, validates each entry has `id` (str), `name` (str), `steps` (list).
5. Add pytest tests: `flow_paths: []` passes validation; a valid flow path object passes; a flow path missing `id`/`name`/`steps` raises `ValueError`; a graph without `flow_paths` at all still passes.

---

## Requirement: Flow Shows Paths Through Structure (SHALL) — schema layer deliverable

Task-020 scope: `steps` array (ordered node-id list from entry to terminus) represents the path through structure in the JSON.

### STATUS: MISSING

This is the same underlying issue — `FlowPath` with `steps` does not exist. See above.

Additionally:

**Godot loader (`godot/scripts/scene_graph_loader.gd`, lines 16-21):**
- `load_from_dict` returns only `nodes`, `edges`, `metadata`. There is no `data.get("flow_paths", [])` call.
- The task requires: "The Godot application MUST NOT crash when `flow_paths` is absent or empty; it treats the field as optional with a default of `[]`."
- Currently the loader silently ignores `flow_paths` (which avoids a crash but does not fulfill the contract that the field is *treated* as optional with a default — there is no code path that reads it at all).

**Godot tests (`godot/tests/test_scene_graph_loader.gd`):**
- No test exercises a fixture that includes `flow_paths` and verifies the loader returns `flow_paths: []` for absent input or passes through a non-empty array.

**What is needed:**
1. In `scene_graph_loader.gd`, add `"flow_paths": data.get("flow_paths", [])` to `load_from_dict`'s return dictionary.
2. Add a GDScript behavioral test with two scenarios: (a) fixture without `flow_paths` → loader returns `flow_paths` as empty array; (b) fixture with a populated `flow_paths` array → loader returns it with correct `id`, `name`, `steps` values.

---

## Schema Document

Task-020 requires updating `extractor/schema.md` or `extractor/schema.json` with the `flow_paths` field definition and examples.

### STATUS: MISSING

No `schema.md` or `schema.json` file exists anywhere under `extractor/` or in the repository root. The task requires creating or updating this document with the new field definition and at least one example flow path object.

---

## Requirement: Aggregate Flow Patterns (SHOULD)

This requirement is marked SHOULD and is also explicitly excluded from prototype scope. Absence is a note, not a failure.

### STATUS: NOTE (out of prototype scope; SHOULD only)

---

## Summary

| Deliverable | Status | Blocker |
|---|---|---|
| `FlowPath` TypedDict in `schema.py` | MISSING | No type definition added |
| `flow_paths` field in `SceneGraph` | MISSING | Not present in TypedDict |
| Validator accepts `flow_paths` as optional | MISSING | Validator actively rejects it |
| Validator validates `FlowPath` objects | MISSING | No validation logic |
| Pytest tests for all above | MISSING | No `flow_paths`-related test exists |
| Schema document updated | MISSING | No `schema.md`/`schema.json` file |
| Godot loader reads `flow_paths` with default `[]` | MISSING | Not in `load_from_dict` return |
| GDScript tests for Godot loader behavior | MISSING | No such tests |

The branch appears to be at the same state as `main` — no implementation work for task-020 has been committed.