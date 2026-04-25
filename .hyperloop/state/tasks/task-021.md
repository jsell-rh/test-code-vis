---
id: task-021
title: Extractor — emit flow paths from import chains
spec_ref: specs/visualization/data-flow.spec.md
status: not-started
phase: null
deps: [task-020, task-004]
round: 0
branch: null
pr: null
---

Extend the Python extractor to derive and emit named flow paths by tracing import
dependency chains through the already-extracted graph.

Covers `specs/visualization/data-flow.spec.md` — Requirement: Flow Shows Paths Through
Structure:
- Reuse the dependency graph built in task-004 (cross-context and internal edges) as the
  source of traversal.
- Implement a path-tracing algorithm that, given a set of entry-point nodes (top-level
  bounded contexts or designated entry modules), produces ordered sequences of node IDs
  representing how data/control flows through the system.
  - A simple heuristic: for each bounded context, trace the longest acyclic import chain
    starting from that context's outermost module; emit each distinct chain as a flow path.
  - Cycles in the dependency graph MUST be broken (skip already-visited nodes) to ensure
    `steps` arrays are acyclic.
- Assign each path a slug `id` (kebab-case of the entry node name + "-flow") and a
  human-readable `name`.
- Write the resulting `flow_paths` array to the JSON output via the output-writer module
  (task-006).
- The extractor MUST NOT fail if the dependency graph has no traceable chains; it emits
  `"flow_paths": []` in that case.
- Keep the implementation within the Python stdlib + tree-sitter constraint from
  `specs/prototype/nfr.spec.md` (no additional dependencies).
