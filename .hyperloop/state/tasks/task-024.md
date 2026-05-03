---
id: task-024
title: Independence queryable property — module selection and orthogonal complement
  highlight
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: not_started
phase: null
deps:
- task-020
round: 0
branch: null
pr: null
pr_title: 'feat(godot): module selection highlights orthogonal complement with animated
  tint'
pr_description: "## What and Why\n\nIndependence groups are visible in the spatial\
  \ layout (task-020) but require manual\ncomparison to identify safe change boundaries.\
  \ Making independence *queryable* turns a\npassive visual layout into an active\
  \ reasoning tool: the user clicks a module and\nimmediately sees everything structurally\
  \ independent of it (safe to change without\naffecting it) and everything co-dependent\
  \ with it (the blast radius). This PR adds\nclick-to-select on module volumes and\
  \ a two-state highlight — \"co-dependent\" (same\nindependence group, muted) vs\
  \ \"orthogonally independent\" (different group, emissive\ntint) — with animated\
  \ transitions. Cross-context independence is surfaced as a\nsecond-level signal\
  \ at bounded-context granularity.\n\n## Spec Requirements Satisfied\n\nFrom `specs/visualization/orthogonal-independence.spec.md`:\n\
  \n- **Independence as Queryable Property — Selecting a module shows its independent\n\
  \  peers**: selecting module A highlights all modules in other independence groups\
  \ within\n  the same bounded context; modules in A's own group are visually distinguished\
  \ as\n  \"co-dependent\"; the transition between default and highlighted states\
  \ is animated\n  smoothly.\n- **Independence as Queryable Property — Cross-context\
  \ independence**: selecting module\n  A in context X causes bounded contexts with\
  \ no transitive dependency on context X to\n  be highlighted as \"fully independent\"\
  ; the highlight animates outward from the\n  selected module.\n\n## Key Design Decisions\n\
  \n- Each `NodeVolume` gains a `StaticBody3D` + `CollisionShape3D` and an `input_event`\n\
  \  signal handler so it responds to left-click. If task-010 / task-011 already added\n\
  \  collision shapes for picking, reuse them; otherwise add them here.\n- A `SelectionManager`\
  \ autoload singleton owns all selection state:\n  - On `select(node_a)`: iterate\
  \ all module nodes in the same parent bounded context as\n    A; apply \"co_dependent\"\
  \ state to nodes sharing A's `independence_group`, \"independent\"\n    state to\
  \ nodes in other groups. At the context level, apply a lighter \"independent\"\n\
  \    tint to bounded contexts with no transitive dependency on A's context. Deselect\
  \ any\n    previously selected node first.\n  - On `deselect()`: restore all nodes\
  \ to \"default\" state.\n  - Pressing Escape calls `deselect()`.\n- Material transition\
  \ states per node: `\"default\"`, `\"selected\"`, `\"co_dependent\"`,\n  `\"independent\"\
  `. Implemented as a `Tween` on `StandardMaterial3D.emission_energy` or\n  `albedo_color.a`;\
  \ duration ≈ 200 ms. A new Tween cancels any in-progress Tween on\n  the same node.\n\
  - Independence group data is read directly from the in-memory scene graph (`independence_group`\n\
  \  field per node, already set by task-005 extractor and loaded by task-009 loader).\n\
  - Transitive context reachability: on scene load, `SelectionManager` performs a\
  \ BFS over\n  cross-context edges (type `\"cross_context\"` and `\"aggregate\"`)\
  \ to build a reachability\n  set per bounded context. Contexts NOT reachable from\
  \ A's context are \"fully independent\"\n  and receive the cross-context highlight.\n\
  - Only one module can be selected at a time. Clicking a second module deselects\
  \ the\n  first. Clicking a selected module deselects it.\n\n## Files Affected\n\n\
  - `godot/scenes/NodeVolume.gd` — add collision shape (if absent), `input_event`\
  \ handler\n  that calls `SelectionManager.select(self)`, and\n  `set_highlight_state(state:\
  \ String, duration: float)` method (states: \"default\",\n  \"selected\", \"co_dependent\"\
  , \"independent\") that tweens the material overlay.\n- `godot/autoload/SelectionManager.gd`\
  \ (new) — autoload singleton: tracks selected node,\n  dispatches `set_highlight_state`\
  \ calls to all nodes, precomputes transitive context\n  reachability on `_ready()`,\
  \ handles Escape key input.\n- `godot/scenes/SceneRoot.gd` — wire Escape action\
  \ to `SelectionManager.deselect()` if\n  not already handled by SelectionManager's\
  \ own `_input()`.\n- `godot/project.godot` — register `SelectionManager` as an autoload.\n\
  - `godot/tests/test_selection.gd` (new) — GUT tests:\n  - Selecting node A assigns\
  \ \"independent\" state to nodes in different groups and\n    \"co_dependent\" state\
  \ to nodes in A's group within the same context.\n  - Pressing Escape restores all\
  \ nodes to \"default\" state.\n  - Selecting node B while A is selected first deselects\
  \ A (all nodes restored) then\n    applies B's highlight states.\n  - Cross-context\
  \ highlight: contexts with no transitive dep on A's context receive\n    \"independent\"\
  \ state on their bounded-context volume.\n  - All state changes use a Tween (not\
  \ instant assignment).\n\n## Verification\n\n1. GUT tests pass.\n2. Load kartograph\
  \ scene: click a module volume → peers in different independence groups\n   animate\
  \ to an emissive tint; peers in the same group dim slightly; the selected\n   module\
  \ is visually distinct from both. Click the same module again or press Escape\n\
  \   → all volumes animate back to their default appearance.\n3. While a module is\
  \ selected, zoom out to the context level: bounded contexts with no\n   transitive\
  \ dependency on the selected module's context are highlighted.\n4. All transitions\
  \ are animated — no instant colour snaps at any point.\n5. Select module A in context\
  \ IAM; then select module B in context graph without pressing\n   Escape first —\
  \ IAM modules return to default before graph modules are highlighted.\n\n## Caveats\n\
  \nCollision shapes added here must be consistent with those used in task-023 (cluster\n\
  collapse affordance click detection). If both tasks land in the same sprint, coordinate\n\
  so collision shapes are added once and shared, not duplicated. The `NodeVolume`\n\
  `set_highlight_state` method should be composable: if a node is also cluster-tinted\n\
  (task-023 suggestion tint), the independence overlay should layer on top rather\
  \ than\nreplace it. A simple approach is to drive independence overlay via the\n\
  `emission_energy` parameter while cluster suggestions use `albedo_color` modulation,\n\
  keeping the two axes orthogonal."
---
