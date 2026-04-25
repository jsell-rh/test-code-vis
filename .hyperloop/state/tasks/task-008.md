---
id: task-008
title: Godot — JSON scene graph loader
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-001, task-007]
round: 0
branch: null
pr: null
---

Implement the GDScript module that reads and parses the JSON scene graph file.

Covers:
- Read the JSON file using `FileAccess.get_as_text()` (Godot 4.6 API — not `read_as_text()`).
- Parse with `JSON.parse_string()` and surface a structured result (nodes array, edges array,
  metadata dict).
- Accept the file path as a configurable export variable or command-line argument so different
  scene graph files can be loaded without code changes.
- On load failure (missing file, malformed JSON), emit a clear error message and halt gracefully.
- Expose the parsed data (node list, edge list) to other modules via a singleton or autoload
  so rendering scripts can access it.
