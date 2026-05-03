---
id: task-023
title: Pre-computed cluster suggestion rendering (visual hint + accept/ignore)
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-022]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render pre-computed cluster suggestions with visual tinting and accept/ignore UI"
pr_description: |
  ## What and Why

  The extractor pre-computes which module groups are tightly coupled enough to benefit
  from collapsing (task-007). Without a visual hint, the user would have to intuit which
  groups to collapse from the spatial layout alone. A subtle shared tint on suggestion
  members draws attention to the option without forcing a decision — the user always
  initiates the collapse.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:

  - **Pre-computed cluster suggestions**: suggested clusters indicated visually (subtle
    shared tint or proximity grouping); human can accept (collapse) or ignore suggestions;
    suggestions never auto-collapse — human always initiates

  ## Key Design Decisions

  - On scene load, `CollapseController` (task-022) reads `SceneGraphLoader.clusters()`.
    For each cluster with ≥2 members, it sets a "suggestion tint" on all member
    `NodeRenderer` nodes: a subtle desaturated yellow overlay (albedo colour blend,
    ~15% blend factor) that does not interfere with independence highlight colours.
  - A tooltip label is added above each suggested cluster's centroid displaying
    "Collapse suggestion" or a collapse icon. Label is only visible at MEDIUM/NEAR LOD.
  - "Accept": the user double-clicks any member in the suggested cluster → normal collapse
    animation (task-022) plays; tint is removed as part of the collapse.
  - "Ignore": right-clicking the tooltip or pressing Escape with a member selected
    dismisses the suggestion tint for that cluster (session-persistent, not saved to disk).
  - If `clusters` array is empty, no tints are applied; no UI elements are created.
  - Suggestions are not re-applied after the user dismisses them (within the session).

  ## Files Affected

  - `godot/autoload/CollapseController.gd` — updated: apply suggestion tint on load,
    dismiss-suggestion logic, suggestion tooltip lifecycle
  - `godot/scenes/NodeRenderer.gd` — updated: `set_suggestion_tint(enabled: bool)` method
  - `godot/scenes/SuggestionTooltip.tscn` + `SuggestionTooltip.gd` — new: floating label
    above cluster centroid
  - `godot/tests/test_suggestions.gd` — GUT tests: suggestion tint applied to all cluster
    members; tint removed after collapse; tint removed after dismiss; empty clusters →
    no tints

  ## Verification

  1. GUT tests pass.
  2. In the running app (with a synthetic scene graph containing a known cluster): member
    nodes have a subtle yellow tint and a "Collapse suggestion" label appears above them.
  3. Double-clicking a member collapses the cluster and removes the tint.
  4. Suggestions do not auto-collapse.

  ## Caveats

  The tint colour must be distinguishable from the independence highlight (task-021) and
  the module type colour (task-011). Use yellow for suggestions, blue/cyan for independence
  highlights, and context-specific hues for type colours — document the palette in
  `godot/docs/colour_palette.md` as part of this task.
---
