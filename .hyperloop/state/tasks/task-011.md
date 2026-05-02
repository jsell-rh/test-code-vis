---
id: task-011
title: Godot app — top-down camera with basic orbit and zoom
spec_ref: specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed
status: not_started
phase: null
deps:
- task-008
round: 0
branch: null
pr: null
pr_title: 'feat(godot): top-down camera with orbit and zoom controls'
pr_description: "## What and Why\n\nThe 3D visualization is only useful if the human\
  \ can navigate it. This task\nadds the camera with its default top-down view and\
  \ the basic interaction modes:\nzoom (scroll wheel) and orbit (right mouse button\
  \ drag). Pan (left mouse\nbutton) and the UX-polish behaviors (zoom-to-cursor, orbit-around-point,\n\
  smooth interpolation) are added in task-012.\n\nThis task can be developed in parallel\
  \ with task-009 and task-010 since it\nonly depends on the project scaffold (task-008).\n\
  \n## Spec Requirements Satisfied\n\nFrom `specs/prototype/godot-application.spec.md`:\n\
  - **Camera Controls — Top-down overview**: camera defaults to a top-down\n  position\
  \ showing the entire scene on startup.\n- **Camera Controls — Zooming in**: scroll\
  \ moves the camera closer; internal\n  structure becomes visible at close range;\
  \ labels remain readable.\n- **Camera Controls — Orbiting**: right-mouse drag rotates\
  \ around the focal\n  point; \"up stays up\" (gimbal-lock-free orbit).\n\nFrom `specs/prototype/prototype-scope.spec.md`:\n\
  - **Navigation**: pan, zoom, rotate; smooth transitions between overview and\n \
  \ detail levels.\n\n## Key Design Decisions\n\n- Camera is a `Camera3D` child of\
  \ a `CameraRig` `Node3D`. The rig separates\n  the focal point (rig position) from\
  \ camera distance (rig's camera child Z\n  offset). This is the standard Godot orbit\
  \ pattern.\n- On startup the rig is positioned at the centroid of all loaded nodes,\
  \ and\n  the camera is elevated 80 units on the Y axis looking straight down\n \
  \ (`rotation_degrees = Vector3(-90, 0, 0)`).\n- **Zoom**: `InputEventMouseButton`\
  \ WHEEL_UP/DOWN adjusts `camera_distance`\n  (clamped 5–200 units). Basic (non-smooth,\
  \ non-cursor-centered) at this\n  stage — smoothing added in task-012.\n- **Orbit**:\
  \ `InputEventMouseMotion` with right-button held adjusts rig\n  `rotation_degrees.y`\
  \ (yaw) and a pitch offset. Pitch is clamped\n  [-89°, 0°] to prevent flipping.\n\
  \n## Files Affected\n\n- `godot/scripts/CameraRig.gd`\n- `godot/scenes/Main.tscn`\
  \ — CameraRig added to scene tree\n\n## How to Verify\n\nLaunch the application:\n\
  1. Default view shows all nodes from above.\n2. Scroll wheel moves the camera closer/farther.\n\
  3. Right-mouse drag orbits around the scene center without the up vector\n   flipping.\n\
  \n`bash .hyperloop/checks/godot-compile.sh`\n\n## Caveats\n\nZoom is centered on\
  \ screen center at this stage. Zoom-to-cursor and\norbit-around-point are implemented\
  \ in task-012. Pan (left mouse button) is\nalso task-012. The camera may feel slightly\
  \ sluggish without the smooth\ninterpolation added in task-012."
---
