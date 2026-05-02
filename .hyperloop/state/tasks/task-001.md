---
id: task-001
title: Define JSON scene graph schema
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: "feat: define JSON scene graph schema (nodes, edges, metadata, clusters)"
pr_description: |
  ## What and Why

  This PR establishes the JSON scene graph schema — the sole interface contract
  between the Python extractor and the Godot application. Neither component may
  have direct knowledge of the other; the JSON file is their only communication
  channel.

  Defining the schema first unlocks parallel development: the extractor team can
  build toward the schema while the Godot team can write a loader against it
  using a hand-crafted fixture.

  ## Spec Requirements Satisfied

  From `specs/extraction/scene-graph-schema.spec.md`:
  - **Schema Structure** — top-level fields: `nodes`, `edges`, `metadata`, `clusters`
  - **Node Schema** — `id`, `name`, `type`, `position` (x/y/z), `size`, `parent`
    (nullable), `independence_group` (optional)
  - **Edge Schema** — `source`, `target`, `type`, `weight` (optional); aggregate
    edges with `type: "aggregate"` for far-distance rendering
  - **Metadata** — `source_path`, `extracted_at` (ISO-8601 timestamp)
  - **Cluster Schema** — `id`, `members`, `context`, `aggregate_metrics`
    (`total_loc`, `in_degree`, `out_degree`)

  ## Key Design Decisions

  - Schema is defined as a Python `TypedDict` hierarchy in
    `extractor/schema.py` so both the extractor (writer) and any future
    validation tooling (reader) can import it.
  - A JSON Schema file (`schema/scene-graph.schema.json`) is also provided for
    Godot-side validation and documentation.
  - A minimal fixture `schema/kartograph-fixture.json` is included with
    hand-authored sample data covering all node types, edge types, and a
    cluster entry. Used by Godot task-008 to bootstrap loader development.

  ## Files Affected

  - `extractor/schema.py` — TypedDict definitions
  - `schema/scene-graph.schema.json` — JSON Schema (for tooling/docs)
  - `schema/kartograph-fixture.json` — minimal test fixture

  ## How to Verify

  1. `python -c "import extractor.schema"` — no errors.
  2. `python -m pytest extractor/tests/test_schema.py` — schema field
     coverage tests pass.
  3. The fixture validates against the JSON Schema.

  ## Caveats

  Cascade depth fields (cascade/blast-radius analysis) are explicitly excluded
  — that feature is out of scope for the prototype per
  `specs/prototype/prototype-scope.spec.md` lines 89-91.
---
