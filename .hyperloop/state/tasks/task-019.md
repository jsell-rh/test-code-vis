---
id: task-019
title: Aggregate edge LOD — smooth transition between aggregate and module-level edges
spec_ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4
status: not_started
phase: null
deps:
- task-013
- task-018
round: 0
branch: null
pr: null
pr_title: 'feat(godot): smoothly transition aggregate cross-context edges to per-module
  edges at medium zoom'
pr_description: "## What and Why\n\nAt far zoom the user sees one thick edge per context\
  \ pair (aggregate), communicating\nthe existence and strength of coupling. As they\
  \ zoom in, individual module-level edges\nreveal exactly which modules are coupled.\
  \ The transition between these two representations\nmust be smooth — aggregate edges\
  \ dissolve as individual edges emerge — so the user\nexperiences a continuous reveal\
  \ rather than a mode switch.\n\n## Spec Requirements Satisfied\n\nFrom `specs/visualization/spatial-structure.spec.md`:\n\
  \n- **Scale Through Zoom — Far**: single aggregate edge per context pair shown;\
  \ individual\n  edges not visible\n- **Scale Through Zoom — Medium**: aggregate\
  \ cross-context edges \"smoothly dissolve into\n  their constituent module-level\
  \ edges\"\n- **Smooth Transitions**: \"aggregate edges morph smoothly into individual\
  \ edges (or\n  vice versa) rather than switching discretely\"\n\n## Key Design Decisions\n\
  \n- Aggregate `EdgeRenderer` (type `\"aggregate\"`) and individual module-level\n\
  \  `EdgeRenderer` nodes exist side-by-side in the scene (both created by task-013).\n\
  - `LODController` (task-018) drives the fade:\n  - FAR: aggregate edges alpha=1,\
  \ individual cross-context edges alpha=0\n  - MEDIUM: crossfade — aggregate alpha\
  \ fades from 1→0 as individual alpha fades 0→1\n  - NEAR: aggregate edges alpha=0,\
  \ individual edges alpha=1\n- Crossfade is driven by the same normalized distance\
  \ value from task-018 so the two\n  fade curves are complementary (aggregate + individual\
  \ alpha ≈ 1 throughout).\n- Aggregate edge line thickness (if supported by Godot\
  \ 4's shader/material) is scaled\n  by `weight` so heavier coupling is visually\
  \ prominent at far zoom.\n- When weight data is not available (edge weight = 1),\
  \ aggregate edges use standard\n  thickness.\n\n## Files Affected\n\n- `godot/autoload/LODController.gd`\
  \ — updated: emit aggregate-specific LOD values\n  (or reuse `lod_changed` with\
  \ a `progress` float parameter)\n- `godot/scenes/EdgeRenderer.gd` — updated: respond\
  \ to LOD progress signal; tween\n  alpha based on edge type (aggregate vs individual\
  \ cross-context)\n- `godot/tests/test_aggregate_lod.gd` — GUT tests: at FAR aggregate\
  \ alpha=1 and\n  individual cross-context alpha=0; at NEAR vice versa; at threshold\
  \ progress=0.5\n  both are partial\n\n## Verification\n\n1. GUT tests pass (`check-aggregate-edge-impl.sh`,\
  \ `check-individual-edge-weight.sh`).\n2. In the running app: zoom from maximum\
  \ to close distance on IAM — a single thick\n  orange line (aggregate) fades out\
  \ as multiple thinner lines (individual) fade in.\n3. No discrete jump in edge visibility.\n\
  \n## Caveats\n\nGodot 4's `ImmediateMesh` does not natively support line thickness.\
  \ If thick aggregate\nedges are desired, use a tube `MeshInstance3D` (cylinder scaled\
  \ to line length) or a\ncustom shader. The prototype may use uniform line thickness\
  \ and rely on colour or\n`weight` label to indicate coupling strength."
---
