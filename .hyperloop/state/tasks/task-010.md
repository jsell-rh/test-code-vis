---
id: task-010
title: Node volume renderer with size encoding
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-009]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render node volumes sized proportionally to LOC complexity metric"
pr_description: |
  ## What and Why

  Creates a 3D volume (BoxMesh) for each node in the scene graph and positions it at the
  coordinates provided by the extractor. Volume size is proportional to the node's LOC
  metric, making complexity visible at a glance. This is the foundational rendering task
  that containment (task-011), labels (task-012), and edges (task-013) all build on.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:

  - **JSON Scene Graph Loading** (generates 3D volumes for each node)
  - **Size Encoding**: module with more code appears larger; sizes proportional to metric

  From `specs/prototype/prototype-scope.spec.md`:

  - Abstract volumes (boxes or similar primitives), not buildings or terrain

  ## Key Design Decisions

  - Each node → one `MeshInstance3D` with a `BoxMesh`. Size is normalized across all
    nodes: `display_size = min_size + (node.size / max_size) * (max_size_range)` so the
    largest node is visually prominent but no node is invisible.
  - Position comes directly from the node's `position.x`, `position.y`, `position.z`
    fields — no layout computation in Godot.
  - Each `MeshInstance3D` is added as a child of a `NodeRenderer` scene that wraps the
    node data (id, name, type, parent) for use by downstream tasks.
  - Node type determines material: bounded-context nodes get a semi-transparent material;
    module nodes get an opaque material. (Containment rendering fine-tunes this in task-011.)
  - A `NodeRenderer` scene is instantiated for each entry in `SceneGraphLoader.nodes()`.

  ## Files Affected

  - `godot/scenes/NodeRenderer.tscn` + `NodeRenderer.gd` — new: scene and script for a
    single rendered node
  - `godot/scenes/SceneRoot.gd` — updated: instantiates `NodeRenderer` for each node on
    `_ready()`
  - `godot/tests/test_node_renderer.gd` — GUT tests: node at correct position; size
    scales with metric; largest node is larger than smallest

  ## Verification

  1. GUT tests pass.
  2. Running the app with kartograph scene graph: visible box volumes at distinct positions.
  3. The `iam` bounded context node is visually larger than, e.g., `iam.domain`.

  ## Caveats

  Size normalization breaks if all nodes have identical LOC (e.g. a synthetic test graph).
  Guard against division-by-zero with a fallback minimum size.
---
