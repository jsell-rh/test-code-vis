---
id: task-025
title: Independence queryable property — click-to-select and orthogonal highlight
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-020]
round: 0
branch: null
pr: null
pr_title: "feat(godot): click-to-select module reveals orthogonal complement with animated highlight"
pr_description: |
  ## What and Why

  Independence groups are already rendered with visible spatial gaps (task-020), but the
  scene is still passive: the user must manually compare group positions to understand
  what is orthogonal to what. This PR makes independence an actively queryable property —
  the user clicks a module and immediately sees everything that can change without
  affecting it (the orthogonal complement), highlighted and animated in.

  This converts a layout convention into a reasoning tool. The key question the prototype
  tests is whether spatial 3D representation produces architectural understanding. Click-
  to-select independence reveal is a direct test of that: the user should be able to ask
  "what is safe to change here?" and get an answer in one click.

  ## Spec Requirements Satisfied

  Implements `specs/visualization/orthogonal-independence.spec.md` §
  "Independence as Queryable Property":

  - **Scenario: Selecting a module shows its independent peers** — clicking module A
    highlights all modules in *other* independence groups within the same bounded context
    (the orthogonal complement). Modules in A's own group are visually distinguished as
    "co-dependent" (muted or unchanged). The state change animates smoothly.

  - **Scenario: Cross-context independence** — when module A (in context X) is selected,
    bounded contexts that have *no transitive dependency* on context X are highlighted as
    fully independent at the context level. The highlight animates outward from the
    selected module.

  ## Key Design Decisions

  - **Input**: uses Godot's collision-based mouse picking (Area3D or StaticBody3D on each
    node volume). The existing node volume meshes from task-010 already exist — this task
    adds collision shapes and an `input_event` handler.

  - **State machine**: the scene has two display modes — `DEFAULT` and
    `INDEPENDENCE_HIGHLIGHTED`. Clicking a module transitions to highlighted mode;
    clicking empty space or the same module returns to default. Only one module can be
    selected at a time.

  - **Independence data**: `independence_group` is already present on each node from
    task-005 (extractor) and task-020 (renderer). The selection handler reads this field
    to classify every other module in the same bounded context as either co-dependent
    (same group) or independent (different group).

  - **Cross-context**: cross-context independence requires checking the edge list for
    transitive dependencies on context X. A context Y is fully independent of X if no
    path in the directed graph leads from any module in Y to any module in X (or vice
    versa). This reachability check runs at selection time on the in-memory graph data
    already loaded by task-009.

  - **Visual encoding**: orthogonally independent modules/contexts get a distinct tint
    or emissive highlight. Co-dependent modules in the selected module's group get a
    muted/desaturated appearance. The selected module itself gets a selection outline or
    bright tint. All transitions use Godot tweens for smooth animation.

  - **No new extractor work**: all data required (independence_group, edges) is already
    present in the scene graph JSON from tasks 005 and 006.

  ## Files / Areas Affected

  - `godot/scripts/independence_controller.gd` (new) — manages selection state, computes
    orthogonal complements at runtime, coordinates highlight transitions.
  - `godot/scripts/node_renderer.gd` (modify) — adds collision shape, mouse input
    handler, and visual state methods (`set_highlight_state(state: String)`).
  - `godot/scripts/main.gd` (or scene manager) — wires node click signals to
    `independence_controller.gd`.
  - `godot/scenes/` — may require adding Area3D/CollisionShape3D to node volume scene.

  ## How to Verify

  1. Run the extractor on kartograph to produce `scene_graph.json`.
  2. Open the Godot project and load the scene.
  3. Click on any module node. Verify:
     - Modules in other independence groups within the same bounded context are highlighted
       (orthogonal complement).
     - Modules in the clicked module's own group appear co-dependent (muted or unchanged).
     - Bounded contexts with no transitive dependency on the clicked module's context gain
       a context-level highlight.
     - The highlight appears with a smooth animated transition (no instant pop).
  4. Click empty space. Verify all nodes return to default appearance with animation.
  5. Click a second module. Verify the highlight updates to reflect the new selection.

  ## Caveats and Follow-Up

  - The cross-context reachability check is a BFS/DFS on the in-memory edge list. For
    kartograph's scale this is fast enough at click time; a future optimisation could
    pre-compute reachability during scene load.
  - The "animate outward from selected module" direction for the cross-context highlight
    is a UX goal; a simple simultaneous fade-in is acceptable for the prototype if the
    outward propagation proves too complex to implement cleanly.
  - Hover-before-click affordance (cursor change on hover) is optional polish; the spec
    requires click-to-select but not hover preview.
---
