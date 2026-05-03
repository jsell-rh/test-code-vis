---
id: task-016
title: UX — scroll-wheel zoom toward mouse cursor
spec_ref: "specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee"
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement scroll-wheel zoom aimed at world point under cursor"
pr_description: |
  ## What and Why

  Zooming toward the center of the screen is disorienting: the thing you want to examine
  drifts away from your cursor as you zoom. Zooming toward the cursor keeps your point
  of interest anchored, matching the user's intuitive model from maps and design tools.
  This is a significant UX differentiator for the prototype.

  ## Spec Requirements Satisfied

  From `specs/prototype/ux-polish.spec.md`:

  - **Zoom Toward Mouse Cursor**: scroll zoom aims at the world-space point under the
    cursor; the component under the cursor stays under the cursor during the zoom

  From `specs/prototype/godot-application.spec.md`:

  - **Camera Controls — Zooming in**: camera moves closer on scroll; internal structure
    becomes visible as camera approaches (visibility is task-018's concern)

  ## Key Design Decisions

  - On `InputEventMouseButton` WHEEL_UP/DOWN, cast a ray from the camera through the
    mouse cursor to find the world-space hit point on the ground plane (y=0).
  - Compute the vector from the camera rig to the hit point. Move the rig a fraction of
    that vector toward (or away from) the hit point. This naturally keeps the hit point
    stationary relative to the screen.
  - Zoom formula: `new_rig_pos = rig_pos + (hit_point - rig_pos) * zoom_factor`
    where `zoom_factor ≈ 0.15` for zoom-in and `-0.15` for zoom-out.
  - Camera height (distance) is clamped to `[min_zoom, max_zoom]` to prevent going below
    the ground plane or zooming out infinitely.
  - Smooth zoom animation (spec: "zoom is animated smoothly") is implemented via a
    `Tween` that interpolates `rig_pos` to the target position over ~0.15s.

  ## Files Affected

  - `godot/scenes/CameraController.gd` — updated: `_handle_zoom()` implementation with
    ray cast, hit point calculation, tween-based animation
  - `godot/tests/test_camera_zoom.gd` — GUT tests: zooming in reduces camera height;
    camera rig moves toward hit point not screen center; zoom is clamped at min/max

  ## Verification

  1. GUT tests pass.
  2. In the running app: position cursor over the IAM volume, scroll in → IAM stays
    under the cursor and grows; IAM does not drift.
  3. Scroll out from a zoomed-in position → view zooms out from cursor point.

  ## Caveats

  Ray casting to the ground plane (y=0) works for the top-down prototype. If the camera
  tilts significantly during orbit, the ground plane ray cast may miss; a fallback
  distance-based approach can be added in that case.
---
