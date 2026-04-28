---
id: task-033
title: Godot — Simulation Mode: split-service action
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-032]
round: 0
branch: null
pr: null
---

Extend Simulation Mode (task-032) to support a "split service" action — the human
selects a node and simulates dividing it into two parts to see which neighbouring
services would need to be reconnected, and what new inter-service interfaces would
be required.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Simulation Mode,
Scenario: Splitting a service:

- The split action is only available while already inside Simulation Mode (task-032).
- **Entering split-planning for a node**: while in Simulation Mode, the human
  right-clicks a node (or presses `X` with a node focused) to enter split-planning
  state for that node.
- **Visual representation of the split**:
  - Render the selected node as two overlapping translucent half-volumes (e.g. two
    side-by-side boxes inside the original node boundary) to indicate the conceptual
    division into Half-A and Half-B.
  - Label the two halves with `[node name] / A` and `[node name] / B`.
- **Neighbour analysis** — walk all edges in the loaded scene graph:
  - Nodes that have an **inbound** edge from the target (i.e. they depend on the
    target) receive a floating `"RECONNECT → ?"` label: after the split, they must
    decide which half to depend on.
  - Nodes that have an **outbound** edge to the target (i.e. the target depends on
    them) receive a floating `"WILL SERVE → ?"` label: they must be told which half
    to serve.
  - Nodes that have **both** inbound and outbound edges to/from the target receive
    both labels plus a `"BIDIRECTIONAL"` annotation flagging potential circular
    dependency risk after the split.
- **HUD summary**: display a banner while split-planning is active:
  `"Splitting [node name] — [N] services must reconnect"` where N is the count of
  distinct neighbouring nodes.
- **Exiting split-planning**:
  - Pressing `R` clears split-planning state and returns to the Simulation Mode
    entry state (as defined in task-032), ready for a new action.
  - Pressing `Escape` exits Simulation Mode entirely (delegated to task-032 logic)
    and restores all base structural appearance.
- Only one node may be in split-planning state at a time; starting a split on a
  second node implicitly cancels the first.
- The action is non-destructive: all split-planning state is ephemeral Godot node
  metadata and does not modify the loaded scene graph.
- Use only GDScript and Godot 4.6 API.
