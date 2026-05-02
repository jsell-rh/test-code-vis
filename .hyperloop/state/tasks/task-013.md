---
id: task-013
title: Implement Edge primitive renderer
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-011]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Edge primitive renderer"
pr_description: |
  ## What and Why

  Renders the dependency connections between modules as directed 3D lines in the
  Godot scene. Edges make the dependency topology visible — without them the
  bounded context boxes float in isolation and the user cannot see which contexts
  depend on which. The prototype-scope requirement is explicit: "dependencies
  between modules shown as visible connections, direction of dependency
  discernible."

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Edge Primitive

  - Each edge in the `edges` array is rendered as a directed visual connection
    between its source and target nodes.
  - Edge `weight` drives visual thickness: a weight-12 edge is visibly thicker
    than a weight-1 edge.
  - Edge `type` drives line style:
    - `"cross_context"` / `"aggregate"` — solid line
    - `"internal"` — dashed line (visible only at medium/near zoom, per LOD)
    - `"external"` — suppressed in default view
  - Arrowhead or gradient indicates direction (source → target).

  `specs/prototype/prototype-scope.spec.md` — "line or connection drawn between
  them, direction of dependency is discernible"

  ## Key Design Decisions

  - Edges are rendered as `ImmediateMesh` or `CSGCylinder` cylinders scaled by
    weight. ImmediateMesh is preferred for runtime-generated geometry.
  - Aggregate edges (`type: "aggregate"`) are rendered at far zoom; individual
    module-level edges at medium/near zoom. Switching between them is handled by
    task-014 (LOD Shell). This task renders all edges; LOD task controls
    visibility.
  - External edges (`type: "external"`) are instantiated but hidden by default
    (visible property = false). No toggle UI in this prototype phase.
  - Arrow direction: a small cone mesh at the target endpoint, aligned to the
    edge direction vector.
  - Line thickness is implemented as cylinder radius = `0.02 + weight * 0.01`
    (clamped to avoid occlusion at high weights).

  ## Files / Areas Affected

  - `godot/scenes/edge_node.tscn` — new scene for a single Edge instance
  - `godot/scripts/edge_renderer.gd` — instantiates edges from loader data;
    positions them between source and target Container world positions
  - `godot/scripts/main.gd` — calls `edge_renderer.render_all()` after containers
    are placed (so source/target positions are known)
  - `godot/tests/test_edge_renderer.gd` — tests covering:
    - edge count matches non-external edges in JSON
    - aggregate edge connects correct source/target bounded contexts
    - external edges are instantiated but hidden
    - edge cylinder radius proportional to weight

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`.
  2. Launch Godot; confirm directed lines appear between bounded contexts.
  3. From a top-down view, verify the dependency arrows point from importer to
     importee (source → target direction).
  4. Inspect two edges with different weights; confirm the higher-weight edge has
     a visibly thicker cylinder.

  ## Caveats / Follow-up

  LOD-based edge visibility (aggregate at far, individual at near) is implemented
  by task-014. The Port primitive (edges connecting to Container membranes rather
  than Container centers) is deferred. Power Rail notation (suppressing ubiquitous
  dependencies with a small indicator) is deferred to a future phase.
---
