---
id: task-003
title: "Extractor: import-based dependency extraction"
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-002]
round: 0
branch: null
pr: null
---

## Goal

Implement the dependency extraction stage: parse Python imports in each module and produce edge objects conforming to the task-001 schema.

## Scope

- For each discovered module (from task-002), parse all `.py` files using `ast` to collect import statements
- Resolve imports to known node ids (from the discovery step)
- Produce edge objects: `source`, `target`, `type`
  - `type = "cross_context"` when source and target are in different top-level bounded contexts
  - `type = "internal"` when source and target are within the same bounded context
- Ignore imports that cannot be resolved to a known node (third-party, stdlib)
- Deduplicate edges (multiple files importing the same target produce one edge at the module level)

## Out of Scope

- Complexity metrics — task-004
- Layout — task-005
- JSON output — task-006
