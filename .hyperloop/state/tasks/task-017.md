---
id: task-017
title: Implement cluster collapsing mechanic
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-009, task-011, task-013]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement cluster collapse/expand with supernode and edge re-routing"
pr_description: |
  ## What and Why

  Allows the user to collapse a group of tightly-coupled modules (from the
  `clusters` array in the scene graph) into a single supernode showing aggregate
  metrics, and expand it back. This reduces visual complexity in dense bounded
  contexts without losing structural information. Pre-computed cluster suggestions
  are shown as subtle visual indicators so the user knows collapsing is possible.

  This feature is what makes the visualization tractable for large codebases:
  instead of drowning in 40 module boxes, the user can collapse a known-tight
  cluster into a single representative node.

  ## Spec Requirements Satisfied

  `specs/visualization/spatial-structure.spec.md` — Requirement: Cluster Collapsing

  - Collapse: member modules animate together, converging smoothly to a single
    supernode at their centroid. The supernode displays `aggregate_metrics`
    (total_loc, in_degree, out_degree from the cluster entry).
  - Expand: supernode smoothly expands back; modules animate outward to original
    positions.
  - Edges entering/leaving any member of the cluster are re-routed to the
    supernode on collapse; re-routed back to original endpoints on expand.
  - Edge re-routing animates smoothly (endpoints slide rather than jump).
  - Pre-computed cluster suggestions: member modules share a subtle visual
    indicator (e.g. a faint shared outline or a small icon on each member).
    Suggestions are visible but never auto-collapse — the user initiates.
  - Nested collapsing: multiple clusters in the same context can be independently
    collapsed/expanded.

  ## Key Design Decisions

  - Collapse trigger: right-click context menu on any cluster member showing
    "Collapse cluster". For the prototype, a keyboard shortcut (e.g. `C` key when
    hovering a member) is also acceptable.
  - The supernode is a new `MeshInstance3D` instantiated at the centroid of the
    member positions. Label shows the cluster id.
  - Member Container nodes are set invisible (not deleted) so expand can restore
    them at their original positions without re-parsing the JSON.
  - Edge re-routing: edges whose source or target is a cluster member have their
    endpoint moved to the supernode's world position. A Tween drives the
    endpoint-slide animation over 0.5s.
  - Suggestion indicators: each member of a suggested cluster receives a faint
    colored outline (a slightly larger wireframe box rendered behind the member
    with 20% opacity).
  - State: `collapsed: bool` per cluster is tracked in `CollapseManager`
    autoload to support nested/independent collapsing.

  ## Files / Areas Affected

  - `godot/scripts/collapse_manager.gd` — new autoload tracking collapse state
    per cluster; handles collapse/expand logic and triggers Tweens
  - `godot/scenes/supernode.tscn` — supernode visual with label and aggregate
    metric display
  - `godot/scripts/edge_renderer.gd` — extended with `reroute_edge_to_supernode()`
    and `restore_edge_endpoint()` methods
  - `godot/scripts/container_renderer.gd` — extended with cluster suggestion
    outline rendering on load
  - `godot/tests/test_collapse_manager.gd` — tests covering:
    - after collapse, member Containers are hidden; supernode is visible
    - after expand, member Containers are visible; supernode is hidden
    - edges to cluster members point to supernode position after collapse
    - two independent clusters in same context collapse independently
    - suggestion outline visible on members before any collapse

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`; confirm the `clusters` array has
     at least one entry.
  2. Launch Godot; zoom into a context with a suggested cluster. Confirm the
     subtle suggestion outlines are visible on member modules.
  3. Trigger collapse on a cluster member; confirm member boxes animate to the
     centroid and a supernode appears with aggregate metrics.
  4. Confirm edges re-route smoothly to the supernode.
  5. Trigger expand; confirm members animate back and edges return to original
     endpoints.
  6. Collapse two separate clusters in the same context; confirm they collapse
     independently.

  ## Caveats / Follow-up

  If `~/code/kartograph` produces no clusters (all module coupling below the
  threshold), increase the coupling threshold constant in `cluster_detection.py`
  (task-009) for testing. The expand/collapse animation duration and curve are
  tunable constants. Suggestions-auto-applying based on LOD is a possible future
  enhancement but is explicitly not implemented here (user always initiates).
---
