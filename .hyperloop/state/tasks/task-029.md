---
id: task-029
title: Extractor — ingest spec files into scene graph
spec_ref: specs/core/system-purpose.spec.md
status: not-started
phase: null
deps: [task-028, task-006]
round: 0
branch: null
pr: null
---

Extend the Python extractor to accept a `--specs` directory argument, walk human-authored
spec files, and emit `spec_item` nodes into the JSON scene graph alongside the codebase
nodes.

Covers `specs/core/system-purpose.spec.md` — Requirement: Spec-Driven Context:
- Add an optional `--specs <path>` CLI argument to the extractor entry point (task-006).
  If omitted, the extractor runs as before with no spec nodes in the output.
- Walk the given specs directory and read every `*.spec.md` file.
- For each spec file, parse the top-level `## Requirements` sections and emit one
  `spec_item` node per requirement heading:
  - `id`: derived from spec file path + section slug (e.g. `"spec.system-purpose.conformance-mode"`).
  - `name`: the requirement heading text (e.g. `"Conformance Mode"`).
  - `type`: `"spec_item"`.
  - `spec_ref`: relative path to the originating spec file.
  - `spec_section`: the heading text.
  - `parent`: null (spec items are top-level in the node list).
  - `position`: place spec nodes outside the main codebase layout (e.g. on a separate
    horizontal plane or along a reserved axis so they don't overlap code nodes).
  - `size`: uniform default size (e.g. 1.0).
  - `metrics`: `{"loc": 0}` (spec items carry no code metrics).
- Attempt simple name-matching between spec requirement names and discovered codebase
  node names (e.g. `"auth"` in a spec section → `"auth"` bounded context node); emit a
  `spec_to_code` edge for each plausible match with `source` = spec node id, `target` =
  code node id.
- Unmatched spec nodes are still included in the output — the absence of a `spec_to_code`
  edge is itself meaningful (the spec item has no realized counterpart).
- Output remains valid per the schema from task-028.
- Use only Python standard library; no external parsing dependencies.
