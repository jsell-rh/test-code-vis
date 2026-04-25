---
id: task-026
title: Godot — LLM question input and view spec generation
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps: [task-025]
round: 0
branch: null
pr: null
---

Add a natural language question interface to the Godot application: the human types a
question, an LLM generates a view spec, and the scene updates to answer the question.

Covers `specs/interaction/moldable-views.spec.md` — Requirement: Question-Driven View
Generation:
- Add a minimal overlay UI (a CanvasLayer with a LineEdit + submit Button) that appears
  when the human presses a designated key (e.g. `/` or `Q`).
- On submit, collect the question text and the current scene graph's structural summary
  (node ids, names, types, and edges — serialised as a compact JSON string from the
  already-loaded scene data).
- Send the question and structural summary to an LLM API (use the Anthropic Messages API
  or any compatible endpoint configured via an environment variable `CODE_VIS_LLM_URL`
  and `CODE_VIS_LLM_KEY`).
  - The system prompt instructs the LLM to respond with a valid view spec JSON object
    conforming to the schema from task-024, and nothing else.
  - Include the fixed primitive set definitions in the system prompt so the LLM knows
    which operations are available.
- Parse the LLM's JSON response; validate it using the view spec validator from task-024.
- If valid, call `ViewSpecInterpreter.apply(spec)` (task-025) to transform the scene.
- If invalid or the API call fails, display an error label in the overlay and do not
  change the scene.
- Pressing `Escape` dismisses the overlay and calls `ViewSpecInterpreter.reset()` to
  restore the base structural view.
- The LLM key and URL MUST NOT be hardcoded; they are read from OS environment variables
  or a `.env` file loaded at startup. Warn clearly in the Godot output log if they are
  absent rather than crashing.
- Use Godot 4.6's `HTTPRequest` node for the API call (async, non-blocking).
- Use only GDScript and Godot 4.6 API.
