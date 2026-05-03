---
id: task-014
title: Camera controller with top-down default view
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-009]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement top-down camera controller with pan, zoom, and orbit base"
pr_description: |
  ## What and Why

  The prototype's entire hypothesis depends on the user being able to navigate the 3D
  space. This task establishes the camera, positions it in a top-down view that shows
  the entire loaded system on startup, and creates the input-handling infrastructure that
  pan (task-015), zoom (task-016), and orbit (task-017) build on.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:

  - **Camera Controls — Top-down overview**: camera defaults to top-down view showing
    the entire system when the application starts
  - **Camera Controls — Zooming in**: camera moves closer on scroll; labels scale to
    remain readable
  - **Camera Controls — Orbiting**: camera rotates around focal point with intuitive
    orientation
  - **Godot 4.6**: uses Godot 4.6 Camera3D API

  ## Key Design Decisions

  - Camera rig: a pivot `Node3D` (`CameraRig`) holds a `Camera3D` at a fixed offset.
    Pan moves the rig; zoom changes the Camera3D's distance from the rig; orbit rotates
    the rig.
  - On `_ready()`, the rig is positioned at the centroid of all loaded nodes, at a height
    that fits the entire scene in view (`Camera3D.fov` + bounding-box diagonal).
  - Camera looks straight down at startup (`rotation_degrees.x = -90`).
  - Input is routed through a single `CameraController` GDScript that reads
    `InputEvent*` in `_input()` and delegates to three methods: `_handle_pan()`,
    `_handle_zoom()`, `_handle_orbit()`. Task-015/016/017 fill in those methods.
  - Stub implementations in this task: pan/zoom/orbit are no-ops that print a debug
    message; the camera rig and default positioning are the deliverable here.

  ## Files Affected

  - `godot/scenes/CameraRig.tscn` + `CameraController.gd` — new: rig hierarchy and
    input handler
  - `godot/scenes/SceneRoot.tscn` — updated: CameraRig added as child
  - `godot/tests/test_camera_default.gd` — GUT tests: camera starts in top-down
    orientation; camera position centred on scene bounds

  ## Verification

  1. GUT tests pass.
  2. On app start with kartograph scene graph, all bounded-context volumes are visible in
     the viewport without needing to pan or zoom.
  3. Camera looks straight down (pitch ≈ -90°).

  ## Caveats

  "Labels scale to remain readable" is a spec requirement for the zoom scenario; the actual
  label-scale logic is implemented in task-018 (LOD) since it depends on distance
  thresholds.
---
