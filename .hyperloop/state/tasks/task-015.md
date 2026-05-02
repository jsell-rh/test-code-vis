---
id: task-015
title: Implement top-down camera navigation
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1"
status: not-started
phase: null
deps: [task-012]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement top-down camera navigation"
pr_description: |
  ## What and Why

  Implements the primary navigation mode for the prototype: a top-down orthographic
  (or steep perspective) camera that the user can pan, zoom, and rotate. This is
  the "architectural overview" perspective required by prototype-scope. Without
  navigation, the user cannot explore the rendered scene.

  NOTE: First-person navigation is explicitly excluded from the prototype by
  `prototype-scope.spec.md` line 95. This task implements only the top-down mode.

  ## Spec Requirements Satisfied

  `specs/prototype/prototype-scope.spec.md` — Requirement: Navigation

  "The user can pan, zoom, and rotate the view" and "smoothly transition between
  overview and detail levels."

  `specs/prototype/prototype-scope.spec.md` — Requirement: Top-Down Architectural
  View

  "A top-down camera view showing the overall system architecture."

  `specs/visualization/spatial-structure.spec.md` — Requirement: 3D Interactive
  Navigation (top-down mode only; first-person excluded)

  ## Key Design Decisions

  - Camera is a `Camera3D` node with a high Y position looking down. The angle is
    configurable (default: 60° from vertical, not straight-down, to give depth cues
    to the nested box structure).
  - **Pan**: middle mouse drag or WASD moves the camera target point in the XZ plane.
  - **Zoom**: scroll wheel adjusts camera Y position (zoom in/out), which also
    drives the LOD tier transitions (task-014).
  - **Rotate**: right mouse drag orbits the camera around the target point. Rotation
    is constrained to ±45° from the default angle to prevent going below the scene.
  - Smooth transitions: all camera movements are interpolated via a Tween or
    `lerp()` in `_process()` to avoid jarring jumps.
  - The camera starts positioned to show all bounded contexts of `~/code/kartograph`
    in a single view.

  ## Files / Areas Affected

  - `godot/scenes/camera_controller.tscn` — new scene node for camera + input
    handling
  - `godot/scripts/camera_controller.gd` — pan/zoom/rotate input handling and
    smooth interpolation
  - `godot/scripts/main.gd` — instantiate camera controller after scene loads;
    compute initial position to frame all bounded contexts

  ## How to Verify

  1. Launch Godot with the kartograph scene graph.
  2. Scroll wheel: zoom in and out. The scene should smoothly scale.
  3. Middle-click drag: pan around the scene.
  4. Right-click drag: rotate the camera; confirm it does not go below the scene.
  5. Zoom close to the IAM context and confirm LOD transitions trigger (modules
     appear as you zoom in).

  ## Caveats / Follow-up

  The prototype does not implement a click-to-focus or smooth-fly-to-node feature
  (those require knowing which context the user intends to inspect). These are
  natural next steps but not required by prototype-scope. Keyboard navigation
  sensitivity and zoom speed constants should be configurable in the project
  settings or an exported variable.
---
