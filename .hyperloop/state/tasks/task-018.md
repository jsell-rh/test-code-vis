---
id: task-018
title: Implement top-down camera navigation
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-012]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement top-down camera navigation"
pr_description: |
  ## What and Why

  Implements the navigation system for the prototype: a top-down orthographic-style
  camera that lets the user pan, zoom, and rotate around the 3D scene. Without
  navigation, the user is locked to a fixed viewpoint and cannot explore the
  rendered architecture. This is one of the prototype's two interaction primitives
  (the other being cluster collapse, task-017).

  Navigation is required by two converging spec requirements:
  - `specs/prototype/prototype-scope.spec.md` — "Navigation": the user can pan,
    zoom, and rotate the view, and can smoothly transition between overview and
    detail levels.
  - `specs/visualization/spatial-structure.spec.md` — "Scale Through Zoom":
    each zoom level tells a semantically complete story and LOD transitions are
    smooth and continuous.

  The camera is the mechanism that drives LOD tier transitions (task-014): as the
  camera's Y position decreases, the scene crosses far → medium → near thresholds.

  ## Spec Requirements Satisfied

  `specs/prototype/prototype-scope.spec.md` — Requirement: Navigation

  "The user can pan, zoom, and rotate the view" and "smoothly transition between
  overview and detail levels."

  `specs/prototype/prototype-scope.spec.md` — Requirement: Top-Down Architectural
  View

  "A top-down camera view showing the overall system architecture."

  `specs/visualization/spatial-structure.spec.md` — Requirement: Scale Through Zoom

  Zoom is the mechanism that drives LOD transitions. The camera controller
  determines the viewer's distance from the scene and signals the LOD Shell system
  (task-014) to fade elements in or out accordingly.

  ## Key Design Decisions

  - Camera is a `Camera3D` node positioned at high Y, angled steeply downward
    (configurable, default ~60° from horizontal, ~30° from vertical) to give depth
    cues to the nested-box structure without going fully overhead.
  - **Pan**: middle-mouse drag or WASD keys translate the camera target point
    in the XZ plane. The translation speed scales with the current zoom distance so
    far-out panning covers more world space per pixel.
  - **Zoom**: scroll wheel adjusts the camera's Y position (and therefore its
    distance from the scene). Zoom drives the LOD tier transitions in task-014.
  - **Rotate**: right-mouse drag orbits the camera around the target point. Rotation
    is constrained to ±45° from the default heading to prevent going below the
    scene floor.
  - All camera movements are interpolated via `lerp()` inside `_process()` (or a
    `Tween`) so transitions are smooth, not instantaneous.
  - On scene load, the camera is auto-positioned to frame all bounded contexts in
    a single view (compute axis-aligned bounding box of all nodes, set Y so the
    AABB fits the viewport at the current FOV).

  ## Files / Areas Affected

  - `godot/scenes/camera_controller.tscn` — new scene: a Node3D parent with
    Camera3D child; mounted in the main scene after JSON load
  - `godot/scripts/camera_controller.gd` — pan, zoom, rotate input handling;
    smooth interpolation; initial auto-frame computation; exposes `zoom_distance`
    as a signal source for task-014's LOD threshold checks
  - `godot/scripts/main.gd` — instantiate and mount CameraController after the
    scene graph is loaded; pass the bounding box of all root nodes for auto-framing

  ## How to Verify

  1. Launch Godot with the kartograph scene graph loaded.
  2. Scroll wheel up/down: the scene zooms in and out smoothly.
  3. Middle-click drag: the camera pans across the scene without jumping.
  4. Right-click drag: the camera orbits; confirm the scene stays visible and the
     camera does not go below the scene floor.
  5. Zoom close to the IAM bounded context volume: confirm LOD transitions from
     task-014 trigger (internal module boxes appear as distance decreases).
  6. On launch, all bounded context volumes fit within the viewport without any
     manual adjustment.

  ## Caveats / Follow-up

  Pan and zoom sensitivity constants and the rotation constraint angle should be
  exported variables on the camera controller so they can be tuned without code
  changes. A click-to-focus / fly-to-node feature (smooth animated transition to
  center a selected node) is a natural next step but is not required by
  prototype-scope and is deferred.
---
