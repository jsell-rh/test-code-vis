---
id: task-009
title: Godot app — containment rendering and size encoding
spec_ref: specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed
status: not_started
phase: null
deps:
- task-008
- task-004
round: 0
branch: null
pr: null
pr_title: 'feat(godot): render nested volumes with size proportional to complexity'
pr_description: "## What and Why\n\nReplaces the invisible `Node3D` stubs from task-008\
  \ with visible 3D geometry.\nBounded contexts become large translucent box volumes;\
  \ their child modules\nbecome smaller opaque volumes nested inside them. The size\
  \ of each volume is\nproportional to the node's `size` field (derived from LOC in\
  \ task-004).\n\nThis produces the first visually meaningful render: a 3D map of\
  \ kartograph's\npackage structure where \"how big\" and \"what contains what\" are\
  \ immediately\napparent.\n\n## Spec Requirements Satisfied\n\nFrom `specs/prototype/godot-application.spec.md`:\n\
  - **Containment Rendering**: bounded context appears as a larger translucent\n \
  \ volume; child modules appear as smaller opaque volumes inside it; parent\n  boundary\
  \ is visually distinct from children.\n- **Size Encoding**: module with more code\
  \ appears as a larger volume;\n  relative sizes are proportional to the LOC metric.\n\
  \nFrom `specs/prototype/prototype-scope.spec.md`:\n- **Abstract Visual Language**:\
  \ elements appear as labeled geometric volumes\n  (boxes); size reflects relative\
  \ complexity; containment is shown by nesting.\n\n## Key Design Decisions\n\n- Bounded\
  \ context nodes use a `BoxMesh` with semi-transparent material\n  (`StandardMaterial3D.transparency\
  \ = BaseMaterial3D.TRANSPARENCY_ALPHA`,\n  alpha ≈ 0.25). Module nodes use a `BoxMesh`\
  \ with opaque material.\n- Node size in 3D space: `scale = Vector3(size, size *\
  \ 0.5, size)` where\n  `size` comes from the JSON. Bounded contexts scale up by\
  \ a factor of 5 so\n  they visually contain their children (children are scaled\
  \ within parent\n  bounds).\n- Each volume has a `Label3D` child with the node `name`.\
  \ Label faces the\n  camera via `Label3D.billboard = BaseMaterial3D.BILLBOARD_ENABLED`.\n\
  - Positions are read directly from JSON `position.x/y/z`; no re-computation.\n-\
  \ A `NodeRenderer.gd` script takes a node dict and returns a configured\n  `MeshInstance3D`.\n\
  \n## Files Affected\n\n- `godot/scripts/NodeRenderer.gd`\n- `godot/scripts/SceneGraphLoader.gd`\
  \ — updated to call NodeRenderer\n- `godot/scenes/Main.tscn` — updated scene tree\n\
  - `godot/tests/test_node_renderer.gd`\n\n## How to Verify\n\nLaunch the Godot application\
  \ with kartograph's scene graph (produced by\ntask-004). Verify:\n1. Bounded contexts\
  \ appear as large translucent boxes.\n2. Module nodes appear as smaller opaque boxes\
  \ inside their parent context.\n3. Module with the highest LOC appears visually\
  \ larger than lower-LOC modules.\n4. All nodes are labeled with their name.\n\n\
  `bash .hyperloop/checks/godot-compile.sh`\n\n## Caveats\n\nAt this stage all volumes\
  \ are white/grey — color differentiation (tinting by\nbounded context) is a future\
  \ enhancement. Edges are not yet rendered (task-010).\nCamera defaults to Godot's\
  \ origin until task-011 adds proper camera controls."
---
