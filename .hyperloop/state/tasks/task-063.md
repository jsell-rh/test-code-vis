---
id: task-063
title: Extractor — edge weight annotation and aggregate cross-context edge emission
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-061, task-003]
round: 0
branch: null
pr: null
---

Annotate individual module-level edges with `weight` and emit one aggregate edge per
directed bounded-context pair, as required by the updated schema.

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirement: Edge Schema,
Scenario: Weighted edge:

**Individual edge weight** — individual module-level edges each carry `weight: 1`
(or the field may be omitted; the schema defaults absent weight to 1).  The aggregate
edges MUST carry an explicit numeric `weight` so the validator passes.

**Aggregate edge emission**:
1. Group all cross-context edges (type: "cross_context") by directed bounded-context
   pair `(source_context_id, target_context_id)`, where the context is the top-level
   ancestor of the source/target module.
2. For each unique ordered pair (A, B): count N = total number of individual
   cross-context edges from any module in A to any module in B.
3. Emit one new edge: `{ "source": "A", "target": "B", "type": "aggregate",
   "weight": N }`.
4. Internal edges (type: "internal") do NOT produce aggregate edges.

**Scenarios**:
- Context A has 12 individual imports referencing modules in B → aggregate edge
  source:"A", target:"B", type:"aggregate", weight:12.
- No cross-context edges between two contexts → no aggregate edge for that pair.

**Output**: the edge list from task-003, augmented with aggregate edges appended at
the end.

Use only Python standard library.
