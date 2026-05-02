---
task_id: task-027
round: 5
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — Non-Functional Requirements (specs/prototype/nfr.spec.md)

Branch: hyperloop/task-027
Task spec_ref: specs/core/visual-primitives.spec.md (task-027 scope)
NFR spec reviewed: specs/prototype/nfr.spec.md (shown in assignment Spec section)

---

## Scope Check Output

```
NOTE: Pre-existing prohibited spec-extraction code in extractor/extractor.py (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
NOTE: Pre-existing prohibited spec-extraction tests in extractor/tests/ (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
OK: No prohibited (not-in-scope) features detected.
```

---

## Process Check Results

| Check | Result |
|-------|--------|
| check-rebased-onto-main.sh | FAIL — 1 commit behind origin/main |
| check-not-in-scope.sh | OK (informational NOTEs only) |
| check-checks-in-sync.sh | OK |
| check-spec-ref-matches-task.sh | OK |
| check-branch-has-impl-files.sh | OK |
| check-class-test-count.sh | OK (269 >= 264) |
| All other checks | OK |

**Blocking process failure:** Branch is 1 commit behind origin/main.

Missing commit: `a6367113 process(task-078): add STOP PROTOCOL handling rule to orchestrator overlay`
This commit touches only `.hyperloop/agents/process/orchestrator-overlay.yaml` — no
implementation files. Fix: `git fetch origin main:main && git rebase origin/main`.

---

## Requirements Coverage — specs/prototype/nfr.spec.md

### Requirement: Godot 4.6 Engine — COVERED

**Implementation:** `godot/project.godot` declares
`config/features=PackedStringArray("4.6")`. All GDScript files use Godot 4.6 API:
`FileAccess.open()`, `FileAccess.get_as_text()`, `DirAccess.open()`. No deprecated
Godot 3 methods (`File.new()`, `read_as_text()`) found.

**Scenario: Engine version — COVERED**

| THEN-clause | Test | File |
|-------------|------|------|
| opens in Godot 4.6.x | `test_project_godot_declares_46_feature()`, `test_project_godot_config_features_line()` | `godot/tests/test_engine_version.gd` |
| all scripts use GDScript | `test_scripts_dir_contains_only_gdscript()` (iterates `res://scripts/`, asserts `.gd` extension) | `godot/tests/test_engine_version.gd`, `godot/tests/test_nfr.gd` |
| all API calls valid for Godot 4.6 | `test_file_access_get_as_text_returns_non_empty_string()` (exercises `get_as_text()`); `test_main_uses_godot4_fileaccess_api()` (asserts `FileAccess.open()` present, `File.new()` absent) | `godot/tests/test_engine_version.gd`, `godot/tests/test_godot_version.gd` |

---

### Requirement: Python Extractor — COVERED

**Implementation:** `extractor/extractor.py` imports only `ast`, `math`, `datetime`,
`pathlib` (all stdlib). `extractor/__main__.py` provides argparse-based CLI.
`check-extractor-stdlib-only.sh` exits 0. `check-extractor-cli-tested.sh` exits 0.

**Scenario: Running the extractor — COVERED**

| THEN-clause | Evidence |
|-------------|----------|
| runs as standalone Python script or CLI tool | `extractor/__main__.py` with `argparse`; `python -m extractor` entry point |
| requires no deps beyond stdlib and tree-sitter (or ast module) | Only `ast`, `math`, `datetime`, `pathlib` imported; `check-extractor-stdlib-only.sh` OK |

---

### Requirement: JSON Interface Contract — COVERED

**Implementation:** `godot/scripts/scene_graph_loader.gd` parses a JSON dictionary.
No `OS.execute()`, `OS.create_process()`, or Python-spawning calls found in any GDScript.
Godot app references the Python extractor only in doc-comments.

**Scenario: Decoupled pipeline — COVERED**

| THEN-clause | Test | File |
|-------------|------|------|
| does not need access to Python extractor or source codebase | `test_volumes_created_for_each_node()`, `test_mesh_instances_exist_in_anchors()` — work from self-contained JSON fixture without any Python or source access | `godot/tests/test_scene_graph_loading.gd` |
| JSON file is self-contained | All Godot tests operate on standalone Dictionary fixtures | `godot/tests/test_scene_graph_loader.gd`, `godot/tests/test_godot_app_spec.gd` |

---

### Requirement: Desktop Platform — COVERED

**Implementation:** No HTML5/Web export preset in project.godot. No web/mobile
platform features used in GDScript.

**Scenario: Running the prototype — COVERED**

| THEN-clause | Test | File |
|-------------|------|------|
| runs natively without browser dependencies | `test_not_running_in_web_browser()` — `OS.has_feature("web")` must be false | `godot/tests/test_desktop_platform.gd` |
| no container or VM dependencies | `test_not_running_on_android()`, `test_not_running_on_ios()` | `godot/tests/test_desktop_platform.gd` |
| no web export preset (config level) | `test_project_godot_has_no_web_export_preset()` — asserts project.godot has no HTML5/Web preset | `godot/tests/test_desktop_platform.gd` |

---

### Requirement: Performance at Kartograph Scale — PARTIAL

**Implementation:** LOD system (`godot/scripts/lod_manager.gd`) integrated in
`godot/scripts/main.gd`. `build_from_graph()` successfully builds 6 bounded
contexts × 9 modules = 60 nodes at kartograph scale.

**Scenario: Smooth navigation — PARTIAL**

| THEN-clause | Status | Evidence |
|-------------|--------|----------|
| frame rate remains above 30fps | MISSING — untestable in headless mode | `test_nfr_scale.gd` explicitly documents this as untestable; architectural evidence: LOD system culls invisible geometry per frame |
| no perceptible stutter or pop-in | MISSING — untestable in headless mode | Same headless limitation; LOD thresholds in `lod_manager.gd` manage pop-in |

**Structural tests that exist (necessary but not sufficient):**
- `test_kartograph_scale_anchor_count()` — 60 anchors created ✓
- `test_kartograph_scale_context_anchors_exist()` — all 6 bounded contexts ✓
- `test_kartograph_scale_module_anchors_exist()` — all 54 modules ✓
- `test_kartograph_scale_build_produces_world_positions()` — 60 world positions ✓
All in `godot/tests/test_nfr_scale.gd`.

**Why PARTIAL and not MISSING:** The FPS and stutter THEN-clauses require a render
pipeline to measure. Headless Godot cannot produce or measure frame rates. The tests
that exist are behavioral (instantiating Node3D, calling methods, asserting scene-tree
state) and cover the structural correctness THEN-clause as fully as headless testing
allows. No test can be written that asserts `fps > 30` without a display server.

**What is needed to resolve PARTIAL:**
The spec requirement is physically untestable under headless constraints. Options:
1. Accept PARTIAL as sufficient architectural evidence (LOD system + scale build success).
2. Add a manual/integration test note documenting that FPS was manually verified at
   kartograph scale.
3. Revise the spec to bound what is testable headlessly vs. what requires manual sign-off.

---

### Requirement: Prototype Disposability — SHOULD (informational)

This is a SHOULD, not SHALL/MUST. No test required. Not a FAIL.

---

## Requirements Coverage — specs/core/visual-primitives.spec.md § Ubiquitous Dependency Detection

(Task-027's assigned spec_ref; previously reviewed on unrebased branch. Confirmed
still COVERED after rebase — only 1 process-only commit was missing from main, which
touched no implementation files.)

| Requirement | Status | Code | Test |
|-------------|--------|------|------|
| Compute fraction of modules importing each dependency | COVERED | `detect_ubiquitous_dependencies()`, `compute_ubiquitous_flags()` in `extractor.py` | `TestUbiquitousFlags`, `TestUbiquitousDependencyDetection` |
| Flag dependencies imported by >50% (configurable) | COVERED | `UBIQUITOUS_THRESHOLD = 0.5`; `threshold` param | `test_custom_threshold_respected()`, `test_threshold_controls_detection()` |
| Edge `ubiquitous: true` annotation for flagged deps | COVERED | `e["ubiquitous"] = True` in `compute_ubiquitous_flags()` | `test_edge_marked_ubiquitous_above_threshold()`, `test_ubiquitous_edges_flagged()` |
| Threshold recorded in extraction metadata | COVERED | `metadata["ubiquitous_deps"]["threshold_pct"] = 50` | `TestUbiquitousDepsMetadata.test_metadata_ubiquitous_deps_has_threshold_pct()` |
| Flagged module list in extraction metadata | COVERED | `metadata["ubiquitous_deps"]["flagged"] = sorted(...)` | `TestUbiquitousDepsMetadata.test_metadata_ubiquitous_deps_has_flagged_list()` |

---

## FAIL Reasons

1. **check-rebased-onto-main.sh exits 1**: Branch is 1 commit behind `origin/main`.
   Missing: `a6367113 process(task-078)` (orchestrator overlay only, no implementation).
   Fix: `git fetch origin main:main && git rebase origin/main`.

2. **NFR Requirement: Performance at Kartograph Scale — PARTIAL**: The "frame rate
   remains above 30fps" and "no perceptible stutter or pop-in" THEN-clauses have no
   executable test assertions. Structural scale tests exist but cannot substitute for
   FPS measurement which requires a render pipeline unavailable in headless Godot.

---

## Summary

All NFR SHALL requirements are implemented. Four of five have full test coverage
(Godot 4.6, Python Extractor, JSON Interface Contract, Desktop Platform). The fifth
(Performance at Kartograph Scale) has structural scale tests but the FPS/stutter
THEN-clauses are untestable in headless mode — a known architectural constraint, not
a careless omission. All task-027 visual-primitives.spec.md requirements are COVERED.

The verdict is FAIL due to: (1) rebase required (1 process commit behind main) and
(2) strict reading of MUST requirement — FPS test coverage is absent even though it
is impossible to provide under headless constraints.

**Required fixes:**
1. `git fetch origin main:main && git rebase origin/main`
2. Resolve the FPS test gap: either accept structural evidence as sufficient (requires
   orchestrator guidance on the headless limitation) or add a manual test documentation
   note to `test_nfr_scale.gd` formalizing that FPS was manually verified.