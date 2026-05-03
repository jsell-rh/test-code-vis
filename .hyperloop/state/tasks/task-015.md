---
id: task-015
title: UX — pan with left mouse button (non-inverted)
spec_ref: "specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee"
status: not-started
phase: null
deps: [task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement non-inverted LMB pan for camera controller"
pr_description: |
  ## What and Why

  If panning is inverted or unresponsive, users cannot place specific architectural areas
  into view — the prototype's navigability hypothesis fails immediately. This task
  implements intuitive drag-to-pan: hold left mouse button and drag; the scene moves in
  the same direction as the drag (Google Maps convention).

  ## Spec Requirements Satisfied

  From `specs/prototype/ux-polish.spec.md`:

  - **Pan with Left Mouse Button**: left mouse button + drag pans the view
  - **Non-Inverted Movement**: dragging left moves the view left (non-inverted in
    the Maps sense — content you drag toward follows your cursor)

  ## Key Design Decisions

  - Implemented inside `CameraController._handle_pan()` (stub from task-014).
  - On `InputEventMouseButton` with `MOUSE_BUTTON_LEFT` pressed, set a `_panning` flag.
  - On `InputEventMouseMotion` while `_panning`, translate the camera rig by
    `(-delta.x, 0, -delta.y) * pan_speed` in the camera's local XZ plane.
  - Pan speed is proportional to camera height (zoom level) so pan distance is consistent
    regardless of zoom: `pan_speed = camera_distance * pan_sensitivity_constant`.
  - Direction: dragging right → camera rig moves in +X (scene appears to move left, which
    reveals content to the right of the current view). This matches the spec's "dragging
    left reveals content to the right" description.
  - Movement is immediate (no lerp) for responsiveness; smooth deceleration (momentum)
    is out of scope for the prototype.

  ## Files Affected

  - `godot/scenes/CameraController.gd` — updated: `_handle_pan()` implementation,
    `_panning` flag, pan speed calculation
  - `godot/tests/test_camera_pan.gd` — GUT tests: camera position changes in expected
    direction for positive x-delta; camera position changes in expected direction for
    positive y-delta; direction is non-inverted

  ## Verification

  1. GUT tests pass.
  2. In the running app: hold LMB, drag right → bounded contexts move left (correct).
  3. Hold LMB, drag up → bounded contexts move up (correct).

  ## Caveats

  "Smooth pan proportional to drag speed" (smooth pan scenario in ux-polish spec) is
  satisfied by immediate response — movement is already proportional to drag speed because
  delta is accumulated per frame. No additional smoothing is needed.
---
