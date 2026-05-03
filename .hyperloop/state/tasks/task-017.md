---
id: task-017
title: UX — orbit around cursor point with smooth camera movement
spec_ref: "specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee"
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement RMB orbit around cursor point with smooth interpolation"
pr_description: |
  ## What and Why

  Orbit lets users tilt the perspective to inspect 3D structure from an angle, revealing
  depth relationships that the top-down view hides. Orbiting around the cursor point
  (not the world origin) keeps the area of interest centred. Smooth movement prevents
  disorienting snaps and makes the tool feel responsive and polished. This task also
  covers the "smooth camera movement" requirement from ux-polish.spec.md since pan and
  zoom smooth behaviour is validated here holistically.

  ## Spec Requirements Satisfied

  From `specs/prototype/ux-polish.spec.md`:

  - **Orbit Around Mouse Point**: RMB drag orbits around world-space point under cursor
    at drag start; component remains at visual centre during orbit
  - **Smooth Camera Movement**: all camera transitions interpolated (no snapping or
    jerking); smooth pan proportional to drag speed; smooth zoom already in task-016

  From `specs/prototype/godot-application.spec.md`:

  - **Camera Controls — Orbiting**: rotates around focal point; up stays up

  ## Key Design Decisions

  - On RMB press, ray-cast to find the world-space orbit pivot point (same ray-cast
    logic as zoom in task-016; reuse the helper).
  - Store the pivot. On `InputEventMouseMotion` while RMB held:
    - Compute the spherical-coordinate offset of the camera from the pivot.
    - Apply horizontal delta to azimuth, vertical delta to elevation.
    - Clamp elevation to `[5°, 85°]` to prevent gimbal flip and ground-clipping.
    - Recompute camera position from updated spherical coordinates.
  - `up` direction is always `Vector3.UP` (Y-up world) — Godot's `look_at()` handles this.
  - Smooth orbit: target position/rotation is set immediately (no tween) to ensure 1:1
    feel with mouse movement. Smooth zoom (task-016 tween) is the only eased motion.
  - Pan smoothness: the pan delta from task-015 is already frame-proportional; no
    additional tweening required to satisfy the "smooth pan" scenario.

  ## Files Affected

  - `godot/scenes/CameraController.gd` — updated: `_handle_orbit()` implementation,
    spherical-coordinate math, pivot caching, elevation clamp
  - `godot/tests/test_camera_orbit.gd` — GUT tests: orbit changes camera azimuth/elevation;
    pivot point stays at same screen position after orbit; elevation is clamped

  ## Verification

  1. GUT tests pass.
  2. In the running app: hold RMB over IAM volume, drag horizontally → camera orbits; IAM
    stays approximately at the same screen position.
  3. Dragging RMB vertically pitches the view; Y-up is maintained.
  4. Cannot orbit to below the ground plane (elevation clamp active).

  ## Caveats

  Spherical coordinates introduce gimbal lock only at the poles (±90° elevation), which
  is prevented by the elevation clamp. If the user orbits to a near-vertical view and then
  pans, pan direction may feel counter-intuitive — this is acceptable for the prototype.
---
