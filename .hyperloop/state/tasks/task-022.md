---
id: task-022
title: 'Godot: wire question UI → LLM → view-spec interpreter end-to-end'
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps:
- task-019
- task-021
round: 0
branch: null
pr: null
---

## What

Connect the three moldable-views components into a working end-to-end flow: the question UI (task-020) triggers the LLM client (task-021), which returns a view spec that the interpreter (task-019) applies to the live scene. This is the integration task that closes the loop.

## Acceptance criteria

- A coordinator script (e.g. `MoldableViewController`) connects the `question_submitted` signal from the UI panel to the LLM client.
- On receiving the LLM response, the coordinator passes the view spec to the interpreter and applies it to the scene.
- On error (LLM failure, malformed spec), a user-visible error message is shown in the UI panel; the scene is not modified.
- A "Reset view" control restores the scene to its default state (calls interpreter `reset()`).
- A happy-path scenario works end-to-end: typing "what depends on the user database?", submitting, receiving a spec, and seeing the scene update accordingly.

## Notes

- This task does not add new logic to any of the three sub-components; it only wires them together.
- Integration testing requires a live LLM API key or a local mock server that returns a valid view-spec fixture.
