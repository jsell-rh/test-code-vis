---
id: task-061
title: Extend scene graph schema — clusters, independence_group, weighted/aggregate edges
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Extend the canonical scene graph schema (task-001) to define the new fields introduced
by the modified spec. All subsequent extractor and Godot tasks that use these fields
depend on this definition being stable first.

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirements: Schema Structure,
Node Schema (independence_group), Edge Schema (weight, aggregate type), Cluster Schema:

**Top-level structure** — the JSON now has four required top-level keys (in order):
`nodes`, `edges`, `metadata`, `clusters`.  No other top-level fields are permitted.

**Node schema addition** — module nodes (type: "module") MAY carry:
- `independence_group` (string | absent): group identifier within a bounded context,
  formatted as `"{context_id}:{index}"` (e.g. "iam:0", "iam:1").  Modules in the same
  group share the identifier; modules with no internal peers form singleton groups.
  The field is absent on `bounded_context` nodes.

**Edge schema additions**:
- `weight` (int | absent, defaults to 1): number of individual import statements this
  edge represents.  Individual module-level edges MAY omit `weight` (implies 1).
- `type: "aggregate"` added to the set of valid type strings.  An aggregate edge has
  `source` and `target` set to bounded-context ids and carries an explicit `weight`.

**Clusters array entry shape**:
```json
{
  "id": "<context_id>:cluster_<n>",
  "members": ["<node_id>", ...],
  "context": "<bounded_context_id>",
  "aggregate_metrics": {
    "total_loc": <int>,
    "in_degree": <int>,
    "out_degree": <int>
  }
}
```
The entry does NOT include a position; Godot computes the supernode centroid from
member node positions at runtime.

**Deliverables**:
1. Update `extractor/schema.md` (or `extractor/schema.json`) with all new fields,
   their types, and whether required or optional.
2. Update the Python validator (from task-001) to assert: `clusters` is present and
   is a list; each cluster entry has the four required keys; each aggregate edge has
   an explicit numeric `weight`.
3. Add 2–3 worked examples showing a module node with `independence_group`, an
   aggregate edge with `weight: 12`, and a full cluster entry.
