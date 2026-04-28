---
id: task-035
title: Godot — simulation mode: failure injection and cascade visualisation
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-034]
round: 0
branch: null
pr: null
---

Extend simulation mode (task-034) with failure injection: the user marks a component
as failed and the application traverses the dependency graph to reveal which other
components would be affected by the cascade. This implements the remaining Simulation
Mode scenario from `specs/core/understanding-modes.spec.md`.

Covers:
- When simulation mode is active (task-034), provide a secondary interaction: right-click
  (or a keyboard modifier + click) on a node to trigger "failure injection" for that node,
  distinct from the split-preview interaction.
- Failure injection behaviour:
  - The selected node's volume is rendered in a failure state (e.g., red X overlay or
    darkened volume with a "FAILED" label).
  - Traverse the dependency graph outward from the failed node: any node that has a
    direct or transitive dependency on the failed node is considered "at risk."
  - Highlight at-risk nodes with a visual severity gradient: direct dependents (distance 1)
    are bright red; indirect dependents (distance 2+) are progressively lighter shades,
    showing the cascade depth visually.
  - Nodes with no path to the failed component remain at their default appearance.
  - A floating annotation near the failed node shows: "Failure affects X components
    (Y direct, Z transitive)."
- Graph traversal must handle cycles in the dependency graph without infinite loops
  (use a visited set).
- Pressing Escape or clicking elsewhere cancels the failure injection preview and
  restores all nodes.
- Failure injection and split preview (task-034) are mutually exclusive within simulation
  mode — starting one cancels the other.
- The simulation does NOT persist state: no JSON modification, no file writes.
- Use GDScript and Godot 4.6 API only. No external libraries.

Scenario coverage:
- Central service failure: failing a high-centrality node turns most of the scene red,
  making the risk immediately visceral.
- Leaf node failure: failing a node with no dependents leaves all other nodes unchanged,
  confirming low blast radius.
- Failure of a node in a cycle: traversal terminates correctly without hanging.
