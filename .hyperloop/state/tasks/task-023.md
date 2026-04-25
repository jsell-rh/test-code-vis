---
id: task-023
title: Godot — aggregate flow pattern overlay (hot paths)
spec_ref: specs/visualization/data-flow.spec.md
status: not-started
phase: null
deps: [task-022]
round: 0
branch: null
pr: null
---

Implement an aggregate flow overlay that visualises which edges and nodes are traversed
most frequently across all flow paths, revealing hot paths and bottlenecks in the system.

Covers `specs/visualization/data-flow.spec.md` — Requirement: Aggregate Flow Patterns
(SHOULD):
- Compute edge and node participation counts: for each edge and node, count how many
  distinct flow paths pass through it.
- Map participation count to a visual weight:
  - Edges with higher counts are rendered with greater visual prominence (e.g. thicker
    lines, brighter colour, or a hot colour gradient from cool/blue → warm/red).
  - Nodes traversed by many paths are visually prominent (e.g. brighter emissive or
    larger scale indicator).
- Identify bottleneck points: nodes that appear in the `steps` of every flow path (or a
  configurable threshold fraction) are marked distinctly (e.g. a warning-colour halo or
  label suffix "— bottleneck").
- Toggle this overlay with a dedicated shortcut (e.g. `A` key); it is off by default.
- The aggregate overlay and the single-path highlight (task-022) are mutually exclusive:
  activating one deactivates the other.
- If `flow_paths` is empty the overlay toggle is a no-op (no crash, no visual change).
- Use only GDScript and Godot 4.6 API.
