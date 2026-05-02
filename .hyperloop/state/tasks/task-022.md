---
id: task-022
title: Implement independence queryable property (click-to-highlight independent peers)
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: in_progress
phase: spec-review
deps:
- task-005
- task-011
- task-016
round: 3
branch: hyperloop/task-022
pr: https://github.com/jsell-rh/test-code-vis/pull/232
pr_title: 'feat(godot): implement independence queryable property with animated highlight'
pr_description: "## What and Why\n\nTask-016 makes independence visible passively\
  \ — independent groups occupy distinct\nspatial regions within a bounded context.\
  \ But the human still needs to interact to\nunderstand which modules are independent\
  \ of a specific module they care about.\n\nThis task adds an interactive query:\
  \ when the human clicks/selects a module node,\nthe renderer highlights all modules\
  \ in OTHER independence groups within the same\nbounded context (the orthogonal\
  \ complement — things that can change without\naffecting the selected module). Modules\
  \ in the selected module's own group are\ndistinctly styled as \"co-dependent.\"\
  \ Unrelated contexts remain in a neutral state.\nA second click on the same node\
  \ (or click on empty space) returns to the default\nview, with smooth animated transitions\
  \ throughout.\n\nThis implements the \"Independence as Queryable Property\" requirement\
  \ from the\northogonal independence spec — the passive spatial layout (task-016)\
  \ shows WHERE\nthe groups are; this task answers \"what is independent of THIS thing\
  \ I selected?\"\n\n## Spec Requirements Satisfied\n\nFrom `specs/visualization/orthogonal-independence.spec.md`\
  \ § Independence as\nQueryable Property:\n\n- Human selects module A → all modules\
  \ in OTHER independence groups within A's\n  bounded context are highlighted as\
  \ \"independent peers.\"\n- Modules in A's own group are visually distinguished\
  \ as \"co-dependent.\"\n- Transition between default and independence-highlighted\
  \ states is animated smoothly.\n- Cross-context independence: selecting module A\
  \ in context X → bounded contexts\n  with no transitive dependency on context X\
  \ are highlighted as fully independent.\n- The highlight animates in from the selected\
  \ module outward.\n\n## Key Design Decisions\n\n- **Input**: Left-click on a Container\
  \ or Node mesh in 3D space, detected via\n  Godot's `PhysicsDirectSpaceState3D.intersect_ray`\
  \ or Area3D input events.\n- **Independence data source**: The `independence_group`\
  \ field on each node\n  (produced by task-005, serialized in task-006, loaded by\
  \ task-011) is the sole\n  data source. No additional computation is needed at query\
  \ time.\n- **Highlight modes**:\n  - `selected`: The clicked module — shown with\
  \ a bright outline or rim-light effect.\n  - `co_dependent`: Modules in the same\
  \ `independence_group` — desaturated/dimmed\n    slightly (they change together\
  \ with the selected module).\n  - `independent_peer`: Modules in OTHER groups in\
  \ the same context — highlighted\n    with a distinct accent color (e.g. a green\
  \ tint overlay) — these are the safe\n    change zone.\n  - `neutral`: Modules in\
  \ other contexts — unaffected, at their normal appearance.\n- **Cross-context query**:\
  \ Uses the context-level edges in the scene graph. Contexts\n  with no path (direct\
  \ or transitive) to context X are highlighted as independent\n  at the context volume\
  \ level (a subtle outer glow or tint shift on the context\n  Container).\n- **Animation**:\
  \ Use Godot Tweens to animate the material property change (emission,\n  albedo\
  \ multiplier, or modulate) over 0.25 s. The animation fans out from the\n  selected\
  \ node: the selected node highlights first, then co-dependent nodes\n  (within 0.05\
  \ s), then independent peers (within 0.15 s), mirroring the spec's\n  \"animates\
  \ in from the selected module outward.\"\n- **Deselect**: Clicking the same node\
  \ again or clicking empty space returns all\n  nodes to neutral state via a 0.25\
  \ s reverse tween.\n\n## Files / Areas Affected\n\n- `godot/` — new `independence_query.gd`:\
  \ stateless helper that, given a node_id\n  and the full nodes list, returns `{\
  \ node_id: \"selected\"|\"co_dependent\"|\n  \"independent_peer\"|\"neutral\" }`\
  \ for all nodes in the same context.\n- `godot/` — new `cross_context_independence.gd`:\
  \ computes which bounded contexts\n  are transitively independent of a selected\
  \ context using BFS on context-level edges.\n- `godot/` — input handling in the\
  \ main scene or camera controller: detects\n  3D click via raycast, maps hit to\
  \ node_id, calls `independence_query.gd`.\n- `godot/` — Container/Node visual state\
  \ machine: adds \"highlighted_independent\",\n  \"highlighted_codependent\", and\
  \ \"selected\" visual states with tween transitions.\n- No changes to `extractor/`\
  \ or scene graph JSON format.\n\n## How to Verify\n\n1. Run the extractor on kartograph,\
  \ launch the Godot application.\n2. Zoom into a bounded context that has at least\
  \ 2 independence groups (confirmed\n   present in kartograph from task-005 output).\n\
  3. Click on a module node in group A:\n   - The clicked node shows a bright selection\
  \ effect.\n   - Modules in the same group dim slightly (co-dependent).\n   - Modules\
  \ in other groups within the same context receive the green accent\n     (independent\
  \ peers).\n   - Modules in other contexts remain unchanged.\n4. Observe the animation:\
  \ highlight fans out from the clicked node in ~0.25 s.\n5. Click empty space — all\
  \ nodes animate back to neutral in ~0.25 s.\n6. At the context overview zoom tier,\
  \ click a bounded context volume:\n   - Contexts with no transitive dependency on\
  \ the selected context receive a\n     subtle glow/tint indicating full independence.\n\
  7. Run `godot-tests.sh` — all existing tests pass.\n8. Run `check-assigned-spec-in-scope.sh\
  \ specs/visualization/orthogonal-independence.spec.md`\n   — exits 0.\n\n## Caveats\
  \ and Follow-up\n\n- Cross-context transitive reachability (BFS over context-level\
  \ edges) is O(V+E)\n  on the context graph. For kartograph this is trivially fast\
  \ (<10 contexts).\n- The click interaction is from the top-down camera perspective\
  \ only; walk-through\n  exploration is deferred to a future phase and is not part\
  \ of this task.\n- If no independence groups exist in the loaded scene graph (all\
  \ modules in one\n  group), clicking produces no highlight and logs an info message."
---
