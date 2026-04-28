---
id: task-028
title: Extend scene graph schema with spec-reference annotations
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Add a `spec_refs` field to node objects in the JSON scene graph schema to support
conformance mode. Each code entity (bounded context, module) can carry a list of
specification references indicating which spec requirements describe its intended role.

Covers:
- Extend the node object shape in the schema document (from task-001) with an optional
  `spec_refs` field: an array of objects, each with:
  - `spec_file` (string) — relative path to the originating spec file
  - `requirement` (string) — short identifier or heading of the requirement in that spec
- `spec_refs` is optional: nodes without corresponding spec coverage carry an empty
  array or omit the field; the validator must not reject nodes lacking `spec_refs`.
- Update the Python validator function (from task-001) to accept and validate the
  optional `spec_refs` field on nodes without requiring its presence.
- Document the new field in the schema document with an example showing a bounded
  context node carrying a spec reference to a requirement in an understanding-modes spec.
- No extractor or Godot changes in this task — schema definition only.

This is the shared interface contract that task-029 (extractor spec ingestion) writes
to and task-030 (conformance view) reads from.
