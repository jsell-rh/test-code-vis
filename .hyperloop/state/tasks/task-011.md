---
id: task-011
title: Godot — size encoding (volume scale from complexity metric)
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-009]
round: 0
branch: null
pr: null
---

Ensure rendered volume sizes are proportional to the complexity metric stored in each node's
`size` field, so larger modules are visually larger.

Covers:
- Read the `size` value from each node in the JSON.
- Map `size` values to a consistent visual scale (e.g. min/max normalisation to a
  `[0.5, 4.0]` unit range) so relative differences are perceptible but no node is
  invisible or overwhelmingly large.
- Apply the computed scale to the `MeshInstance3D` created in task-009.
- Verify with the kartograph scene graph that modules with more LOC render larger than
  modules with less.
