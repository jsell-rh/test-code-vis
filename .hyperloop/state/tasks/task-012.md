---
id: task-012
title: Godot — label rendering (node names as 3D text)
spec_ref: specs/prototype/prototype-scope.spec.md
status: not-started
phase: null
deps: [task-009]
round: 0
branch: null
pr: null
---

Attach a readable text label to every rendered volume so the user can identify each
structural element.

Covers:
- For each node, add a `Label3D` (or `Billboard` Label3D) displaying the node's `name` field.
- Position the label above or on top of its volume so it does not overlap with child volumes.
- Use billboard mode (`BILLBOARD_ENABLED`) so the label always faces the camera.
- Set a font size that is readable at typical viewing distances for the kartograph scene.
- Labels must remain legible at the default top-down overview zoom level (not just when
  zoomed in).
