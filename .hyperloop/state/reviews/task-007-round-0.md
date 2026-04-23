---
task_id: task-007
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — godot-application.spec.md

### Summary

Five of six requirements are fully COVERED (code + test). One requirement
(Camera Controls) is PARTIAL: the "Zooming in" scenario's THEN clause
"AND labels scale to remain readable" has implementation via Godot's inherent
3D rendering, but **no GDScript behavioral test asserts the label properties
that produce that behavior**.  Per protocol, missing test coverage on a SHALL
condition is a FAIL.

---

### Requirement: JSON Scene Graph Loading — COVERED

**SHALL**: load a JSON scene graph and generate the 3D scene from it.

**Scenario: Loading kartograph's scene graph**

| THEN clause | Code | Test |
|---|---|---|
| reads the JSON file | `main.gd::_load_and_build()` opens `FileAccess`, parses with `JSON.new()` | `_build()` exercised directly with fixture; file I/O path is a thin wrapper (acceptable) |
| generates 3D volumes for each node | `_build()` → `_create_volume()` populates `_anchors` | `test_volumes_created_for_each_node`, `test_mesh_instances_exist_in_anchors` |
| generates connections for each edge | `_build()` → `_create_edge()` adds `ImmediateMesh` + cone | `test_edge_mesh_instances_created` |
| positions elements per layout data | `anchor.position = Vector3(p["x"], p["y"], p["z"])` | `test_anchor_positions_match_json` |

---

### Requirement: Containment Rendering — COVERED

**SHALL**: render containment as nested volumes — child nodes visually inside parent.

**Scenario: Modules inside a bounded context**

| THEN clause | Code | Test |
|---|---|---|
| bounded context is larger translucent volume | `TRANSPARENCY_ALPHA`, `albedo_color.a = 0.18`, `BoxMesh(sz, sz*0.2, sz)` | `test_bounded_context_is_translucent`, `test_bounded_context_larger_than_module` |
| child modules are smaller opaque volumes | `albedo_color.a = 1.0`, `BoxMesh(sz, sz*0.6, sz)` | `test_module_is_opaque` |
| module anchor is child of context anchor | `_create_volume(nd, parent_anchor)` parents to ctx anchor | `test_module_parented_inside_context` |
| parent boundary visually distinct | `CULL_DISABLED` on context material | `test_bounded_context_cull_disabled` |

---

### Requirement: Dependency Rendering — COVERED

**SHALL**: render dependency edges as visible lines with direction indication.

**Scenario: Rendering a cross-context dependency**

| THEN clause | Code | Test |
|---|---|---|
| line connects the two context volumes | `ImmediateMesh` with `PRIMITIVE_LINES`, two vertices at world positions | `test_edge_line_mesh_created` |
| line direction visually indicated | `CylinderMesh(top_radius=0)` cone at target end, oriented via `Quaternion(UP, dir)` | `test_direction_indicator_cone_created`, `test_direction_cone_near_target` |
| cross-context color distinct (orange) | `Color(1.0, 0.50, 0.10)` when `type == "cross_context"` | `test_cross_context_cone_is_orange` |

---

### Requirement: Size Encoding — COVERED

**SHALL**: encode complexity metrics as visual size of volumes.

**Scenario: Large module vs small module**

| THEN clause | Code | Test |
|---|---|---|
| larger metric → larger volume | `sz = float(nd["size"])` drives `BoxMesh.size.x` directly | `test_large_module_has_bigger_mesh` |
| relative sizes proportional to metric | ratio `9/3 = 3.0`; mesh x-ratio asserted within 0.001 | `test_mesh_sizes_proportional_to_metric` |

---

### Requirement: Camera Controls — PARTIAL ← FAIL reason

**SHALL**: provide camera controls for navigating the scene.

**Scenario: Top-down overview** — COVERED

| THEN clause | Code | Test |
|---|---|---|
| camera defaults to top-down view | `_theta = 0.15` (8.6° from vertical, < PI/4) | `test_initial_theta_is_near_top_down` |
| camera positioned (not at pivot) | `_distance = 40.0` initially | `test_initial_distance_is_positive` |
| framed to show entire system | `_frame_camera()` → `set_pivot(centre, span*1.5)` | `test_set_pivot_updates_state` |

**Scenario: Zooming in** — PARTIAL

| THEN clause | Code | Test |
|---|---|---|
| camera moves closer | scroll-up decreases `_distance` | `test_scroll_up_decreases_distance` ✓ |
| internal structure becomes visible | inherent 3D perspective rendering | *(no explicit test — acceptable as engine behavior)* |
| **labels scale to remain readable** | Labels created with `billboard = BILLBOARD_ENABLED` and `pixel_size = 0.012`; in a perspective scene labels appear larger as the camera approaches | **NO TEST** ✗ |

The label readability behavior IS implemented (world-space Label3D with
`BILLBOARD_ENABLED` scales visually with camera distance in perspective rendering).
However, no GDScript behavioral test asserts the label properties that guarantee
this behavior.  The guidelines require a test with fixture data and property-value
assertions.

**What is needed**: Add a test in `test_camera_controls.gd` (or
`test_scene_graph_loading.gd`) that, after calling `_build(fixture)`, retrieves
the `Label3D` child from any anchor and asserts:
- `label.billboard == BaseMaterial3D.BILLBOARD_ENABLED`
- `label.pixel_size > 0.0`
- `label.no_depth_test == true` (ensures labels are visible through geometry at all zoom levels)

**Scenario: Orbiting** — COVERED

| THEN clause | Code | Test |
|---|---|---|
| camera rotates around focal point | middle-mouse drag changes `_phi` | `test_orbit_horizontal_drag_changes_phi` |
| altitude changes on vertical drag | middle-mouse drag changes `_theta` | `test_orbit_vertical_drag_changes_theta` |
| up stays up | `_theta` clamped `[0.01, PI-0.01]`; `look_at(_pivot, Vector3.UP)` | *(clamping asserted implicitly by orbit tests; UP enforced in code)* |
| zoom clamped | repeated scroll-up never breaches `min_distance` | `test_zoom_clamped_at_minimum` |

---

### Requirement: Godot 4 — COVERED

**SHALL**: be built with Godot 4.x and GDScript.

| Criterion | Evidence |
|---|---|
| Godot 4.x | `project.godot`: `config/features=PackedStringArray("4.6")` |
| GDScript | All scripts use `.gd` extension; no C# or other language files present |

No unit test required for a structural/toolchain requirement; project file
inspection is sufficient.

---

### What the Implementer Must Fix

Add **one test method** (suggested location:
`godot/tests/test_scene_graph_loading.gd` or `test_camera_controls.gd`) that
builds a scene from fixture data and asserts the following property values on
the `Label3D` created inside a volume anchor:

```gdscript
func test_labels_are_billboard_and_readable() -> bool:
    var main_node: Node3D = MainScript.new()
    main_node._build(_make_fixture())

    var anchor: Node3D = main_node._anchors.get("ctx1")
    if anchor == null:
        return false

    for child: Node in anchor.get_children():
        if child is Label3D:
            var lbl := child as Label3D
            return (
                lbl.billboard == BaseMaterial3D.BILLBOARD_ENABLED
                and lbl.pixel_size > 0.0
                and lbl.no_depth_test == true
            )
    return false
```

This directly asserts the property values that make labels "scale to remain
readable" as the camera zooms in, satisfying the spec's THEN clause with
known fixture data and runtime property assertions.