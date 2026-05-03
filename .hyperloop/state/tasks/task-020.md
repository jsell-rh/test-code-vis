---
id: task-020
title: Independence group spatial separation in Godot renderer
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-005, task-009, task-010]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render independence groups with visible spatial gaps"
pr_description: |
  ## What and Why

  Independence is a first-class structural concept: knowing that two groups of modules
  cannot affect each other is just as important as knowing how they are connected. The
  extractor (task-005) already annotates each node with an `independence_group` identifier
  and the layout algorithm (task-004) positions nodes so coupled nodes cluster together.
  However, the visual gap between independent groups must be rendered explicitly so users
  can perceive independence at a glance — without having to query the data.

  This task makes the Godot renderer honour the `independence_group` field: modules in
  different groups are visually separated by a spatial gap within their parent bounded
  context volume.

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:

  - **Spatial Separation of Independent Groups**: groups occupy distinct spatial regions
    within the context volume; a visible gap separates the groups; modules within each
    group remain close to each other (coupling-aware layout still applies within groups).

  ## Key Design Decisions

  - The extractor's layout (task-004) already encodes group separation in the `position`
    fields of nodes; the `independence_group` field is the authoritative tag.
  - In the Godot scene loader (task-009), after placing all nodes, group sibling nodes by
    their `independence_group` value within each parent bounded context.
  - Draw a subtle visual separator (e.g. a thin translucent plane or a gap in the floor
    texture) between groups if the gap between their bounding boxes exceeds a threshold.
    The separator should be visually lighter than the node volumes so it reads as
    "breathing room" rather than a barrier.
  - The gap is already embedded in positions from the extractor; the renderer just needs
    to NOT collapse it (do not re-layout nodes in Godot).
  - Smooth regrouping on scene graph reload: if a new JSON is loaded (e.g. developer
    reruns the extractor), nodes whose `independence_group` changed animate smoothly to
    new positions using a `Tween`. This is a secondary deliverable; the primary is the
    static rendering.

  ## Files Affected

  - `godot/scenes/SceneLoader.gd` — group sibling nodes by independence_group after
    placing all nodes in a context; identify group boundaries
  - `godot/scenes/IndependenceGapRenderer.gd` (new) — draws the visual separator plane
    between groups within a bounded context volume
  - `godot/tests/test_independence_gap.gd` — GUT tests: nodes in different groups have
    a measured spatial gap above threshold; nodes in same group are not separated by the
    renderer; separator plane is instantiated between distinct groups

  ## Verification

  1. GUT tests pass.
  2. Load kartograph scene graph: IAM context should show any independent module groups
     separated by a visible gap. If all IAM modules are mutually dependent the gap
     renderer is a no-op (no separator drawn) — verify this case too.
  3. Inspect `independence_group` values in the JSON and confirm they match the visual
     grouping on screen.

  ## Caveats

  The smooth-regrouping-on-reload scenario is a secondary deliverable. If time-boxed,
  deliver static rendering first and mark reload animation as a follow-up. The primary
  requirement is that a freshly loaded scene shows the correct gaps.
---
