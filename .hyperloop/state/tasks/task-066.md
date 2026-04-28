---
id: task-066
title: Extractor — output writer: emit clusters array, validate new schema fields
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-061, task-062, task-063, task-064, task-065, task-006]
round: 0
branch: null
pr: null
---

Extend the extractor's CLI output writer (task-006) to include the `clusters` array
as the fourth required top-level field and to validate the new schema fields before
writing.

Covers `specs/extraction/scene-graph-schema.spec.md` — Requirement: Schema Structure,
Scenario: Top-level structure ("it contains a `nodes` array, an `edges` array, a
`metadata` object, and a `clusters` array — AND no other top-level fields are present"):

**Pipeline integration** — after the existing extraction steps, call:
1. task-062's independence group analysis to annotate module nodes.
2. task-063's edge weight + aggregate edge pass to augment the edge list.
3. task-065's layout separation pass (runs after task-005 positions nodes, before
   finalising positions).
4. task-064's cluster detection to produce the clusters list.

**JSON serialisation** — build the output dict with exactly four top-level keys:
`nodes`, `edges`, `metadata`, `clusters`.  The `clusters` value is the list from
task-064 (may be an empty list).

**Validator** — invoke the updated validator from task-061 before writing.  The
validator now also asserts:
- `"clusters"` is present and is a list.
- Each cluster entry has `id` (str), `members` (non-empty list of str), `context`
  (str), and `aggregate_metrics` with integer fields `total_loc`, `in_degree`,
  `out_degree`.
- No extra top-level keys beyond the four required ones.

**Backward compatibility** — an optional `--no-clusters` flag may skip task-064 and
emit an empty `clusters` array, for fast extraction runs on large codebases.  When the
flag is absent, the full pipeline runs by default.

**Output**: a JSON file directly loadable by the Godot scene graph loader that
conforms to the full schema defined in task-061.
