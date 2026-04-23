---
id: task-021
title: 'Godot: LLM API integration — question + graph context → view spec'
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps:
- task-018
- task-020
round: 0
branch: null
pr: null
---

## What

Implement the GDScript module that takes a natural language question and the loaded scene graph, calls an LLM API, and returns a parsed view-spec dictionary. The LLM is prompted with the question, the structural graph as context, and the view-spec schema (task-018) as the required output format.

## Acceptance criteria

- A GDScript class `LLMViewSpecClient` (or equivalent) exposes an async method `ask(question: String, graph_context: Dictionary) -> Dictionary`.
- The method constructs a prompt that includes: the user question, a serialised summary of the scene graph (node IDs, types, edges), and the view-spec schema as the required response format.
- The method makes an HTTP POST request to a configurable LLM API endpoint (e.g. OpenAI-compatible or Claude API).
- The API key and endpoint are read from a config file or environment variable — never hardcoded.
- The response is parsed and returned as a GDScript Dictionary matching the view-spec schema.
- If the API call fails or the response is malformed, an error is returned gracefully (no crash).
- The module can be tested independently by passing a fixture question and a mock graph context.

## Notes

- Godot's `HTTPRequest` node is the standard mechanism for HTTP calls in GDScript.
- The LLM must be constrained to emit only view-spec primitives defined in task-018. This is enforced via prompt engineering, not runtime validation.
- The specific LLM provider is not fixed; the endpoint/key config should make it easy to switch.
