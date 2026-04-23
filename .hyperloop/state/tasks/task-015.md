---
id: task-015
title: 'Godot: on-demand flow path activation and selection'
spec_ref: specs/visualization/data-flow.spec.md
status: not-started
phase: null
deps:
- task-010
round: 0
branch: null
pr: null
---

## What

Implement the mechanism by which the user invokes a flow view in the Godot app. By default, no flow is shown. When triggered, the user can specify or select a start node (and optionally an end node), and the app computes the reachable path through the existing dependency edge graph.

This satisfies the "Flow is On-Demand" requirement: flow visualization is never shown by default and is only activated in response to an explicit user action.

## Acceptance criteria

- The structural view renders with no flow indication by default.
- A UI control (button or keyboard shortcut) toggles flow mode on/off.
- In flow mode, the user can select a starting node from the rendered scene.
- The app traverses the dependency edges (already rendered by task-010) to identify the connected path(s) from the selected node.
- The computed path is stored as state for downstream rendering (task-016).
- Exiting flow mode returns the view to the default structural state.

## Notes

- Does not require changes to the JSON scene graph schema; uses dependency edges already present.
- Path computation logic lives in GDScript (BFS/DFS over the in-memory graph).
- The visual rendering of the highlighted path is handled by task-016.
