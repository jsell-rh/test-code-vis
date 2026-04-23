---
task_id: task-007
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — specs/prototype/godot-application.spec.md

Godot 4.6.2 headless compilation passes (project compiles clean).
All GDScript scripts are `.gd` files. The engine version requirement is satisfied.

However, **no GDScript test suite exists**. Every scenario below is missing automated test
coverage. The only test file in the repo (`extractor/tests/test_schema.py`) validates Python
schema TypedDicts and does not touch any Godot behaviour. The headless-compile CI check
(`godot --headless --path godot/ --quit`) confirms compilation only — it does not assert any
runtime behaviour.

Additionally, one scenario has a PARTIAL code implementation (direction indication on edges).

---

### Requirement: JSON Scene Graph Loading — PARTIAL

**Code:** `godot/scripts/main.gd` → `_load_and_build()` + `_build()`

`_load_and_build()` opens `scene_graph_path`, JSON-parses the content, and calls `_build()`.
`_build()` iterates `graph["nodes"]` to create 3D volumes and `graph["edges"]` to create lines.
Node positions are read from `nd["position"]` and applied via `anchor.position`. Code fulfils
the loading contract.

**Tests — MISSING.** No GDScript test provides a synthetic JSON scene graph, runs the scene,
and asserts that:
- 3D volumes (MeshInstance3D nodes) are created for each JSON node.
- Edge line meshes are created for each JSON edge.
- Anchor positions match the `position` fields in the JSON.

What is needed: a headless GDScript test (e.g. using GUT or a minimal `res://tests/` runner)
that calls `_build()` with a known fixture dictionary and asserts the resulting scene-tree
contents.

---

### Requirement: Containment Rendering — PARTIAL

**Code:** `godot/scripts/main.gd` → `_create_volume()`

`bounded_context` nodes receive a flat translucent box (`TRANSPARENCY_ALPHA`, alpha 0.18,
`CULL_DISABLED`). Module nodes receive a compact opaque green box. Child nodes are parented to
their parent's `Node3D` anchor so they are physically nested inside it. The visual distinction
between parent and child is achieved through colour, opacity, and size difference.

**Tests — MISSING.** No test verifies that:
- A bounded context is rendered as a translucent volume.
- Its child module appears as an opaque, smaller volume whose world position is inside the parent.
- The visual properties (transparency flag, colour, size) are set correctly.

What is needed: a GDScript test that builds a minimal graph with one bounded-context and one
child module node and inspects the resulting MeshInstance3D materials and positions.

---

### Requirement: Dependency Rendering — PARTIAL (code gap + no tests)

**Code:** `godot/scripts/main.gd` → `_create_edge()`

A line is drawn between source and target world positions using `ImmediateMesh` /
`PRIMITIVE_LINES`. The edge colour differs by type (orange = `cross_context`,
grey = `internal`). The line itself is rendered.

**Scenario gap — direction not visually indicated.** The spec scenario states:
> "the line's direction is visually indicated"

The current implementation draws a plain two-vertex line with no arrowhead, cone, or other
directional marker. Colour alone distinguishes edge *type* but not *direction*. This requirement
is unmet at the code level.

**Tests — MISSING.** No test verifies:
- A line mesh is created between source and target positions.
- The colour matches the edge type.
- The direction of the edge is visually indicated.

What is needed: (1) add a directional indicator in `_create_edge()` (e.g. a small cone mesh
placed at the `to_pos` end, oriented along `to_pos - from_pos`); (2) a GDScript test that
confirms the mesh and directional marker are created with correct properties.

---

### Requirement: Size Encoding — PARTIAL

**Code:** `godot/scripts/main.gd` → `_create_volume()`

`sz = float(nd["size"])` is read from the JSON and used directly to scale the box mesh
dimensions. Larger size values produce larger boxes. The proportionality is linear.

**Tests — MISSING.** No test verifies that two nodes with different `size` values produce
meshes whose dimensions are proportional to those values.

What is needed: a GDScript test that builds a graph with two module nodes of different sizes
and asserts that the resulting `BoxMesh.size` vectors are proportional to the input `size`
fields.

---

### Requirement: Camera Controls — PARTIAL

**Code:** `godot/scripts/camera_controller.gd`

- **Zoom:** `MOUSE_BUTTON_WHEEL_UP` / `WHEEL_DOWN` adjust `_distance` and call
  `_update_transform()`. ✓
- **Orbit:** Middle-mouse drag adjusts `_phi` and `_theta` (clamped to `[0.01, PI-0.01]` to
  prevent pole-flip). `look_at(_pivot, Vector3.UP)` keeps up-orientation intuitive. ✓
- **Top-down default:** `_theta = 0.15` (≈ 8.6° from vertical). This is nearly top-down and
  satisfies the spirit of the scenario. ✓
- **Labels readable when zooming:** `Label3D` with `billboard = BILLBOARD_ENABLED` and fixed
  `pixel_size = 0.012`. As the camera moves closer, the label subtends a larger screen angle
  and stays readable. This is a reasonable implementation of the scenario. ✓

**Tests — MISSING.** No test verifies any camera behaviour:
- Camera starts at a near-vertical angle after scene load.
- Scroll input moves the camera closer / farther.
- Middle-mouse drag changes camera orientation while keeping `up = Vector3.UP`.

What is needed: GDScript tests that instantiate `CameraController`, call
`_handle_button` / `_handle_motion` with synthetic events, and assert the resulting
`global_position` and orientation.

---

### Requirement: Godot 4 — COVERED

**Code:** `godot/project.godot` declares `config/features=PackedStringArray("4.6")`.
All scripts (`main.gd`, `camera_controller.gd`) are GDScript.

**Test:** The CI check `godot --headless --path godot/ --quit` runs against Godot Engine
v4.6.2.stable.official (confirmed by live execution). Engine version and script language are
verified by compilation.

---

## Summary

| Requirement               | Code        | Tests       | Status  |
|---------------------------|-------------|-------------|---------|
| JSON Scene Graph Loading  | ✓ complete  | ✗ missing   | PARTIAL |
| Containment Rendering     | ✓ complete  | ✗ missing   | PARTIAL |
| Dependency Rendering      | ✗ no direction indicator | ✗ missing | PARTIAL |
| Size Encoding             | ✓ complete  | ✗ missing   | PARTIAL |
| Camera Controls           | ✓ complete  | ✗ missing   | PARTIAL |
| Godot 4                   | ✓ complete  | ✓ compile check | COVERED |

**Verdict: FAIL**

Primary reasons:
1. Every Godot scenario (Loading, Containment, Dependency, Size, Camera) lacks automated test
   coverage. A GDScript test suite (GUT or equivalent headless runner) is required.
2. The Dependency Rendering scenario requires a visual direction indicator on edge lines;
   the current code draws a plain undirected line.