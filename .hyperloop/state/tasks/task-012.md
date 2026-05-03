---
id: task-012
title: Text label rendering on node volumes
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-010]
round: 0
branch: null
pr: null
pr_title: "feat(godot): attach readable Label3D text labels to all node volumes"
pr_description: |
  ## What and Why

  Every structural element must display its name so the user can identify modules without
  having to click or hover. Labels must remain readable across zoom levels. This task adds
  a `Label3D` to each `NodeRenderer`, positioned above the volume and billboard-oriented
  toward the camera.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:

  - **Readable Labels**: all visible structural elements labeled with their names; label
    remains readable at the current zoom level

  From `specs/prototype/prototype-scope.spec.md`:

  - Labeled geometric volumes

  ## Key Design Decisions

  - Use Godot 4's `Label3D` node (built-in, no custom shader needed).
  - `billboard = FIXED_Y` so labels always face the camera but don't tilt as the camera
    pitches — keeps labels upright during orbit.
  - Label text = node `name` field (e.g. "IAM", "domain").
  - Label is positioned at `Vector3(0, size/2 + 0.5, 0)` relative to the node volume
    centre — just above the top face.
  - Label font size is fixed in pixels but `pixel_size` is tuned so the label is readable
    at typical viewing distances without being overwhelming. The `no_depth_test` flag is
    set to prevent labels from being occluded by volumes.
  - Bounded-context labels use a larger font size than module labels to convey hierarchy.
  - LOD visibility (fading at distance) is handled separately in task-018; this task leaves
    label `visible = true` unconditionally.

  ## Files Affected

  - `godot/scenes/NodeRenderer.tscn` — updated: `Label3D` child node added
  - `godot/scenes/NodeRenderer.gd` — updated: sets `Label3D.text` from node name on
    `_ready()`
  - `godot/tests/test_labels.gd` — GUT tests: label text matches node name; label is
    positioned above the mesh

  ## Verification

  1. GUT tests pass.
  2. In the running app, all visible volumes show their name in text above the box.
  3. Labels remain legible at the default top-down camera distance.

  ## Caveats

  `no_depth_test` on Label3D means labels render on top of everything, which can cause
  visual clutter when many overlapping contexts are visible. Task-018 (LOD) will
  selectively hide child-module labels at far zoom to reduce clutter.
---
