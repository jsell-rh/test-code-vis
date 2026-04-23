---
id: task-008
title: "Godot: node volume rendering"
spec_ref: specs/prototype/prototype-scope.spec.md
status: not-started
phase: null
deps: [task-007]
round: 0
branch: null
pr: null
---

## Goal

Render each node from the loaded scene graph as an abstract labeled geometric volume positioned at its pre-computed coordinates.

## Scope

- For each node in `SceneData`, instantiate a 3D volume (box or sphere MeshInstance3D) at its `position` (x, y, z)
- Use the node's `size` field to set the volume's scale
- Apply a basic material: opaque for leaf nodes (modules), translucent for container nodes (bounded contexts)
- Attach a text label (Label3D or billboard) showing the node's `name` — detailed label behavior is task-012; here, just ensure a label exists and is readable at default zoom
- All node types render using abstract geometric primitives — no thematic decoration, icons, or buildings

## Out of Scope

- Containment nesting — task-009
- Dependency edges — task-010
- Size encoding from metrics (the `size` field is already in the JSON from task-005; just apply it) — task-011 refines the mapping
- Camera — task-013
