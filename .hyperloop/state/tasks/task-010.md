---
id: task-010
title: Godot app — dependency edge rendering
spec_ref: specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed
status: not_started
phase: null
deps:
- task-009
round: 0
branch: null
pr: null
pr_title: 'feat(godot): render directed dependency edges between nodes'
pr_description: "## What and Why\n\nAdds visible connections between nodes based on\
  \ the `edges` array in the\nscene graph. Without edges, the 3D space is a collection\
  \ of boxes with no\nvisible relationships — the core value proposition of the visualization\n\
  (showing how modules depend on each other) is absent.\n\n## Spec Requirements Satisfied\n\
  \nFrom `specs/prototype/godot-application.spec.md`:\n- **Dependency Rendering —\
  \ Rendering a cross-context dependency**: a line\n  connects the two context volumes;\
  \ direction is visually indicated.\n\nFrom `specs/prototype/prototype-scope.spec.md`:\n\
  - **Dependency Visualization**: dependencies between modules visible as\n  connections;\
  \ direction is discernible.\n\n## Key Design Decisions\n\n- Edges are drawn as `ImmediateMesh`\
  \ lines (or `CSGCylinder3D` arrows) in\n  GDScript. `ImmediateMesh` is preferred\
  \ for performance at kartograph scale\n  (~100 edges).\n- Direction is encoded by\
  \ an arrowhead at the target end: a small cone\n  `CSGCylinder3D` (with `top_radius:\
  \ 0`, `bottom_radius: 0.15`) oriented\n  along the edge direction.\n- Edge thickness\
  \ encodes the `weight` field: `width = clamp(weight * 0.05,\n  0.02, 0.5)`. At kartograph\
  \ scale (weights 1–12), this gives a visible\n  range without extremes.\n- Only\
  \ `type != \"aggregate\"` edges are rendered by default in this task.\n  Aggregate\
  \ edges are used by the LOD system (task-013) and are rendered\n  there.\n- An `EdgeRenderer.gd`\
  \ script takes source/target node positions and a weight\n  and returns a configured\
  \ set of `MeshInstance3D` nodes.\n\n## Files Affected\n\n- `godot/scripts/EdgeRenderer.gd`\n\
  - `godot/scripts/SceneGraphLoader.gd` — updated to build a node-id → position\n\
  \  lookup and call EdgeRenderer for each edge\n- `godot/tests/test_edge_renderer.gd`\n\
  \n## How to Verify\n\nLaunch the Godot application with kartograph's scene graph:\n\
  1. Lines with arrowheads connect bounded context volumes.\n2. Lines connecting modules\
  \ with weight > 1 are visibly thicker than\n   single-import edges.\n3. Arrowheads\
  \ point toward the dependency target (the module being imported).\n\n`bash .hyperloop/checks/godot-compile.sh`\n\
  \n## Caveats\n\nAt this task's completion, all edges are rendered at all zoom levels.\
  \ LOD\n(showing only aggregate edges at far zoom) is added in task-013. The scene\n\
  may look cluttered at far zoom — that is expected and resolved by task-013."
---
