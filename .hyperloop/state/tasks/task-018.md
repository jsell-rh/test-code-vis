---
id: task-018
title: Godot — smooth camera movement (interpolated transitions)
spec_ref: specs/prototype/ux-polish.spec.md
status: not-started
phase: null
deps: [task-015, task-016, task-017]
round: 0
branch: null
pr: null
---

Make all camera movements smooth and continuous — no snapping or jerking — by interpolating
camera position and orientation each frame.

Covers:
- Pan (task-015): movement is proportional to drag speed; no lag beyond the drag itself.
- Zoom (task-016): each scroll tick animates the camera smoothly toward the target zoom
  level over a short duration (e.g. ~100–150 ms) rather than jumping instantly.
- Orbit (task-017): rotation is smooth and proportional to mouse speed.
- Use `lerp()` or `move_toward()` in `_process()` to interpolate toward target camera
  state each frame.
- Ensure accumulated scroll ticks stack correctly (rapid scrolling continues zooming in
  the same direction without resetting).
