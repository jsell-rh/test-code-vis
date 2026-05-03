---
id: task-022
title: Cluster collapse/expand UI with animated edge re-routing
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-013]
round: 0
branch: null
pr: null
pr_title: "feat(godot): collapse/expand cluster groups into supernodes with animated edge re-routing"
pr_description: |
  ## What and Why

  Heavily interdependent modules create visual noise that hides the big picture. Collapsing
  them into a single supernode lets the user temporarily simplify a context to see its
  external interface clearly. The operation must be fully reversible and animated — a
  sudden visual change breaks the user's spatial mental model.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:

  - **Cluster Collapsing — Collapse**: modules animate together converging into a single
    supernode; supernode shows aggregate metrics (total LOC, combined in/out-degree); edges
    entering/leaving any cluster member are re-routed to the supernode; re-routing animates
    (endpoints slide to supernode)
  - **Cluster Collapsing — Expand**: supernode smoothly expands back into constituent
    modules; modules animate to original positions; edges re-route back with animation
  - **Cluster Collapsing — Nested collapsing**: collapsing one cluster leaves others
    untouched; uncollapsed modules stay in place; their edges update if they pointed to
    the now-collapsed cluster

  ## Key Design Decisions

  - Trigger: double-click on a `NodeRenderer` that belongs to a cluster (determined by
    `SceneGraphLoader.clusters()` membership). First click selects; second click collapses.
    A collapsed supernode double-click expands.
  - Supernode: a new `NodeRenderer` is created at the centroid of the collapsing cluster's
    member positions. Size is proportional to `aggregate_metrics.total_loc`. Label is
    "↗ {context}:{cluster_index}" (collapsed indicator prefix).
  - Collapse animation (`Tween`, ~0.4s): member nodes animate position → centroid, then
    `visible = false`. Supernode fades in from alpha=0 to 1.
  - Edge re-routing: `EdgeRenderer` nodes whose source or target is a collapsing member
    update their endpoint to the supernode position, animated over the same ~0.4s.
  - Expand animation: reverse — supernode fades out, members fade in and animate back to
    stored original positions. Edges re-route back.
  - State: `CollapseController` (autoload) tracks which clusters are collapsed, stores
    original member positions, and manages supernode lifecycle.
  - Nested collapsing: multiple clusters in the same context collapse independently.
    `CollapseController` tracks collapsed state per cluster id.

  ## Files Affected

  - `godot/autoload/CollapseController.gd` — new: collapse state machine, centroid
    calculation, supernode creation/destruction
  - `godot/scenes/NodeRenderer.gd` — updated: double-click detection, collapse trigger
  - `godot/scenes/EdgeRenderer.gd` — updated: `reroute_endpoint(node_id, new_pos)` method
    with Tween for smooth endpoint slide
  - `godot/tests/test_collapse.gd` — GUT tests: after collapse, member nodes invisible
    and supernode visible; after expand, vice versa; edge endpoints updated correctly;
    nested collapse does not disturb uncollapsed clusters

  ## Verification

  1. GUT tests pass (`check-edge-rerouting-wired.sh`).
  2. In the running app (if kartograph has any suggested clusters): double-clicking a
    cluster member group collapses it into a supernode showing LOC/degree metrics.
  3. All edges that connected to cluster members now connect to the supernode.
  4. Double-clicking the supernode expands back; original layout restored.
  5. Collapsing one cluster does not affect other visible modules.

  ## Caveats

  If `SceneGraphLoader.clusters()` is empty (no clusters above threshold for kartograph),
  this feature has nothing to act on — the test suite uses a synthetic fixture with a
  known cluster. The double-click threshold should distinguish from a single selection
  click (task-021).
---
