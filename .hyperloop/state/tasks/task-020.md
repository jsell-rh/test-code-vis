---
id: task-020
title: 'Godot: natural language question input UI panel'
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps:
- task-007
round: 0
branch: null
pr: null
---

## What

Implement a question input UI panel in the Godot app. The user types a natural language question (e.g. "how does authentication work?" or "what depends on the user database?") and submits it. The submitted question is surfaced as a signal or callable for the LLM integration layer (task-021) to consume.

## Acceptance criteria

- A UI panel (CanvasLayer or Control node) is available in the Godot scene.
- The panel contains a single-line or multi-line text input field and a Submit button (or Enter key shortcut).
- Submitting a question emits a signal `question_submitted(text: String)`.
- The panel can be toggled open/closed without disrupting the 3D view.
- While waiting for an LLM response, the input is disabled and a loading indicator is shown.
- On receiving a response (success or error), the input is re-enabled and the indicator clears.

## Notes

- The panel does not perform any LLM call itself — it is purely input/output UI.
- Does not depend on task-018 or task-019; can be developed in parallel with the schema and interpreter.
