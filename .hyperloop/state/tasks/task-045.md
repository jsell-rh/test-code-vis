---
id: task-045
title: Godot — Evaluation Mode: CRITICAL node dependent-count annotation
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-031]
round: 0
branch: null
pr: null
---

Extend the CRITICAL label rendered by Evaluation Mode (task-031) to include a second
line showing the concrete dependent count, making the single-point-of-failure risk
immediately legible without requiring the human to click through to a detail panel.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Evaluation Mode,
Scenario: Identifying single point of failure ("AND the risk it represents is clear"):

Task-031 annotates high-centrality nodes with a floating `"CRITICAL"` Label3D and
renders them at full warning intensity. A human unfamiliar with graph centrality can
see that the node is important, but cannot immediately read *what risk* that importance
represents or *how severe* that risk is. This task makes the risk concrete without
requiring an additional interaction step.

**Label extension** — for every node that task-031 annotates with a `"CRITICAL"` label,
replace the single-line text with a two-line label:

```
CRITICAL
← N dependents
```

Where N is the **total number of distinct nodes that transitively depend on this node**:
- Start from the node in question.
- Walk all edges whose `target` is this node; collect their `source` ids. These are
  direct dependents (distance 1).
- Continue transitively (BFS or DFS with a visited set to avoid cycles) collecting all
  nodes that have any path *to* this node through the directed dependency graph.
- N is the count of all such nodes (direct + transitive), excluding the node itself.
- If N = 0 (the node has no inbound paths), it will not have been classified as CRITICAL
  by task-031's degree heuristic in the first place, so this case does not arise in
  practice. Guard against it defensively and emit `"← 0 dependents"` if it occurs.

The label format uses `\n` between the two lines. Use the same `Label3D` node that
task-031 creates for CRITICAL labels; update its `text` property rather than adding a
new node.

**Visual style** — the second line should render at a slightly smaller font size than
the `"CRITICAL"` header (e.g. 80% of the header size) and in a slightly lighter shade
(white or pale orange instead of the CRITICAL header's red), so the count reads as
a sub-label rather than competing with the primary warning signal. If Godot 4.6's
`Label3D` does not support per-line font sizes, render both lines at the same size and
differentiate by colour only.

**Cleanup** — the two-line label is removed by the same cleanup logic that task-031
uses when Evaluation Mode is toggled off. No separate cleanup logic is needed because
this task modifies the same `Label3D` node task-031 creates.

**Performance** — the transitive-dependent count computation must be performed once per
CRITICAL node at mode-toggle time, from the already-loaded edge list. No re-parsing or
file I/O after initial scene load. A visited-set BFS is sufficient; the graph is bounded
by the number of nodes in the scene.

- Use only GDScript and Godot 4.6 API. No external libraries.
