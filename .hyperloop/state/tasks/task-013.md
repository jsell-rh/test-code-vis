---
id: task-013
title: Dependency edge renderer (directed lines between node volumes)
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-010]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render dependency edges as directed lines between node volumes"
pr_description: |
  ## What and Why

  Dependencies between modules must be visible as spatial connections. Without this,
  the visualization conveys structure (where things are) but not coupling (what depends
  on what). This is one of the two primary data points the prototype hypothesis depends on.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:

  - **Dependency Rendering**: edge from graph context to shared_kernel drawn as a line;
    direction of dependency is visually indicated

  From `specs/prototype/prototype-scope.spec.md`:

  - Dependencies between contexts visible as connections; direction discernible

  ## Key Design Decisions

  - Use `ImmediateMesh` (or `MeshInstance3D` with `ArrayMesh` line primitives) in Godot 4
    to draw line segments between node centre positions.
  - Each edge is a `EdgeRenderer` node: a line from `source` node centre to `target`
    node centre. An arrowhead (small cone `MeshInstance3D` at the target end, oriented
    along the line direction) indicates dependency direction.
  - Edge colour: cross-context edges in orange; internal edges in a muted grey. This
    provides at-a-glance cross/internal distinction without interaction.
  - Edges are children of a dedicated `EdgesRoot` node in the scene tree, not children
    of individual `NodeRenderer` nodes, so they can update their endpoints if nodes are
    ever repositioned (task-020, task-022).
  - All edges start with `visible = true`; LOD task-018 will set visibility based on
    distance.
  - Aggregate edges (type `"aggregate"`) are drawn the same way at this stage; the LOD
    task (task-019) adds the switching logic between aggregate and individual edges.

  ## Files Affected

  - `godot/scenes/EdgeRenderer.tscn` + `EdgeRenderer.gd` — new: draws one directed line
    with arrowhead
  - `godot/scenes/EdgesRoot.gd` — new: iterates `SceneGraphLoader.edges()`, instantiates
    `EdgeRenderer` for each, resolves source/target node positions from the scene
  - `godot/tests/test_edge_renderer.gd` — GUT tests: edge endpoints match source/target
    node positions; arrowhead orientation correct; cross-context vs internal colour

  ## Verification

  1. GUT tests pass.
  2. In the running app, visible lines connect the IAM and graph bounded context volumes.
  3. Arrow direction points from dependent (e.g. `graph`) toward dependency (e.g.
     `shared_kernel`).

  ## Caveats

  `ImmediateMesh` is rebuilt each frame if positions change. For the static prototype,
  edges are built once on scene load. If smooth animation is needed (tasks-019, 022),
  the `EdgeRenderer` will need an update method that rebuilds its mesh.
---
