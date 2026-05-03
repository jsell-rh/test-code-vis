---
id: task-017
title: UX — orbit around mouse point (right-drag)
spec_ref: "specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee"
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): orbit camera around cursor point on right mouse drag"
pr_description: |
  ## What and Why

  An orbit that pivots around the screen centre or world origin feels detached — the
  component the user wanted to examine slides away as soon as they rotate. This PR locks
  the orbit pivot to the world point that was under the cursor when the right mouse button
  was pressed, so the target component stays visually centred throughout the rotation.

  ## Spec Requirements Satisfied

  From `specs/prototype/ux-polish.spec.md`:

  - **Orbit Around Mouse Point**: right-mouse-button drag rotates the camera around the
    world point under the cursor at orbit start; the component under the cursor remains
    at the visual centre during the orbit.

  ## Key Design Decisions

  - On `InputEventMouseButton` with `MOUSE_BUTTON_RIGHT` pressed: ray-cast from camera
    through cursor to the XZ ground plane to find the orbit pivot in world space;
    store it as `_orbit_pivot`.
  - On `InputEventMouseMotion` while `_orbiting`: apply spherical coordinate rotation
    (azimuth and elevation delta) around `_orbit_pivot`, repositioning the camera rig so
    the pivot stays fixed.
  - Clamp elevation angle to prevent gimbal lock at the poles (e.g. 5°–85°).
  - Up-axis stays +Y throughout; no full inversion of the camera is allowed.
  - When right mouse button is released, clear `_orbiting` and `_orbit_pivot`.

  ## Files Affected

  - `godot/scenes/CameraController.gd` — updated `_handle_orbit()`: pivot capture on
    RMB press, spherical rotation around pivot, elevation clamp
  - `godot/tests/test_camera_orbit.gd` — GUT tests: camera position changes on
    horizontal drag (azimuth); camera position changes on vertical drag (elevation);
    pivot world position does not translate during orbit (within tolerance); elevation
    is clamped at boundaries

  ## Verification

  1. GUT tests pass.
  2. In the running app: right-click over graph context, drag horizontally → graph
     context stays centred; drag vertically → elevation changes, graph stays centred.
  3. No other camera state (zoom level, pan position) is disturbed by orbit.

  ## Caveats

  Smooth orbit animation (no snapping) is delivered by the immediate per-frame response
  to `InputEventMouseMotion`; additional lerp smoothing is handled in task-018.
---
