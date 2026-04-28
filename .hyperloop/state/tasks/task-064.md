---
id: task-064
title: Extractor — cluster detection (tightly-coupled module groups)
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-061, task-003, task-004]
round: 0
branch: null
pr: null
---

Identify groups of tightly-coupled modules within each bounded context and emit
cluster entries into the `clusters` array, enabling Godot to surface pre-computed
collapse suggestions to the human.

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirement: Cluster Schema:

**Coupling score** — for any two module nodes A and B within the same bounded context,
the pairwise coupling score is the count of directed internal edges between them
(both directions combined).

**Threshold** — per bounded context:
- Collect all pairwise coupling scores for module pairs within the context.
- If fewer than 2 distinct pairs exist, use a default threshold of 2.
- Otherwise, use the mean of all pairwise scores as the threshold.
- Any pair whose score strictly exceeds the threshold is "tightly coupled."

**Grouping** — build a graph of tightly-coupled pairs and find connected components
(same BFS/DFS approach as task-062).  Each connected component with ≥ 2 members is
a candidate cluster.  Singleton components are not emitted.

**Cluster entry construction** (per candidate cluster):
- `id`: `"{context_id}:cluster_{n}"` (zero-based index within the context).
- `members`: sorted list of node ids belonging to the cluster.
- `context`: the bounded-context node id.
- `aggregate_metrics`:
  - `total_loc`: sum of `metrics.loc` for all member nodes (from task-004).
  - `in_degree`: count of edges from outside the cluster that target any member.
  - `out_degree`: count of edges from any member that target outside the cluster.

**No-clusters case** — if no pair exceeds the threshold (or fewer than 2 modules
exist), no cluster entries are emitted for that context.  The top-level `clusters`
array collects entries from all contexts; it may be empty.

**Output**: a list of cluster dicts conforming to the schema in task-061.

Use only Python standard library.  No external graph or ML libraries.
