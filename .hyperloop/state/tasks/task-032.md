---
id: task-032
title: Godot — Simulation Mode
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-009, task-013]
round: 0
branch: null
pr: null
---

Implement Simulation Mode in the Godot application: an interactive overlay that lets
the human hypothetically remove or isolate a component and immediately see which other
components are affected, without modifying the underlying scene graph.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Simulation Mode,
scenarios: Splitting a service / Failure injection:

- Add a keyboard shortcut (e.g. `S`) that enters Simulation Mode; `Escape` exits it.
- On entering Simulation Mode, add a HUD label ("SIMULATION MODE — click a node to
  simulate failure") and dim all nodes to a low-opacity neutral state.
- **Failure injection**: when the human clicks a node while in Simulation Mode:
  - Mark the selected node as "failed" — render it with a distinct red X overlay
    (e.g. a crossed MeshInstance3D or an emissive red material).
  - Walk all edges in the scene graph to find nodes that depend on the failed node
    (i.e. have an edge whose `target` is the failed node's id).
  - Highlight all directly dependent nodes in a warning colour (e.g. amber) with a
    floating "AFFECTED" label above each.
  - Highlight nodes that are transitively dependent (second-order: depend on an affected
    node) in a lighter warning colour with a "DOWNSTREAM" label.
  - Nodes with no dependency on the failed node remain dimmed but receive no label.
- The human may click additional nodes to simulate multi-component failures; each
  additional selected node adds its direct and transitive dependents to the affected set.
- A "Reset simulation" button in the HUD (or pressing `R`) clears all failure markers
  and returns to the dimmed Simulation Mode entry state, ready for a new selection.
- Pressing `Escape` exits Simulation Mode entirely and restores all nodes and edges to
  their base structural appearance.
- No changes to the loaded scene graph data: all simulation state is ephemeral and lives
  only in Godot node metadata.
- Use only GDScript and Godot 4.6 API.
