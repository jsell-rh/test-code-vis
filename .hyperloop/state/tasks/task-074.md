---
id: task-074
title: Schema — structural significance fields on nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema (task-061) to define the `significance`
object on module and bounded-context nodes, enabling the structural significance
extraction (task-082) and Landmark rendering (task-086) to share a stable contract.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Structural Significance
Extraction (hub detection, bridge detection, peripheral detection, community detection):

**New field — `significance` object on node entries** (present on `module` and
`bounded_context` nodes after significance analysis runs; absent on nodes not yet
analysed):

```
significance (object | absent, optional)
  hub          (bool)    — true if node has the highest in-degree tier
  bridge       (bool)    — true if node has high betweenness centrality
  peripheral   (bool)    — true if node has in-degree 0 and out-degree ≤ 1
  in_degree    (int)     — count of edges where this node appears as target
  betweenness  (float)   — normalised betweenness centrality in [0.0, 1.0]
  community_id (str|null)— detected community identifier (null if only one community)
  community_drift (bool) — true if community_id differs from declared package grouping
```

**Landmark derivation field** — add a top-level boolean `landmark: bool` to node
entries. Set to `true` for nodes that are hubs, bridges, or have in-degree 0 with
no internal out-edges (true entry points). The significance object is the evidence;
`landmark` is the derived summary consumed by Godot (task-086).

```
landmark (bool | absent, optional, default false)
  true  — this node should persist across all LOD tiers
  false or absent — normal LOD rules apply
```

**Validator updates** (extend the validator from task-061):
- `significance`, if present, MUST contain all seven sub-fields with the correct types.
- `landmark`, if present, MUST be a boolean.
- Neither field is required on any node (both optional; absent means "not yet analysed").

**Worked example** — add to the schema document's examples section:

```json
{
  "id": "iam.domain",
  "name": "Domain",
  "type": "module",
  "parent": "iam",
  "position": { "x": 0.0, "y": 0.0, "z": 0.0 },
  "size": 1.8,
  "independence_group": "iam:0",
  "significance": {
    "hub": true,
    "bridge": false,
    "peripheral": false,
    "in_degree": 12,
    "betweenness": 0.72,
    "community_id": "iam:0",
    "community_drift": false
  },
  "landmark": true
}
```

**Non-deliverables** — do NOT implement:
- The computation logic (task-082).
- Any Godot rendering (task-086).
