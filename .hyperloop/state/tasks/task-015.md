---
id: task-015
title: Godot — pan camera with left mouse button (non-inverted)
spec_ref: specs/prototype/ux-polish.spec.md
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
---

Implement left-mouse-button drag to pan the camera across the scene, with natural
(non-inverted) movement direction.

Covers:
- Detect `MOUSE_BUTTON_LEFT` press/release to enter and exit pan mode.
- On mouse motion while panning, translate the camera along the ground plane (XZ) in the
  direction of the drag.
- Movement direction MUST match the drag direction (dragging left moves the view left, as
  in Google Maps — the scene appears to move in the same direction as the drag).
- Pan speed should be proportional to the camera's current distance from the scene (pan
  faster when zoomed out, slower when zoomed in) for consistent feel.
