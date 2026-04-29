---
task_id: task-108
round: 2
role: verifier
verdict: fail
---
## Review: task-108 (fix commit — second round)
Spec: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
Branch: hyperloop/task-108

---

## Scope Check Output

```
NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main
  (NOT introduced by this branch — attributed to their originating task, not to you):
  godot/scripts/understanding_overlay.gd  (origin: a2f9d139 feat(core): godot: evaluation mode — coupling and centrality visualization (#108))
  These are informational only and do NOT count as a FAIL for this branch.
OK: No prohibited (not-in-scope) features detected.
```

---

## run-all-checks.sh Output (verbatim)

All 41 automated checks exit 0 **except** `check-report-scope-section.sh` (which exits 1
only because `worker-result.yaml` did not yet exist — it passes once this file is written).

Individual check results:

| Check | Exit |
|---|---|
| check-aggregate-edge-impl.sh | 0 ✓ |
| check-branch-has-commits.sh | 0 ✓ |
| check-checks-in-sync.sh | 0 ✓ |
| check-circular-position-y-axis.sh | 0 ✓ |
| check-clamp-boundary-tests.sh | 0 ✓ |
| check-commit-trailer-task-ref.sh | 0 ✓ |
| check-compute-functions-called-from-entry-point.sh | 0 ✓ |
| check-directional-signchain-comments.sh | 0 ✓ |
| check-extractor-cli-tested.sh | 0 ✓ |
| check-extractor-stdlib-only.sh | 0 ✓ |
| check-gdscript-only-test.sh | 0 ✓ |
| check-godot-no-script-errors.sh | 0 ✓ |
| check-kartograph-integration-test.sh | 0 ✓ |
| check-layout-radius-bound.sh | 0 ✓ |
| check-lod-level-tests.sh | 0 ✓ |
| check-lod-opacity-animation.sh | 0 ✓ |
| check-new-modules-wired.sh | 0 ✓ |
| check-no-duplicate-toplevel-functions.sh | 0 ✓ |
| check-nondirectional-movement-assertions.sh | 0 ✓ |
| check-not-in-scope.sh | 0 ✓ |
| check-no-zero-commit-reattempt.sh | 0 ✓ |
| check-pipeline-wiring.sh | 0 ✓ |
| check-preloaded-gdscript-files.sh | 0 ✓ |
| check-prescribed-fixes-applied.sh | 0 ✓ |
| check-pytest-passes.sh | 0 ✓ |
| check-racf-prior-cycle.sh | 0 ✓ |
| check-racf-remediation.sh | 0 ✓ |
| check-relative-position-tests.sh | 0 ✓ |
| check-report-scope-section.sh | 1 ✗ (worker-result.yaml absent — expected) |
| check-ruff-format.sh | 0 ✓ |
| check-scope-report-not-falsified.sh | 0 ✓ |
| check-spec-ref-staleness.sh | 0 ✓ |
| check-spec-ref-valid.sh | 0 ✓ |
| check-task-ref-report-not-falsified.sh | 0 ✓ |
| check-typeddict-fields-extractor-tested.sh | 0 ✓ |
| check-worker-result-clean.sh | 0 ✓ |

check-lod-opacity-animation.sh verbatim:
```
NOTE: godot/scripts/lod_manager.gd (pre-existing on main) uses binary .visible toggle without opacity
  animation — this is a pre-existing spec gap, not attributed to this branch.
OK: Branch LOD files include Tween/modulate.a opacity animation.
```

check-aggregate-edge-impl.sh verbatim:
```
OK: Aggregate-edge implementation found.
  godot/scripts/aggregate_edge_renderer.gd
  godot/scripts/main.gd
```

check-lod-level-tests.sh verbatim:
```
LOD/visualization files modified by this branch:
  godot/scripts/main.gd

OK: 'Near (full detail)' LOD level test found.
  godot/tests/test_spatial_structure.gd
OK: 'Medium (module structure)' LOD level test found.
  godot/tests/test_spatial_structure.gd
OK: 'Far (aggregate edges / bounded context)' LOD level test found.
  godot/tests/test_spatial_structure.gd

OK: All LOD levels (Near / Medium / Far) have behavioral test coverage.
```

check-compute-functions-called-from-entry-point.sh verbatim:
```
Entry point file: extractor/extractor.py
OK: compute_layout() is called from extractor/extractor.py
OK: compute_loc() is called from extractor/extractor.py
```

check-typeddict-fields-extractor-tested.sh verbatim:
```
Schema file:     extractor/schema.py
test_extractor:  extractor/tests/test_extractor.py
test_schema:     extractor/tests/test_schema.py

Literal values found in schema TypedDicts:
  "bounded_context"
  "cross_context"
  "internal"
  "module"
  "spec"

OK: "bounded_context" — covered in test_extractor.py (9 occurrence(s))
OK: "cross_context" — covered in test_extractor.py (3 occurrence(s))
OK: "internal" — covered in test_extractor.py (2 occurrence(s))
OK: "module" — covered in test_extractor.py (3 occurrence(s))
OK: "spec" — covered in test_extractor.py (8 occurrence(s))

OK: All Literal type values have coverage in test_extractor.py.
```

check-spec-ref-staleness.sh verbatim:
```
OK (no drift): specs/visualization/spatial-structure.spec.md is identical at Spec-Ref
  (7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

---

## BLOCKING ISSUE — Broken main.tscn (dangling FPS script reference)

The fix commit (`06d2413e`) deleted `godot/scripts/first_person_camera_controller.gd`
and `godot/autoload/camera_mode.gd` correctly. However, **it did not revert
`godot/scenes/main.tscn`**. The scene file retains both the resource declaration and
the `FirstPersonController` node added by the first commit:

```
godot/scenes/main.tscn line 5:
  [ext_resource type="Script" path="res://scripts/first_person_camera_controller.gd" id="3"]

godot/scenes/main.tscn line 16-17:
  [node name="FirstPersonController" type="Node" parent="."]
  script = ExtResource("3")
```

`godot-compile.sh` emits these errors at runtime:

```
ERROR: Attempt to open script 'res://scripts/first_person_camera_controller.gd'
       resulted in error 'File not found'.
ERROR: Failed loading resource: res://scripts/first_person_camera_controller.gd.
ERROR: res://scenes/main.tscn:17 - Parse Error: [ext_resource] referenced
       non-existent resource at: res://scripts/first_person_camera_controller.gd.
```

`godot --headless --quit` exits 0 despite these errors (Godot does not fail its
process exit code on parse errors), so `godot-compile.sh` incorrectly reports
"Godot project compiles successfully." The GDScript unit tests also pass because
the test runner (`tests/run_tests.gd`) instantiates scripts directly without
loading `main.tscn`. The scene file is nonetheless broken: the app cannot be
launched without this parse error.

**What is needed:** Revert `godot/scenes/main.tscn` to the pre-branch state.
Specifically, in a single commit:

1. Remove line 5: `[ext_resource type="Script" path="res://scripts/first_person_camera_controller.gd" id="3"]`
2. Remove lines 16-17: `[node name="FirstPersonController" type="Node" parent="."]` and `script = ExtResource("3")`
3. Change `load_steps=4` back to `load_steps=3` on line 1.

After this change, `git diff main..HEAD -- godot/scenes/main.tscn` must be empty
(main.tscn should be identical to its state on main).

---

## Spec-Drift Summary

No spec drift detected. The committed spec at Spec-Ref is identical to HEAD.

---

## Cluster Collapsing — Out of Prototype Scope

All four Cluster Collapsing scenarios (collapsing, expanding, pre-computed suggestions,
nested collapsing) are absent from `specs/prototype/prototype-scope.spec.md` scope.
Not evaluated; not a FAIL driver.

---

## Requirement-by-Requirement Table

| Scenario | Status | Notes |
|---|---|---|
| 3D Interactive Navigation — First-person exploration | COVERED | Orbital camera provides navigable 3D space; FPS code correctly removed; orbit tests in test_spatial_structure.gd |
| Structure as Persistent Geography — Structural elements | COVERED | Pre-existing; test_spatial_structure.gd asserts anchors, positions, containment, translucency |
| Scale Through Zoom — Far (aggregate edges) | COVERED | aggregate_edge_renderer.gd groups by context pair, scales weight with count; 5 behavioral tests pass |
| Scale Through Zoom — Medium (module fade) | PRE-EXISTING GAP | Binary .visible toggle in lod_manager.gd; attributed to originating task by check-lod-opacity-animation.sh; not this branch's remit |
| Scale Through Zoom — Near (full detail) | COVERED | lod_manager.gd _apply_near(); test_near_distance_shows_all_nodes + test_near_distance_shows_internal_edges |
| Smooth transitions — aggregate edges | COVERED | Tween on albedo_color:a in show_edges/hide_edges |
| Smooth transitions — individual edges | PRE-EXISTING GAP | Binary .visible via lod_manager.gd; pre-existing, not this branch |
| Cluster Collapsing (all 4 scenarios) | OUT OF PROTOTYPE SCOPE | Not evaluated |

**FAIL reason:** `godot/scenes/main.tscn` was not reverted in the fix commit; it
retains a dangling `[ext_resource]` reference to the deleted
`first_person_camera_controller.gd`, causing a parse error on scene load.

All other requirements from the committed spec that are in prototype scope are
correctly implemented and tested.