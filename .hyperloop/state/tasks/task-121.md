---
id: task-121
title: Godot — smooth node opacity animation on LOD tier transition
spec_ref: specs/visualization/spatial-structure.spec.md
status: not-started
phase: null
deps: [task-019, task-067]
round: 0
branch: null
pr: null
---

Replace the instant `visible` toggle in task-019's LOD system with Tween-based
opacity animation so that nodes fade in and out smoothly as the camera crosses LOD
tier boundaries. This satisfies the spatial-structure spec's requirement that elements
never appear or disappear instantly.

Covers `specs/visualization/spatial-structure.spec.md` — Requirement: Scale Through
Zoom, Scenario: Smooth transitions between levels ("elements fade in or out with
animated opacity, never appearing or disappearing instantly AND the transition from
medium to near is continuous — no elements pop in or snap to visibility").

---

**Problem with task-019** — task-019 currently toggles `MeshInstance3D.visible`
(and its parent `Node3D.visible`) as a boolean based on camera distance. This
produces an instant snap: one frame a node is fully visible, the next it is gone.
The spec requires a continuous opacity fade.

---

**Implementation approach** — use Godot's `StandardMaterial3D` transparency and
`modulate` (via `GeometryInstance3D.transparency` or `BaseMaterial3D.albedo_color.a`)
to animate opacity, keeping `visible = true` throughout the fade and only setting
`visible = false` at the completion of a fade-out tween.

**Material setup** (extend task-009's node mesh creation):

Each node `MeshInstance3D` must use a material with:
- `transparency = BaseMaterial3D.TRANSPARENCY_ALPHA` (enables alpha channel).
- `albedo_color` with `a = 1.0` initially (fully opaque).

If task-009 already creates materials, extend them; do NOT create new material
instances per node (use `set_instance_shader_parameter` or `surface_get_material` as
appropriate for Godot 4.6).

---

**LOD fade-in logic** (replace the `visible = true` toggle in task-019):

When a node transitions from hidden to visible (camera enters tier range):

```gdscript
func _fade_in_node(node_mesh: MeshInstance3D, duration: float = 0.3) -> void:
    node_mesh.visible = true
    var mat: StandardMaterial3D = node_mesh.get_surface_override_material(0)
    if mat == null:
        mat = node_mesh.mesh.surface_get_material(0).duplicate()
        node_mesh.set_surface_override_material(0, mat)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var tween := create_tween()
    tween.tween_property(mat, "albedo_color:a", 1.0, duration).from(0.0)
```

**LOD fade-out logic** (replace the `visible = false` toggle in task-019):

When a node transitions from visible to hidden (camera leaves tier range):

```gdscript
func _fade_out_node(node_mesh: MeshInstance3D, duration: float = 0.2) -> void:
    var mat: StandardMaterial3D = node_mesh.get_surface_override_material(0)
    if mat == null:
        return  # already invisible or no material
    var tween := create_tween()
    tween.tween_property(mat, "albedo_color:a", 0.0, duration)
    tween.tween_callback(func(): node_mesh.visible = false)
```

**Hysteresis** — to prevent flicker when the camera hovers at a tier boundary, add
a small distance buffer (e.g. ±5% of the threshold distance) before triggering a
new fade. Specifically, the fade-in fires at `distance < threshold - buffer` and
the fade-out fires at `distance > threshold + buffer`.

---

**Integration with task-019** — task-019's `_process()` loop currently does:
```gdscript
node_mesh.visible = camera_dist < tier_threshold
```
Replace with calls to `_fade_in_node` / `_fade_out_node`, gated so they are only
called when the transition state CHANGES (not every frame). Use a per-node
`_lod_state: bool` dict to track current visibility state and call fade only on state
change:

```gdscript
var new_visible := camera_dist < tier_threshold
if new_visible != _lod_state.get(node_id, false):
    _lod_state[node_id] = new_visible
    if new_visible:
        _fade_in_node(node_mesh)
    else:
        _fade_out_node(node_mesh)
```

---

**Label3D nodes** — apply the same fade logic to `Label3D` nodes that are children
of the fading `Node3D`. Label3D supports `modulate.a` for opacity:

```gdscript
tween.tween_property(label_3d, "modulate:a", target_alpha, duration)
```

Fade labels in sync with their parent mesh.

---

**Interaction with task-067** — task-067 manages edge line opacity using a separate
system (edges connect nodes). Edge fade timing should remain independent; this task
only controls node (volume) and label opacity. Both systems may run concurrently
without conflict.

**Mode compatibility** — mode overlays (task-030 through task-053) apply colour
tints and border rings on top of the base material. Since those overlays use
`modulate` on separate child nodes or border meshes, the alpha fade on the base
mesh material does not interfere with mode-specific visual channels.

Use only GDScript and Godot 4.6 API. No external libraries.
