---
id: task-022
title: Cluster collapse/expand UI with animated edge re-routing
spec_ref: specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4
status: not_started
phase: null
deps:
- task-013
round: 0
branch: null
pr: null
pr_title: 'feat(godot): collapse/expand cluster groups into supernodes with animated
  edge re-routing'
pr_description: "## What and Why\n\nHeavily interdependent modules create visual noise\
  \ that hides the big picture. Collapsing\nthem into a single supernode lets the\
  \ user temporarily simplify a context to see its\nexternal interface clearly. The\
  \ operation must be fully reversible and animated — a\nsudden visual change breaks\
  \ the user's spatial mental model.\n\n## Spec Requirements Satisfied\n\nFrom `specs/visualization/spatial-structure.spec.md`:\n\
  \n- **Cluster Collapsing — Collapse**: modules animate together converging into\
  \ a single\n  supernode; supernode shows aggregate metrics (total LOC, combined\
  \ in/out-degree); edges\n  entering/leaving any cluster member are re-routed to\
  \ the supernode; re-routing animates\n  (endpoints slide to supernode)\n- **Cluster\
  \ Collapsing — Expand**: supernode smoothly expands back into constituent\n  modules;\
  \ modules animate to original positions; edges re-route back with animation\n- **Cluster\
  \ Collapsing — Nested collapsing**: collapsing one cluster leaves others\n  untouched;\
  \ uncollapsed modules stay in place; their edges update if they pointed to\n  the\
  \ now-collapsed cluster\n\n## Key Design Decisions\n\n- Trigger: double-click on\
  \ a `NodeRenderer` that belongs to a cluster (determined by\n  `SceneGraphLoader.clusters()`\
  \ membership). First click selects; second click collapses.\n  A collapsed supernode\
  \ double-click expands.\n- Supernode: a new `NodeRenderer` is created at the centroid\
  \ of the collapsing cluster's\n  member positions. Size is proportional to `aggregate_metrics.total_loc`.\
  \ Label is\n  \"↗ {context}:{cluster_index}\" (collapsed indicator prefix).\n- Collapse\
  \ animation (`Tween`, ~0.4s): member nodes animate position → centroid, then\n \
  \ `visible = false`. Supernode fades in from alpha=0 to 1.\n- Edge re-routing: `EdgeRenderer`\
  \ nodes whose source or target is a collapsing member\n  update their endpoint to\
  \ the supernode position, animated over the same ~0.4s.\n- Expand animation: reverse\
  \ — supernode fades out, members fade in and animate back to\n  stored original\
  \ positions. Edges re-route back.\n- State: `CollapseController` (autoload) tracks\
  \ which clusters are collapsed, stores\n  original member positions, and manages\
  \ supernode lifecycle.\n- Nested collapsing: multiple clusters in the same context\
  \ collapse independently.\n  `CollapseController` tracks collapsed state per cluster\
  \ id.\n\n## Files Affected\n\n- `godot/autoload/CollapseController.gd` — new: collapse\
  \ state machine, centroid\n  calculation, supernode creation/destruction\n- `godot/scenes/NodeRenderer.gd`\
  \ — updated: double-click detection, collapse trigger\n- `godot/scenes/EdgeRenderer.gd`\
  \ — updated: `reroute_endpoint(node_id, new_pos)` method\n  with Tween for smooth\
  \ endpoint slide\n- `godot/tests/test_collapse.gd` — GUT tests: after collapse,\
  \ member nodes invisible\n  and supernode visible; after expand, vice versa; edge\
  \ endpoints updated correctly;\n  nested collapse does not disturb uncollapsed clusters\n\
  \n## Verification\n\n1. GUT tests pass (`check-edge-rerouting-wired.sh`).\n2. In\
  \ the running app (if kartograph has any suggested clusters): double-clicking a\n\
  \  cluster member group collapses it into a supernode showing LOC/degree metrics.\n\
  3. All edges that connected to cluster members now connect to the supernode.\n4.\
  \ Double-clicking the supernode expands back; original layout restored.\n5. Collapsing\
  \ one cluster does not affect other visible modules.\n\n## Caveats\n\nIf `SceneGraphLoader.clusters()`\
  \ is empty (no clusters above threshold for kartograph),\nthis feature has nothing\
  \ to act on — the test suite uses a synthetic fixture with a\nknown cluster. The\
  \ double-click threshold should distinguish from a single selection\nclick (task-021)."
---
