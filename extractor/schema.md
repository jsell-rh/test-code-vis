# JSON Scene Graph Schema

This document is the authoritative description of the JSON format produced by the
Python extractor and consumed by the Godot application.  The Python type stubs in
`schema.py` (TypedDict definitions) mirror this document; if they diverge, this
document takes precedence.

---

## Top-level structure

```json
{
  "nodes":    [ … ],
  "edges":    [ … ],
  "metadata": { … },
  "clusters": [ … ]
}
```

All four keys are **required**.  No other top-level keys are permitted.

---

## Node fields

| Field                    | Type               | Required | Description |
|--------------------------|--------------------|----------|-------------|
| `id`                     | string             | yes      | Unique identifier, e.g. `"iam"` or `"iam.domain"`. |
| `name`                   | string             | yes      | Human-readable display name, e.g. `"IAM"` or `"Domain"`. |
| `type`                   | string (enum)      | yes      | Level of the node.  One of `"bounded_context"`, `"module"`, `"spec"`. |
| `position`               | Position object    | yes      | Pre-computed 3D position.  Coordinates are relative to the parent node. |
| `size`                   | number             | yes      | Normalised visual scale factor derived from `metrics.loc`.  Computed as `max(0.5, log1p(loc) / log(10))`.  Dimensionless; used by Godot to set the MeshInstance3D scale.  **Do NOT use `size` for display of raw line counts** — use `metrics.loc` instead. |
| `parent`                 | string \| null     | yes      | ID of the containing node, or `null` for top-level nodes. |
| `metrics`                | Metrics object     | no       | Raw complexity metrics.  Present for code-derived nodes where line counting has run.  Absent on nodes where it has not (e.g. spec nodes). |
| `independence_group`     | string             | no       | Structural independence group identifier, e.g. `"iam:0"`.  Present only on module nodes after independence-group computation. |
| `depth`                  | integer            | no       | Cascade depth from a failure-simulation origin node.  Present only in simulation output. |
| `betweenness_centrality` | number (float)     | no       | Normalised betweenness centrality score in [0.0, 1.0].  Fraction of shortest paths between all pairs of nodes that pass through this node.  Computed by Brandes algorithm over the undirected module graph.  Set by `compute_structural_significance()`.  A score > 0 indicates this node lies on at least one shortest path between two other nodes. |
| `is_bridge`              | boolean            | no       | True when this node is an articulation point (its removal disconnects the undirected module graph).  Set by `compute_structural_significance()`. |

### Position object

| Field | Type   | Required | Description |
|-------|--------|----------|-------------|
| `x`   | number | yes      | X coordinate (scene units). |
| `y`   | number | yes      | Y coordinate (scene units). |
| `z`   | number | yes      | Z coordinate (scene units). |

### Metrics object

Carries raw complexity metrics derived from the source tree.  The entire `metrics`
object is **optional**; its absence means "not yet computed" or "not applicable".

| Field | Type    | Required | Description |
|-------|---------|----------|-------------|
| `loc` | integer | yes (when metrics present) | Raw source line count for this node. For `bounded_context` nodes: sum of all descendant module line counts. For `module` nodes: direct line count of the module files. For class/function nodes: line count of the declaration block. Must be a non-negative integer (`>= 0`). |

**Relationship between `metrics.loc` and `size`:**

- `metrics.loc` is the *raw* input: absolute, human-readable line count.
- `size` is the *derived* output: a normalised scale factor used by Godot for
  rendering.  The LOD tier-0 display shows `"LOC: 12,400"` from `metrics.loc`; it
  does **not** invert the `size` formula.

**Worked example — bounded context node with metrics:**

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

**Worked example — spec node without metrics:**

```json
{
  "id": "spec.core.system_purpose_spec",
  "name": "System Purpose Spec",
  "type": "spec",
  "position": { "x": 0.0, "y": 0.0, "z": -25.0 },
  "size": 0.9,
  "parent": null
}
```

---

## Edge fields

| Field    | Type          | Required | Description |
|----------|---------------|----------|-------------|
| `source` | string        | yes      | ID of the node that has the dependency. |
| `target` | string        | yes      | ID of the node being depended upon. |
| `type`   | string (enum) | yes      | One of `"cross_context"`, `"internal"`, `"aggregate"`. |
| `weight` | integer       | no       | Number of individual import statements this edge represents.  Absent implies weight = 1.  Aggregate edges carry the sum of all individual import counts between the two bounded contexts. |

---

## Metadata fields

| Field         | Type   | Required | Description |
|---------------|--------|----------|-------------|
| `source_path` | string | yes      | Absolute path to the source codebase that was analysed. |
| `timestamp`   | string | yes      | ISO-8601 UTC timestamp of when the extraction was performed. |

---

## Cluster fields

Pre-computed coupling group suggestions for tightly-coupled module groups.

| Field              | Type              | Required | Description |
|--------------------|-------------------|----------|-------------|
| `id`               | string            | yes      | Unique cluster identifier, e.g. `"iam:cluster_0"`. |
| `members`          | array of strings  | yes      | Node IDs of the modules belonging to this cluster. |
| `context`          | string            | yes      | ID of the parent bounded context that contains all members. |
| `aggregate_metrics` | AggregateMetrics | yes      | Rolled-up complexity and connectivity metrics. |

### AggregateMetrics fields

| Field        | Type    | Required | Description |
|--------------|---------|----------|-------------|
| `total_loc`  | integer | yes      | Sum of lines-of-code across all member modules. |
| `in_degree`  | integer | yes      | Number of edges arriving at cluster members from outside the cluster. |
| `out_degree` | integer | yes      | Number of edges leaving cluster members to nodes outside the cluster. |

---

---

## Annotation Fields

These three optional node fields bridge the gap between mechanism (what the code does)
and meaning (what the code is for).  They implement the **Purpose-Level Annotation**
primitive from `specs/core/visual-primitives.spec.md`.

**Important:** annotation fields are populated by LLM-based annotation agents, **not**
by the deterministic extractor pipeline.  The extractor's own analysis steps do NOT
populate these fields; they remain absent in purely extractor-produced outputs.

---

### `purpose_annotation` (string | null | absent)

A human-readable sentence or short paragraph describing what this module or context
is **for**, not what it mechanically does.

| Value | Meaning |
|-------|---------|
| string | Authored purpose description |
| `null` | Annotation key present but intentionally blank |
| absent | Annotation has not been computed for this node |

Present on `module` and `bounded_context` nodes only.

**Worked example — bounded_context node:**

```json
{
  "id": "iam",
  "name": "IAM",
  "type": "bounded_context",
  "purpose_annotation": "Identity and Access Management — ensures every request is authenticated before reaching business logic, and enforces role-based access control across all bounded contexts."
}
```

---

### `beacons` (array | absent)

Each entry identifies a well-known programming pattern recognized in this node's
implementation.  Computed by the LLM or a future pattern-recognizer.

| State | Meaning |
|-------|---------|
| absent | No beacon analysis has run |
| `[]` | Analysis ran but no patterns were recognized |
| array of entries | Each entry is a `BeaconInfo` object |

**BeaconInfo object fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pattern` | string (non-empty) | yes | Short canonical name of the recognized pattern, e.g. `"retry_loop"`, `"accumulator"`, `"observer_dispatch"`, `"circuit_breaker"`, `"command_pattern"`, `"repository_pattern"`. Open vocabulary — the LLM names what it finds. |
| `description` | string | yes | One sentence explaining the specific instance. |

Unlike Badges (which have a closed fixed vocabulary), beacon `pattern` values are
**open strings**: the LLM names what it finds.  The validator does NOT check pattern
names against any fixed list.  New patterns are naturally discovered without a schema
change.

**Worked example — module node:**

```json
{
  "id": "iam.application",
  "beacons": [
    {
      "pattern": "retry_loop",
      "description": "Retries the token validation call up to 3 times with exponential backoff on transient failures."
    }
  ]
}
```

---

### `invariants` (array | absent)

Each entry is a business rule or structural constraint that the validation logic
within this node collectively enforces.

| State | Meaning |
|-------|---------|
| absent | No invariant analysis has run |
| `[]` | Analysis ran but no invariants were identified |
| array of entries | Each entry is an `InvariantInfo` object |

**InvariantInfo object fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `rule` | string (non-empty) | yes | One sentence stating the invariant in domain language. E.g. `"Order cannot ship if payment is pending."` |
| `enforced_by` | array of strings | yes | Node IDs of the modules or functions that enforce this invariant. May be empty if the enforcement path is unclear. |

Present on `module` and `bounded_context` nodes only.

**Worked example — module node:**

```json
{
  "id": "iam.domain",
  "invariants": [
    {
      "rule": "A token cannot be issued unless the requesting identity has passed all active policy checks.",
      "enforced_by": ["iam.domain", "iam.application"]
    }
  ]
}
```

---

## Validation rules

The `validate_scene_graph()` function in `schema.py` enforces the following rules
at runtime (raises `ValueError` on any violation):

1. The graph must be a `dict` with exactly the four top-level keys.
2. `nodes`, `edges`, `clusters` must be lists; `metadata` must be a dict.
3. Every node must contain: `id`, `name`, `type`, `position`, `size`, `parent`.
4. Every node's `position` must contain numeric `x`, `y`, `z` values.
5. Every edge must contain: `source`, `target`, `type`.
6. `metadata` must contain: `source_path`, `timestamp`.
7. Every cluster must contain: `id`, `members`, `context`, `aggregate_metrics`.
8. Every cluster's `aggregate_metrics` must contain: `total_loc`, `in_degree`, `out_degree`.
9. If a node's `metrics` field is present, it must be a `dict`.
10. If `metrics` is present and contains `loc`, that value must be a non-negative integer (`>= 0`).
11. If a node's `betweenness_centrality` field is present, it must be a numeric float or int (not a bool).
12. If a node's `purpose_annotation` field is present, it must be a string or `null`.
13. If a node's `beacons` field is present, it must be a list.  Each entry must be a dict with `pattern` (non-empty string) and `description` (string).  The `pattern` value is NOT validated against a fixed vocabulary.
14. If a node's `invariants` field is present, it must be a list.  Each entry must be a dict with `rule` (non-empty string) and `enforced_by` (list of strings, may be empty).
15. None of `purpose_annotation`, `beacons`, or `invariants` is required on any node.  Absent means the annotation has not been computed; the validator does NOT error on absence.
