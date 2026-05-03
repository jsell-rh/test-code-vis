---
id: task-011
title: Containment rendering (nested translucent parent / opaque children)
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-010]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render containment relationships as nested translucent/opaque volumes"
pr_description: |
  ## What and Why

  Child nodes (modules) must appear visually inside their parent node (bounded context).
  The parent is shown as a larger semi-transparent volume so the children remain visible
  through it, making the containment hierarchy immediately readable. This is a key
  visual affordance of the prototype — if containment is not visible, the user cannot
  understand the architectural layering.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:

  - **Containment Rendering**: bounded context = larger translucent volume; child modules =
    smaller opaque volumes inside; parent boundary visually distinct from children

  From `specs/visualization/spatial-structure.spec.md` (Structure as Persistent Geography):

  - Each structural element occupies a distinct region; boundaries between elements are
    visually clear; structural relationships expressed spatially

  ## Key Design Decisions

  - Bounded-context volumes use a `StandardMaterial3D` with `transparency = ALPHA` and
    `albedo_color.a ≈ 0.25`. Each bounded context gets a distinct hue (palette of 6+
    colours cycling) so contexts are distinguishable.
  - Module (child) volumes use fully opaque materials, using a slightly lighter shade of
    their parent's hue.
  - Godot scene tree hierarchy: `SceneRoot → BoundedContextNode → ModuleNode`. Child nodes
    are Godot scene-tree children of their parent, so transforms compose naturally.
  - Parent volume is sized to fully contain all its children with a margin. The extractor
    layout guarantees child positions are within parent bounds (task-004), but Godot adds
    a visual padding margin of ~10% to the parent's visual box size.
  - Existing `NodeRenderer` from task-010 is extended (not replaced): a `parent` property
    is set, and the material variant (translucent vs opaque) is selected based on node type.

  ## Files Affected

  - `godot/scenes/NodeRenderer.gd` — updated: material selection based on node type,
    parent-scoped colour palette
  - `godot/scenes/SceneRoot.gd` — updated: parenting logic (child MeshInstance3D nodes
    are re-parented to their parent NodeRenderer after all nodes are instantiated)
  - `godot/tests/test_containment.gd` — GUT tests: child node has parent id matching
    NodeRenderer parent; bounded context material is translucent; module material is opaque

  ## Verification

  1. GUT tests pass.
  2. In the running app, the IAM bounded context box is visually transparent and contains
     visible module boxes inside it.
  3. Distinct bounded contexts have distinct colours.

  ## Caveats

  Translucent volumes in Godot 4 require `transparency = ALPHA` and can interact poorly
  with depth sorting when volumes overlap. Use `render_priority` or `no_depth_test` if
  z-fighting is observed between parent and child volumes.
---
