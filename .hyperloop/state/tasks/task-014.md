---
id: task-014
title: Godot app — cluster collapsing UI
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: not-started
phase: null
deps: [task-013, task-006]
round: 0
branch: null
pr: null
pr_title: "feat(godot): cluster collapse/expand with supernode and animated edge re-routing"
pr_description: |
  ## What and Why

  Heavily interdependent modules within a bounded context produce visual noise:
  many edges crisscrossing in a small area. Cluster collapsing lets the human
  reduce this noise by merging a cluster into a single supernode that shows
  aggregate metrics while still routing all external edges correctly.

  The extractor (task-006) pre-computes cluster suggestions. This task makes
  them interactive: the human can click a cluster indicator to collapse or
  expand it.

  ## Spec Requirements Satisfied

  From `specs/visualization/spatial-structure.spec.md`:
  - **Cluster Collapsing — Collapsing a cluster**: modules animate together into
    a supernode displaying aggregate metrics; external edges re-route to the
    supernode with smooth animation.
  - **Cluster Collapsing — Expanding a supernode**: supernode expands back to
    constituent modules; edges re-route back to original endpoints.
  - **Cluster Collapsing — Pre-computed cluster suggestions**: suggested clusters
    are visually indicated (subtle shared tint); human can accept to collapse or
    ignore; suggestions never auto-collapse.
  - **Cluster Collapsing — Nested collapsing**: collapsing one cluster does not
    affect others.

  ## Key Design Decisions

  - Each suggested cluster (from `clusters` array) is rendered with a shared
    subtle tint (yellow, alpha 0.15) on its member nodes — previously set up in
    task-013.
  - Clicking on any tinted cluster member triggers a collapse prompt (a simple
    `ConfirmationDialog` or a click-again toggle — keep it simple for prototype).
  - **Collapse animation**: all member nodes `Tween` their positions to the
    cluster centroid over 0.4 seconds; then member `MeshInstance3D` nodes are
    hidden and a supernode `MeshInstance3D` is shown at the centroid.
  - **Supernode display**: `Label3D` shows cluster ID and aggregate metrics
    (e.g. "auth-core | 1,240 LOC | in: 5 | out: 3").
  - **Edge re-routing**: edges whose source or target is a cluster member have
    their target endpoint `Tween`d to the supernode position. Uses a
    `ClusterManager.gd` that tracks which nodes are collapsed and redirects
    `EdgeRenderer` endpoint lookups.
  - **Expand**: clicking the supernode reverses the animation; member nodes
    reappear at their original positions; edges restore their original endpoints.

  ## Files Affected

  - `godot/scripts/ClusterManager.gd`
  - `godot/scripts/EdgeRenderer.gd` — endpoint redirection via ClusterManager
  - `godot/scripts/NodeRenderer.gd` — cluster tint and supernode mesh
  - `godot/scripts/SceneGraphLoader.gd` — reads `clusters` array and passes to
    ClusterManager
  - `godot/tests/test_cluster_manager.gd`

  ## How to Verify

  1. Launch with kartograph scene graph. Clusters (if any detected by task-006)
     appear with subtle yellow tint.
  2. Click a cluster member → animate to supernode; supernode shows aggregate
     metrics; external edges re-route.
  3. Click supernode → expand back; nodes return to original positions.
  4. Collapse one cluster, verify adjacent clusters are unaffected.
  5. Edges re-route and restore smoothly (no jumping).

  `bash .hyperloop/checks/godot-compile.sh`

  ## Caveats

  If task-006 finds no clusters in kartograph (possible if coupling threshold is
  too high), test with a lower threshold or a synthetic fixture. The interaction
  model (click cluster member) is a prototype-grade UX — not polished for
  production. The collapse/expand feature works independently of LOD state but
  interacts: a collapsed cluster supernode participates in LOD opacity the same
  way as any other node.
---
