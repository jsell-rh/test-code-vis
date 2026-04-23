---
id: task-016
title: 'Godot: flow path overlay renderer with structural de-emphasis'
spec_ref: specs/visualization/data-flow.spec.md
status: not-started
phase: null
deps:
- task-015
round: 0
branch: null
pr: null
---

## What

Render the active flow path as a visually distinct overlay on the existing structural geography. Nodes and edges on the path are highlighted; everything else is de-emphasized. The structural context (all nodes and containment volumes) remains visible — it is not replaced or hidden.

This satisfies the "Flow Shows Paths Through Structure" requirement.

## Acceptance criteria

- Nodes on the active flow path are rendered with a distinct highlight material/color.
- Dependency edges on the active flow path are rendered with increased visibility (e.g. brighter, thicker, animated).
- Nodes and edges not on the path are de-emphasized (e.g. reduced opacity or desaturated) but remain visible.
- The flow path is spatially traceable from entry node to terminus node.
- When flow mode is deactivated (task-015), all materials revert to their default state.

## Notes

- The active path state is produced by task-015.
- Uses Godot material overrides or shader parameters on existing mesh instances — no new geometry types required.
- The structural containment volumes (bounded contexts, modules) remain visible and unaffected.
