---
id: task-012
title: Godot app — UX polish (pan, zoom-to-cursor, smooth movement)
spec_ref: specs/prototype/ux-polish.spec.md@b7fbdb12f3dc33c4ba4d8b09a229b44120c156ee
status: not_started
phase: null
deps:
- task-011
round: 0
branch: null
pr: null
pr_title: 'feat(godot): UX polish — pan, zoom-to-cursor, orbit-around-point, smooth
  transitions'
pr_description: "## What and Why\n\nA prototype that is clunky to navigate cannot\
  \ test whether spatial\nrepresentation creates understanding. This task upgrades\
  \ the basic camera from\ntask-011 to match the quality bar described in the UX Polish\
  \ spec: controls\nthat feel immediately natural without a tutorial.\n\n## Spec Requirements\
  \ Satisfied\n\nFrom `specs/prototype/ux-polish.spec.md`:\n- **Pan with Left Mouse\
  \ Button**: LMB + drag pans in the drag direction.\n- **Non-Inverted Movement**:\
  \ drag left moves scene left (Google Maps convention).\n- **Zoom Toward Mouse Cursor**:\
  \ scroll zoom moves toward the world point under\n  the cursor, so the component\
  \ under the cursor stays anchored.\n- **Orbit Around Mouse Point**: RMB orbit rotates\
  \ around the world point under\n  the cursor at orbit start, not the screen center.\n\
  - **Smooth Camera Movement**: all transitions use `lerp`/`move_toward` so\n  there\
  \ is no snapping or jerking.\n\n## Key Design Decisions\n\n- **Pan**: on LMB drag,\
  \ unproject the mouse delta from screen to world space\n  at the current camera\
  \ distance and translate the rig in the opposite\n  direction (so the scene follows\
  \ the pointer, not the rig).\n- **Zoom-to-cursor**: on scroll, raycast from cursor\
  \ to the scene plane (Y=0),\n  compute the world point, then move the rig position\
  \ toward that point by\n  a fraction of the camera-distance change. Formula from\
  \ standard \"zoom to\n  point\" camera techniques.\n- **Orbit-around-point**: on\
  \ RMB press, record the world point under the\n  cursor using a raycast. During\
  \ subsequent mouse motion, orbit the rig\n  around that fixed world point (not the\
  \ rig origin) by recomputing rig\n  position as `pivot + offset.rotated(...)`.\n\
  - **Smooth movement**: target positions/distances are set as goals; `_process`\n\
  \  lerps the actual camera state toward the goal with `delta * smoothing_factor`\n\
  \  (smoothing_factor ≈ 10.0 for responsiveness without overshoot).\n\n## Files Affected\n\
  \n- `godot/scripts/CameraRig.gd` — all UX behaviors added here\n\n## How to Verify\n\
  \n1. LMB drag: scene follows the pointer in the same direction (not inverted).\n\
  2. Hover cursor over a specific context box, scroll in: that box stays centered\n\
  \   under the cursor during zoom.\n3. Hover cursor over a context box, RMB drag:\
  \ orbit is centered on that box,\n   not the world origin.\n4. All movements are\
  \ visibly smooth — no frame-to-frame snapping.\n\n`bash .hyperloop/checks/godot-compile.sh`\n\
  \n## Caveats\n\nSmooth interpolation introduces a tiny lag behind input — this is\
  \ intentional\nand feels natural. If the smoothing feels too sluggish, reduce\n\
  `smoothing_factor`. The orbit-around-point requires a raycast hit against\nvisible\
  \ geometry; if the cursor is over empty space, fall back to orbiting\naround the\
  \ current rig position."
---
