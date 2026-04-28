---
id: task-047
title: Godot — Simulation Mode: filter spec nodes and edges from graph traversal
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-032, task-034]
round: 0
branch: null
pr: null
---

Extend Simulation Mode (task-032, task-034) to exclude `spec_item` nodes and
`spec_to_code` edges from all graph traversals, ensuring that failure-injection
cascades and split-service impact analysis operate on codebase structure only.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Simulation Mode,
Scenario: Failure injection ("the cascade of effects through the system is visible"
and "components that would be affected are clearly identified"):

Without this filtering, `spec_to_code` edges are reversed during failure-injection
traversal. A `spec_to_code` edge has `source = spec_item` and `target = code_node`;
task-032 finds dependents by locating edges whose `target` equals the failed node's id.
If `code_node_X` fails, this traversal will find the `spec_to_code` edge from
`spec_item_Y` to `code_node_X` and mark `spec_item_Y` as "AFFECTED" — a nonsensical
result. Spec items are design intent, not runtime dependents. Similarly, split-service
analysis (task-034) would flag spec_items as "callers" that must reconnect after a
split, producing meaningless annotations.

**Filtering rules** — applied once at simulation-mode entry, before any traversal
state is prepared:

- **Node exclusion**: build the working node list by iterating the loaded scene graph
  node list and skipping any node whose `type` field equals `"spec_item"`. Only
  working-list nodes are rendered as selectable targets, highlighted with AFFECTED /
  DOWNSTREAM labels, or counted in impact summaries. `spec_item` nodes receive no
  simulation-mode visual treatment.

- **Edge exclusion**: build the working edge list by iterating the loaded scene graph
  edge list and skipping any edge whose `type` field equals `"spec_to_code"`. All
  graph traversals (BFS/DFS for failure cascade, neighbour analysis for split-service)
  use only this filtered edge list.

**Impact on task-032 (failure injection):**
- The "find dependents" walk uses filtered edges only. No `spec_item` node appears
  in the AFFECTED or DOWNSTREAM set.
- The cascade count in "Failure affects X components (Y direct, Z transitive)" counts
  only codebase nodes.

**Impact on task-034/task-035 (split-service and failure injection extension):**
- Afferent (inbound) and efferent (outbound) neighbour discovery uses filtered edges.
  `spec_to_code` edges do not appear as caller or dependency edges.
- The split annotation "X callers, Y dependencies" counts only codebase nodes.
- The BIDIRECTIONAL flag is not set because of `spec_to_code` edges; it only reflects
  genuine code-to-code bidirectional dependencies.

**Impact on task-033 (split-service action extending task-032):**
- RECONNECT / WILL SERVE labels are placed only on codebase nodes, not on spec_items.
- The HUD summary "N services must reconnect" counts only codebase neighbours.

**Backward compatibility** — when no spec data is loaded, the scene graph contains no
`spec_item` nodes and no `spec_to_code` edges. The filtering step is a no-op; task-032
and task-034 behaviour is unchanged.

**No schema or extractor changes** — this task is a Godot-only change. It adds a
pre-traversal filtering step to the Simulation Mode scripts. The JSON scene graph
format is unchanged.

- Use only GDScript and Godot 4.6 API. No external libraries.
