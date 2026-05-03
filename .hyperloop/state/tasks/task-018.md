---
id: task-018
title: Level-of-detail opacity animation (far/medium/near distance thresholds)
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-010, task-013]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement LOD opacity transitions at far/medium/near distance thresholds"
pr_description: |
  ## What and Why

  At far zoom, showing individual module volumes and all edges creates visual noise that
  overwhelms the user. At near zoom, hiding edges loses critical context. Level-of-detail
  (LOD) makes each zoom level tell a semantically complete story: far shows architecture,
  medium shows context internals, near shows full detail. Elements must fade with animated
  opacity — never popping in or out — to keep spatial continuity.

  **Scope note**: `spatial-structure.spec.md` contains one requirement excluded from the
  prototype (see prototype-scope.spec.md § Not In Scope). This task implements only the
  LOD/zoom-level requirements (Scale Through Zoom, Smooth Transitions) from that spec.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:

  - **Scale Through Zoom — Far**: only bounded-context volumes + labels visible; module
    volumes and internal edges invisible; single aggregate edge per context pair visible
  - **Scale Through Zoom — Medium**: internal module volumes and per-module edges fade in
    with animated opacity as camera approaches a context
  - **Scale Through Zoom — Near**: all edges, annotations, and metrics visible; no detail
    is hidden
  - **Smooth Transitions**: elements fade via animated opacity, never appear/disappear
    instantly; transition is continuous as user zooms

  ## Key Design Decisions

  - LOD controller: a GDScript autoload (`LODController`) monitors camera height each
    frame and classifies the current view as `FAR`, `MEDIUM`, or `NEAR` based on two
    configurable distance thresholds.
  - On threshold crossing, `LODController` emits a signal `lod_changed(level)`.
  - `NodeRenderer` (task-010) subscribes to `lod_changed` and runs a `Tween` on each
    node's `albedo_color.a` to animate visibility in/out over ~0.3s.
  - Module nodes: `visible = false` at FAR (alpha 0); fade to alpha 1 at MEDIUM/NEAR.
  - Module labels: hidden at FAR, visible at MEDIUM/NEAR.
  - Internal edges (type `"internal"`): hidden at FAR; visible at MEDIUM/NEAR.
  - The transition is continuous (not snapping to three discrete states) — camera distance
    is mapped to a normalized [0,1] value within each band, and alpha is interpolated.
  - Aggregate-edge switching is handled separately in task-019.

  ## Files Affected

  - `godot/autoload/LODController.gd` — new: camera distance monitor, `lod_changed`
    signal, threshold constants
  - `godot/scenes/NodeRenderer.gd` — updated: subscribe to `lod_changed`, tween alpha
  - `godot/scenes/EdgeRenderer.gd` — updated: subscribe to `lod_changed`, show/hide
    internal edges
  - `godot/tests/test_lod.gd` — GUT tests: FAR hides module nodes; MEDIUM shows them;
    NEAR shows all; transitions use Tween (not instant)

  ## Verification

  1. GUT tests pass (`check-lod-level-tests.sh`).
  2. In the running app: zoom to maximum distance → module boxes disappear with a fade.
  3. Zoom in toward IAM → IAM's module children fade in smoothly.
  4. No elements snap to visibility.

  ## Caveats

  Per-node `Tween` creation on every LOD transition may create many concurrent tweens.
  Cancel existing tweens before starting new ones to prevent alpha jitter.
---
