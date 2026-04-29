---
id: task-120
title: Extractor — emit `metrics.loc` per node (raw line count, bounded context aggregation)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-004, task-006, task-119]
round: 0
branch: null
pr: null
---

Extend the Python extractor's output writer to populate the `metrics.loc` field on
every node in the scene graph JSON, as defined in task-119. Module and class/function
nodes carry their direct line counts; bounded context nodes carry the sum of all
descendant module line counts.

Covers `specs/core/visual-primitives.spec.md` — Requirement: LOD Shell Primitive,
Scenario: Three-tier LOD ("tier 0 (far): the context is a single Container with
aggregate metrics (total LOC, total in-degree, total out-degree)").

---

**Input** — the node list produced by task-002 (module discovery) and task-004
(complexity metrics, which computes per-module LOC). task-004 makes LOC values
available in the in-memory node representation; this task writes them to the JSON.

---

**Algorithm:**

**Step 1 — Annotate leaf nodes (modules, classes, functions):**

For each node with `type` in `("module", "class", "function")`:
- Read the LOC value already computed by task-004 for this node.
- Set `node["metrics"] = {"loc": <int>}` in the node dict.

**Step 2 — Aggregate for bounded context nodes (bottom-up):**

For each node with `type == "bounded_context"`, after all module nodes have been
annotated:
1. Collect all descendant module nodes (nodes whose `parent` chain reaches this
   bounded context id). Use a recursive walk of the parent → children index built
   from the node list.
2. Sum `descendant["metrics"]["loc"]` for each descendant module node.
   Skip descendants that have no `metrics.loc` (e.g. if task-004 did not run for
   that path).
3. Set `node["metrics"] = {"loc": <aggregated_sum>}`.

**Note on ordering:** Step 2 must run after Step 1 so descendant `metrics.loc`
values are available. Process all module-type nodes first, then bounded contexts.

---

**Output writer integration** — this task extends task-006's output writing logic
(or task-066/task-085 if the writer has already been split). Add the `metrics` dict
to the serialised node object immediately after the `size` field so the JSON output
matches the schema example in task-119.

**Worked example output fragment:**
```json
{
  "id": "iam",
  "name": "IAM",
  "type": "bounded_context",
  "position": { "x": -12.5, "y": 0.0, "z": 4.0 },
  "size": 3.2,
  "parent": null,
  "metrics": { "loc": 3200 }
}
```

---

**Edge cases:**

- Bounded context with no child modules (e.g. empty package): `metrics.loc = 0`.
- Module with no source files discovered (task-002 found directory but no .py files):
  `metrics.loc = 0` rather than absent, so task-104 can always read the field.
- Class and function nodes: emit `metrics.loc` only if task-004 computes fine-grained
  LOC for those granularities; otherwise omit `metrics` entirely on those node types.

---

**Validator assertion** (extend from task-119's validator update):
- For all `bounded_context` and `module` nodes: assert `metrics.loc` is present and
  is a non-negative integer.
- For `class` and `function` nodes: `metrics` is optional; if present, `loc` must
  be a non-negative integer.

Use only Python standard library. No external dependencies.
