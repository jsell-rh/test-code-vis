---
id: task-024
title: Independence queryable property — module selection and orthogonal complement highlight
spec_ref: null
status: closed
phase: null
deps: [task-020]
round: 0
branch: null
pr: null
pr_title: "feat(godot): module selection highlights orthogonal complement with animated tint"
pr_description: |
  ## What and Why

  Independence groups are visible in the spatial layout (task-020) but require manual
  comparison to identify safe change boundaries. Making independence *queryable* turns a
  passive visual layout into an active reasoning tool: the user clicks a module and
  immediately sees everything structurally independent of it (safe to change without
  affecting it) and everything co-dependent with it (the blast radius). This PR adds
  click-to-select on module volumes and a two-state highlight — "co-dependent" (same
  independence group, muted) vs "orthogonally independent" (different group, emissive
  tint) — with animated transitions. Cross-context independence is surfaced as a
  second-level signal at bounded-context granularity.

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:

  - **Independence as Queryable Property — Selecting a module shows its independent
    peers**: selecting module A highlights all modules in other independence groups within
    the same bounded context; modules in A's own group are visually distinguished as
    "co-dependent"; the transition between default and highlighted states is animated
    smoothly.
  - **Independence as Queryable Property — Cross-context independence**: selecting module
    A in context X causes bounded contexts with no transitive dependency on context X to
    be highlighted as "fully independent"; the highlight animates outward from the
    selected module.

  ## Key Design Decisions

  - Each `NodeVolume` gains a `StaticBody3D` + `CollisionShape3D` and an `input_event`
    signal handler so it responds to left-click. If task-010 / task-011 already added
    collision shapes for picking, reuse them; otherwise add them here.
  - A `SelectionManager` autoload singleton owns all selection state:
    - On `select(node_a)`: iterate all module nodes in the same parent bounded context as
      A; apply "co_dependent" state to nodes sharing A's `independence_group`, "independent"
      state to nodes in other groups. At the context level, apply a lighter "independent"
      tint to bounded contexts with no transitive dependency on A's context. Deselect any
      previously selected node first.
    - On `deselect()`: restore all nodes to "default" state.
    - Pressing Escape calls `deselect()`.
  - Material transition states per node: `"default"`, `"selected"`, `"co_dependent"`,
    `"independent"`. Implemented as a `Tween` on `StandardMaterial3D.emission_energy` or
    `albedo_color.a`; duration ≈ 200 ms. A new Tween cancels any in-progress Tween on
    the same node.
  - Independence group data is read directly from the in-memory scene graph (`independence_group`
    field per node, already set by task-005 extractor and loaded by task-009 loader).
  - Transitive context reachability: on scene load, `SelectionManager` performs a BFS over
    cross-context edges (type `"cross_context"` and `"aggregate"`) to build a reachability
    set per bounded context. Contexts NOT reachable from A's context are "fully independent"
    and receive the cross-context highlight.
  - Only one module can be selected at a time. Clicking a second module deselects the
    first. Clicking a selected module deselects it.

  ## Files Affected

  - `godot/scenes/NodeVolume.gd` — add collision shape (if absent), `input_event` handler
    that calls `SelectionManager.select(self)`, and
    `set_highlight_state(state: String, duration: float)` method (states: "default",
    "selected", "co_dependent", "independent") that tweens the material overlay.
  - `godot/autoload/SelectionManager.gd` (new) — autoload singleton: tracks selected node,
    dispatches `set_highlight_state` calls to all nodes, precomputes transitive context
    reachability on `_ready()`, handles Escape key input.
  - `godot/scenes/SceneRoot.gd` — wire Escape action to `SelectionManager.deselect()` if
    not already handled by SelectionManager's own `_input()`.
  - `godot/project.godot` — register `SelectionManager` as an autoload.
  - `godot/tests/test_selection.gd` (new) — GUT tests:
    - Selecting node A assigns "independent" state to nodes in different groups and
      "co_dependent" state to nodes in A's group within the same context.
    - Pressing Escape restores all nodes to "default" state.
    - Selecting node B while A is selected first deselects A (all nodes restored) then
      applies B's highlight states.
    - Cross-context highlight: contexts with no transitive dep on A's context receive
      "independent" state on their bounded-context volume.
    - All state changes use a Tween (not instant assignment).

  ## Verification

  1. GUT tests pass.
  2. Load kartograph scene: click a module volume → peers in different independence groups
     animate to an emissive tint; peers in the same group dim slightly; the selected
     module is visually distinct from both. Click the same module again or press Escape
     → all volumes animate back to their default appearance.
  3. While a module is selected, zoom out to the context level: bounded contexts with no
     transitive dependency on the selected module's context are highlighted.
  4. All transitions are animated — no instant colour snaps at any point.
  5. Select module A in context IAM; then select module B in context graph without pressing
     Escape first — IAM modules return to default before graph modules are highlighted.

  ## Caveats

  Collision shapes added here must be consistent with those used in task-023 (cluster
  collapse affordance click detection). If both tasks land in the same sprint, coordinate
  so collision shapes are added once and shared, not duplicated. The `NodeVolume`
  `set_highlight_state` method should be composable: if a node is also cluster-tinted
  (task-023 suggestion tint), the independence overlay should layer on top rather than
  replace it. A simple approach is to drive independence overlay via the
  `emission_energy` parameter while cluster suggestions use `albedo_color` modulation,
  keeping the two axes orthogonal.
---
