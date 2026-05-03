---
id: task-021
title: Independence queryable UI — select module, highlight orthogonal peers
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: not_started
phase: null
deps:
- task-020
round: 0
branch: null
pr: null
pr_title: 'feat(godot): select a module to highlight its orthogonal complement and
  co-dependents'
pr_description: "## What and Why\n\nIndependence becomes actionable when the user\
  \ can point to a module and immediately see\nwhat it is independent *from*. This\
  \ is the \"safe change boundary\" use case: click a\nmodule, see which modules you\
  \ can safely modify in parallel without coordination.\nThe highlight must animate\
  \ in to reinforce the spatial reading (highlighting propagates\noutward from the\
  \ selected module, not all at once).\n\n## Spec Requirements Satisfied\n\nFrom `specs/visualization/orthogonal-independence.spec.md`:\n\
  \n- **Independence as Queryable Property — Selecting a module shows its independent\
  \ peers**:\n  all modules in *other* independence groups highlighted; modules in\
  \ the selected\n  module's own group visually distinguished as \"co-dependent\"\
  ; animated transition\n- **Cross-context independence**: selected module → bounded\
  \ contexts with no transitive\n  dependency on the module's context are highlighted\
  \ as fully independent; highlight\n  animates outward from selected module\n\n##\
  \ Key Design Decisions\n\n- Selection: user clicks a `NodeRenderer` volume. Use\
  \ Godot 4's `Area3D` + collision\n  shape on each `NodeRenderer`, and a ray cast\
  \ from `CameraController` on\n  `InputEventMouseButton` LEFT click (no-drag, i.e.\
  \ mouse up without motion since LMB\n  press).\n- On selection, `SelectionController`\
  \ (new autoload) reads the clicked node's\n  `independence_group` and categorises\
  \ all other visible nodes as:\n  - \"co-dependent\": same group → dimmed (alpha\
  \ reduced, own colour retained)\n  - \"independent-peer\": different group, same\
  \ context → highlighted (bright outline or\n    emissive glow)\n  - \"context-independent\"\
  : different context with no transitive dep on selected context →\n    highlighted\
  \ at context level\n  - \"context-dependent\": different context with a transitive\
  \ dep → dimmed\n- Animation: emit `Tween` per node, staggered by distance from selected\
  \ node\n  (closer nodes animate first, giving an \"outward pulse\" effect). Duration\
  \ ~0.4s total.\n- Clicking empty space or clicking the same node again resets all\
  \ highlights to default.\n- Context-level independence is computed at runtime from\
  \ the edge data\n  (`SceneGraphLoader.edges()`) — no pre-computation needed for\
  \ the prototype.\n\n## Files Affected\n\n- `godot/autoload/SelectionController.gd`\
  \ — new: manages selection state and highlight\n  categorisation\n- `godot/scenes/NodeRenderer.gd`\
  \ — updated: `Area3D` + `CollisionShape3D` added for\n  click detection; methods\
  \ `highlight_independent()`, `dim_codependent()`, `reset()`\n- `godot/scenes/CameraController.gd`\
  \ — updated: ray cast on LMB click (no-drag)\n  forwarded to `SelectionController`\n\
  - `godot/tests/test_selection.gd` — GUT tests: selecting a node triggers correct\n\
  \  highlight/dim categorisation; click on empty space resets; animation uses Tween\n\
  \n## Verification\n\n1. GUT tests pass.\n2. In the running app: click on `iam.domain`\
  \ → modules in other independence groups\n  within IAM glow; `iam.domain`'s own\
  \ group dims slightly.\n3. Highlight animates outward from clicked module.\n4. Click\
  \ empty space → all modules return to default colour.\n\n## Caveats\n\nRuntime transitive\
  \ dependency computation for cross-context independence can be slow\non large graphs.\
  \ For the prototype (kartograph's ~6 bounded contexts), a simple BFS on\nthe edge\
  \ list is fast enough. Cache the result per selected context to avoid re-computing\n\
  on every click within the same context."
---
