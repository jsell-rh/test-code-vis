---
id: task-034
title: Godot — simulation mode: service split what-if exploration
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-008, task-027]
round: 0
branch: null
pr: null
---

Implement the first half of simulation mode in the Godot application: hypothetical
service split exploration. The user selects any node and simulates splitting it into
two independent components, immediately seeing which dependents would be affected and
what new interfaces would be needed. This is non-destructive — the loaded scene graph
is not modified. This implements part of the Simulation Mode requirement from
`specs/core/understanding-modes.spec.md`.

Covers:
- Add a simulation mode toggle (e.g., keyboard shortcut `S` or a UI button). When
  active, left-clicking a node enters "split preview" for that node.
- Split preview behaviour:
  - The selected node's volume is rendered with a dashed or split visual (e.g., two
    halves of the volume separated slightly) to indicate it is being considered for
    splitting.
  - All nodes that have an edge pointing TO the selected node (afferent dependencies)
    are highlighted in amber — they would need to be updated to know which of the two
    new components to talk to.
  - All nodes that the selected node points TO (efferent dependencies) are highlighted
    in blue — they become dependencies of one or both of the two new components.
  - A floating annotation near the selected node lists the count: "X callers, Y
    dependencies — split requires X interface updates."
- Clicking elsewhere or pressing Escape cancels the split preview and returns all
  nodes to their normal appearance.
- Simulation mode is mutually exclusive with conformance mode (task-030) and evaluation
  mode (task-033) — activating one deactivates the others.
- The simulation does NOT persist state: no JSON modification, no file writes.
- Use GDScript and Godot 4.6 API only. No external libraries.

Scenario coverage:
- Monolithic service split: selecting a large bounded context highlights all cross-context
  dependents as amber and all outbound dependencies as blue.
- Already-isolated service: selecting a node with zero afferent edges shows zero
  callers and confirms the split is low-impact.
