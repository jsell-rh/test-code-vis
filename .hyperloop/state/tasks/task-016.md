---
id: task-016
title: UX — zoom toward mouse cursor
spec_ref: "specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee"
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): zoom toward mouse cursor on scroll wheel"
pr_description: |
  ## What and Why

  Zoom that always pulls toward the screen centre feels wrong: if you position your cursor
  over a specific bounded context and scroll in, the context drifts away from the cursor.
  This PR makes scroll-wheel zoom target the world point under the cursor, keeping that
  point anchored during the zoom. This is the standard behaviour users expect from
  map applications and is required by the ux-polish spec.

  ## Spec Requirements Satisfied

  From `specs/prototype/ux-polish.spec.md`:

  - **Zoom Toward Mouse Cursor**: scrolling in zooms toward the point under the cursor;
    the component under the cursor stays under the cursor throughout the zoom.
  - **Zoom Out**: scrolling out zooms away from the point under the cursor.

  ## Key Design Decisions

  - On `InputEventMouseWheel`, ray-cast from the camera through the cursor to find the
    world-space hit point on the XZ ground plane (y = 0).
  - Shift the camera's position along the vector from current position toward the hit
    point by the zoom delta fraction.
  - Clamp camera distance to a min/max range to prevent clipping or infinite zoom-out.
  - Implemented inside `CameraController._handle_zoom()` (extending the stub from
    task-014); the pan and orbit logic from task-015 are not modified.
  - Pan sensitivity recalculation (height-based) already set in task-015 automatically
    stays correct after zoom because it reads the live camera height each frame.

  ## Files Affected

  - `godot/scenes/CameraController.gd` — updated `_handle_zoom()`: ray-cast to ground
    plane, cursor-anchored zoom shift, distance clamp
  - `godot/tests/test_camera_zoom.gd` — GUT tests: zooming in moves camera toward the
    pre-cursor world point; zooming out moves camera away from that point; cursor world
    point does not shift during zoom (within floating-point tolerance)

  ## Verification

  1. GUT tests pass.
  2. In the running app: position cursor over IAM context, scroll in → IAM stays under
     cursor; scroll out → IAM stays under cursor.
  3. No other camera axes are disturbed by scroll events.

  ## Caveats

  Smooth (interpolated) zoom animation is addressed separately in task-018. This task
  delivers correct geometry; task-018 adds the lerp wrapper.
---
