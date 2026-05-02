---
id: task-022
title: Implement independence queryable property (click-to-highlight independent peers)
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-005, task-011, task-016]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement independence queryable property with animated highlight"
pr_description: |
  ## What and Why

  Task-016 makes independence visible passively — independent groups occupy distinct
  spatial regions within a bounded context. But the human still needs to interact to
  understand which modules are independent of a specific module they care about.

  This task adds an interactive query: when the human clicks/selects a module node,
  the renderer highlights all modules in OTHER independence groups within the same
  bounded context (the orthogonal complement — things that can change without
  affecting the selected module). Modules in the selected module's own group are
  distinctly styled as "co-dependent." Unrelated contexts remain in a neutral state.
  A second click on the same node (or click on empty space) returns to the default
  view, with smooth animated transitions throughout.

  This implements the "Independence as Queryable Property" requirement from the
  orthogonal independence spec — the passive spatial layout (task-016) shows WHERE
  the groups are; this task answers "what is independent of THIS thing I selected?"

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md` § Independence as
  Queryable Property:

  - Human selects module A → all modules in OTHER independence groups within A's
    bounded context are highlighted as "independent peers."
  - Modules in A's own group are visually distinguished as "co-dependent."
  - Transition between default and independence-highlighted states is animated smoothly.
  - Cross-context independence: selecting module A in context X → bounded contexts
    with no transitive dependency on context X are highlighted as fully independent.
  - The highlight animates in from the selected module outward.

  ## Key Design Decisions

  - **Input**: Left-click on a Container or Node mesh in 3D space, detected via
    Godot's `PhysicsDirectSpaceState3D.intersect_ray` or Area3D input events.
  - **Independence data source**: The `independence_group` field on each node
    (produced by task-005, serialized in task-006, loaded by task-011) is the sole
    data source. No additional computation is needed at query time.
  - **Highlight modes**:
    - `selected`: The clicked module — shown with a bright outline or rim-light effect.
    - `co_dependent`: Modules in the same `independence_group` — desaturated/dimmed
      slightly (they change together with the selected module).
    - `independent_peer`: Modules in OTHER groups in the same context — highlighted
      with a distinct accent color (e.g. a green tint overlay) — these are the safe
      change zone.
    - `neutral`: Modules in other contexts — unaffected, at their normal appearance.
  - **Cross-context query**: Uses the context-level edges in the scene graph. Contexts
    with no path (direct or transitive) to context X are highlighted as independent
    at the context volume level (a subtle outer glow or tint shift on the context
    Container).
  - **Animation**: Use Godot Tweens to animate the material property change (emission,
    albedo multiplier, or modulate) over 0.25 s. The animation fans out from the
    selected node: the selected node highlights first, then co-dependent nodes
    (within 0.05 s), then independent peers (within 0.15 s), mirroring the spec's
    "animates in from the selected module outward."
  - **Deselect**: Clicking the same node again or clicking empty space returns all
    nodes to neutral state via a 0.25 s reverse tween.

  ## Files / Areas Affected

  - `godot/` — new `independence_query.gd`: stateless helper that, given a node_id
    and the full nodes list, returns `{ node_id: "selected"|"co_dependent"|
    "independent_peer"|"neutral" }` for all nodes in the same context.
  - `godot/` — new `cross_context_independence.gd`: computes which bounded contexts
    are transitively independent of a selected context using BFS on context-level edges.
  - `godot/` — input handling in the main scene or camera controller: detects
    3D click via raycast, maps hit to node_id, calls `independence_query.gd`.
  - `godot/` — Container/Node visual state machine: adds "highlighted_independent",
    "highlighted_codependent", and "selected" visual states with tween transitions.
  - No changes to `extractor/` or scene graph JSON format.

  ## How to Verify

  1. Run the extractor on kartograph, launch the Godot application.
  2. Zoom into a bounded context that has at least 2 independence groups (confirmed
     present in kartograph from task-005 output).
  3. Click on a module node in group A:
     - The clicked node shows a bright selection effect.
     - Modules in the same group dim slightly (co-dependent).
     - Modules in other groups within the same context receive the green accent
       (independent peers).
     - Modules in other contexts remain unchanged.
  4. Observe the animation: highlight fans out from the clicked node in ~0.25 s.
  5. Click empty space — all nodes animate back to neutral in ~0.25 s.
  6. At the context overview zoom tier, click a bounded context volume:
     - Contexts with no transitive dependency on the selected context receive a
       subtle glow/tint indicating full independence.
  7. Run `godot-tests.sh` — all existing tests pass.
  8. Run `check-assigned-spec-in-scope.sh specs/visualization/orthogonal-independence.spec.md`
     — exits 0.

  ## Caveats and Follow-up

  - Cross-context transitive reachability (BFS over context-level edges) is O(V+E)
    on the context graph. For kartograph this is trivially fast (<10 contexts).
  - The click interaction is from the top-down camera perspective only; walk-through
    exploration is deferred to a future phase and is not part of this task.
  - If no independence groups exist in the loaded scene graph (all modules in one
    group), clicking produces no highlight and logs an info message.
---

## Task

Add interactive independence querying to the Godot application: clicking a module
node highlights its orthogonal complement (modules that can change without affecting
it) and distinguishes co-dependent modules, with smooth animated transitions.

### Acceptance Criteria

1. Clicking a module node in the 3D scene selects it and triggers the independence
   highlight: independent peers are distinctly accented, co-dependent modules are
   subtly dimmed, and the selected node has a bright rim/outline.
2. The highlight animates outward from the selected node over ≤ 0.3 s.
3. Clicking empty space or clicking the same node deselects, returning all nodes
   to neutral state over ≤ 0.3 s.
4. At the context overview zoom level, clicking a bounded context volume highlights
   fully independent contexts (no transitive dependency on the selected context).
5. All existing rendering tests (Container, Edge, LOD, spatial separation) pass.
6. The `independence_group` field from the scene graph is the sole data source for
   intra-context grouping — no additional extractor computation is needed.

### Implementation Notes

- Depends on task-005 (independence groups emitted to scene graph by extractor),
  task-011 (scene graph loader populates node `independence_group` field in Godot),
  and task-016 (spatial separation rendering — nodes are already grouped spatially,
  so the query adds interaction on top of the existing visual layout).
- `IndependenceQuery.gd` is a pure function module (no Node, just a GDScript class
  or static functions): `query(selected_id: String, nodes: Array) -> Dictionary`.
- Raycast input: use `get_world_3d().direct_space_state.intersect_ray(...)` from the
  camera's `_unhandled_input` or a dedicated InputManager node.
- Keep visual state machine simple: a ShaderMaterial uniform or
  `BaseMaterial3D.albedo_color` multiplier toggled via Tween.
