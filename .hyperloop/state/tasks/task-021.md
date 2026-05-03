---
id: task-021
title: Independence queryable UI — select module, highlight orthogonal peers
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-020]
round: 0
branch: null
pr: null
pr_title: "feat(godot): select a module to highlight its orthogonal complement and co-dependents"
pr_description: |
  ## What and Why

  Independence becomes actionable when the user can point to a module and immediately see
  what it is independent *from*. This is the "safe change boundary" use case: click a
  module, see which modules you can safely modify in parallel without coordination.
  The highlight must animate in to reinforce the spatial reading (highlighting propagates
  outward from the selected module, not all at once).

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:

  - **Independence as Queryable Property — Selecting a module shows its independent peers**:
    all modules in *other* independence groups highlighted; modules in the selected
    module's own group visually distinguished as "co-dependent"; animated transition
  - **Cross-context independence**: selected module → bounded contexts with no transitive
    dependency on the module's context are highlighted as fully independent; highlight
    animates outward from selected module

  ## Key Design Decisions

  - Selection: user clicks a `NodeRenderer` volume. Use Godot 4's `Area3D` + collision
    shape on each `NodeRenderer`, and a ray cast from `CameraController` on
    `InputEventMouseButton` LEFT click (no-drag, i.e. mouse up without motion since LMB
    press).
  - On selection, `SelectionController` (new autoload) reads the clicked node's
    `independence_group` and categorises all other visible nodes as:
    - "co-dependent": same group → dimmed (alpha reduced, own colour retained)
    - "independent-peer": different group, same context → highlighted (bright outline or
      emissive glow)
    - "context-independent": different context with no transitive dep on selected context →
      highlighted at context level
    - "context-dependent": different context with a transitive dep → dimmed
  - Animation: emit `Tween` per node, staggered by distance from selected node
    (closer nodes animate first, giving an "outward pulse" effect). Duration ~0.4s total.
  - Clicking empty space or clicking the same node again resets all highlights to default.
  - Context-level independence is computed at runtime from the edge data
    (`SceneGraphLoader.edges()`) — no pre-computation needed for the prototype.

  ## Files Affected

  - `godot/autoload/SelectionController.gd` — new: manages selection state and highlight
    categorisation
  - `godot/scenes/NodeRenderer.gd` — updated: `Area3D` + `CollisionShape3D` added for
    click detection; methods `highlight_independent()`, `dim_codependent()`, `reset()`
  - `godot/scenes/CameraController.gd` — updated: ray cast on LMB click (no-drag)
    forwarded to `SelectionController`
  - `godot/tests/test_selection.gd` — GUT tests: selecting a node triggers correct
    highlight/dim categorisation; click on empty space resets; animation uses Tween

  ## Verification

  1. GUT tests pass.
  2. In the running app: click on `iam.domain` → modules in other independence groups
    within IAM glow; `iam.domain`'s own group dims slightly.
  3. Highlight animates outward from clicked module.
  4. Click empty space → all modules return to default colour.

  ## Caveats

  Runtime transitive dependency computation for cross-context independence can be slow
  on large graphs. For the prototype (kartograph's ~6 bounded contexts), a simple BFS on
  the edge list is fast enough. Cache the result per selected context to avoid re-computing
  on every click within the same context.
---
