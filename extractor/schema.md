# Scene Graph JSON Schema

This document describes the JSON format produced by the Python extractor and
consumed by the Godot application. It is the sole interface contract between
the two components.

## Top-Level Structure

```json
{
  "nodes":      [ <Node>, ... ],
  "edges":      [ <Edge>, ... ],
  "metadata":   <Metadata>,
  "clusters":   [ <Cluster>, ... ],
  "flow_paths": [ <FlowPath>, ... ]
}
```

**Required fields:** `nodes`, `edges`, `metadata`, `clusters`

**Optional fields:** `flow_paths` (absent or `[]` when no flow paths are defined)

---

## Node

Represents a bounded context or module extracted from the codebase.

```json
{
  "id":                "iam",
  "name":              "IAM",
  "type":              "bounded_context",
  "position":          {"x": 10.0, "y": 0.0, "z": 5.0},
  "size":              5.0,
  "parent":            null,
  "metrics":           {"loc": 1200},
  "independence_group": "iam:0",
  "depth":             1
}
```

| Field               | Type                                        | Required | Description |
|---------------------|---------------------------------------------|----------|-------------|
| `id`                | string                                      | Yes      | Unique identifier, e.g. `"iam"` or `"iam.domain"` |
| `name`              | string                                      | Yes      | Human-readable display name |
| `type`              | `"bounded_context"` \| `"module"` \| `"spec"` | Yes   | Level of the node |
| `position`          | `{x, y, z}` (floats)                        | Yes      | Pre-computed 3D position relative to parent |
| `size`              | float                                       | Yes      | Visual size derived from complexity |
| `parent`            | string \| null                              | Yes      | ID of containing node; `null` for top-level |
| `metrics`           | `{loc: int}`                                | No       | Raw complexity metrics |
| `independence_group`| string                                      | No       | Structural independence group, e.g. `"iam:0"` |
| `depth`             | int                                         | No       | Cascade depth in simulation output |

---

## Edge

A directed dependency edge between two nodes.

```json
{
  "source": "iam",
  "target": "shared_kernel",
  "type":   "cross_context",
  "weight": 5
}
```

| Field    | Type                                         | Required | Description |
|----------|----------------------------------------------|----------|-------------|
| `source` | string                                       | Yes      | ID of the node that has the dependency |
| `target` | string                                       | Yes      | ID of the node being depended upon |
| `type`   | `"cross_context"` \| `"internal"` \| `"aggregate"` | Yes | Dependency classification |
| `weight` | int                                          | No       | Import count; absent implies 1 |

---

## Metadata

Extraction provenance recorded alongside the graph.

```json
{
  "source_path": "/home/user/code/kartograph",
  "timestamp":   "2026-04-22T12:00:00Z"
}
```

| Field         | Type   | Required | Description |
|---------------|--------|----------|-------------|
| `source_path` | string | Yes      | Absolute path to the analysed codebase |
| `timestamp`   | string | Yes      | ISO-8601 UTC extraction timestamp |

---

## Cluster

A pre-computed suggestion for a group of tightly-coupled modules.

```json
{
  "id":      "iam:cluster_0",
  "members": ["iam.application", "iam.domain"],
  "context": "iam",
  "aggregate_metrics": {
    "total_loc":  800,
    "in_degree":  3,
    "out_degree": 1
  }
}
```

| Field               | Type          | Required | Description |
|---------------------|---------------|----------|-------------|
| `id`                | string        | Yes      | Unique cluster ID, e.g. `"iam:cluster_0"` |
| `members`           | string[]      | Yes      | Node IDs of cluster members |
| `context`           | string        | Yes      | Parent bounded context ID |
| `aggregate_metrics` | AggregateMetrics | Yes   | Rolled-up complexity metrics |

### AggregateMetrics

| Field        | Type | Description |
|--------------|------|-------------|
| `total_loc`  | int  | Sum of LOC across member modules |
| `in_degree`  | int  | Edges arriving from outside the cluster |
| `out_degree` | int  | Edges leaving to nodes outside the cluster |

---

## FlowPath _(optional)_

A named path through the structural graph, representing a sequence of node
traversals for on-demand overlay display.

```json
{
  "id":    "order-submission",
  "name":  "Order Submission Path",
  "steps": ["iam", "graph", "shared_kernel"]
}
```

| Field   | Type     | Required | Description |
|---------|----------|----------|-------------|
| `id`    | string   | Yes      | Unique identifier for this path |
| `name`  | string   | Yes      | Human-readable display name |
| `steps` | string[] | Yes      | Ordered node IDs from entry point to terminus |

The `flow_paths` top-level array MAY be absent or empty (`[]`). The Godot
application treats a missing field as equivalent to `[]` and does not display
any flow overlays in that case.

### Example: scene graph with flow paths

```json
{
  "nodes":    [ ... ],
  "edges":    [ ... ],
  "metadata": { "source_path": "/home/user/code/kartograph", "timestamp": "2026-04-29T00:00:00Z" },
  "clusters": [],
  "flow_paths": [
    {
      "id":    "order-submission",
      "name":  "Order Submission Path",
      "steps": ["iam", "graph", "shared_kernel"]
    }
  ]
}
```
