---
id: task-009
title: Godot app — containment rendering and size encoding
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-008, task-004]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render nested volumes with size proportional to complexity"
pr_description: |
  ## What and Why

  Replaces the invisible `Node3D` stubs from task-008 with visible 3D geometry.
  Bounded contexts become large translucent box volumes; their child modules
  become smaller opaque volumes nested inside them. The size of each volume is
  proportional to the node's `size` field (derived from LOC in task-004).

  This produces the first visually meaningful render: a 3D map of kartograph's
  package structure where "how big" and "what contains what" are immediately
  apparent.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:
  - **Containment Rendering**: bounded context appears as a larger translucent
    volume; child modules appear as smaller opaque volumes inside it; parent
    boundary is visually distinct from children.
  - **Size Encoding**: module with more code appears as a larger volume;
    relative sizes are proportional to the LOC metric.

  From `specs/prototype/prototype-scope.spec.md`:
  - **Abstract Visual Language**: elements appear as labeled geometric volumes
    (boxes); size reflects relative complexity; containment is shown by nesting.

  ## Key Design Decisions

  - Bounded context nodes use a `BoxMesh` with semi-transparent material
    (`StandardMaterial3D.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA`,
    alpha ≈ 0.25). Module nodes use a `BoxMesh` with opaque material.
  - Node size in 3D space: `scale = Vector3(size, size * 0.5, size)` where
    `size` comes from the JSON. Bounded contexts scale up by a factor of 5 so
    they visually contain their children (children are scaled within parent
    bounds).
  - Each volume has a `Label3D` child with the node `name`. Label faces the
    camera via `Label3D.billboard = BaseMaterial3D.BILLBOARD_ENABLED`.
  - Positions are read directly from JSON `position.x/y/z`; no re-computation.
  - A `NodeRenderer.gd` script takes a node dict and returns a configured
    `MeshInstance3D`.

  ## Files Affected

  - `godot/scripts/NodeRenderer.gd`
  - `godot/scripts/SceneGraphLoader.gd` — updated to call NodeRenderer
  - `godot/scenes/Main.tscn` — updated scene tree
  - `godot/tests/test_node_renderer.gd`

  ## How to Verify

  Launch the Godot application with kartograph's scene graph (produced by
  task-004). Verify:
  1. Bounded contexts appear as large translucent boxes.
  2. Module nodes appear as smaller opaque boxes inside their parent context.
  3. Module with the highest LOC appears visually larger than lower-LOC modules.
  4. All nodes are labeled with their name.

  `bash .hyperloop/checks/godot-compile.sh`

  ## Caveats

  At this stage all volumes are white/grey — color differentiation (tinting by
  bounded context) is a future enhancement. Edges are not yet rendered (task-010).
  Camera defaults to Godot's origin until task-011 adds proper camera controls.
---
