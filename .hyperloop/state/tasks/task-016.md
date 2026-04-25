---
id: task-016
title: Godot — zoom toward mouse cursor (scroll wheel)
spec_ref: specs/prototype/ux-polish.spec.md
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
---

Implement scroll-wheel zoom that zooms toward the point in the scene currently under the
mouse cursor, not toward the screen centre.

Covers:
- On `MOUSE_BUTTON_WHEEL_UP` / `WHEEL_DOWN`, raycast from the mouse position to find the
  world-space point under the cursor (intersect with the ground plane or a scene AABB).
- Move the camera toward (or away from) that world point, keeping the point under the cursor
  visually stable throughout the zoom.
- Zoom speed should feel proportional (logarithmic or multiplicative distance change per
  scroll tick).
- Enforce minimum and maximum zoom distance to prevent clipping into geometry or zooming
  to infinity.
