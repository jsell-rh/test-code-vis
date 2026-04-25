---
id: task-009
title: Godot — node volume rendering (boxes at schema positions)
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-008]
round: 0
branch: null
pr: null
---

Instantiate a 3D geometric volume (box or similar primitive) for every node in the scene
graph, placed at the position and sized according to the `size` field from the JSON.

Covers:
- For each node dict, create a `MeshInstance3D` with a `BoxMesh` (or equivalent primitive).
- Place the node at `position.x`, `position.y`, `position.z` from the JSON.
- Scale the volume proportionally to the node's `size` value.
- Use a neutral material by default (colour differentiation for containment and type
  encoding is handled in task-010 and task-011).
- Top-level bounded contexts and nested modules are both rendered by this task; nesting
  appearance is task-010's concern.
- The result: all nodes appear in the scene as correctly sized and positioned boxes.
