---
id: task-019
title: 'Godot: view-spec interpreter (apply show/hide/highlight/arrange/annotate/connect)'
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps:
- task-018
- task-007
round: 0
branch: null
pr: null
---

## What

Implement the Godot-side interpreter that parses a view-spec JSON object and applies it to the live scene. Given a view spec, the renderer adjusts which elements are shown, hidden, highlighted, arranged, annotated, or connected — without any new rendering logic being generated at runtime.

This satisfies the "View Specs as Intermediate Representation" and "Fixed Visual Primitive Set" requirements.

## Acceptance criteria

- A GDScript class `ViewSpecInterpreter` (or equivalent) accepts a parsed view-spec dictionary.
- Implements all six primitives from the schema (task-018):
  - `show` — makes a node/group visible.
  - `hide` — makes a node/group invisible or fully transparent.
  - `highlight` — applies a highlight material/color to a node or edge.
  - `arrange` — repositions nodes to a specified layout or spatial hint.
  - `annotate` — attaches a text label or tooltip to a node.
  - `connect` — draws a visual connection (line/arrow) between two nodes not otherwise connected by a dependency edge.
- Applying a view spec is idempotent; applying it twice has the same effect as once.
- A `reset()` method restores all nodes to their default scene-graph state.
- The interpreter can be exercised with a hand-authored view-spec JSON file for testing, without requiring LLM integration.

## Notes

- The interpreter must not contain per-question logic. It is a pure applier of a declarative spec.
- Node lookups use IDs from the loaded scene graph (task-007).
