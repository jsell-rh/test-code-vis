---
id: task-011
title: Godot app — top-down camera with basic orbit and zoom
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-008]
round: 0
branch: null
pr: null
pr_title: "feat(godot): top-down camera with orbit and zoom controls"
pr_description: |
  ## What and Why

  The 3D visualization is only useful if the human can navigate it. This task
  adds the camera with its default top-down view and the basic interaction modes:
  zoom (scroll wheel) and orbit (right mouse button drag). Pan (left mouse
  button) and the UX-polish behaviors (zoom-to-cursor, orbit-around-point,
  smooth interpolation) are added in task-012.

  This task can be developed in parallel with task-009 and task-010 since it
  only depends on the project scaffold (task-008).

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:
  - **Camera Controls — Top-down overview**: camera defaults to a top-down
    position showing the entire scene on startup.
  - **Camera Controls — Zooming in**: scroll moves the camera closer; internal
    structure becomes visible at close range; labels remain readable.
  - **Camera Controls — Orbiting**: right-mouse drag rotates around the focal
    point; "up stays up" (gimbal-lock-free orbit).

  From `specs/prototype/prototype-scope.spec.md`:
  - **Navigation**: pan, zoom, rotate; smooth transitions between overview and
    detail levels.

  ## Key Design Decisions

  - Camera is a `Camera3D` child of a `CameraRig` `Node3D`. The rig separates
    the focal point (rig position) from camera distance (rig's camera child Z
    offset). This is the standard Godot orbit pattern.
  - On startup the rig is positioned at the centroid of all loaded nodes, and
    the camera is elevated 80 units on the Y axis looking straight down
    (`rotation_degrees = Vector3(-90, 0, 0)`).
  - **Zoom**: `InputEventMouseButton` WHEEL_UP/DOWN adjusts `camera_distance`
    (clamped 5–200 units). Basic (non-smooth, non-cursor-centered) at this
    stage — smoothing added in task-012.
  - **Orbit**: `InputEventMouseMotion` with right-button held adjusts rig
    `rotation_degrees.y` (yaw) and a pitch offset. Pitch is clamped
    [-89°, 0°] to prevent flipping.

  ## Files Affected

  - `godot/scripts/CameraRig.gd`
  - `godot/scenes/Main.tscn` — CameraRig added to scene tree

  ## How to Verify

  Launch the application:
  1. Default view shows all nodes from above.
  2. Scroll wheel moves the camera closer/farther.
  3. Right-mouse drag orbits around the scene center without the up vector
     flipping.

  `bash .hyperloop/checks/godot-compile.sh`

  ## Caveats

  Zoom is centered on screen center at this stage. Zoom-to-cursor and
  orbit-around-point are implemented in task-012. Pan (left mouse button) is
  also task-012. The camera may feel slightly sluggish without the smooth
  interpolation added in task-012.
---
