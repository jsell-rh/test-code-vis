---
id: task-021
title: Independence queryable property — selection and orthogonal highlight
spec_ref: null
status: closed
phase: null
deps: [task-020]
round: 0
branch: null
pr: null
pr_title: "feat(godot): highlight orthogonal complement on module selection"
pr_description: |
  ## What and Why

  Making independence queryable transforms a passive visual layout into an active
  reasoning tool: the user clicks a module and immediately sees everything that is
  structurally independent from it — the safe change boundary. Without this interaction,
  independence groups are visible but require manual comparison. This PR adds click-
  to-select on module nodes and a two-state highlight: "co-dependent" (same group, muted
  or unchanged) and "orthogonally independent" (different group, visually highlighted).

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:

  - **Independence as Queryable Property**: selecting a module shows all modules in
    other independence groups highlighted; modules in the same group are visually
    distinguished as "co-dependent"; transitions are animated smoothly.
  - **Cross-context independence**: selecting a module also highlights bounded contexts
    with no transitive dependency on the selected module's context; highlight animates
    outward from the selected module.

  ## Key Design Decisions

  - Add an `input_event` handler on each node volume (Area3D or StaticBody3D) to detect
    left-click. Only one node can be "selected" at a time; clicking a selected node
    deselects it and restores default rendering.
  - On selection of node A: iterate all nodes in the same parent bounded context; those
    with a different `independence_group` get an "independent" material overlay (e.g.
    bright emissive tint); those in the same group get a "co-dependent" overlay (e.g.
    desaturated tint). Unselected-group contexts at the global level get a lighter tint
    if they have no transitive dependency on A's context.
  - Transitions use a `Tween` on the material's `emission_energy` or `albedo_color`
    property; duration ≈ 200 ms.
  - The highlight state must be reversible: clicking elsewhere or pressing Escape clears
    all overlays and restores original materials with the same Tween duration.
  - Do NOT implement persistent selection state across scene reloads — the prototype does
    not need that complexity.

  ## Files Affected

  - `godot/scenes/NodeVolume.gd` — add `input_event` handler, `select()` / `deselect()`
    methods, material state management
  - `godot/scenes/SelectionManager.gd` (new) — singleton that tracks the currently
    selected node, dispatches highlight commands to all nodes, manages Tween lifecycle
  - `godot/tests/test_selection.gd` — GUT tests: selecting node A causes nodes in
    different groups to transition to "independent" material; nodes in A's group
    transition to "co-dependent" material; deselecting restores all materials; cross-
    context highlight fires for contexts with no dependency on A's context

  ## Verification

  1. GUT tests pass.
  2. Load kartograph scene: click a module → independent peers highlight with animated
     tint; same-group peers dim; click again or press Escape → all restore to normal.
  3. At the bounded-context level (zoomed out), contexts independent of the selected
     module's context also highlight.

  ## Caveats

  Click detection in Godot 4 requires either `Area3D` with collision shape enabled on
  node volumes or `_gui_input` on Control nodes. The implementer should choose the
  approach that is consistent with how node volumes are constructed in task-010 and
  task-011. If node volumes do not yet have collision shapes, they must be added as part
  of this task.
---
