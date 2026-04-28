---
id: task-031
title: Godot — Evaluation Mode
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-009, task-013]
round: 0
branch: null
pr: null
---

Implement Evaluation Mode in the Godot application: a toggleable view that surfaces
architectural quality signals — coupling intensity and component centrality — derived
from the realized codebase structure, independent of any spec.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Evaluation Mode:

- Add a keyboard shortcut (e.g. `E`) that toggles Evaluation Mode on and off.
- When Evaluation Mode is off, the scene looks and behaves as in the base structural view.
- When Evaluation Mode is on:
  - **Coupling signals on edges**: compute the number of edges between each pair of
    nodes. Re-colour and thicken each edge proportionally to the edge count between its
    endpoints (more edges = thicker, more saturated red line). A single edge between two
    nodes is rendered at baseline thickness; the maximum observed coupling drives the
    upper bound.
  - **Centrality signals on nodes**: compute the in-degree + out-degree for every node
    using the loaded edge list. Re-colour each node volume from a neutral hue through to
    a warning hue (e.g. white → orange → red) proportional to its normalised degree
    centrality. The node with the highest degree is rendered at full warning intensity.
  - A node that is both highly connected and connected to many distinct partners (high
    betweenness proxy: sum of neighbour degrees) should be annotated with a floating
    "CRITICAL" label rendered as a `Label3D` above the node.
  - Add a HUD legend in the corner explaining the colour scale while Evaluation Mode is
    active.
- Toggling off Evaluation Mode resets all materials and labels to base structural appearance.
- Metric computation must be done at mode-toggle time from the already-loaded scene data;
  no re-parsing or file I/O after initial load.
- Use only GDScript and Godot 4.6 API.
