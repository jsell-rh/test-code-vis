---
id: task-006
title: Aggregate cross-context edge computation with import weights
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): emit aggregate cross-context edges with import-count weights"
pr_description: |
  ## What and Why

  The schema spec and spatial-structure spec both require two tiers of cross-context edges:
  individual module-to-module edges (used at medium/near zoom) and aggregate
  context-to-context edges (used at far zoom, with `weight` = total import count).
  This task adds the weight counting and aggregate edge emission to the extractor output.

  ## Spec Requirements Satisfied

  From `specs/extraction/scene-graph-schema.spec.md`:

  - **Edge Schema — Weighted edge**: individual module-level edges carry `weight: 1`
  - Aggregate edges have `source: "{context_A}"`, `target: "{context_B}"`,
    `type: "aggregate"`, `weight: N` (total import statements from A into B)

  From `specs/visualization/spatial-structure.spec.md` (Scale Through Zoom — Far scenario):

  - Cross-context dependencies shown as single aggregate edges per context pair, with
    weight indicating total import count

  ## Key Design Decisions

  - Task-003 produces module-level edges with `weight: 1`. This task adds a post-pass that:
    1. Groups cross-context module edges by (source_context, target_context) pair.
    2. Sums individual module-edge weights to compute the aggregate weight.
    3. Emits one additional `Edge` dict per unique context pair with `type: "aggregate"`.
  - Individual module-level edges are **kept** (not replaced). Both tiers exist in the JSON.
  - Aggregate edges use bounded-context node ids as source/target (e.g. `"iam"`, `"graph"`).
  - If context A imports from context B via M module-pair edges, the aggregate edge has
    `weight: M` (number of import relationships, not number of import statements in files;
    file-level counting would require re-reading source at this stage).

  ## Files Affected

  - `extractor/aggregate.py` — new file:
    `compute_aggregate_edges(nodes: list[Node], edges: list[Edge]) -> list[Edge]`
    (returns the full edge list with aggregate edges appended)
  - `extractor/tests/test_aggregate.py` — tests: aggregate edge weight equals sum of
    individual cross-context edges; no aggregate edge for internal pairs

  ## Verification

  1. `pytest extractor/tests/test_aggregate.py` passes.
  2. kartograph output JSON contains at least one edge with `type: "aggregate"` and
     `weight > 1`.
  3. Aggregate edges use bounded-context ids (no dots in source/target).

  ## Caveats

  This design counts module-pair edges, not raw import-statement occurrences. The schema
  spec example says "12 individual import statements" — if exact statement-count is
  required in a future iteration, the dependency extractor (task-003) would need to be
  enhanced to count per-file import occurrences.
---
