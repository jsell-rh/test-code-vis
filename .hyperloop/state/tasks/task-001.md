---
id: task-001
title: Define JSON scene graph schema
spec_ref: specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21
status: not_started
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: 'feat: define JSON scene graph schema (nodes, edges, metadata, clusters)'
pr_description: "## What and Why\n\nThis PR establishes the JSON scene graph schema\
  \ — the sole interface contract\nbetween the Python extractor and the Godot application.\
  \ Neither component may\nhave direct knowledge of the other; the JSON file is their\
  \ only communication\nchannel.\n\nDefining the schema first unlocks parallel development:\
  \ the extractor team can\nbuild toward the schema while the Godot team can write\
  \ a loader against it\nusing a hand-crafted fixture.\n\n## Spec Requirements Satisfied\n\
  \nFrom `specs/extraction/scene-graph-schema.spec.md`:\n- **Schema Structure** —\
  \ top-level fields: `nodes`, `edges`, `metadata`, `clusters`\n- **Node Schema**\
  \ — `id`, `name`, `type`, `position` (x/y/z), `size`, `parent`\n  (nullable), `independence_group`\
  \ (optional)\n- **Edge Schema** — `source`, `target`, `type`, `weight` (optional);\
  \ aggregate\n  edges with `type: \"aggregate\"` for far-distance rendering\n- **Metadata**\
  \ — `source_path`, `extracted_at` (ISO-8601 timestamp)\n- **Cluster Schema** — `id`,\
  \ `members`, `context`, `aggregate_metrics`\n  (`total_loc`, `in_degree`, `out_degree`)\n\
  \n## Key Design Decisions\n\n- Schema is defined as a Python `TypedDict` hierarchy\
  \ in\n  `extractor/schema.py` so both the extractor (writer) and any future\n  validation\
  \ tooling (reader) can import it.\n- A JSON Schema file (`schema/scene-graph.schema.json`)\
  \ is also provided for\n  Godot-side validation and documentation.\n- A minimal\
  \ fixture `schema/kartograph-fixture.json` is included with\n  hand-authored sample\
  \ data covering all node types, edge types, and a\n  cluster entry. Used by Godot\
  \ task-008 to bootstrap loader development.\n\n## Files Affected\n\n- `extractor/schema.py`\
  \ — TypedDict definitions\n- `schema/scene-graph.schema.json` — JSON Schema (for\
  \ tooling/docs)\n- `schema/kartograph-fixture.json` — minimal test fixture\n\n##\
  \ How to Verify\n\n1. `python -c \"import extractor.schema\"` — no errors.\n2. `python\
  \ -m pytest extractor/tests/test_schema.py` — schema field\n   coverage tests pass.\n\
  3. The fixture validates against the JSON Schema.\n\n## Caveats\n\nCascade depth\
  \ fields (cascade/blast-radius analysis) are explicitly excluded\n— that feature\
  \ is out of scope for the prototype per\n`specs/prototype/prototype-scope.spec.md`\
  \ lines 89-91."
---
