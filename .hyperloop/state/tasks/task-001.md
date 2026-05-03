---
id: task-001
title: Define JSON scene graph schema (TypedDicts + documentation)
spec_ref: null
status: closed
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: "feat: define JSON scene graph schema as Python TypedDicts"
pr_description: |
  ## What and Why

  Establishes the JSON scene graph as the sole interface contract between the Python
  extractor and the Godot application. Every subsequent extraction and rendering task
  depends on this schema being stable and well-defined. Defining it once, in code,
  prevents both sides from drifting.

  ## Spec Requirements Satisfied

  Implements all fields required by `specs/extraction/scene-graph-schema.spec.md`:

  - **Schema Structure**: top-level `nodes`, `edges`, `metadata`, `clusters` arrays/objects
  - **Node Schema**: `id`, `name`, `type`, `position` (x/y/z), `size`, `parent`,
    optional `independence_group`
  - **Edge Schema**: `source`, `target`, `type`, optional `weight`
  - **Metadata**: `source_path`, `extracted_at` timestamp
  - **Cluster Schema**: `id`, `members`, `context`, `aggregate_metrics`
    (`total_loc`, `in_degree`, `out_degree`)

  One schema field is explicitly **not** implemented in this task:
  - `cascade_depth` — excluded per prototype-scope.spec.md § Not In Scope (failure cascade
    analysis is a deferred capability, not part of the prototype)

  ## Key Design Decisions

  - Implemented as Python `TypedDict` classes in `extractor/schema.py` so the extractor
    has a single authoritative type source. Godot reads the JSON directly and does not
    share this file.
  - Position coordinates are always `float`; the extractor owns layout computation.
  - `independence_group` is `str | None` — `None` for nodes where group assignment has
    not yet been computed (e.g. top-level bounded-context nodes).
  - `weight` on edges defaults to 1 when omitted; aggregate edges carry an explicit
    integer weight.

  ## Files Affected

  - `extractor/schema.py` — new file: TypedDicts for SceneGraph, Node, Edge, Metadata,
    Cluster, AggregateMetrics
  - `extractor/tests/test_schema.py` — basic structural tests (required field presence,
    optional field defaulting)

  ## Verification

  1. `pytest extractor/tests/test_schema.py` passes with no warnings.
  2. `mypy extractor/schema.py --strict` reports no errors.
  3. All downstream tasks can import `from extractor.schema import Node, Edge, ...`
     without modification.

  ## Caveats

  The `aggregate_metrics` sub-object inside `Cluster` uses a nested TypedDict.
  If the Godot loader needs to support optional schema versions, a `version` field
  should be added to `Metadata` in a follow-up.
---
