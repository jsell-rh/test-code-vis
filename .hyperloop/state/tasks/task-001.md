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

Produce a canonical, machine-readable definition of the JSON scene graph format that
is the sole interface contract between the Python extractor and the Godot application.
All subsequent extractor tasks write to this schema; all Godot tasks read from it.

Covers:
- Document the top-level structure: exactly three keys — `nodes` (array), `edges`
  (array), `metadata` (object) — with no additional top-level fields.
- Node object shape:
  - `id` (string, unique, dot-separated path — e.g. `"iam"`, `"iam.domain"`)
  - `name` (string, human-readable label)
  - `type` (string, e.g. `"bounded_context"` or `"module"`)
  - `parent` (string | null — null for top-level nodes, parent node id for children)
  - `position` (object with `x`, `y`, `z` float fields — pre-computed by extractor)
  - `size` (float — derived from complexity metric, pre-computed by extractor)
  - `metrics` (object — arbitrary metric key/value pairs; `loc` is required)
- Edge object shape:
  - `source` (string, node id)
  - `target` (string, node id)
  - `type` (string, e.g. `"cross_context"` or `"internal"`)
- Metadata object shape:
  - `source_path` (string, absolute path to the extracted codebase)
  - `extracted_at` (string, ISO-8601 UTC timestamp)
- Deliverable: a schema document (e.g. `extractor/schema.md` or `extractor/schema.json`)
  plus a lightweight Python validator function that asserts the required fields are
  present on every node and edge (used by the output writer in task-006).
- The Godot application MUST NOT recompute positions — it renders `position` values
  verbatim from this schema.
