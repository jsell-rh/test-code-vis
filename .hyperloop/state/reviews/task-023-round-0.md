---
task_id: task-023
round: 0
role: spec-reviewer
verdict: fail
---
# Spec Alignment Review: specs/prototype/nfr.spec.md

All automated checks exit 0. Godot tests: 95 passed, 0 failed.
Python extractor tests: 90 passed, 0 failed.

---

## Requirement 1: Godot 4.6 Engine — COVERED

**Implementation:**
- `godot/project.godot` declares `config/features=PackedStringArray("4.6")`.
- All scripts in `godot/scripts/` are `.gd` files.
- API uses `FileAccess.open()` + `get_as_text()` (Godot 4.x API), not deprecated Godot 3
  `File.new()` / `read_as_text()`.

**Tests:**
- `godot/tests/test_engine_version.gd`: 5 tests — `test_project_godot_declares_46_feature`,
  `test_project_godot_config_features_line`, `test_project_does_not_declare_csharp`,
  `test_file_access_get_as_text_returns_non_empty_string`,
  `test_scripts_dir_contains_only_gdscript` (DirAccess iteration predicate).
- `godot/tests/test_godot_version.gd`: 3 tests — `test_project_declares_godot_46`,
  `test_main_script_is_gdscript`, `test_main_uses_godot4_fileaccess_api`.

All GIVEN/WHEN/THEN conditions covered.

---

## Requirement 2: Python Extractor — PARTIAL

**Implementation:**
- `extractor/__main__.py` provides `python -m extractor <src_path> [--output ...]` CLI.
- Only stdlib imports throughout: `ast`, `math`, `datetime`, `pathlib`, `json`,
  `argparse`, `sys`, `typing` — no `requirements.txt`, no third-party packages.

**Tests:**
- Extraction logic is well-tested (90 pytest tests in `extractor/tests/test_extractor.py`
  and `extractor/tests/test_schema.py`).
- `check-kartograph-integration-test.sh` passes on the basis that `test_extractor.py`
  references "kartograph" and asserts expected context names (`iam`, `shared_kernel`,
  `graph`) in a temp-dir fixture.

**Missing:**
1. No test exercises the CLI entry point (`main()` in `extractor/__main__.py`).
   The scenario THEN-clause "it runs as a standalone Python script or CLI tool" requires
   a test that calls `main(["<tmp_src_path>"])` or invokes `python -m extractor` via
   subprocess and asserts a 0 exit code and valid JSON output.
2. No test verifies the "requires no dependencies beyond stdlib" constraint — a test that
   inspects all imports in the extractor package and asserts they are all stdlib would
   cover this THEN-clause explicitly.

**Action needed:**
Add a pytest test (e.g. `test_cli.py`) with at minimum:
```python
from extractor.__main__ import main

def test_main_produces_json_output(tmp_path, src):
    output = tmp_path / "out.json"
    rc = main([str(src), "--output", str(output)])
    assert rc == 0
    assert output.exists()
    data = json.loads(output.read_text())
    assert "nodes" in data and "edges" in data and "metadata" in data
```

---

## Requirement 3: JSON Interface Contract — COVERED

**Implementation:**
- The Python extractor outputs `{"nodes": [...], "edges": [...], "metadata": {...}}` via
  `json.dumps(graph, indent=2)` in `__main__.py`.
- The Godot application loads JSON via `SceneGraphLoader.load_from_dict(json.data)` in
  `godot/scripts/main.gd`; it has no import of or reference to the Python extractor.

**Tests:**
- `godot/tests/test_scene_graph_loader.gd` (24 tests): verifies Godot parses the dict
  without calling the Python extractor — uses pure dict fixtures.
- `godot/tests/test_scene_graph_loading.gd` (5 tests): verifies `build_from_graph()`
  consumes a JSON-shaped dict and creates correct 3D nodes and edges.
- `extractor/tests/test_schema.py` (19 tests): verifies the schema TypedDicts are
  JSON-serialisable and self-contained.

The JSON dict is the sole interface; neither component references the other. All scenario
THEN-clauses ("does not need access to the Python extractor", "JSON file is self-contained")
are demonstrated by the Godot tests which never import the extractor.

---

## Requirement 4: Desktop Platform — MISSING (inherently untestable via unit tests)

**Implementation:**
- `godot/project.godot` configures a standard Godot desktop application (no web export
  target, no container manifest). The Godot runtime itself handles OS-level integration.

**Tests:**
- No test exists that verifies "runs natively without browser, container, or VM
  dependencies" on Fedora Linux.
- This scenario is not testable via GDScript headless unit tests because:
  - OS platform identity (`OS.get_name()`) would only be meaningful when run on Fedora.
  - "No browser/container dependency" is a deployment property, not a runtime assertion.

**Assessment:**
The implementation satisfies the requirement architecturally (native Godot desktop
project). The absence of a test is an inherent limitation of the headless testing
framework, not an oversight in the implementation. This gap is noted but is not
correctable via a meaningful unit test.

---

## Requirement 5: Performance at Kartograph Scale — PARTIAL

**Implementation:**
- `godot/scripts/lod_manager.gd`: Level-of-detail system with `FAR_THRESHOLD`,
  `NEAR_THRESHOLD`, `_apply_far()`, `_apply_medium()`, `_apply_near()` — reduces draw
  calls by hiding module nodes and edges when the camera is distant.
- `godot/scripts/main.gd`: registers all nodes/edges with LOD manager; calls
  `_update_lod()` every frame.

**Tests:**
- `godot/tests/test_spatial_structure.gd`: 12 LOD tests verify the mechanism works
  (`test_far_distance_shows_only_bounded_contexts`, `test_far_distance_hides_all_edges`,
  `test_medium_distance_shows_modules`, etc.).

**Missing:**
- No test loads a kartograph-scale fixture (~50 modules, ~100 files across 6 bounded
  contexts) and verifies the scene builds without error or perceptible lag.
- No frame-rate benchmark exists (30fps minimum). Headless Godot has no render pipeline
  so measuring FPS is not possible via the current test framework.

**Assessment:**
The LOD mechanism — which is the architectural solution for the 30fps requirement — is
implemented and tested. The actual frame-rate guarantee cannot be verified via automated
headless tests. The PARTIAL status reflects that the solution's building blocks are
tested but the end-to-end performance scenario at kartograph scale is unverified.

To address the kartograph-scale part: add a GDScript test that calls
`build_from_graph()` with a fixture of 6 bounded contexts and 50+ modules and asserts
no errors (no push_error calls) and correct node counts.

---

## Requirement 6: Prototype Disposability — NOTE (SHOULD, not MUST)

The prototype is built for learning; code quality takes second place to iteration speed.
The JSON scene graph format is the only artifact intended for preservation. No test is
needed for this SHOULD requirement.

---

## Summary

| Requirement                          | Status   |
|--------------------------------------|----------|
| Godot 4.6 Engine (MUST)              | COVERED  |
| Python Extractor (MUST)              | PARTIAL  |
| JSON Interface Contract (MUST)       | COVERED  |
| Desktop Platform (MUST)              | MISSING  |
| Performance at Kartograph Scale (MUST)| PARTIAL  |
| Prototype Disposability (SHOULD)     | NOTE     |

**Verdict: FAIL**

Two SHALL/MUST requirements lack full test coverage:

1. **Requirement 2 (Python Extractor)**: The CLI entry point `main()` in
   `extractor/__main__.py` is never called by any test. Add a pytest test in
   `extractor/tests/test_cli.py` that invokes `main()` with a temp src_path and asserts
   exit code 0 and a valid JSON output file.

2. **Requirement 5 (Performance)**: No kartograph-scale build test exists. Add a GDScript
   test that calls `build_from_graph()` with a 6-context, 50-module fixture and asserts
   no errors and correct anchor counts.

Requirement 4 (Desktop Platform) also lacks a test, but this is an inherent limitation
of headless unit testing and not addressable by a meaningful automated test.