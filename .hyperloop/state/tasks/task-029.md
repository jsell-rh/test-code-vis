---
id: task-029
title: Extractor — spec ingestion and spec-to-code mapping
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-028, task-006]
round: 0
branch: null
pr: null
---

Extend the Python extractor to accept a directory of spec files as an optional
additional input alongside the codebase. When a spec directory is provided, the
extractor parses the specs and maps named components in them to code entities in
the scene graph, populating `spec_refs` on matching nodes.

Covers:
- Add an optional `--specs <directory>` CLI argument to the extractor entry point
  (task-006) that accepts a path to a directory of Markdown spec files.
- Implement a spec parser that:
  - Recursively discovers `.md` files (and `.spec.md` files) under the spec directory.
  - Extracts component names from spec headings, scenario descriptions, and GIVEN/WHEN/THEN
    clauses (e.g., "auth service", "payment processing service", "IAM context").
  - Normalises component names for matching (lowercase, strip punctuation).
- Implement a mapper that:
  - For each extracted spec component name, searches the scene graph nodes (bounded
    contexts, modules) for a name match (exact or fuzzy — use difflib SequenceMatcher,
    threshold ≥ 0.8).
  - Populates `spec_refs` on matched nodes with the spec file path and the originating
    requirement heading.
- When `--specs` is not supplied, the extractor runs identically to pre-task behaviour
  (no `spec_refs` fields populated, existing tests must still pass).
- Add tests covering: a spec with a named component that matches a node, a spec with
  a component that has no match (no error, no spec_ref added), and the no-`--specs`
  baseline.
- The output JSON must validate against the extended schema from task-028.
