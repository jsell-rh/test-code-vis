---
id: task-017
title: Godot — orbit camera around cursor point (right mouse button)
spec_ref: specs/prototype/ux-polish.spec.md
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
---

Implement right-mouse-button drag to orbit the camera around the world-space point that was
under the cursor when the drag began.

Covers:
- On `MOUSE_BUTTON_RIGHT` press, raycast to determine the orbit pivot point in world space
  (the point under the cursor at drag start).
- While the right button is held and the mouse moves, rotate the camera around that fixed
  pivot point.
- Maintain an intuitive up-axis constraint (camera up stays up; pitch clamped to avoid
  flipping past the zenith or below the ground).
- The pivot component under the cursor at drag start should remain visually centred
  throughout the orbit.
