---
id: task-032
title: Implement Distortion Legend renderer in Godot
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: not_started
phase: null
deps:
- task-014
- task-019
- task-020
- task-030
round: 0
branch: null
pr: null
pr_title: 'feat(godot): implement Distortion Legend (always-visible panel showing
  current view distortions)'
pr_description: "## What and Why\n\nThis PR implements the **Distortion Legend** as\
  \ defined in `specs/core/visual-primitives.spec.md`\n(Composition Principles § Distortion\
  \ Legend). Every composed view is a deliberate distortion of\nthe full codebase\
  \ — elements are hidden by LOD, edges are suppressed as power rails, Tints encode\n\
  a category. Without a legend, the human cannot tell the difference between \"this\
  \ module has no\ndependencies\" and \"this module's dependencies are suppressed.\"\
  \ The Distortion Legend makes the\ndistortion explicit and prevents the human from\
  \ mistaking a filtered view for a complete picture.\n\nThe spec frames this as a\
  \ core design principle: *what is hidden is as important as what is shown*.\n\n\
  ## Spec Requirements Satisfied\n\n- A persistent legend panel is always visible\
  \ when the 3D scene is loaded.\n- The legend shows, at minimum:\n  - **Tint encoding**:\
  \ what the active Tint colour channel represents (e.g. \"Tint: bounded context\n\
  \    domain\"). If no Tint is active, shows \"Tint: none\".\n  - **Suppressed edges**:\
  \ count of edges suppressed by power rail notation (e.g. \"Power rails:\n    3 ubiquitous\
  \ modules suppressed, 47 edges hidden\"). Reads from the metadata written by\n \
  \   task-027 and the power rail state from task-030.\n  - **LOD-hidden elements**:\
  \ count of nodes/edges not visible at the current zoom tier (e.g.\n    \"Showing\
  \ 12 of 147 modules at current zoom\").\n  - **Active Landmarks**: list of currently\
  \ highlighted Landmark nodes.\n- The legend updates dynamically as the human changes\
  \ zoom level (LOD tier) or toggles power\n  rails.\n- The legend is rendered as\
  \ a 2D overlay (CanvasLayer in Godot) rather than a 3D element, so it\n  remains\
  \ readable regardless of camera angle.\n- The Tint legend is ONLY shown when a Tint\
  \ is active; it is absent (not greyed out) otherwise.\n\n## Design Notes\n\nThe\
  \ Distortion Legend is the one element in the prototype that validates the \"principled\n\
  information loss\" design principle. Its presence makes the prototype a honest visualization\
  \ rather\nthan one that silently hides information. Even a minimal text-based panel\
  \ (a Control node with\nlabels) satisfies this requirement for the prototype.\n\n\
  ## Files / Areas Affected\n\n- `godot/` — new 2D CanvasLayer scene containing the\
  \ legend Control node.\n- The legend script queries: LOD tier state (task-014),\
  \ Tint assignments (task-019), active\n  Landmarks (task-020), and power rail suppression\
  \ counts (task-030).\n- The main scene (or scene loader, task-011) adds the legend\
  \ CanvasLayer as an always-on overlay.\n\n## How to Verify\n\n1. Load the kartograph\
  \ scene graph in Godot.\n2. Confirm: legend panel is visible in a screen corner.\n\
  3. At far zoom (tier 0): legend shows \"Showing N bounded contexts, M hidden at\
  \ this zoom\".\n4. Zoom to medium (tier 1): legend updates to show module-level\
  \ counts.\n5. With power rails active (task-030): legend shows \"Power rails: X\
  \ modules suppressed, Y edges\n   hidden\".\n6. Toggle ubiquitous edges on: legend\
  \ updates suppression count to 0 while visible.\n7. Toggle off: suppression count\
  \ returns.\n8. If Tint is active (task-019): legend shows what Tint encodes.\n9.\
  \ Godot test suite passes, no script errors.\n\n## Caveats / Follow-up\n\n- For\
  \ the prototype, the legend is read-only and informational only. Future iterations\
  \ may make\n  it interactive (click a legend item to toggle the facet).\n- The legend\
  \ does NOT describe edge weight encoding in this implementation; that is a future\n\
  \  enhancement consistent with the full Distortion Legend spec.\n- If Tint (task-019)\
  \ or Landmarks (task-020) are not yet implemented when this task runs,\n  the legend\
  \ can show placeholder text (\"Tint: not implemented\") without blocking this task.\n\
  \  The legend should be implemented even in a minimal form so the principle is established."
---
