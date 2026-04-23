---
id: task-012
title: "Godot: readable node labels at all zoom levels"
spec_ref: specs/prototype/prototype-scope.spec.md
status: not-started
phase: null
deps: [task-008]
round: 0
branch: null
pr: null
---

## Goal

Ensure every visible node has a text label that remains readable at the current zoom level, from overview to close-up detail.

## Scope

- Use Godot's `Label3D` node (billboard mode) or a viewport-space label anchored to each volume
- Label text is the node's `name` field
- Labels must scale or adjust so they remain legible as the camera zooms in or out (e.g. fixed screen-space size, or size clamped between min/max)
- At the overview level (all bounded contexts visible), bounded context labels must be readable
- At the detail level (zoomed into one context), module labels within that context must be readable
- Labels must not overlap to the point of being unreadable at normal usage zoom levels

## Out of Scope

- Dynamic label visibility toggling based on zoom (nice-to-have, not required by spec)
