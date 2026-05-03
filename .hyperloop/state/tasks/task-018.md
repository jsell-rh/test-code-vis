---
id: task-018
title: Level-of-detail opacity animation (far/medium/near distance thresholds)
spec_ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4
status: not_started
phase: null
deps:
- task-010
- task-013
round: 0
branch: null
pr: null
pr_title: 'feat(godot): implement LOD opacity transitions at far/medium/near distance
  thresholds'
pr_description: "## What and Why\n\nAt far zoom, showing individual module volumes\
  \ and all edges creates visual noise that\noverwhelms the user. At near zoom, hiding\
  \ edges loses critical context. Level-of-detail\n(LOD) makes each zoom level tell\
  \ a semantically complete story: far shows architecture,\nmedium shows context internals,\
  \ near shows full detail. Elements must fade with animated\nopacity — never popping\
  \ in or out — to keep spatial continuity.\n\n**Scope note**: `spatial-structure.spec.md`\
  \ contains one requirement excluded from the\nprototype (see prototype-scope.spec.md\
  \ § Not In Scope). This task implements only the\nLOD/zoom-level requirements (Scale\
  \ Through Zoom, Smooth Transitions) from that spec.\n\n## Spec Requirements Satisfied\n\
  \nFrom `specs/visualization/spatial-structure.spec.md`:\n\n- **Scale Through Zoom\
  \ — Far**: only bounded-context volumes + labels visible; module\n  volumes and\
  \ internal edges invisible; single aggregate edge per context pair visible\n- **Scale\
  \ Through Zoom — Medium**: internal module volumes and per-module edges fade in\n\
  \  with animated opacity as camera approaches a context\n- **Scale Through Zoom\
  \ — Near**: all edges, annotations, and metrics visible; no detail\n  is hidden\n\
  - **Smooth Transitions**: elements fade via animated opacity, never appear/disappear\n\
  \  instantly; transition is continuous as user zooms\n\n## Key Design Decisions\n\
  \n- LOD controller: a GDScript autoload (`LODController`) monitors camera height\
  \ each\n  frame and classifies the current view as `FAR`, `MEDIUM`, or `NEAR` based\
  \ on two\n  configurable distance thresholds.\n- On threshold crossing, `LODController`\
  \ emits a signal `lod_changed(level)`.\n- `NodeRenderer` (task-010) subscribes to\
  \ `lod_changed` and runs a `Tween` on each\n  node's `albedo_color.a` to animate\
  \ visibility in/out over ~0.3s.\n- Module nodes: `visible = false` at FAR (alpha\
  \ 0); fade to alpha 1 at MEDIUM/NEAR.\n- Module labels: hidden at FAR, visible at\
  \ MEDIUM/NEAR.\n- Internal edges (type `\"internal\"`): hidden at FAR; visible at\
  \ MEDIUM/NEAR.\n- The transition is continuous (not snapping to three discrete states)\
  \ — camera distance\n  is mapped to a normalized [0,1] value within each band, and\
  \ alpha is interpolated.\n- Aggregate-edge switching is handled separately in task-019.\n\
  \n## Files Affected\n\n- `godot/autoload/LODController.gd` — new: camera distance\
  \ monitor, `lod_changed`\n  signal, threshold constants\n- `godot/scenes/NodeRenderer.gd`\
  \ — updated: subscribe to `lod_changed`, tween alpha\n- `godot/scenes/EdgeRenderer.gd`\
  \ — updated: subscribe to `lod_changed`, show/hide\n  internal edges\n- `godot/tests/test_lod.gd`\
  \ — GUT tests: FAR hides module nodes; MEDIUM shows them;\n  NEAR shows all; transitions\
  \ use Tween (not instant)\n\n## Verification\n\n1. GUT tests pass (`check-lod-level-tests.sh`).\n\
  2. In the running app: zoom to maximum distance → module boxes disappear with a\
  \ fade.\n3. Zoom in toward IAM → IAM's module children fade in smoothly.\n4. No\
  \ elements snap to visibility.\n\n## Caveats\n\nPer-node `Tween` creation on every\
  \ LOD transition may create many concurrent tweens.\nCancel existing tweens before\
  \ starting new ones to prevent alpha jitter."
---
