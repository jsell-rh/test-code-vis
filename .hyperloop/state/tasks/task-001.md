---
id: task-001
title: Define JSON scene graph schema
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: []
round: 0
branch: null
pr: null
---

## Goal

Produce the canonical JSON scene graph schema document that serves as the sole interface contract between the Python extractor and the Godot application.

## Scope

- Define top-level structure: `nodes` array, `edges` array, `metadata` object (no other top-level fields)
- Define node object shape: `id`, `name`, `type`, `position` (x/y/z), `size`, `parent` (nullable)
- Define edge object shape: `source`, `target`, `type`
- Define metadata object shape: `source_path`, `extracted_at` (ISO timestamp)
- Capture valid values for `type` on nodes (`bounded_context`, `module`) and edges (`cross_context`, `internal`)
- Deliver as a written schema artifact (e.g. JSON Schema file or spec document in `extractor/`) that both the extractor and Godot tasks can reference

## Out of Scope

- Layout algorithm (how positions are computed) — that is task-005
- Any implementation code
