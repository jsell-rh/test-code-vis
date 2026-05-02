---
id: task-009
title: Implement cluster detection and cluster schema output
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-003, task-004]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement cluster detection and cluster schema"
pr_description: |
  ## What and Why

  Identifies groups of tightly-coupled modules within each bounded context that
  are good candidates for being collapsed into a single supernode in the Godot
  renderer. Writes these groups to the `clusters` array in the scene graph JSON.
  The Godot collapse mechanic (task-017) reads this data to show collapsing
  suggestions to the user.

  Without pre-computed cluster suggestions, the user has no guided entry point for
  simplifying a complex bounded context. The extractor is the right place to compute
  these — it has access to the full module graph and significance metrics.

  ## Spec Requirements Satisfied

  `specs/extraction/scene-graph-schema.spec.md` — Requirement: Cluster Schema

  Each entry in the `clusters` array MUST carry:
  - `id` — string identifier, e.g. `"iam:cluster_0"`
  - `members` — array of module node ids
  - `context` — parent bounded context id
  - `aggregate_metrics` — object with `total_loc`, `in_degree`, `out_degree`

  When no modules exceed the coupling threshold, `clusters` is an empty array for
  that context.

  ## Key Design Decisions

  - A cluster is identified by finding module pairs within a context whose mutual
    edge weight exceeds a configurable threshold (default: weight ≥ 3 import
    statements). Connected components of the high-coupling subgraph form clusters.
  - Only intra-context edges are considered. Cross-context coupling does not form
    a cluster.
  - `total_loc` is approximated as the sum of each member module's `size` value
    (from task-006). Actual LOC measurement is deferred.
  - `in_degree` and `out_degree` in `aggregate_metrics` count edges entering/
    leaving the cluster boundary from/to other modules (not internal cluster edges).
  - The Godot renderer computes supernode position as the centroid of member
    positions (not prescribed by the extractor).

  ## Files / Areas Affected

  - `extractor/cluster_detection.py` — new module
  - `extractor/tests/test_cluster_detection.py` — unit tests covering:
    - two modules with weight ≥ threshold form a cluster
    - modules below threshold do not form a cluster
    - context with no qualifying pairs has empty clusters array
    - aggregate_metrics in_degree counts only external-facing edges
    - cluster id format is `"{context_id}:cluster_{n}"`

  ## How to Verify

  1. Run `pytest extractor/tests/test_cluster_detection.py`.
  2. Run on `~/code/kartograph`; confirm `clusters` array contains entries for
     contexts with tightly-coupled internal modules.
  3. Verify the Godot scene (task-011 onwards) displays subtle suggestion
     indicators for cluster members.

  ## Caveats / Follow-up

  The coupling threshold is configurable but not yet exposed as a CLI flag — it
  is a module-level constant for now. The Godot collapse mechanic (task-017) is
  where clusters actually become interactive. Supernode positioning is computed
  by Godot, not the extractor.
---
