---
id: task-023
title: Pre-computed cluster suggestion rendering (visual hint + accept/ignore)
spec_ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4
status: not_started
phase: null
deps:
- task-022
round: 0
branch: null
pr: null
pr_title: 'feat(godot): render pre-computed cluster suggestions with visual tinting
  and accept/ignore UI'
pr_description: "## What and Why\n\nThe extractor pre-computes which module groups\
  \ are tightly coupled enough to benefit\nfrom collapsing (task-007). Without a visual\
  \ hint, the user would have to intuit which\ngroups to collapse from the spatial\
  \ layout alone. A subtle shared tint on suggestion\nmembers draws attention to the\
  \ option without forcing a decision — the user always\ninitiates the collapse.\n\
  \n## Spec Requirements Satisfied\n\nFrom `specs/visualization/spatial-structure.spec.md`:\n\
  \n- **Pre-computed cluster suggestions**: suggested clusters indicated visually\
  \ (subtle\n  shared tint or proximity grouping); human can accept (collapse) or\
  \ ignore suggestions;\n  suggestions never auto-collapse — human always initiates\n\
  \n## Key Design Decisions\n\n- On scene load, `CollapseController` (task-022) reads\
  \ `SceneGraphLoader.clusters()`.\n  For each cluster with ≥2 members, it sets a\
  \ \"suggestion tint\" on all member\n  `NodeRenderer` nodes: a subtle desaturated\
  \ yellow overlay (albedo colour blend,\n  ~15% blend factor) that does not interfere\
  \ with independence highlight colours.\n- A tooltip label is added above each suggested\
  \ cluster's centroid displaying\n  \"Collapse suggestion\" or a collapse icon. Label\
  \ is only visible at MEDIUM/NEAR LOD.\n- \"Accept\": the user double-clicks any\
  \ member in the suggested cluster → normal collapse\n  animation (task-022) plays;\
  \ tint is removed as part of the collapse.\n- \"Ignore\": right-clicking the tooltip\
  \ or pressing Escape with a member selected\n  dismisses the suggestion tint for\
  \ that cluster (session-persistent, not saved to disk).\n- If `clusters` array is\
  \ empty, no tints are applied; no UI elements are created.\n- Suggestions are not\
  \ re-applied after the user dismisses them (within the session).\n\n## Files Affected\n\
  \n- `godot/autoload/CollapseController.gd` — updated: apply suggestion tint on load,\n\
  \  dismiss-suggestion logic, suggestion tooltip lifecycle\n- `godot/scenes/NodeRenderer.gd`\
  \ — updated: `set_suggestion_tint(enabled: bool)` method\n- `godot/scenes/SuggestionTooltip.tscn`\
  \ + `SuggestionTooltip.gd` — new: floating label\n  above cluster centroid\n- `godot/tests/test_suggestions.gd`\
  \ — GUT tests: suggestion tint applied to all cluster\n  members; tint removed after\
  \ collapse; tint removed after dismiss; empty clusters →\n  no tints\n\n## Verification\n\
  \n1. GUT tests pass.\n2. In the running app (with a synthetic scene graph containing\
  \ a known cluster): member\n  nodes have a subtle yellow tint and a \"Collapse suggestion\"\
  \ label appears above them.\n3. Double-clicking a member collapses the cluster and\
  \ removes the tint.\n4. Suggestions do not auto-collapse.\n\n## Caveats\n\nThe tint\
  \ colour must be distinguishable from the independence highlight (task-021) and\n\
  the module type colour (task-011). Use yellow for suggestions, blue/cyan for independence\n\
  highlights, and context-specific hues for type colours — document the palette in\n\
  `godot/docs/colour_palette.md` as part of this task."
---
