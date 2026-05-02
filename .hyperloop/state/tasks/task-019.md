---
id: task-019
title: Implement Tint Primitive renderer for bounded contexts
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-012]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Tint Primitive renderer for bounded contexts"
pr_description: |
  ## What and Why

  Adds categorical fill coloring to bounded context Container volumes in the Godot
  renderer. Currently, all bounded contexts render with the same material, making them
  visually indistinguishable at the overview (far) zoom tier. The Tint Primitive gives
  each bounded context a distinct desaturated fill color, allowing the human to
  immediately identify domain regions by color without reading labels.

  ## Spec Requirements Satisfied

  From `specs/core/visual-primitives.spec.md` § Tint Primitive:

  - Each bounded context receives a distinct desaturated fill color from a palette of
    4–6 categorical colors (within the preattentive discrimination limit).
  - Only ONE categorical dimension (domain identity) is encoded via Tint at a time.
    The Tint channel is not layered — assigning a new dimension replaces the previous.
  - Tint is acknowledged as the only symbolic primitive requiring a legend; the legend
    is always visible when Tint is active.

  ## Key Design Decisions

  - **Palette**: A fixed palette of 6 desaturated colors is defined in a GDScript
    constant. Colors are assigned round-robin to bounded contexts in scene graph load
    order. The palette must be WCAG-contrast-safe against the background.
  - **Godot-side only**: No changes to the scene graph JSON or extractor. The color
    assignment is purely a rendering concern determined at load time.
  - **Legend widget**: A minimal HBoxContainer UI overlay listing each active Tint
    entry (color swatch + context name). It appears whenever Tint is active (always
    for the prototype, since domain tinting is the default).
  - **Single-dimension enforcement**: The Tint channel is managed through a
    `TintManager` singleton (or autoload) that holds the active dimension label and
    palette assignment, so future facets can replace it cleanly.

  ## Files / Areas Affected

  - `godot/` — new `tint_manager.gd` (or equivalent singleton), palette constants
  - `godot/` — Container node scene or script updated to accept and apply a tint color
  - `godot/` — HUD/UI scene updated to include the Tint legend widget
  - No changes to `extractor/` or scene graph JSON format

  ## How to Verify

  1. Run the extractor on kartograph, then launch the Godot application.
  2. At the far overview zoom tier, each bounded context volume should display a
     distinct desaturated fill color.
  3. A legend widget should be visible listing each context name beside its color.
  4. No two bounded contexts should share the same hue (up to 6 unique contexts;
     if more than 6 exist, colors wrap and a note is logged).
  5. Run `godot-tests.sh` — all existing rendering tests must still pass.

  ## Caveats and Follow-up

  - The prototype always applies domain tinting. The future "facet switching" mechanism
    (changing tint to encode a different dimension) is out of prototype scope but the
    `TintManager` singleton is designed to support it.
  - If the scene graph contains more than 6 bounded contexts, colors will repeat.
    This is acceptable for the kartograph prototype (which has fewer than 6 contexts)
    and should be logged as a warning.
---

## Task

Implement the Tint Primitive in the Godot application: assign a distinct desaturated
categorical fill color to each bounded context Container volume, and show a persistent
legend widget that maps color to context name.

### Acceptance Criteria

1. Each bounded context volume is rendered with a unique desaturated fill color drawn
   from a fixed palette of 4–6 colors.
2. A legend widget is visible in the HUD listing each color and its associated context
   name whenever tinting is active.
3. No more than one categorical dimension is tinted simultaneously.
4. Existing Container geometry, LOD behavior, and edge rendering are unaffected.
5. All existing Godot tests pass.

### Implementation Notes

- Build on task-012 (Container primitive renderer), which provides the meshes/nodes
  that Tint will color.
- Define a `TintManager` autoload with a fixed 6-color palette and a method
  `assign_tints(context_ids: Array[String]) -> Dictionary` that returns a map of
  context_id → Color.
- Apply the tint color as the `albedo_color` of the Container node's material
  (or an equivalent ShaderMaterial parameter).
- The legend widget should be a lightweight CanvasLayer/Control node, not a 3D object.
