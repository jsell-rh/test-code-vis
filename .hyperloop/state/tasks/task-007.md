---
id: task-007
title: Implement edge schema fields in extractor output (including aggregate edges)
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-001, task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement edge schema with aggregate edges"
pr_description: |
  ## What and Why

  Serializes the module dependency graph (task-003) into the `edges` array of the
  scene graph JSON. Critically, this task also computes and emits *aggregate* edges
  — one edge per context pair summarizing total cross-context import weight. The
  LOD rendering in Godot uses aggregate edges at far zoom (one thick line between
  two bounded contexts) and individual module-level edges at near zoom. Without the
  aggregate edges, the far-zoom view would either show overwhelming detail or nothing.

  ## Spec Requirements Satisfied

  `specs/extraction/scene-graph-schema.spec.md` — Requirement: Edge Schema

  Each edge in the `edges` array MUST carry:
  - `source` — source node id
  - `target` — target node id
  - `type` — one of: `"internal"` (intra-context), `"cross_context"`,
    `"aggregate"` (context-level summary), `"external"` (third-party/stdlib)
  - `weight` — integer count of individual import statements (defaults to 1 if
    omitted)

  Aggregate edges: when context A has N individual import statements referencing
  modules in context B, the extractor emits:
  - All individual module-level edges (each with `weight: 1` or their actual count)
  - One aggregate edge `{"source": "A", "target": "B", "type": "aggregate",
    "weight": N}`

  ## Key Design Decisions

  - Aggregate edge computation is a reduce over all module-level cross-context
    edges, grouping by (source_context, target_context) and summing weights.
  - External (stdlib/third-party) edges are included in the `edges` array with
    `"type": "external"` but are expected to be suppressed by the Godot renderer
    by default (their rendering is deferred to a future phase).
  - The `type` field is a string enum, not a GDScript int, to keep the JSON
    human-readable.

  ## Files / Areas Affected

  - `extractor/serialization.py` — new `edges_to_json()` function (alongside
    `nodes_to_json()` from task-006)
  - `extractor/tests/test_serialization_edges.py` — unit tests covering:
    - internal edge has `type: "internal"`
    - cross-context edge has `type: "cross_context"`
    - aggregate edge weight equals sum of individual cross-context weights
    - external import produces `type: "external"` edge
    - edge with two import statements between same pair has `weight: 2`

  ## How to Verify

  1. Run `pytest extractor/tests/test_serialization_edges.py`.
  2. Run on `~/code/kartograph`; check that for each pair of bounded contexts with
     dependencies, a single `"aggregate"` edge exists alongside the individual
     module-level `"cross_context"` edges.
  3. Confirm `weight` on the aggregate edge equals the sum of weights on the
     individual edges between the same context pair.

  ## Caveats / Follow-up

  External/stdlib edges are emitted but the Godot renderer (task-013) should
  suppress them in the default view. Ubiquitous dependency detection (flagging
  `logging`, `typing`, etc.) is deferred. Edge direction encoding in the renderer
  (arrowheads) is handled by task-013.
---
