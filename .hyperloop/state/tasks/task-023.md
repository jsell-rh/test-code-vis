---
id: task-023
title: Cluster collapse/expand interaction with animated edge re-routing
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-007, task-009, task-010, task-013]
round: 0
branch: null
pr: null
pr_title: "feat(godot): cluster collapse/expand with supernode and animated edge re-routing"
pr_description: |
  ## What and Why

  Tightly-coupled modules create visual noise: many edges between a few nodes dominate
  the viewport and obscure architectural patterns elsewhere. The spatial-structure spec
  lets the user collapse a pre-computed cluster of high-coupling modules into a single
  supernode, reducing clutter while preserving the aggregate structural information.
  The collapse and expand must animate smoothly — nodes converge, edges slide to the
  supernode, then reverse on expansion.

  The extractor (task-007) pre-computes cluster suggestions and writes them to the
  `clusters` array in the scene graph JSON. This task renders those suggestions and
  implements the user-triggered collapse/expand lifecycle.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:

  - **Collapsing a cluster**: member nodes animate together into a single supernode;
    supernode displays aggregate metrics (total LOC, combined in-degree, out-degree);
    edges re-route to supernode with smooth animation.
  - **Expanding a supernode**: supernode expands back into constituent modules; modules
    animate to original positions; edges re-route back with smooth animation.
  - **Pre-computed cluster suggestions**: suggested clusters are indicated visually
    (subtle shared tint or proximity grouping); the human can accept or ignore;
    suggestions never auto-collapse.
  - **Nested collapsing**: collapsing one cluster does not affect uncollapsed clusters;
    edges to the newly collapsed cluster update while other edges remain stable.

  ## Key Design Decisions

  - On scene load, read the `clusters` array from JSON (task-007 output). For each
    cluster, apply a subtle shared tint to member node volumes (e.g. a faint background
    highlight colour) and render a "Collapse" affordance (a small button/label on the
    cluster boundary).
  - **Collapse**: on user click of the affordance, instantiate a `SupernodeVolume` at
    the centroid of member positions (Godot computes centroid from member positions; the
    JSON cluster does not prescribe it per the schema spec). Tween member nodes toward
    the centroid while simultaneously fading their opacity to 0. When tween completes,
    free member nodes; show `SupernodeVolume` with aggregate metrics label.
    Re-route all edges whose source or target was a cluster member to the `SupernodeVolume`
    by tweening the edge endpoint positions.
  - **Expand**: on user click of the supernode, reverse: re-instantiate member nodes at
    their original positions (cached before collapse), tween from centroid outward, free
    the `SupernodeVolume`, re-route edges back.
  - Store collapse state per cluster in a `ClusterStateManager` singleton so nested
    collapsing (multiple clusters in the same context) is handled independently.
  - The `SupernodeVolume` is a standard `NodeVolume` variant with aggregate metric data
    substituted; it participates in the LOD system (task-022) and the independence
    highlight system (task-021) using the union of its members' metadata.

  ## Files Affected

  - `godot/scenes/ClusterManager.gd` (new) — reads `clusters` array, applies suggestion
    tints, owns collapse/expand state machine per cluster
  - `godot/scenes/SupernodeVolume.gd` (new) — specialised NodeVolume displaying aggregate
    metrics; receives re-routed edges
  - `godot/scenes/EdgeRenderer.gd` — updated: add `reroute_endpoint(edge_id, new_target,
    duration)` method for smooth endpoint sliding
  - `godot/scenes/NodeVolume.gd` — updated: `collapse_to(centroid, duration)` and
    `expand_from(centroid, duration)` tween helpers
  - `godot/tests/test_cluster.gd` — GUT tests: after collapse, member nodes have opacity
    0 and are freed; supernode is present at centroid; edge endpoints target supernode;
    after expand, member nodes restored at original positions; edges target original
    endpoints; collapsing cluster A does not move or modify cluster B's nodes

  ## Verification

  1. GUT tests pass.
  2. Load kartograph scene: if task-007 produces cluster suggestions, a subtle tint
     appears on member nodes and a "Collapse" label is visible on the cluster boundary.
     Click it → members animate to centroid and disappear; supernode appears with LOC
     and degree metrics. Click supernode → reverses smoothly.
  3. If no clusters are suggested (empty `clusters` array), no tints or affordances
     appear, and the scene is unchanged.
  4. Collapse one cluster, then collapse a second cluster in the same context; both
     collapse independently with no interference.

  ## Caveats

  The cluster centroid is computed in Godot from member node positions (not prescribed
  by the extractor); verify this matches the schema spec's requirement. The `Tween`
  timeline for collapse/expand should be ≈ 400 ms for clarity; this is tunable via
  an exported constant. If task-007 has not completed, the implementer can mock a
  `clusters` array in the JSON for development and testing.
---
