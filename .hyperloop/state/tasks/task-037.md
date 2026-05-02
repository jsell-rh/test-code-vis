---
id: task-037
title: Implement Badge primitive renderer in Godot (glyph dock on Node)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-029, task-036]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render Badge primitives as glyphs docked to Node entities"
pr_description: |
  ## What and Why

  Implements the Badge primitive renderer in Godot. A Badge is a small glyph docked to a
  Node that indicates a cross-cutting property (pure, io, async, stateful, error_handling,
  test, entry_point, deprecated). Badges make structural aspects readable at a glance
  without requiring the human to zoom in and read code.

  This task consumes the `badges` array added to each symbol by the badge detection pass
  (task-036) and renders them as visible glyph indicators on Node primitives (task-029).

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Badge Primitive

  - Each Node displays badge glyphs for all applicable cross-cutting properties
  - Badges are positioned consistently across all Nodes (e.g. top-right corner arrangement)
  - Multiple badges are visible simultaneously, arranged in a consistent order
  - Badge vocabulary is closed: `pure`, `io`, `async`, `stateful`, `error_handling`,
    `test`, `entry_point`, `deprecated`

  ## Key Design Decisions

  ### Badge glyph rendering

  Each badge type maps to a distinct small icon rendered at a fixed anchor position on
  the Node's 3D bounding volume:

  - Badges appear at the top-right corner of the Node, stacked or arranged in a row
  - Up to 4 badges visible simultaneously in the primary anchor; overflow badges are
    indicated by a count indicator ("+N more") to avoid clutter
  - Badge glyphs use `Label3D` nodes (same as the Node primitive labels) or
    `MeshInstance3D` with simple shapes (small spheres/cubes as stand-ins for prototype)
  - Each badge type has a distinct color from a fixed palette (not overloading the Tint
    channel — badges use shape+color as a combined glyph channel)

  ### Badge data path

  1. `SceneGraphLoader` (established by task-011) reads node data including `symbols`
  2. For each symbol with non-empty `badges`, the Node renderer (task-029) instantiates
     badge sub-nodes
  3. Badge sub-nodes are children of the Node's GDScript scene tree

  ### Perceptual channel allocation

  Per the spec's "Primitives Compose, Not Interfere" requirement, badges use the glyph
  channel (shape/icon). They MUST NOT use the hue channel (Tint) or the spatial
  containment channel (Container). The badge color palette is distinct from the Tint
  categorical palette.

  ### LOD integration

  Badges are only visible at tier-2 LOD (near zoom). At tier-0 (far) and tier-1 (medium),
  badges are hidden (alpha = 0). This follows the LOD Shell behavior: badges are near-zoom
  detail, not overview-level information. Badge visibility animates with the same opacity
  transition used by the LOD Shell system (task-014).

  ## Files / Areas Affected

  - `godot/rendering/badge_renderer.gd` — new GDScript; instantiates badge glyph nodes
    for a given symbol's badge list; positions them consistently on the Node; manages
    LOD-driven opacity
  - `godot/rendering/node_renderer.gd` — extended to call `badge_renderer` for each
    symbol loaded from the scene graph; passes badge data and LOD state
  - `godot/assets/badge_icons/` — placeholder visual assets (simple colored Label3D or
    MeshInstance3D placeholders for each of the 8 badge types); can be replaced with
    proper icons in a future pass
  - `godot/tests/test_badge_renderer.gd` — Godot behavioral tests covering:
    - Node with `badges: ["pure"]` displays exactly one badge glyph
    - Node with `badges: ["io", "async", "error_handling"]` displays three glyphs
    - Node with `badges: []` displays no badge glyphs
    - Badges are positioned at the same anchor point across different Nodes
    - At tier-0 LOD, all badge glyphs have alpha = 0
    - At tier-2 LOD, badge glyphs have alpha > 0
    - Badge glyph count indicator appears when more than 4 badges are present

  ## How to Verify

  1. Run the extractor on `~/code/kartograph` to generate a scene graph with badge data.
  2. Load the scene graph in Godot.
  3. Zoom into a module/class that has async functions — confirm `async` badge glyphs
     appear on the corresponding Node primitives.
  4. Zoom out to tier-0 — confirm badge glyphs disappear.
  5. Zoom back in — confirm badge glyphs fade back in.
  6. Run Godot behavioral tests: all test suites pass.

  ## Caveats / Follow-up

  - Prototype uses simple placeholder visuals (colored labels or basic shapes). A future
    task can replace placeholders with proper SVG-based badge icons.
  - If `badges` data is absent from a symbol entry (e.g. older schema without task-036),
    the badge renderer should gracefully render no badges and log a debug warning.
  - The badge glyph color palette must be defined carefully to avoid clashing with the
    Tint primitive palette (task-019). Document the two palettes separately.
---
