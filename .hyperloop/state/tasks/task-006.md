---
id: task-006
title: Extractor — JSON scene graph output writer
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-001, task-002, task-003, task-004, task-005]
round: 0
branch: null
pr: null
---

Implement the CLI entry point and JSON output writer for the Python extractor. This is the
assembly step that combines all prior extraction tasks into a single output file.

Covers:
- Expose a CLI command (e.g. `python -m extractor <target_path> -o <output.json>`) that
  orchestrates module discovery, dependency extraction, metric computation, and layout.
- Write the final JSON file conforming to the schema defined in task-001: top-level fields
  `nodes`, `edges`, `metadata` only.
- Populate `metadata` with `source_path` (absolute path to the target codebase) and
  `extracted_at` (ISO-8601 UTC timestamp).
- Validate output structure before writing (e.g. assert required fields are present on
  every node and edge).
- The output file must be directly loadable by the Godot application (task-008) without
  further transformation.
