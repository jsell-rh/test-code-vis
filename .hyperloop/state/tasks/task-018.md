---
id: task-018
title: Define view-spec intermediate representation schema
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps:
- task-001
round: 0
branch: null
pr: null
---

## What

Define and document the view-spec JSON format that serves as the intermediate representation between the LLM and the Godot renderer. The LLM produces a view spec; the Godot interpreter (task-019) consumes it.

The primitive set is fixed and finite: `show`, `hide`, `highlight`, `arrange`, `annotate`, `connect`. The LLM selects from these primitives — it does not invent new ones.

## Acceptance criteria

- A schema document (JSON Schema or equivalent) is written and committed under `specs/interaction/` or `extractor/schema/` (alongside the scene-graph schema from task-001).
- The schema defines the top-level structure of a view spec (version field, list of operations).
- Each operation type (`show`, `hide`, `highlight`, `arrange`, `annotate`, `connect`) has a documented structure with required and optional fields.
- Node references in view specs use the same node identifiers as the scene graph schema (task-001), ensuring the two schemas are compatible.
- The schema document includes one worked example per primitive type.

## Notes

- This is a design artifact, not executable code. The output is a schema file and documentation.
- The schema is an internal Godot/LLM concern — the Python extractor does not consume it.
- Node IDs must be consistent with task-001's scene graph schema.
