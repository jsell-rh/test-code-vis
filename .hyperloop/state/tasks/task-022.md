---
id: task-022
title: Godot — on-demand flow path highlighting
spec_ref: specs/visualization/data-flow.spec.md
status: not-started
phase: null
deps: [task-021, task-009, task-013]
round: 0
branch: null
pr: null
---

Implement on-demand flow path visualization in the Godot application: the human triggers
a specific flow path and the relevant nodes and edges light up through the structure while
everything else is de-emphasised.

Covers `specs/visualization/data-flow.spec.md` — Requirement: Flow is On-Demand and
Requirement: Flow Shows Paths Through Structure:
- Load the `flow_paths` array from the JSON scene graph on startup (default to `[]` if
  absent).
- Do NOT render any flow highlighting by default; the structural view is unchanged until
  the human invokes a flow.
- Add a keyboard shortcut (e.g. `F` key or number keys `1`–`9`) to cycle through
  available flow paths, or a minimal UI label listing path names.
- When a flow path is active:
  - Highlight every node listed in `steps` (e.g. emissive tint or brightened material).
  - Highlight every dependency edge whose source and target are consecutive `steps` entries
    (mark the edge line with a distinct colour or increased width).
  - De-emphasise all other nodes and edges (e.g. reduce opacity or darken material).
  - The structural geography remains visible beneath the overlay — the flow is rendered on
    top of the existing scene, not in a separate view.
- Pressing the same shortcut again (or `Escape`) resets all materials to their base state.
- Use only GDScript and Godot 4.6 API; no additional plugins.
- LOD rules from task-019 still apply: flow highlighting on a hidden node has no visible
  effect until that node's LOD tier becomes visible.
