---
id: task-002
title: "Extractor: Python module discovery"
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

## Goal

Implement the Python extractor's module discovery stage: walk the target codebase and produce a list of node objects conforming to the task-001 schema.

## Scope

- Set up the `extractor/` Python package with a CLI entrypoint (standalone script, no dependencies beyond stdlib and `ast`)
- Accept a target codebase path as a CLI argument (defaults to `~/code/kartograph`)
- Discover all top-level bounded contexts (directories that represent DDD contexts)
- Discover nested modules within each bounded context (domain, application, infrastructure, presentation layers)
- Represent each discovered element as a node with: `id`, `name`, `type` (`bounded_context` or `module`), `parent` (null for top-level, parent id for nested)
- Exclude non-module paths (e.g. `__pycache__`, test fixtures, hidden dirs)

## Out of Scope

- Dependency edges — task-003
- Complexity metrics — task-004
- Layout / position computation — task-005
- Writing the final JSON file — task-006
