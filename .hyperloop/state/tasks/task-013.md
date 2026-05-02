---
id: task-013
title: Godot app — level-of-detail rendering (far/medium/near)
spec_ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4
status: not_started
phase: null
deps:
- task-010
- task-006
round: 0
branch: null
pr: null
pr_title: 'feat(godot): level-of-detail rendering with smooth LOD transitions'
pr_description: "## What and Why\n\nAt far zoom the scene should tell a story about\
  \ bounded contexts and their\nrelationships — not overwhelm the viewer with every\
  \ module-level edge. At\nmedium zoom the internal structure of a bounded context\
  \ should become visible.\nAt close zoom all detail is present.\n\nWithout LOD, the\
  \ scene is either too busy at overview distance or too sparse\nat detail distance.\
  \ LOD makes each zoom level semantically complete.\n\n## Spec Requirements Satisfied\n\
  \nFrom `specs/visualization/spatial-structure.spec.md`:\n- **Scale Through Zoom\
  \ — Far**: bounded contexts visible as labeled volumes;\n  only aggregate edges\
  \ (one per context pair) are shown; individual\n  module-level edges are hidden.\n\
  - **Scale Through Zoom — Medium**: internal modules fade in within context\n  volumes;\
  \ inter-module edges appear; aggregate edges dissolve into module\n  edges.\n- **Scale\
  \ Through Zoom — Near**: all edges and annotations visible; no\n  pop-in.\n- **Scale\
  \ Through Zoom — Smooth transitions**: elements fade via animated\n  opacity, never\
  \ snap to visibility.\n\nFrom `specs/extraction/scene-graph-schema.spec.md`:\n-\
  \ **Edge Schema — aggregate edge**: aggregate edges (pre-computed in task-006)\n\
  \  are used at far distance; individual edges at medium/near.\n\n## Key Design Decisions\n\
  \n- LOD is driven by camera distance to the scene centroid (not per-node\n  distance),\
  \ keeping the thresholds simple and stable.\n- Three distance bands: FAR (> 60 units),\
  \ MEDIUM (20–60 units), NEAR (< 20).\n- Nodes: in FAR mode, module-level nodes have\
  \ `modulate.a` lerped to 0;\n  bounded context nodes remain fully visible. In MEDIUM/NEAR,\
  \ module nodes\n  fade back in.\n- Edges: aggregate edges (`type == \"aggregate\"\
  `) visible in FAR/MEDIUM;\n  individual edges visible in MEDIUM/NEAR. In the MEDIUM\
  \ band, both are\n  partially visible and cross-faded (aggregate fading out as individual\n\
  \  fades in).\n- An `LODController.gd` singleton observes `Camera3D.global_position`\
  \ each\n  frame and updates a `current_lod` (FAR/MEDIUM/NEAR) when the camera\n\
  \  crosses a threshold. Node/Edge renderers subscribe to `current_lod`\n  changes\
  \ and tween their opacity.\n- Cluster suggestions (from task-006 `clusters` array)\
  \ are indicated in FAR\n  mode by a subtle shared tint (slight yellow overlay) on\
  \ member nodes —\n  see task-014 for the interactive collapse feature.\n\n## Files\
  \ Affected\n\n- `godot/scripts/LODController.gd`\n- `godot/scripts/NodeRenderer.gd`\
  \ — opacity tween logic added\n- `godot/scripts/EdgeRenderer.gd` — aggregate vs\
  \ individual visibility\n- `godot/tests/test_lod.gd`\n\n## How to Verify\n\n1. At\
  \ far zoom: only bounded context boxes and aggregate edges are visible.\n2. Zoom\
  \ in slowly: module boxes and inter-module edges fade in smoothly —\n   no pop-in.\n\
  3. Continue zooming: all edges visible at close range.\n4. Zoom out: elements fade\
  \ out smoothly without flickering.\n\n`bash .hyperloop/checks/godot-compile.sh`\n\
  `bash .hyperloop/checks/check-lod-level-tests.sh`\n`bash .hyperloop/checks/check-lod-opacity-animation.sh`\n\
  \n## Caveats\n\nDistance thresholds (60, 20 units) are calibrated for kartograph's\
  \ scene\nscale. If the layout places nodes very far apart or very close together,\
  \ these\nthresholds may need tuning. The LOD system does not handle first-person\n\
  navigation (out of scope per prototype-scope.spec.md line 95)."
---
