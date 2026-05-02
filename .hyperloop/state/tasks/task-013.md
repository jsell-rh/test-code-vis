---
id: task-013
title: Godot app — level-of-detail rendering (far/medium/near)
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-010, task-006]
round: 0
branch: null
pr: null
pr_title: "feat(godot): level-of-detail rendering with smooth LOD transitions"
pr_description: |
  ## What and Why

  At far zoom the scene should tell a story about bounded contexts and their
  relationships — not overwhelm the viewer with every module-level edge. At
  medium zoom the internal structure of a bounded context should become visible.
  At close zoom all detail is present.

  Without LOD, the scene is either too busy at overview distance or too sparse
  at detail distance. LOD makes each zoom level semantically complete.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:
  - **Scale Through Zoom — Far**: bounded contexts visible as labeled volumes;
    only aggregate edges (one per context pair) are shown; individual
    module-level edges are hidden.
  - **Scale Through Zoom — Medium**: internal modules fade in within context
    volumes; inter-module edges appear; aggregate edges dissolve into module
    edges.
  - **Scale Through Zoom — Near**: all edges and annotations visible; no
    pop-in.
  - **Scale Through Zoom — Smooth transitions**: elements fade via animated
    opacity, never snap to visibility.

  From `specs/extraction/scene-graph-schema.spec.md`:
  - **Edge Schema — aggregate edge**: aggregate edges (pre-computed in task-006)
    are used at far distance; individual edges at medium/near.

  ## Key Design Decisions

  - LOD is driven by camera distance to the scene centroid (not per-node
    distance), keeping the thresholds simple and stable.
  - Three distance bands: FAR (> 60 units), MEDIUM (20–60 units), NEAR (< 20).
  - Nodes: in FAR mode, module-level nodes have `modulate.a` lerped to 0;
    bounded context nodes remain fully visible. In MEDIUM/NEAR, module nodes
    fade back in.
  - Edges: aggregate edges (`type == "aggregate"`) visible in FAR/MEDIUM;
    individual edges visible in MEDIUM/NEAR. In the MEDIUM band, both are
    partially visible and cross-faded (aggregate fading out as individual
    fades in).
  - An `LODController.gd` singleton observes `Camera3D.global_position` each
    frame and updates a `current_lod` (FAR/MEDIUM/NEAR) when the camera
    crosses a threshold. Node/Edge renderers subscribe to `current_lod`
    changes and tween their opacity.
  - Cluster suggestions (from task-006 `clusters` array) are indicated in FAR
    mode by a subtle shared tint (slight yellow overlay) on member nodes —
    see task-014 for the interactive collapse feature.

  ## Files Affected

  - `godot/scripts/LODController.gd`
  - `godot/scripts/NodeRenderer.gd` — opacity tween logic added
  - `godot/scripts/EdgeRenderer.gd` — aggregate vs individual visibility
  - `godot/tests/test_lod.gd`

  ## How to Verify

  1. At far zoom: only bounded context boxes and aggregate edges are visible.
  2. Zoom in slowly: module boxes and inter-module edges fade in smoothly —
     no pop-in.
  3. Continue zooming: all edges visible at close range.
  4. Zoom out: elements fade out smoothly without flickering.

  `bash .hyperloop/checks/godot-compile.sh`
  `bash .hyperloop/checks/check-lod-level-tests.sh`
  `bash .hyperloop/checks/check-lod-opacity-animation.sh`

  ## Caveats

  Distance thresholds (60, 20 units) are calibrated for kartograph's scene
  scale. If the layout places nodes very far apart or very close together, these
  thresholds may need tuning. The LOD system does not handle first-person
  navigation (out of scope per prototype-scope.spec.md line 95).
---
