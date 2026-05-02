---
id: task-010
title: Godot app — dependency edge rendering
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-009]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render directed dependency edges between nodes"
pr_description: |
  ## What and Why

  Adds visible connections between nodes based on the `edges` array in the
  scene graph. Without edges, the 3D space is a collection of boxes with no
  visible relationships — the core value proposition of the visualization
  (showing how modules depend on each other) is absent.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:
  - **Dependency Rendering — Rendering a cross-context dependency**: a line
    connects the two context volumes; direction is visually indicated.

  From `specs/prototype/prototype-scope.spec.md`:
  - **Dependency Visualization**: dependencies between modules visible as
    connections; direction is discernible.

  ## Key Design Decisions

  - Edges are drawn as `ImmediateMesh` lines (or `CSGCylinder3D` arrows) in
    GDScript. `ImmediateMesh` is preferred for performance at kartograph scale
    (~100 edges).
  - Direction is encoded by an arrowhead at the target end: a small cone
    `CSGCylinder3D` (with `top_radius: 0`, `bottom_radius: 0.15`) oriented
    along the edge direction.
  - Edge thickness encodes the `weight` field: `width = clamp(weight * 0.05,
    0.02, 0.5)`. At kartograph scale (weights 1–12), this gives a visible
    range without extremes.
  - Only `type != "aggregate"` edges are rendered by default in this task.
    Aggregate edges are used by the LOD system (task-013) and are rendered
    there.
  - An `EdgeRenderer.gd` script takes source/target node positions and a weight
    and returns a configured set of `MeshInstance3D` nodes.

  ## Files Affected

  - `godot/scripts/EdgeRenderer.gd`
  - `godot/scripts/SceneGraphLoader.gd` — updated to build a node-id → position
    lookup and call EdgeRenderer for each edge
  - `godot/tests/test_edge_renderer.gd`

  ## How to Verify

  Launch the Godot application with kartograph's scene graph:
  1. Lines with arrowheads connect bounded context volumes.
  2. Lines connecting modules with weight > 1 are visibly thicker than
     single-import edges.
  3. Arrowheads point toward the dependency target (the module being imported).

  `bash .hyperloop/checks/godot-compile.sh`

  ## Caveats

  At this task's completion, all edges are rendered at all zoom levels. LOD
  (showing only aggregate edges at far zoom) is added in task-013. The scene
  may look cluttered at far zoom — that is expected and resolved by task-013.
---
