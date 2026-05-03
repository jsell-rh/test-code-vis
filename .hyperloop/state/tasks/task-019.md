---
id: task-019
title: Aggregate edge LOD — smooth transition between aggregate and module-level edges
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-013, task-018]
round: 0
branch: null
pr: null
pr_title: "feat(godot): smoothly transition aggregate cross-context edges to per-module edges at medium zoom"
pr_description: |
  ## What and Why

  At far zoom the user sees one thick edge per context pair (aggregate), communicating
  the existence and strength of coupling. As they zoom in, individual module-level edges
  reveal exactly which modules are coupled. The transition between these two representations
  must be smooth — aggregate edges dissolve as individual edges emerge — so the user
  experiences a continuous reveal rather than a mode switch.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:

  - **Scale Through Zoom — Far**: single aggregate edge per context pair shown; individual
    edges not visible
  - **Scale Through Zoom — Medium**: aggregate cross-context edges "smoothly dissolve into
    their constituent module-level edges"
  - **Smooth Transitions**: "aggregate edges morph smoothly into individual edges (or
    vice versa) rather than switching discretely"

  ## Key Design Decisions

  - Aggregate `EdgeRenderer` (type `"aggregate"`) and individual module-level
    `EdgeRenderer` nodes exist side-by-side in the scene (both created by task-013).
  - `LODController` (task-018) drives the fade:
    - FAR: aggregate edges alpha=1, individual cross-context edges alpha=0
    - MEDIUM: crossfade — aggregate alpha fades from 1→0 as individual alpha fades 0→1
    - NEAR: aggregate edges alpha=0, individual edges alpha=1
  - Crossfade is driven by the same normalized distance value from task-018 so the two
    fade curves are complementary (aggregate + individual alpha ≈ 1 throughout).
  - Aggregate edge line thickness (if supported by Godot 4's shader/material) is scaled
    by `weight` so heavier coupling is visually prominent at far zoom.
  - When weight data is not available (edge weight = 1), aggregate edges use standard
    thickness.

  ## Files Affected

  - `godot/autoload/LODController.gd` — updated: emit aggregate-specific LOD values
    (or reuse `lod_changed` with a `progress` float parameter)
  - `godot/scenes/EdgeRenderer.gd` — updated: respond to LOD progress signal; tween
    alpha based on edge type (aggregate vs individual cross-context)
  - `godot/tests/test_aggregate_lod.gd` — GUT tests: at FAR aggregate alpha=1 and
    individual cross-context alpha=0; at NEAR vice versa; at threshold progress=0.5
    both are partial

  ## Verification

  1. GUT tests pass (`check-aggregate-edge-impl.sh`, `check-individual-edge-weight.sh`).
  2. In the running app: zoom from maximum to close distance on IAM — a single thick
    orange line (aggregate) fades out as multiple thinner lines (individual) fade in.
  3. No discrete jump in edge visibility.

  ## Caveats

  Godot 4's `ImmediateMesh` does not natively support line thickness. If thick aggregate
  edges are desired, use a tube `MeshInstance3D` (cylinder scaled to line length) or a
  custom shader. The prototype may use uniform line thickness and rely on colour or
  `weight` label to indicate coupling strength.
---
