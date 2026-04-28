---
id: task-031
title: Extend scene graph schema with architectural quality metrics
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Add architectural quality metric fields to the JSON scene graph schema to support
evaluation mode. These metrics allow the Godot application to visualise coupling
strength and structural criticality without reference to the spec.

Covers:
- Extend the node `metrics` object in the schema document (from task-001) with the
  following optional numeric fields:
  - `afferent_coupling` (integer) — number of other nodes that depend on this node
    (fan-in); higher means more depended-upon.
  - `efferent_coupling` (integer) — number of nodes this node depends on (fan-out);
    higher means more dependencies outward.
  - `instability` (float, 0.0–1.0) — efferent / (afferent + efferent); 0 = maximally
    stable, 1 = maximally unstable.
  - `centrality` (float, 0.0–1.0) — normalised degree centrality (total edges /
    max possible edges in the graph); indicates how central this node is to the system.
- All four fields are optional: nodes without computed metrics carry absent or null
  values; the validator must not reject nodes lacking them.
- Update the Python validator function (from task-001) to accept and validate these
  fields where present (correct types, value ranges).
- Document the new fields in the schema document with an example node showing a
  highly-coupled bounded context with all four metrics populated.
- No extractor or Godot changes in this task — schema definition only.

This is the shared interface contract that task-032 (extractor metric computation)
writes to and task-033 (evaluation view) reads from.
