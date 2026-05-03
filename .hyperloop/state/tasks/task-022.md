---
id: task-022
title: Level-of-detail edge rendering with animated opacity transitions
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-009, task-013]
round: 0
branch: null
pr: null
pr_title: "feat(godot): LOD edge rendering — aggregate at far, individual at medium/near"
pr_description: |
  ## What and Why

  At overview distance, showing every individual import-level edge produces a visual
  hairball that makes the scene unreadable. Conversely, only showing aggregate edges
  when zoomed in loses the structural detail that makes the tool valuable. The spatial-
  structure spec defines three LOD bands (far, medium, near) with explicit rules for
  which edges and nodes are visible at each distance, and requires that all transitions
  are animated with opacity rather than instant visibility changes.

  This task implements the LOD system in the Godot renderer, driven by camera distance
  to each bounded context.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:

  - **Far**: bounded contexts as distinct volumes; only aggregate cross-context edges
    (one per context pair, weight-encoded); individual module-level edges not visible.
  - **Medium**: internal modules fade in within context volume; inter-module edges appear
    with animated opacity; aggregate cross-context edges smoothly dissolve into their
    constituent module-level edges.
  - **Near**: all edges, annotations, and metrics visible; transition from medium to near
    is continuous (no pop-in).
  - **Smooth transitions**: elements fade in/out with animated opacity; aggregate edges
    morph into individual edges (and vice versa) rather than switching discretely.

  ## Key Design Decisions

  - Define three distance thresholds as exported constants: `FAR_THRESHOLD`,
    `MEDIUM_THRESHOLD`. Camera distance to a bounded context centroid determines its
    LOD band. Each bounded context manages its own LOD independently (so you can be in
    "medium" for IAM while still in "far" for graph).
  - At FAR: hide all child module nodes and all individual edges within and between
    contexts; show aggregate edges (type = "aggregate" from task-006's JSON output).
  - At MEDIUM: fade in child module nodes using a `Tween` on their `modulate.a`;
    cross-context aggregate edges simultaneously tween opacity out while constituent
    module-level edges tween in.
  - At NEAR: ensure all annotations (labels, metric badges) are fully visible.
  - All opacity tweens use a shared `LodTween` helper that prevents competing tweens
    on the same property.
  - The scene graph JSON already contains both aggregate and individual edges (from
    task-006); the LOD system selects which to render — it does not recompute edges.

  ## Files Affected

  - `godot/scenes/LodController.gd` (new) — per-bounded-context LOD state machine;
    computes camera distance each frame; fires tween transitions on band change
  - `godot/scenes/EdgeRenderer.gd` — updated: expose `set_opacity(v, duration)` method
    used by LodController; differentiate aggregate vs individual edge types
  - `godot/scenes/NodeVolume.gd` — expose `set_opacity(v, duration)` for child module
    fade-in/out
  - `godot/tests/test_lod.gd` — GUT tests: at FAR distance, aggregate edges are visible
    and individual edges have opacity 0; at MEDIUM, child modules have opacity > 0 and
    < 1 during transition; at NEAR, all elements have opacity 1; band transitions trigger
    tweens not instant visibility changes

  ## Verification

  1. GUT tests pass with mocked camera distances.
  2. Load kartograph scene: zoom out fully → only bounded context volumes and aggregate
     edges visible. Zoom in slowly toward IAM → internal modules fade in, aggregate
     cross-context edge from IAM fades out while individual module edges fade in.
  3. No elements snap to visibility; all transitions are visually smooth.
  4. Each bounded context transitions independently (zoom into IAM without affecting
     graph context's LOD band).

  ## Caveats

  The aggregate edge type ("aggregate") must be present in the JSON produced by task-006.
  If task-006 has not been completed, the implementer should mock aggregate edges for
  testing and add an integration check once task-006 lands. The LOD system should
  gracefully degrade (show all edges) if no aggregate edges are present in the JSON.
---
