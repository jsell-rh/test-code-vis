---
id: task-017
title: UX — orbit around cursor point with smooth camera movement
spec_ref: specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee
status: not_started
phase: null
deps:
- task-014
round: 0
branch: null
pr: null
pr_title: 'feat(godot): implement RMB orbit around cursor point with smooth interpolation'
pr_description: "## What and Why\n\nOrbit lets users tilt the perspective to inspect\
  \ 3D structure from an angle, revealing\ndepth relationships that the top-down view\
  \ hides. Orbiting around the cursor point\n(not the world origin) keeps the area\
  \ of interest centred. Smooth movement prevents\ndisorienting snaps and makes the\
  \ tool feel responsive and polished. This task also\ncovers the \"smooth camera\
  \ movement\" requirement from ux-polish.spec.md since pan and\nzoom smooth behaviour\
  \ is validated here holistically.\n\n## Spec Requirements Satisfied\n\nFrom `specs/prototype/ux-polish.spec.md`:\n\
  \n- **Orbit Around Mouse Point**: RMB drag orbits around world-space point under\
  \ cursor\n  at drag start; component remains at visual centre during orbit\n- **Smooth\
  \ Camera Movement**: all camera transitions interpolated (no snapping or\n  jerking);\
  \ smooth pan proportional to drag speed; smooth zoom already in task-016\n\nFrom\
  \ `specs/prototype/godot-application.spec.md`:\n\n- **Camera Controls — Orbiting**:\
  \ rotates around focal point; up stays up\n\n## Key Design Decisions\n\n- On RMB\
  \ press, ray-cast to find the world-space orbit pivot point (same ray-cast\n  logic\
  \ as zoom in task-016; reuse the helper).\n- Store the pivot. On `InputEventMouseMotion`\
  \ while RMB held:\n  - Compute the spherical-coordinate offset of the camera from\
  \ the pivot.\n  - Apply horizontal delta to azimuth, vertical delta to elevation.\n\
  \  - Clamp elevation to `[5°, 85°]` to prevent gimbal flip and ground-clipping.\n\
  \  - Recompute camera position from updated spherical coordinates.\n- `up` direction\
  \ is always `Vector3.UP` (Y-up world) — Godot's `look_at()` handles this.\n- Smooth\
  \ orbit: target position/rotation is set immediately (no tween) to ensure 1:1\n\
  \  feel with mouse movement. Smooth zoom (task-016 tween) is the only eased motion.\n\
  - Pan smoothness: the pan delta from task-015 is already frame-proportional; no\n\
  \  additional tweening required to satisfy the \"smooth pan\" scenario.\n\n## Files\
  \ Affected\n\n- `godot/scenes/CameraController.gd` — updated: `_handle_orbit()`\
  \ implementation,\n  spherical-coordinate math, pivot caching, elevation clamp\n\
  - `godot/tests/test_camera_orbit.gd` — GUT tests: orbit changes camera azimuth/elevation;\n\
  \  pivot point stays at same screen position after orbit; elevation is clamped\n\
  \n## Verification\n\n1. GUT tests pass.\n2. In the running app: hold RMB over IAM\
  \ volume, drag horizontally → camera orbits; IAM\n  stays approximately at the same\
  \ screen position.\n3. Dragging RMB vertically pitches the view; Y-up is maintained.\n\
  4. Cannot orbit to below the ground plane (elevation clamp active).\n\n## Caveats\n\
  \nSpherical coordinates introduce gimbal lock only at the poles (±90° elevation),\
  \ which\nis prevented by the elevation clamp. If the user orbits to a near-vertical\
  \ view and then\npans, pan direction may feel counter-intuitive — this is acceptable\
  \ for the prototype."
---
