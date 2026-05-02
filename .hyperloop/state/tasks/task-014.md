---
id: task-014
title: Godot app — cluster collapsing UI
spec_ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4
status: not_started
phase: null
deps:
- task-013
- task-006
round: 0
branch: null
pr: null
pr_title: 'feat(godot): cluster collapse/expand with supernode and animated edge re-routing'
pr_description: "## What and Why\n\nHeavily interdependent modules within a bounded\
  \ context produce visual noise:\nmany edges crisscrossing in a small area. Cluster\
  \ collapsing lets the human\nreduce this noise by merging a cluster into a single\
  \ supernode that shows\naggregate metrics while still routing all external edges\
  \ correctly.\n\nThe extractor (task-006) pre-computes cluster suggestions. This\
  \ task makes\nthem interactive: the human can click a cluster indicator to collapse\
  \ or\nexpand it.\n\n## Spec Requirements Satisfied\n\nFrom `specs/visualization/spatial-structure.spec.md`:\n\
  - **Cluster Collapsing — Collapsing a cluster**: modules animate together into\n\
  \  a supernode displaying aggregate metrics; external edges re-route to the\n  supernode\
  \ with smooth animation.\n- **Cluster Collapsing — Expanding a supernode**: supernode\
  \ expands back to\n  constituent modules; edges re-route back to original endpoints.\n\
  - **Cluster Collapsing — Pre-computed cluster suggestions**: suggested clusters\n\
  \  are visually indicated (subtle shared tint); human can accept to collapse or\n\
  \  ignore; suggestions never auto-collapse.\n- **Cluster Collapsing — Nested collapsing**:\
  \ collapsing one cluster does not\n  affect others.\n\n## Key Design Decisions\n\
  \n- Each suggested cluster (from `clusters` array) is rendered with a shared\n \
  \ subtle tint (yellow, alpha 0.15) on its member nodes — previously set up in\n\
  \  task-013.\n- Clicking on any tinted cluster member triggers a collapse prompt\
  \ (a simple\n  `ConfirmationDialog` or a click-again toggle — keep it simple for\
  \ prototype).\n- **Collapse animation**: all member nodes `Tween` their positions\
  \ to the\n  cluster centroid over 0.4 seconds; then member `MeshInstance3D` nodes\
  \ are\n  hidden and a supernode `MeshInstance3D` is shown at the centroid.\n- **Supernode\
  \ display**: `Label3D` shows cluster ID and aggregate metrics\n  (e.g. \"auth-core\
  \ | 1,240 LOC | in: 5 | out: 3\").\n- **Edge re-routing**: edges whose source or\
  \ target is a cluster member have\n  their target endpoint `Tween`d to the supernode\
  \ position. Uses a\n  `ClusterManager.gd` that tracks which nodes are collapsed\
  \ and redirects\n  `EdgeRenderer` endpoint lookups.\n- **Expand**: clicking the\
  \ supernode reverses the animation; member nodes\n  reappear at their original positions;\
  \ edges restore their original endpoints.\n\n## Files Affected\n\n- `godot/scripts/ClusterManager.gd`\n\
  - `godot/scripts/EdgeRenderer.gd` — endpoint redirection via ClusterManager\n- `godot/scripts/NodeRenderer.gd`\
  \ — cluster tint and supernode mesh\n- `godot/scripts/SceneGraphLoader.gd` — reads\
  \ `clusters` array and passes to\n  ClusterManager\n- `godot/tests/test_cluster_manager.gd`\n\
  \n## How to Verify\n\n1. Launch with kartograph scene graph. Clusters (if any detected\
  \ by task-006)\n   appear with subtle yellow tint.\n2. Click a cluster member →\
  \ animate to supernode; supernode shows aggregate\n   metrics; external edges re-route.\n\
  3. Click supernode → expand back; nodes return to original positions.\n4. Collapse\
  \ one cluster, verify adjacent clusters are unaffected.\n5. Edges re-route and restore\
  \ smoothly (no jumping).\n\n`bash .hyperloop/checks/godot-compile.sh`\n\n## Caveats\n\
  \nIf task-006 finds no clusters in kartograph (possible if coupling threshold is\n\
  too high), test with a lower threshold or a synthetic fixture. The interaction\n\
  model (click cluster member) is a prototype-grade UX — not polished for\nproduction.\
  \ The collapse/expand feature works independently of LOD state but\ninteracts: a\
  \ collapsed cluster supernode participates in LOD opacity the same\nway as any other\
  \ node."
---
