---
id: task-108
title: Godot — first-person camera navigation mode
spec_ref: specs/visualization/spatial-structure.spec.md
status: not-started
phase: null
deps: [task-018]
round: 0
branch: null
pr: null
---

Add a first-person (FPS-style) camera navigation mode to the Godot application,
allowing the human to walk through the 3D software space, complementing the existing
top-down/orbital camera (tasks 014–018).

Covers `specs/visualization/spatial-structure.spec.md` — Requirement: 3D Interactive
Navigation ("The system MUST present the software system as a 3D space that the human
navigates in first person. The human can move through it in first person. The spatial
layout communicates the system's structure"):

---

**Mode toggle** — press `Tab` to switch between Orbital mode (existing, default) and
First-Person mode. The current mode is shown in the HUD key legend (task-039):
- Orbital: `"[Tab] → First Person"` hint in corner.
- First Person: `"[Tab] → Orbital | WASD: move | Mouse: look | Scroll: speed | Esc: exit"`.

Switching modes preserves the current camera world position so the human does not
lose their place.

---

**First-person controls** — while First-Person mode is active:

1. **Mouse look** — capture the mouse pointer
   (`Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`) on mode entry; restore
   `MOUSE_MODE_VISIBLE` on mode exit.
   On `InputEventMouseMotion`:
   - Yaw (left/right): rotate camera around the world Y axis by
     `event.relative.x * MOUSE_SENSITIVITY` (default `0.002` rad/pixel; named constant).
   - Pitch (up/down): tilt camera around its local X axis by
     `event.relative.y * MOUSE_SENSITIVITY`, clamped to ±85° to prevent flipping.
   Apply rotation order: yaw first (world Y), pitch second (local X). No roll.

2. **Movement keys** — in `_process(delta)`:
   - `W` / `S`: move forward / backward along the camera's horizontal forward vector
     (project the look direction onto the XZ plane, normalise).
   - `A` / `D`: strafe left / right (`forward.cross(Vector3.UP).normalized()`).
   - `Space` / `Shift`: ascend / descend along world Y.
   - Apply: `camera.global_position += direction * MOVE_SPEED * delta`.
   - `MOVE_SPEED` default: `5.0` units/s (named constant).

3. **Speed adjustment** — mouse scroll wheel adjusts `MOVE_SPEED` in steps of 1.0,
   clamped to `[0.5, 50.0]`. Display current speed as `"⚡ N.N u/s"` in the HUD
   while First-Person mode is active.

4. **Exit to Orbital** — pressing `Escape` while in First-Person mode restores
   `MOUSE_MODE_VISIBLE` and switches back to Orbital mode immediately, preventing
   the mouse from being trapped.

---

**Camera node setup** — reuse the existing `Camera3D` node (task-014).

Add a `CameraMode` autoload (`godot/autoload/camera_mode.gd`):
```gdscript
var is_first_person: bool = false
signal mode_changed(first_person: bool)
func enter_first_person() -> void:
    is_first_person = true
    emit_signal("mode_changed", true)
func enter_orbital() -> void:
    is_first_person = false
    emit_signal("mode_changed", false)
```

In the existing Orbital camera script (task-018): connect to `CameraMode.mode_changed`
and disable its `_process()` interpolation when `is_first_person == true`.

Add `FirstPersonCameraController.gd` (new script, attached to the main scene or as
an autoload) that handles `_process()` input only when `CameraMode.is_first_person == true`.

The two controllers are mutually exclusive: exactly one drives the camera per frame.

---

**LOD integration** — the LOD system (task-067) computes distances from
`camera.global_position`. In First-Person mode the camera is inside the scene, but
the same `NEAR_THRESHOLD` and `FAR_THRESHOLD` constants apply without modification —
the LOD system is camera-position-agnostic. As the human walks toward a module, it
transitions far → medium → near LOD exactly as when zooming in from above. No LOD
changes are required by this task.

---

**Simple collision avoidance** — prevent the camera from passing through node
volumes. Implement a lightweight approach:

1. After computing the desired new camera position from movement keys, check whether
   the new position is inside any node's axis-aligned bounding box (derived from
   `node.position ± node.size / 2` for all loaded nodes).
2. If a collision is detected, clamp each axis of the movement delta independently so
   that the camera slides along the node face rather than stopping completely
   (stair-step avoidance: allow movement along the non-colliding axes).
3. If adding per-node AABB checks is too expensive for large scenes, skip collision
   avoidance and document the limitation with a `# TODO: collision` comment; the human
   can navigate around nodes by steering.

No `StaticBody3D` or physics shapes are added to node volumes by this task — use
pure math against the scene graph's `position` and `size` fields already loaded by
task-008.

---

**HUD update** — update the key legend (task-039):

- Add `"[Tab] First Person"` to the Orbital mode key row.
- In First-Person mode, replace orbital camera hints with:
  `"[Tab] Orbital | WASD Move | Mouse Look | Scroll Speed | Esc Exit"`.
- Display speed in the top-right corner while in First-Person mode.

---

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
