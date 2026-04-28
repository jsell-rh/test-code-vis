---
id: task-072
title: Schema — define cascade depth field for simulation output
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-001, task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema to define the optional `depth` field on
node objects, which is used when the system produces cascade failure analysis output.

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirement: Cascade Depth in
Simulation Output:

> "When the system computes failure cascade analysis, each affected node MUST carry a
> `depth` value indicating its hop distance from the failure origin."

**Scope** — this task is schema definition only. The cascade computation logic (which
nodes are affected, BFS to assign depths) is a runtime operation deferred until
simulation mode enters prototype scope. This task establishes the data shape so that
future implementation has a stable contract.

**Field definition** — add to the node schema (in `extractor/schema.md`):

```
depth (integer | absent, optional)
  Only present on node objects that appear in cascade simulation output.
  Absent in the static scene graph produced by the extractor.
  Value: hop distance from the failure-origin node (1 = direct dependent,
         2 = depends on a direct dependent, etc.).
  Minimum value: 1.
  The origin node itself does NOT carry depth (it is the source, not a
  downstream affected node).
```

**Validator update** — extend the Python validator (from task-001, extended in task-061)
to accept `depth` as an OPTIONAL field on any node entry:
- If present: assert it is an integer ≥ 1.
- If absent: no error (valid for both static graph nodes and simulation nodes that
  were not reached by the cascade).
- The validator MUST NOT require `depth` on static scene graph output; the field
  is contextual to simulation runs.

**Worked example** — add to the schema document's examples section:

```json
{
  "id": "iam.application",
  "name": "Application",
  "type": "module",
  "parent": "iam",
  "position": { "x": 10.0, "y": 0.0, "z": 5.0 },
  "size": 1.4,
  "depth": 1
}
```

Comment: node `iam.application` is a direct (depth-1) dependent of the simulated
failure origin. A second-order dependent would carry `"depth": 2`.

**Non-deliverables** — do NOT implement:
- The cascade BFS/graph traversal (Godot runtime, deferred).
- Wave animation or gradient encoding (Godot rendering, deferred).
- Any extractor code that computes or writes `depth` (the extractor produces the
  static graph; cascade analysis is runtime).
