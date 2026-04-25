---
id: task-020
title: Extend JSON schema for flow paths
spec_ref: specs/visualization/data-flow.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Add a `flow_paths` top-level array to the JSON scene graph schema so the extractor can
emit named data-flow paths and the Godot application can read and render them.

Covers `specs/visualization/data-flow.spec.md` — Requirement: Flow is On-Demand and
Requirement: Flow Shows Paths Through Structure:
- Add `flow_paths` as an optional top-level array alongside `nodes`, `edges`, and
  `metadata`; a file with no flow paths emits `"flow_paths": []`.
- Each flow path object:
  - `id` (string, unique slug — e.g. `"order-submission"`)
  - `name` (string, human-readable label — e.g. `"Order Submission Path"`)
  - `steps` (array of node id strings, ordered from entry point to terminus)
- Update the schema document (`extractor/schema.md` or `extractor/schema.json`) with the
  new field definition and examples.
- Update the Python validator function (introduced in task-001) to accept `flow_paths` as
  a valid optional top-level key and to validate each flow path object's required fields.
- The Godot application MUST NOT crash when `flow_paths` is absent or empty; it treats
  the field as optional with a default of `[]`.
