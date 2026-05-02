---
id: task-016
title: Implement spatial separation of independent groups
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-005, task-012]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render spatial separation of independent module groups"
pr_description: |
  ## What and Why

  Within each bounded context, modules that are structurally independent (no
  shared transitive dependencies) must occupy visually distinct spatial regions
  separated by a visible gap. The independence_group field on each node (produced
  by task-005) is the data source. The layout algorithm (task-008) positions nodes
  so independent groups are already spatially separated in world coordinates. This
  task makes that separation visually prominent in the Godot renderer so the user
  can see safe change boundaries without any interaction.

  The cognitive value is: a human looking at a bounded context can immediately see
  "this half and that half don't talk to each other — I can change one without
  touching the other."

  ## Spec Requirements Satisfied

  `specs/visualization/orthogonal-independence.spec.md` — Requirement: Spatial
  Separation of Independent Groups

  - Groups within a context occupy distinct spatial regions.
  - A visible gap separates the groups.
  - Modules within each group remain close to each other (coupling-aware layout
    from task-008 applies within groups).
  - When a new scene graph is loaded with different independence groups, nodes
    animate smoothly to their new positions (slide, not jump).

  ## Key Design Decisions

  - The layout algorithm (task-008) pre-computes positions with inter-group spacing
    factored in. This task does not recompute layout — it reads `position` values
    from the JSON and renders accordingly.
  - Visual gap reinforcement: a subtle translucent separator plane (a flat thin
    `CSGBox3D` with low opacity) is placed between independence groups within a
    context volume. This makes the gap explicit even when module boxes happen to
    be close to the boundary.
  - Separator plane is positioned at the midpoint between the two group centroids,
    perpendicular to the axis of greatest separation.
  - On scene graph reload: nodes tween from their current positions to new positions
    over 0.6s using a `Tween`. Separator planes also move to the new midpoint.
  - If all modules in a context are in a single group (no independence), no
    separator plane is instantiated.

  ## Files / Areas Affected

  - `godot/scripts/independence_renderer.gd` — new script that reads
    `independence_group` fields from loaded nodes, groups Container nodes, and
    instantiates separator planes
  - `godot/scenes/separator_plane.tscn` — thin translucent CSGBox or MeshInstance
    used as the visual gap marker
  - `godot/scripts/main.gd` — calls `independence_renderer.render_separators()`
    after `container_renderer.render_all()`
  - `godot/tests/test_independence_renderer.gd` — tests covering:
    - context with two groups has exactly one separator plane
    - context with one group has no separator plane
    - separator plane is between the two group centroids
    - node tween fires on second load call with different positions

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`.
  2. Launch Godot; zoom into a bounded context that has multiple independence
     groups (confirmed by `independence_group` fields in the JSON).
  3. Confirm a visual gap (and optional separator plane) exists between the groups.
  4. Modules within the same group should be noticeably closer to each other than
     to modules in another group.

  ## Caveats / Follow-up

  The "Independence as Queryable Property" feature (click a module to highlight its
  orthogonal complement) is NOT implemented in this task — it is deferred to a
  future phase as it requires interactive selection and is not referenced in
  `prototype-scope.spec.md`. The separator plane is a placeholder visual; the final
  design may use a gap without an explicit plane.
---
