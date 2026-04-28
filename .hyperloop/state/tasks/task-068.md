---
id: task-068
title: Godot — cluster collapse/expand supernode animation
spec_ref: specs/visualization/spatial-structure.spec.md
status: not-started
phase: null
deps: [task-061, task-009, task-013]
round: 0
branch: null
pr: null
---

Implement cluster collapse and expand mechanics: member module nodes animate into a
single supernode; edges are re-routed smoothly; expansion reverses the process.

Covers `specs/visualization/spatial-structure.spec.md` — Requirement: Cluster
Collapsing, Scenarios: Collapsing a cluster, Expanding a supernode, Nested collapsing:

**ClusterManager singleton** — add a `ClusterManager` autoload
(`godot/autoload/cluster_manager.gd`) that holds collapse state:
- `collapsed: Dictionary` mapping cluster_id → `{ supernode: MeshInstance3D,
  original_positions: Dictionary, supernode_position: Vector3 }`.

**`collapse_cluster(cluster_id: String)` method**:
1. Look up member node ids from the clusters data (loaded from JSON by task-069's
   loader extension).
2. Compute supernode position = centroid of member `MeshInstance3D` world positions.
3. Use `Tween` to animate all member `MeshInstance3D` nodes toward the centroid
   (duration: 0.4 s).
4. On tween complete: hide members (`visible = false`), create a `MeshInstance3D`
   at the centroid representing the supernode.  Scale proportional to cluster
   `aggregate_metrics.total_loc`.
5. Add a `Label3D` above the supernode:
   `"[cluster label]\nLOC: <total_loc>  In: <in_degree>  Out: <out_degree>"`.

**Edge re-routing** — for every rendered edge line whose `source` or `target` is a
cluster member: slide the endpoint to the supernode's world position using a `Tween`
in sync with the collapse animation.

**`expand_cluster(cluster_id: String)` method**:
1. Animate the supernode to scale zero and fade out via `Tween`.
2. Restore member `visible = true`; animate members from the supernode's position to
   their stored original positions (0.4 s).
3. Slide edge endpoints back to original positions in sync.
4. On tween complete: free the supernode mesh and label; remove from `collapsed`.

**Nested collapsing** — each cluster collapses independently.  After cluster X is
collapsed, any edge from a non-collapsed node to a member of X points to X's supernode.
If cluster Y is also collapsed, edges between Y's supernode and X's supernode are
re-routed to both supernodes.

**State** — all collapse state is ephemeral in `ClusterManager`.  No JSON is modified.

Use only GDScript and Godot 4.6 API.  No external libraries.
