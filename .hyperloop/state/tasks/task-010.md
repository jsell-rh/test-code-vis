---
id: task-010
title: "Godot: dependency edge rendering"
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-008]
round: 0
branch: null
pr: null
---

## Goal

Render dependency edges from the scene graph as visible directed lines connecting the source and target node volumes.

## Scope

- For each edge in `SceneData`, draw a 3D line (ImmediateMesh or MeshInstance3D with a cylinder/tube) from the source node's position to the target node's position
- Indicate directionality visually (e.g. arrowhead at the target end, or color gradient from source to target)
- Distinguish `cross_context` edges from `internal` edges visually (e.g. different color or line weight)
- Lines must update correctly if node positions change (though positions are static at runtime in the prototype)

## Acceptance

- Loading the kartograph scene graph shows lines between dependent modules/contexts
- Direction of dependency is discernible (e.g. which context depends on which)
