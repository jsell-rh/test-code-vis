---
id: task-001
title: Define scene graph JSON top-level structure
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: "feat(schema): define scene graph JSON top-level structure"
pr_description: |
  ## What and Why

  Establishes the JSON file format that is the sole interface contract between the
  Python extractor and the Godot application. Everything both components produce and
  consume flows through this file. Without an agreed top-level structure, neither
  side can make progress independently.

  ## Spec Requirements Satisfied

  `specs/extraction/scene-graph-schema.spec.md` — Requirement: Schema Structure

  The JSON file MUST contain exactly four top-level fields:
  - `nodes` — array of structural elements
  - `edges` — array of dependency relationships
  - `metadata` — extraction provenance object
  - `clusters` — array of pre-computed collapse suggestions

  No other top-level fields are permitted.

  ## Key Design Decisions

  - Schema is defined as a TypedDict (or dataclass) in the extractor so the Python
    type checker enforces the contract at write time.
  - The Godot loader trusts the schema and does not perform defensive top-level
    key-existence checks beyond what GDScript requires.
  - The four-field constraint is enforced: any extra keys are a schema violation.

  ## Files / Areas Affected

  - `extractor/` — new schema module defining the TypedDict structure and a
    `write_scene_graph(path, nodes, edges, metadata, clusters)` helper
  - `godot/` — new loader script stub that reads and validates the four top-level
    keys (full parsing deferred to task-011)

  ## How to Verify

  1. Run the extractor on any small Python project.
  2. Open the output JSON and confirm exactly the four keys are present at the top level.
  3. Run `python -c "import json; d=json.load(open('scene_graph.json')); assert set(d)=={'nodes','edges','metadata','clusters'}"`.

  ## Caveats / Follow-up

  Downstream tasks (task-002 through task-010) populate the content of these arrays.
  task-011 implements the full Godot loader. This task only defines and validates the
  envelope.
---
