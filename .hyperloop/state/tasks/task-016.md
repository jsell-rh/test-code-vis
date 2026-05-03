---
id: task-016
title: UX — scroll-wheel zoom toward mouse cursor
spec_ref: specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee
status: not_started
phase: null
deps:
- task-014
round: 0
branch: null
pr: null
pr_title: 'feat(godot): implement scroll-wheel zoom aimed at world point under cursor'
pr_description: "## What and Why\n\nZooming toward the center of the screen is disorienting:\
  \ the thing you want to examine\ndrifts away from your cursor as you zoom. Zooming\
  \ toward the cursor keeps your point\nof interest anchored, matching the user's\
  \ intuitive model from maps and design tools.\nThis is a significant UX differentiator\
  \ for the prototype.\n\n## Spec Requirements Satisfied\n\nFrom `specs/prototype/ux-polish.spec.md`:\n\
  \n- **Zoom Toward Mouse Cursor**: scroll zoom aims at the world-space point under\
  \ the\n  cursor; the component under the cursor stays under the cursor during the\
  \ zoom\n\nFrom `specs/prototype/godot-application.spec.md`:\n\n- **Camera Controls\
  \ — Zooming in**: camera moves closer on scroll; internal structure\n  becomes visible\
  \ as camera approaches (visibility is task-018's concern)\n\n## Key Design Decisions\n\
  \n- On `InputEventMouseButton` WHEEL_UP/DOWN, cast a ray from the camera through\
  \ the\n  mouse cursor to find the world-space hit point on the ground plane (y=0).\n\
  - Compute the vector from the camera rig to the hit point. Move the rig a fraction\
  \ of\n  that vector toward (or away from) the hit point. This naturally keeps the\
  \ hit point\n  stationary relative to the screen.\n- Zoom formula: `new_rig_pos\
  \ = rig_pos + (hit_point - rig_pos) * zoom_factor`\n  where `zoom_factor ≈ 0.15`\
  \ for zoom-in and `-0.15` for zoom-out.\n- Camera height (distance) is clamped to\
  \ `[min_zoom, max_zoom]` to prevent going below\n  the ground plane or zooming out\
  \ infinitely.\n- Smooth zoom animation (spec: \"zoom is animated smoothly\") is\
  \ implemented via a\n  `Tween` that interpolates `rig_pos` to the target position\
  \ over ~0.15s.\n\n## Files Affected\n\n- `godot/scenes/CameraController.gd` — updated:\
  \ `_handle_zoom()` implementation with\n  ray cast, hit point calculation, tween-based\
  \ animation\n- `godot/tests/test_camera_zoom.gd` — GUT tests: zooming in reduces\
  \ camera height;\n  camera rig moves toward hit point not screen center; zoom is\
  \ clamped at min/max\n\n## Verification\n\n1. GUT tests pass.\n2. In the running\
  \ app: position cursor over the IAM volume, scroll in → IAM stays\n  under the cursor\
  \ and grows; IAM does not drift.\n3. Scroll out from a zoomed-in position → view\
  \ zooms out from cursor point.\n\n## Caveats\n\nRay casting to the ground plane\
  \ (y=0) works for the top-down prototype. If the camera\ntilts significantly during\
  \ orbit, the ground plane ray cast may miss; a fallback\ndistance-based approach\
  \ can be added in that case."
---
