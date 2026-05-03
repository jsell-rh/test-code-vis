---
id: task-025
title: Independence queryable property — click-to-select and orthogonal highlight
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: not_started
phase: null
deps:
- task-020
round: 0
branch: null
pr: null
pr_title: 'feat(godot): click-to-select module reveals orthogonal complement with
  animated highlight'
pr_description: "## What and Why\n\nIndependence groups are already rendered with\
  \ visible spatial gaps (task-020), but the\nscene is still passive: the user must\
  \ manually compare group positions to understand\nwhat is orthogonal to what. This\
  \ PR makes independence an actively queryable property —\nthe user clicks a module\
  \ and immediately sees everything that can change without\naffecting it (the orthogonal\
  \ complement), highlighted and animated in.\n\nThis converts a layout convention\
  \ into a reasoning tool. The key question the prototype\ntests is whether spatial\
  \ 3D representation produces architectural understanding. Click-\nto-select independence\
  \ reveal is a direct test of that: the user should be able to ask\n\"what is safe\
  \ to change here?\" and get an answer in one click.\n\n## Spec Requirements Satisfied\n\
  \nImplements `specs/visualization/orthogonal-independence.spec.md` §\n\"Independence\
  \ as Queryable Property\":\n\n- **Scenario: Selecting a module shows its independent\
  \ peers** — clicking module A\n  highlights all modules in *other* independence\
  \ groups within the same bounded context\n  (the orthogonal complement). Modules\
  \ in A's own group are visually distinguished as\n  \"co-dependent\" (muted or unchanged).\
  \ The state change animates smoothly.\n\n- **Scenario: Cross-context independence**\
  \ — when module A (in context X) is selected,\n  bounded contexts that have *no\
  \ transitive dependency* on context X are highlighted as\n  fully independent at\
  \ the context level. The highlight animates outward from the\n  selected module.\n\
  \n## Key Design Decisions\n\n- **Input**: uses Godot's collision-based mouse picking\
  \ (Area3D or StaticBody3D on each\n  node volume). The existing node volume meshes\
  \ from task-010 already exist — this task\n  adds collision shapes and an `input_event`\
  \ handler.\n\n- **State machine**: the scene has two display modes — `DEFAULT` and\n\
  \  `INDEPENDENCE_HIGHLIGHTED`. Clicking a module transitions to highlighted mode;\n\
  \  clicking empty space or the same module returns to default. Only one module can\
  \ be\n  selected at a time.\n\n- **Independence data**: `independence_group` is\
  \ already present on each node from\n  task-005 (extractor) and task-020 (renderer).\
  \ The selection handler reads this field\n  to classify every other module in the\
  \ same bounded context as either co-dependent\n  (same group) or independent (different\
  \ group).\n\n- **Cross-context**: cross-context independence requires checking the\
  \ edge list for\n  transitive dependencies on context X. A context Y is fully independent\
  \ of X if no\n  path in the directed graph leads from any module in Y to any module\
  \ in X (or vice\n  versa). This reachability check runs at selection time on the\
  \ in-memory graph data\n  already loaded by task-009.\n\n- **Visual encoding**:\
  \ orthogonally independent modules/contexts get a distinct tint\n  or emissive highlight.\
  \ Co-dependent modules in the selected module's group get a\n  muted/desaturated\
  \ appearance. The selected module itself gets a selection outline or\n  bright tint.\
  \ All transitions use Godot tweens for smooth animation.\n\n- **No new extractor\
  \ work**: all data required (independence_group, edges) is already\n  present in\
  \ the scene graph JSON from tasks 005 and 006.\n\n## Files / Areas Affected\n\n\
  - `godot/scripts/independence_controller.gd` (new) — manages selection state, computes\n\
  \  orthogonal complements at runtime, coordinates highlight transitions.\n- `godot/scripts/node_renderer.gd`\
  \ (modify) — adds collision shape, mouse input\n  handler, and visual state methods\
  \ (`set_highlight_state(state: String)`).\n- `godot/scripts/main.gd` (or scene manager)\
  \ — wires node click signals to\n  `independence_controller.gd`.\n- `godot/scenes/`\
  \ — may require adding Area3D/CollisionShape3D to node volume scene.\n\n## How to\
  \ Verify\n\n1. Run the extractor on kartograph to produce `scene_graph.json`.\n\
  2. Open the Godot project and load the scene.\n3. Click on any module node. Verify:\n\
  \   - Modules in other independence groups within the same bounded context are highlighted\n\
  \     (orthogonal complement).\n   - Modules in the clicked module's own group appear\
  \ co-dependent (muted or unchanged).\n   - Bounded contexts with no transitive dependency\
  \ on the clicked module's context gain\n     a context-level highlight.\n   - The\
  \ highlight appears with a smooth animated transition (no instant pop).\n4. Click\
  \ empty space. Verify all nodes return to default appearance with animation.\n5.\
  \ Click a second module. Verify the highlight updates to reflect the new selection.\n\
  \n## Caveats and Follow-Up\n\n- The cross-context reachability check is a BFS/DFS\
  \ on the in-memory edge list. For\n  kartograph's scale this is fast enough at click\
  \ time; a future optimisation could\n  pre-compute reachability during scene load.\n\
  - The \"animate outward from selected module\" direction for the cross-context highlight\n\
  \  is a UX goal; a simple simultaneous fade-in is acceptable for the prototype if\
  \ the\n  outward propagation proves too complex to implement cleanly.\n- Hover-before-click\
  \ affordance (cursor change on hover) is optional polish; the spec\n  requires click-to-select\
  \ but not hover preview."
---
