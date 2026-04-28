---
id: task-033
title: Godot — evaluation view (coupling and centrality visualisation)
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-031, task-032, task-008, task-027]
round: 0
branch: null
pr: null
---

Implement an evaluation view mode in the Godot application that makes architectural
quality visible independently of spec compliance. Tight coupling and structural
criticality must be immediately apparent without reading labels or numbers. This
implements the Evaluation Mode requirement from `specs/core/understanding-modes.spec.md`.

Covers:
- Add a toggleable evaluation mode (e.g., keyboard shortcut `E` or a UI button) that
  activates/deactivates the quality overlay without reloading the scene.
- When evaluation mode is active:
  - Coupling visualisation: colour-code node volumes by instability score. Use a
    diverging colour ramp — e.g., blue (stable, instability ≈ 0) through white
    (neutral) to red (unstable, instability ≈ 1.0). Render the colour as a material
    override on the volume mesh.
  - Centrality visualisation: scale the node's emissive glow or border thickness
    proportionally to its `centrality` score. Nodes with centrality above a threshold
    (e.g., top 10% of the graph) receive an additional pulsing or highlighted outline
    to flag them as single-point-of-failure candidates.
  - Dependency edges are rendered with thickness or opacity proportional to the
    combined coupling between the two connected nodes.
  - A small HUD legend is shown (top-left corner) identifying the colour ramp and the
    centrality indicator while evaluation mode is active.
- When evaluation mode is inactive, volumes and edges return to their default
  appearance (colours, sizes, opacities from the base prototype).
- Evaluation mode and conformance mode (task-030) MUST be mutually exclusive — activating
  one deactivates the other.
- Use GDScript and Godot 4.6 API only. No external libraries.

Scenario coverage:
- Two heavily interdependent services: their volumes both appear deep red and their
  connecting edge appears thick/opaque.
- One central service depended on by all others: its volume shows the centrality
  highlight; its instability score is near 0 (stable — many depend on it).
- Spec-faithful-but-poor design: quality problems are visible even if all nodes carry
  spec_refs.
