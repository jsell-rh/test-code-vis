---
id: task-032
title: Extractor — architectural quality metric computation
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-031, task-006]
round: 0
branch: null
pr: null
---

Extend the Python extractor to compute architectural quality metrics — coupling and
centrality — for every node in the scene graph, populating the fields defined in
task-031. These metrics power the Godot evaluation view (task-033) independently of
any spec.

Covers:
- After the dependency graph is fully assembled (all edges resolved), compute for each
  node (bounded context and module level):
  - `afferent_coupling`: count of edges where this node is the target (fan-in).
  - `efferent_coupling`: count of edges where this node is the source (fan-out).
  - `instability`: `efferent / (afferent + efferent)`; define as 0.0 when both are
    zero (isolated node).
  - `centrality`: `total_degree / (N - 1)` where `total_degree = afferent + efferent`
    and `N` is the total number of nodes; normalise to [0.0, 1.0].
- Populate these values into each node's `metrics` object before the output writer
  (task-006) serialises the JSON file.
- All four metrics MUST be present on every node in the output (use 0 / 0.0 for
  isolated nodes, not null or absent), so that the Godot evaluation view can read
  them without null-checking.
- Add unit tests covering: a simple 3-node graph with known coupling values, an
  isolated node (zero coupling), and a hub node (high centrality).
- The output JSON must validate against the extended schema from task-031.
- No changes to Godot in this task.
