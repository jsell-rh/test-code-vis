---
id: task-018
title: UX — smooth camera movement (interpolated zoom animation)
spec_ref: "specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee"
status: not-started
phase: null
deps: [task-015, task-016, task-017]
round: 0
branch: null
pr: null
pr_title: "feat(godot): smooth interpolated zoom animation for camera controller"
pr_description: |
  ## What and Why

  Instant camera jumps feel jarring and make it hard for the user to maintain spatial
  orientation. The ux-polish spec explicitly requires that zoom is "animated smoothly
  (interpolated), not instantaneous". This PR wraps the zoom delta computed in task-016
  in a lerp/tween so the camera glides to its target distance rather than snapping.
  Pan movement (task-015) is already smooth by virtue of per-frame proportional delta;
  this task verifies that and, if needed, adds inertia dampening.

  ## Spec Requirements Satisfied

  From `specs/prototype/ux-polish.spec.md`:

  - **Smooth Camera Movement — Smooth zoom**: zoom is animated smoothly (interpolated),
    not instantaneous.
  - **Smooth Camera Movement — Smooth pan**: pan movement is smooth and proportional to
    drag speed (verify that task-015's implementation already satisfies this; add
    dampening only if it does not).

  ## Key Design Decisions

  - Introduce a `_zoom_target` float that receives the discrete scroll delta each wheel
    event; in `_process()`, lerp the camera's actual distance toward `_zoom_target` at a
    configurable `zoom_lerp_speed` (default ≈ 10.0 * delta for ~100 ms settle time).
  - The cursor-anchor geometry from task-016 still applies: the lerp operates on the
    scalar distance while the anchor offset is maintained by translating the camera rig.
  - Do NOT add lerp to pan: per-frame drag delta is inherently smooth; adding lerp would
    introduce lag that violates "proportional to drag speed".
  - Orbit motion (task-017) is also per-frame and does not need additional lerp.
  - Export `zoom_lerp_speed` as a Godot `@export` so it can be tuned in the editor
    without code changes.

  ## Files Affected

  - `godot/scenes/CameraController.gd` — added `_zoom_target`, lerp in `_process()`,
    `@export zoom_lerp_speed`
  - `godot/tests/test_camera_smooth.gd` — GUT tests: after a scroll event, camera
    distance after one frame is strictly between old and new target (lerp in progress);
    camera distance converges to target within N frames; pan delta test confirms
    proportional response (no lerp lag)

  ## Verification

  1. GUT tests pass.
  2. In the running app: scroll wheel → camera glides smoothly to new distance (no snap);
     drag to pan → movement feels immediate and proportional (no lag).
  3. Adjust `zoom_lerp_speed` in the editor and observe effect without code changes.

  ## Caveats

  Task-018 does not change the orbit or pan implementations; those are governed by their
  own tasks. If the UX review finds pan also needs dampening, a follow-up task should be
  opened rather than expanding this one's scope.
---
