---
id: task-062
title: Extractor — independence group analysis
spec_ref: specs/visualization/orthogonal-independence.spec.md
status: not-started
phase: null
deps: [task-061, task-003]
round: 0
branch: null
pr: null
---

Compute structural independence groups for modules within each bounded context and
annotate each module node with its `independence_group` identifier as defined in
task-061.

Covers `specs/visualization/orthogonal-independence.spec.md` — Requirement:
Independence Detection:

**Algorithm** — for each bounded context:
1. Collect all module nodes whose `parent` equals this context's id.
2. Build an undirected adjacency graph using only `internal` edges whose `source` and
   `target` both belong to this module set (cross-context edges are ignored).
3. Run connected-components (BFS or DFS with a visited set) to partition the modules
   into disjoint groups.  Each transitively-connected cluster is one group.
4. A module with no internal edges to any peer forms a singleton group of its own.
5. Assign group identifiers deterministically: sort contexts alphabetically by id,
   then sort groups within a context by the lexicographically smallest member id.
   Label groups `"{context_id}:0"`, `"{context_id}:1"`, etc.
6. Set `independence_group` on each module node dict.

**Scenarios from spec**:
- Modules A, B form group 0; modules C, D (no edge to A or B) form group 1.
- Fully connected context: entire context is group 0.

**Edge cases**:
- A bounded context with a single module: that module forms its own group ":0".
- Modules with only external (cross-context) edges: treated as isolated within their
  context and each form a singleton group.

**Output**: the same node list with `independence_group` populated on every module
node.  `bounded_context` nodes are not annotated.

Use only Python standard library.  No graph library dependency.
