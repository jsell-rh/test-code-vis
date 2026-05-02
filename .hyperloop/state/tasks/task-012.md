---
id: task-012
title: Godot app — UX polish (pan, zoom-to-cursor, smooth movement)
spec_ref: "specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee"
status: not-started
phase: null
deps: [task-011]
round: 0
branch: null
pr: null
pr_title: "feat(godot): UX polish — pan, zoom-to-cursor, orbit-around-point, smooth transitions"
pr_description: |
  ## What and Why

  A prototype that is clunky to navigate cannot test whether spatial
  representation creates understanding. This task upgrades the basic camera from
  task-011 to match the quality bar described in the UX Polish spec: controls
  that feel immediately natural without a tutorial.

  ## Spec Requirements Satisfied

  From `specs/prototype/ux-polish.spec.md`:
  - **Pan with Left Mouse Button**: LMB + drag pans in the drag direction.
  - **Non-Inverted Movement**: drag left moves scene left (Google Maps convention).
  - **Zoom Toward Mouse Cursor**: scroll zoom moves toward the world point under
    the cursor, so the component under the cursor stays anchored.
  - **Orbit Around Mouse Point**: RMB orbit rotates around the world point under
    the cursor at orbit start, not the screen center.
  - **Smooth Camera Movement**: all transitions use `lerp`/`move_toward` so
    there is no snapping or jerking.

  ## Key Design Decisions

  - **Pan**: on LMB drag, unproject the mouse delta from screen to world space
    at the current camera distance and translate the rig in the opposite
    direction (so the scene follows the pointer, not the rig).
  - **Zoom-to-cursor**: on scroll, raycast from cursor to the scene plane (Y=0),
    compute the world point, then move the rig position toward that point by
    a fraction of the camera-distance change. Formula from standard "zoom to
    point" camera techniques.
  - **Orbit-around-point**: on RMB press, record the world point under the
    cursor using a raycast. During subsequent mouse motion, orbit the rig
    around that fixed world point (not the rig origin) by recomputing rig
    position as `pivot + offset.rotated(...)`.
  - **Smooth movement**: target positions/distances are set as goals; `_process`
    lerps the actual camera state toward the goal with `delta * smoothing_factor`
    (smoothing_factor ≈ 10.0 for responsiveness without overshoot).

  ## Files Affected

  - `godot/scripts/CameraRig.gd` — all UX behaviors added here

  ## How to Verify

  1. LMB drag: scene follows the pointer in the same direction (not inverted).
  2. Hover cursor over a specific context box, scroll in: that box stays centered
     under the cursor during zoom.
  3. Hover cursor over a context box, RMB drag: orbit is centered on that box,
     not the world origin.
  4. All movements are visibly smooth — no frame-to-frame snapping.

  `bash .hyperloop/checks/godot-compile.sh`

  ## Caveats

  Smooth interpolation introduces a tiny lag behind input — this is intentional
  and feels natural. If the smoothing feels too sluggish, reduce
  `smoothing_factor`. The orbit-around-point requires a raycast hit against
  visible geometry; if the cursor is over empty space, fall back to orbiting
  around the current rig position.
---
