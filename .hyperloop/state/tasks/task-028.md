---
id: task-028
title: Extend JSON schema for spec nodes
spec_ref: specs/core/system-purpose.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Extend the JSON scene graph schema (task-001) to support spec nodes — a new node type
that represents a human-authored specification element alongside the realized codebase
structure.

Covers `specs/core/system-purpose.spec.md` — Requirement: Spec-Driven Context:
- Add a new `type` value `"spec_item"` to the node type vocabulary.
- Add an optional `spec_ref` field on node objects (string): the relative path of the
  originating spec file (e.g. `"specs/core/system-purpose.spec.md"`).
- Add an optional `spec_section` field on node objects (string): the section heading
  within the spec that this node represents (e.g. `"Requirement: Conformance Mode"`).
- Add an optional `realized_by` field on node objects (array of node ids): the codebase
  node(s) that implement this spec item, enabling conformance comparison.
- Add a new edge `type` value `"spec_to_code"` to represent the mapping between a spec
  node and the codebase node that realises it.
- Update the schema document (`extractor/schema.md` or `extractor/schema.json`) to
  reflect all new fields and type values.
- Update the Python validator function from task-001 to accept (but not require) the
  new optional fields; it must not reject valid scene graphs that omit them.
- The Godot loader (task-008) must not break when spec nodes or `spec_to_code` edges
  are present; the schema change must remain backward-compatible.
