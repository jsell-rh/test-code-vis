---
id: task-006
title: "Extractor: JSON scene graph output writer"
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-001, task-002, task-003, task-004, task-005]
round: 0
branch: null
pr: null
---

## Goal

Implement the final stage of the extractor: serialize nodes, edges, and metadata to a JSON file conforming exactly to the task-001 schema.

## Scope

- Assemble the top-level JSON object: `nodes`, `edges`, `metadata`
- `metadata` must include: `source_path` (absolute path of the analyzed codebase) and `extracted_at` (ISO 8601 UTC timestamp)
- Write the output to a configurable file path (default: `scene_graph.json` in the current directory)
- Validate that every node has `id`, `name`, `type`, `position` (x/y/z), `size`, and `parent` fields
- Validate that every edge has `source`, `target`, and `type` fields
- The output file must be directly loadable by the Godot application without transformation

## Acceptance

- Running the extractor against the kartograph codebase produces a valid `scene_graph.json`
- The file passes schema validation against the task-001 schema artifact
