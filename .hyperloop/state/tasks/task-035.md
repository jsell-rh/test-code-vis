---
id: task-035
title: Implement Node Primitive renderer (labeled entities at tier-2 LOD)
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: complete
phase: null
deps:
- task-011
- task-014
round: 0
branch: hyperloop/task-035
pr: https://github.com/jsell-rh/test-code-vis/pull/235
pr_title: 'feat(godot): implement Node primitive renderer for tier-2 LOD (functions/classes)'
pr_description: "## What and Why\n\nAt tier-2 LOD (near zoom), the scene must show\
  \ individual functions and classes\nas distinct visual entities within their parent\
  \ module Container. The Container\nrenderer (task-012) handles bounded context and\
  \ module-level boxes. Below that\nlevel — the individual symbol layer — there is\
  \ currently nothing to render.\nThis task fills that gap with a Node Primitive renderer.\n\
  \nThe Node primitive is defined in the spec as: \"an entity with identity, carrying\n\
  zero or more Badges. Nodes do not have baked-in types — their visual identity\n\
  comes entirely from their Badges.\" For the prototype (which has no Badge\nextraction\
  \ yet), a Node renders as a small labeled 3D object. Its label is its\nname; its\
  \ size is derived from a complexity metric (e.g. LOC or call-site count\nif available,\
  \ otherwise uniform size). All Nodes look the same visually — only\nlabels and Badges\
  \ would differentiate them — making this renderer intentionally\nsimple and composable.\n\
  \nWithout this renderer, zooming into a module at tier-2 reveals an empty box:\n\
  the Container is drawn but its constituent functions and classes are invisible.\n\
  This breaks the prototype's core \"zoom to detail\" requirement: \"WHEN the user\n\
  zooms into the IAM context, THEN the internal layers become visible.\"\n\nThe LOD\
  \ Shell (task-014) already manages when tier-2 elements fade in and out.\nThis task\
  \ provides the scene node that the LOD Shell fades in — a `NodePrimitive`\nGDScript\
  \ class that the LOD Shell can instantiate and control.\n\n## Spec Requirements\
  \ Satisfied\n\n`specs/core/visual-primitives.spec.md` — Requirement: Node Primitive\n\
  \n- A function `validate_order` is represented as a Node with its name label;\n\
  \  it appears as a plain labeled object with no special shape.\n- An entity with\
  \ no notable aspects (no Badges) renders as a plain Node with\n  its name — Badges\
  \ are additive and their absence is the default state.\n- All Nodes use the same\
  \ geometry (consistent shape vocabulary), differentiated\n  only by their name label\
  \ and size.\n\nAlso satisfies:\n`specs/prototype/prototype-scope.spec.md` — Requirement:\
  \ Zoom to Detail\n\n- Zooming into a bounded context reveals internal layers; at\
  \ tier-2, individual\n  module members (functions, classes) are visible.\n\n## Key\
  \ Design Decisions\n\n- **Geometry**: Node primitives use a flattened box (BoxMesh\
  \ with reduced\n  height) distinct from Container boxes (which use a taller box).\
  \ The visual\n  distinction is intentional: Containers have interior volume, Nodes\
  \ are\n  flat entities sitting inside Containers. At tier-2 distances the difference\n\
  \  is perceptible without requiring color or special shape.\n- **Size**: Node size\
  \ is proportional to a complexity scalar read from the node\n  JSON. For symbol-level\
  \ nodes, complexity defaults to 1.0 if no metric is\n  present. This allows uniform-sized\
  \ Nodes for now; future passes (call graph,\n  symbol table) can populate a `complexity`\
  \ field that scales the Node.\n- **Label**: A `Label3D` child node displays the\
  \ symbol name. Label visibility\n  is managed by the LOD Shell — at distance, labels\
  \ fade out before the Node\n  itself does.\n- **Position**: Node positions are read\
  \ directly from the scene graph JSON\n  (`position.x/y/z`), pre-computed by the\
  \ extractor layout pass (task-008).\n  The Node renderer does not compute layout.\n\
  - **Parenting**: Each Node scene instance is attached to its parent Container\n\
  \  node in the Godot scene tree, using the `parent` field from the JSON to find\n\
  \  the correct Container. The Container renderer (task-012) must already exist\n\
  \  in the tree before NodePrimitives are instantiated.\n- **LOD integration**: `NodePrimitive`\
  \ exposes a `set_lod_visibility(tier)`\n  method. LOD Shell (task-014) calls this\
  \ when the camera distance changes.\n  Tier-0 and tier-1: hidden (opacity 0). Tier-2:\
  \ visible (opacity 1.0). Fade\n  is animated by the LOD Shell's existing opacity\
  \ animation infrastructure.\n- **Badge slot**: the Node primitive includes a reserved\
  \ `badge_container`\n  node (empty `Node3D`) where Badge Primitive children can\
  \ be attached in a\n  future task. This slot is unused in this task but its presence\
  \ avoids\n  rework when Badges are added.\n\n## Files / Areas Affected\n\n- `godot/scenes/node_primitive.tscn`\
  \ — new scene: BoxMesh body + Label3D\n  child + empty badge_container node\n- `godot/scripts/node_primitive.gd`\
  \ — new GDScript class; reads `id`, `name`,\n  `size`/`complexity`, `position` from\
  \ a JSON dict; exposes\n  `set_lod_visibility(tier: int)` method; positions Label3D\
  \ relative to mesh\n- `godot/scripts/scene_loader.gd` — extended to instantiate\
  \ NodePrimitive\n  for every JSON node whose type is `function`, `method`, or `class`\n\
  \  (i.e. symbol-level entities, not `module` or `bounded_context` which are\n  rendered\
  \ by ContainerRenderer)\n- `godot/tests/test_node_primitive.gd` — GDScript tests\
  \ covering:\n  - node with `name: \"validate_order\"` renders Label3D with text\
  \ \"validate_order\"\n  - node with no `complexity` field renders at default size\
  \ (1.0 scale)\n  - `set_lod_visibility(0)` hides the node (modulate alpha = 0)\n\
  \  - `set_lod_visibility(2)` makes the node visible (modulate alpha = 1)\n  - node's\
  \ world position matches the `position` dict from JSON (within\n    floating-point\
  \ tolerance)\n  - node with `parent: \"iam.domain\"` is attached to the correct\
  \ Container\n    in the scene tree\n\n## How to Verify\n\n1. Run the extractor on\
  \ `~/code/kartograph` (ensure task-002 scope nesting\n   is merged so function-level\
  \ nodes appear in the JSON).\n2. Launch the Godot project and zoom to a module (IAM\
  \ domain layer).\n3. As the camera reaches tier-2 distance, individual function\
  \ and class nodes\n   should fade in inside the module Container box.\n4. Each node\
  \ displays its name as a 3D label.\n5. Zooming back out past tier-1 causes the nodes\
  \ to fade out (label first,\n   then mesh — matching LOD Shell behavior).\n6. Run\
  \ `gdscript tests/test_node_primitive.gd` — all assertions pass.\n\n## Caveats /\
  \ Follow-up\n\n- Node size uses a uniform default until a `complexity` field is\
  \ populated by\n  the symbol table pass (task-030) or call graph pass (task-032).\
  \ Uniform size\n  is acceptable for the prototype.\n- The Badge slot is present\
  \ but empty. Badge Primitive rendering is a separate\n  future task (not in current\
  \ scope). When Badges are implemented, they attach\n  as children of `badge_container`\
  \ without changing this renderer.\n- At tier-2, all symbol-level nodes (functions,\
  \ classes, methods) are rendered\n  identically. Visual differentiation between\
  \ e.g. a class and a function\n  requires either different Badge assignments or\
  \ a future shape vocabulary\n  extension — both outside current prototype scope.\n\
  - If a JSON node has a `parent` ID that does not correspond to a loaded\n  Container,\
  \ it is rendered at world origin with a warning logged. This is a\n  defensive fallback\
  \ for partial scene graphs."
---
