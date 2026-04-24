---
task_id: task-023
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — specs/prototype/nfr.spec.md

Branch reviewed: hyperloop/task-023

---

### Requirement: Godot 4.6 Engine — COVERED

**Implementation:**
- `godot/project.godot` line 19: `config/features=PackedStringArray("4.6")` declares the engine version.
- All files under `godot/scripts/` are `.gd` (GDScript); no `.cs` or Mono files present.
- `main.gd` uses `FileAccess.open()` + `get_as_text()` (Godot 4.x API). No deprecated
  `File.new()` or `read_as_text()` calls found.

**Test coverage:**
- `godot/tests/test_engine_version.gd` (included in `run_tests.gd`):
  - `test_project_godot_declares_46_feature` — reads `project.godot` via `FileAccess.open() +
    get_as_text()` and asserts `"4.6"` appears.
  - `test_project_godot_config_features_line` — asserts `config/features` contains `"4.6"`.
  - `test_project_does_not_declare_csharp` — asserts no `"Mono"` or `"C#"` in project.godot.
  - `test_file_access_get_as_text_returns_non_empty_string` — exercises the Godot 4.x
    `FileAccess.get_as_text()` API path directly.
  - `test_scripts_dir_contains_only_gdscript` — iterates `res://scripts/` via `DirAccess`
    and asserts every file ends with `.gd`.
- `godot/tests/test_godot_version.gd` (included in `run_tests.gd`):
  - `test_project_declares_godot_46`, `test_main_script_is_gdscript`,
    `test_main_uses_godot4_fileaccess_api`.

All scenario THEN-clauses are exercised.

---

### Requirement: Python Extractor — COVERED

**Implementation:**
- `extractor/__main__.py` provides a CLI entry point: `python -m extractor <src_path>
  [--output <output.json>]`.
- All production imports (`extractor.py`, `__init__.py`, `__main__.py`, `schema.py`) use
  only stdlib modules: `ast`, `math`, `datetime`, `pathlib`, `argparse`, `json`, `sys`.
  No third-party packages are imported.

**Test coverage:**
- `extractor/tests/test_cli.py`:
  - `test_main_exits_zero` — CLI exits 0 on a valid source path.
  - `test_main_writes_json_output` — CLI writes a valid JSON scene graph with `nodes`,
    `edges`, `metadata`.
  - `test_extractor_imports_are_stdlib_only` — parses all production `.py` files with `ast`
    and asserts every top-level import is in `sys.stdlib_module_names`.
- `extractor/tests/test_extractor.py` contains 50+ tests exercising the extraction logic
  end-to-end with hermetic tmp_path fixtures.

All scenario THEN-clauses are exercised.

---

### Requirement: JSON Interface Contract — COVERED

**Implementation:**
- `godot/scripts/main.gd` loads the scene graph with `FileAccess.open()` + `JSON.parse()`
  + `SceneGraphLoader.load_from_dict()`. No subprocess calls, no extractor imports, no
  access to the Python source codebase.
- Only two comment-level references to "Python extractor" exist in `main.gd` and
  `scene_graph_loader.gd`; no runtime coupling.
- `godot/data/scene_graph.json` (854 lines, 6 bounded contexts + 31 modules) is committed
  to the repo and is a self-contained JSON file requiring no extractor to load.

**Test coverage:**
- `godot/tests/test_scene_graph_loader.gd`: All tests use in-memory Dictionary fixtures —
  the Godot loader is exercised without any extractor involvement.
  - `test_empty_graph_is_handled_gracefully`, `test_missing_top_level_keys_default_to_empty`,
    `test_metadata_is_returned` confirm the Godot app only requires the JSON structure.
- `godot/tests/test_scene_graph_loading.gd`: `test_volumes_created_for_each_node`,
  `test_edge_mesh_instances_created`, `test_anchor_positions_match_json` — all use
  Dictionary fixtures, not the extractor.
- `extractor/tests/test_schema.py`: `TestSchemaStructure.test_scene_graph_has_no_extra_top_level_fields`
  verifies the JSON has exactly `{nodes, edges, metadata}`.

The decoupling is both structurally enforced and exercised by tests.

---

### Requirement: Desktop Platform — PARTIAL ← causes FAIL

**Implementation:**
- `godot/project.godot` is configured as a native desktop application: desktop viewport
  (1920×1080), no web-export settings, no browser/container dependencies.
- The project type (Godot 4.6 desktop) structurally enforces this constraint.

**Test coverage: MISSING.**
No GDScript behavioral test in `godot/tests/` exercises the scenario THEN-clause:
  "it runs natively without browser, container, or VM dependencies."

A minimal test is feasible. For example, in a new test file
`godot/tests/test_desktop_platform.gd` (included in `run_tests.gd`):

```gdscript
func test_platform_is_not_web() -> void:
    _check(not OS.has_feature("web"),
        "Prototype must run as a native desktop app, not in a web browser")

func test_platform_is_not_embedded() -> void:
    _check(not OS.has_feature("android") and not OS.has_feature("ios"),
        "Prototype must target desktop (Linux), not mobile/embedded platforms")

func test_project_godot_has_no_web_export_settings() -> void:
    var file := FileAccess.open("res://project.godot", FileAccess.READ)
    _check(file != null, "project.godot must be readable")
    if file == null:
        return
    var content: String = file.get_as_text()
    file.close()
    _check(not content.contains("web/export"),
        "project.godot must not contain web export settings")
```

**What is needed:** Add `godot/tests/test_desktop_platform.gd` with at least one behavioral
test asserting the platform is non-web, and register it in `run_tests.gd`.

---

### Requirement: Performance at Kartograph Scale — COVERED

**Implementation:**
- `godot/scripts/lod_manager.gd` implements LOD with `FAR_THRESHOLD=80.0` and
  `NEAR_THRESHOLD=20.0`, culling module nodes and edges at distance to maintain
  frame rate.
- `main.gd` calls `_update_lod()` every `_process()` frame, integrating the LOD
  manager into the render loop.

**Test coverage:**
- `godot/tests/test_nfr_scale.gd` (included in `run_tests.gd` at line 55):
  - `test_kartograph_scale_anchor_count` — `build_from_graph()` with 6 bounded contexts +
    54 modules creates exactly 60 anchors.
  - `test_kartograph_scale_context_anchors_exist` — all 6 kartograph context anchors exist.
  - `test_kartograph_scale_module_anchors_exist` — all 54 module anchors exist.
  - `test_kartograph_scale_build_produces_world_positions` — `_world_positions` contains 60
    entries (graph ran to completion without errors).

The test file documents that FPS measurement is impossible in headless mode and provides
structural evidence of compliance via the LOD system. This is the maximum achievable
behavioral coverage for this scenario in a headless test context.

---

### Requirement: Prototype Disposability — NOTE (SHOULD, not a FAIL)

This is a SHOULD requirement about development philosophy, not a testable behavior.
No test is expected or required. The JSON scene graph format is the sole interface artifact
and is preserved in `specs/extraction/scene-graph-schema.spec.md` and
`extractor/schema.py`.

---

## Summary

| Requirement                     | Status  | Notes                                              |
|---------------------------------|---------|----------------------------------------------------|
| Godot 4.6 Engine                | COVERED | project.godot + 8 tests in 2 suites                |
| Python Extractor                | COVERED | CLI + stdlib-only constraint tested                |
| JSON Interface Contract         | COVERED | Loader tests use in-memory fixtures; no extractor  |
| Desktop Platform                | PARTIAL | Implementation correct; no behavioral test exists  |
| Performance at Kartograph Scale | COVERED | LOD + 4 kartograph-scale structural tests          |
| Prototype Disposability         | N/A     | SHOULD only; noted                                 |

**Verdict: FAIL**

One MUST requirement (Desktop Platform) has correct implementation but no GDScript
behavioral test for its scenario. Add `godot/tests/test_desktop_platform.gd` with
`OS.has_feature("web")` assertions and register it in `run_tests.gd` to resolve.