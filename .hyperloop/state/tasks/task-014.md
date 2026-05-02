---
id: task-014
title: Implement LOD Shell (3-tier zoom with smooth transitions)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-012, task-013]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement LOD Shell with 3-tier semantic zoom"
pr_description: |
  ## What and Why

  Implements level-of-detail rendering that presents a semantically complete and
  appropriately-abstracted view at each zoom distance. This is the mechanism that
  makes the prototype testable: a user at the far view sees the overall architecture;
  zooming into a bounded context reveals its internal structure. Without LOD, either
  all detail is shown at once (overwhelming) or nothing is shown at far distances.

  The prototype-scope requirement is: "zoom into a bounded context to see its
  internal layers, internal dependencies, and relative sizes of internal modules"
  with "smooth transition between overview and detail levels."

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: LOD Shell Primitive

  Three tiers (camera distance thresholds are configurable constants):

  **Tier 0 — Far (camera distance > FAR_THRESHOLD):**
  - Bounded context Containers visible; internal module Containers hidden.
  - Only aggregate `"cross_context"` / `"aggregate"` edges drawn.
  - This view alone answers "what are the major parts and how do they relate?"

  **Tier 1 — Medium (MED_THRESHOLD < distance ≤ FAR_THRESHOLD):**
  - Internal module Containers fade in within the focused context.
  - Inter-module `"internal"` edges appear.
  - Aggregate cross-context edges smoothly dissolve into constituent module-level
    `"cross_context"` edges (opacity crossfade, not instant switch).

  **Tier 2 — Near (distance ≤ MED_THRESHOLD):**
  - All edges, annotations, and `size` metrics for the focused module are visible.
  - Class-level Containers fade in (if present in the JSON).
  - No element pops in or snaps: all transitions use animated opacity via a Tween.

  `specs/visualization/spatial-structure.spec.md` — Requirement: Scale Through Zoom

  Smooth transitions between levels; aggregate edges morph to individual edges
  rather than switching discretely.

  ## Key Design Decisions

  - Camera distance is measured from the camera to each Container's world position
    per-frame.
  - Opacity transitions use a `Tween` with a 0.4s duration to avoid jarring
    visibility changes.
  - Aggregate ↔ individual edge crossfade: when entering tier 1, aggregate edges
    fade out (opacity 1→0 over 0.4s) while individual edges fade in (opacity 0→1).
    On exit back to tier 0, the reverse happens.
  - LOD is evaluated per-context, not globally: zooming close to one context shows
    its modules while other contexts remain at tier 0.

  ## Files / Areas Affected

  - `godot/scripts/lod_controller.gd` — new autoload or per-context controller
    that monitors camera distance and drives opacity Tweens on Container and Edge
    nodes
  - `godot/scripts/container_renderer.gd` — exposes `set_lod_tier(tier: int)`
    method
  - `godot/scripts/edge_renderer.gd` — exposes `set_lod_tier(tier: int)` method
    to switch aggregate/individual edge visibility
  - `godot/tests/test_lod_controller.gd` — tests covering:
    - at distance > FAR_THRESHOLD, module Containers have opacity 0
    - at distance < MED_THRESHOLD, module Containers have opacity 1
    - at tier boundary, aggregate and individual edges are crossfading
      (both have intermediate opacity)
    - LOD tier is per-context (two contexts at different distances have
      different tiers simultaneously)

  ## How to Verify

  1. Launch Godot with the kartograph scene graph.
  2. Start at top-down far view: confirm only bounded context boxes are visible.
  3. Zoom into one context: module boxes should fade in smoothly.
  4. Continue zooming: class-level nodes (if any) fade in; aggregate edge
     dissolves into individual module-level edges.
  5. Pan to another context while staying close to the first: the second context
     should remain at tier 0 (module boxes hidden).

  ## Caveats / Follow-up

  The LOD threshold constants (FAR_THRESHOLD, MED_THRESHOLD) need tuning for the
  kartograph scene scale. Mixed-tier rendering (one context at tier 2, all others
  at tier 0) is the core LLM-question-answering technique in the vision, but in
  this prototype phase the LOD tier is driven purely by camera distance, not by
  LLM selection. The LLM-driven tier selection is a future-phase feature.
---
