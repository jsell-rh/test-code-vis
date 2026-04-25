---
id: task-003
title: Extractor — dependency extraction
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-002]
round: 0
branch: null
pr: null
---

Implement import-based dependency extraction in the Python extractor, producing edges between
discovered nodes.

Covers:
- Parse Python import statements in each discovered module using the `ast` module.
- Resolve imports to known node ids (matched against the node list from task-002).
- Emit an edge dict for each resolved dependency with `source`, `target`, and `type`.
- Cross-context edges: source and target belong to different top-level bounded contexts
  → `type: "cross_context"`.
- Internal edges: source and target belong to the same bounded context
  → `type: "internal"`.
- Ignore unresolvable imports (third-party, stdlib).
- Result is a flat list of edge dicts.
