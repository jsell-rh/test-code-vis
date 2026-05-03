---
id: task-020
title: Independence group spatial separation rendering
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-011]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render independence groups in distinct spatial regions with visible gap"
pr_description: |
  ## What and Why

  When two module groups within a bounded context share no dependencies, showing them
  spatially adjacent makes them look coupled. Separating them with a visible gap makes
  independence obvious without requiring the user to read labels or click anything.
  This is "independence as first-class visual concept" from the orthogonal-independence spec.

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:

  - **Spatial Separation of Independent Groups**: groups occupy distinct spatial regions
    within the context's volume; a visible gap separates them; modules within each group
    remain close to each other
  - **Smooth regrouping on data change**: when a new scene graph is loaded with different
    independence groups, nodes animate smoothly to new positions (slide, don't jump)

  ## Key Design Decisions

  - The extractor's layout (task-004/005) already positions modules with independence-aware
    spacing (layout respects group separation). Godot reads those positions from JSON and
    renders at them — no re-layout in Godot.
  - To make the gap *visible*, each independence group within a bounded context gets a
    subtle translucent background plane (`MeshInstance3D` with `PlaneMesh` at y=0.05)
    tinted with a group-specific colour inside the parent's bounding box. This acts as a
    "floor tile" for the group, distinct from the parent's background.
  - Group tint colours cycle through a fixed palette; groups within the same context use
    adjacent palette entries.
  - Smooth regrouping: when `SceneGraphLoader` reloads a new JSON (future feature;
    scaffold for it now), `NodeRenderer` runs a `Tween` on each node's position from old
    to new. The group background plane also tweens its bounds. Duration ~0.5s.
  - The reload trigger is out of scope for this prototype task; only the animation
    infrastructure is scaffolded.

  ## Files Affected

  - `godot/scenes/IndependenceGroupPlane.tscn` + `IndependenceGroupPlane.gd` — new:
    background plane for one independence group
  - `godot/scenes/NodeRenderer.gd` — updated: `independence_group` field used to look up
    group plane; group plane created per unique group id within context
  - `godot/tests/test_independence_rendering.gd` — GUT tests: two distinct groups have
    separate planes; group planes are within parent context bounds; nodes in different
    groups have spatial separation > nodes in same group

  ## Verification

  1. GUT tests pass.
  2. In the running app: within the IAM context, if the extractor outputs ≥2 groups,
    a visible colour-coded background separates them.
  3. Modules with the same `independence_group` value are visually clustered together.

  ## Caveats

  If kartograph's IAM context has only one independence group (all modules transitively
  coupled), no separation will appear — the background plane covers the entire context,
  which is correct behaviour. The test should handle this case by using a fixture with
  a known two-group structure.
---
