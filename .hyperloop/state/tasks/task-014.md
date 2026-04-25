---
id: task-014
title: Godot — default top-down camera
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-007]
round: 0
branch: null
pr: null
---

Configure the Godot camera so that on startup it defaults to a top-down view showing the
entire scene, with all bounded contexts visible.

Covers:
- Add a `Camera3D` to the main scene positioned above the scene centre, looking straight
  down (orthographic or perspective with high FOV).
- On scene load, auto-fit the camera distance so all nodes in the JSON are within the
  camera's frustum.
- Camera starts in a state where panning, zooming, and orbiting (tasks 015–018) can be
  applied via input handling.
- No camera input handling in this task — movement is added in tasks 015–018.
