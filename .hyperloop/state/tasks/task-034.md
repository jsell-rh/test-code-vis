---
id: task-034
title: Schema + extractor — capture spec requirement body text
spec_ref: specs/core/system-purpose.spec.md
status: not-started
phase: null
deps: [task-028, task-029]
round: 0
branch: null
pr: null
---

Extend the JSON schema and the Python extractor so that the full body text of each spec
requirement is stored in the scene graph, making the spec's content available for
downstream inspection.

Covers `specs/core/system-purpose.spec.md` — Requirement: Spec-Driven Context, Scenario:
Spec and codebase loaded together ("the relationship between them is available for
inspection"):

**Schema extension (builds on task-028):**
- Add an optional `spec_body` field on `spec_item` node objects (string): the full
  markdown text of the requirement section, from the heading line down to (but not
  including) the next same-level heading.  Stored as a single string with internal
  newlines preserved.
- Update the schema document (`extractor/schema.md` or `extractor/schema.json`) to
  document the new field.
- Update the Python validator from task-001/task-028 to accept `spec_body` as an
  optional field; it must not reject nodes that omit it, and must not reject nodes
  that include it.

**Extractor extension (builds on task-029):**
- When walking a `*.spec.md` file and emitting `spec_item` nodes, capture all lines
  between the requirement heading and the next sibling heading (or end of file) and
  store them as `spec_body` on the node.
- Strip leading/trailing blank lines from the captured block but preserve internal
  structure (scenario bullets, sub-headings, etc.).
- If a requirement section has no body (heading immediately followed by another
  heading), emit `spec_body: ""`.
- Existing extractor behaviour (id, name, type, spec_ref, spec_section, position,
  size, metrics, spec_to_code edge heuristics) is unchanged.
- Output remains valid per the schema from task-028.
- Use only Python standard library.
