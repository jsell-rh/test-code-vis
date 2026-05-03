---
id: task-007
title: Cluster suggestion computation (high-coupling module groups)
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): compute cluster suggestions for tightly-coupled module groups"
pr_description: |
  ## What and Why

  Identifies groups of modules within each bounded context that have high mutual coupling,
  and writes them to the `clusters` array in the JSON output. Godot uses this data to
  visually hint which groups the user might want to collapse into a supernode (task-023).
  The extractor owns this computation; Godot only renders the suggestions.

  ## Spec Requirements Satisfied

  From `specs/extraction/scene-graph-schema.spec.md`:

  - **Cluster Schema**: `clusters` array with entries containing `id`, `members`,
    `context`, and `aggregate_metrics` (`total_loc`, `in_degree`, `out_degree`)
  - Empty `clusters` array when no context has modules exceeding the coupling threshold
  - `aggregate_metrics` computed from member node data

  ## Key Design Decisions

  - Coupling score between two module nodes = number of edges (in either direction) between
    them. A pair is "tightly coupled" if their coupling score exceeds a threshold (default: 2).
  - Cluster identification: build a graph of module pairs above threshold within each
    context, then find connected components. Each component is one cluster suggestion.
  - Singleton components (no pair exceeds threshold) are excluded — no cluster suggestion
    emitted for isolated modules.
  - Cluster `id` format: `"{context_id}:cluster_{index}"`.
  - `aggregate_metrics`:
    - `total_loc` = sum of `size` for all member nodes
    - `in_degree` = number of edges entering the cluster from outside the cluster
    - `out_degree` = number of edges leaving the cluster to outside the cluster
  - Threshold is a module-level constant (not a CLI argument in this task); can be made
    configurable in a follow-up.

  ## Files Affected

  - `extractor/clusters.py` — new file:
    `compute_clusters(nodes: list[Node], edges: list[Edge]) -> list[Cluster]`
  - `extractor/tests/test_clusters.py` — tests: high-coupling fixture produces at least
    one cluster; low-coupling fixture produces empty list; aggregate_metrics correct

  ## Verification

  1. `pytest extractor/tests/test_clusters.py` passes.
  2. kartograph output JSON has `"clusters"` key (even if `[]`).
  3. If any cluster is present, its `members` array contains ≥2 module ids.

  ## Caveats

  The coupling threshold (default 2) may need tuning for kartograph. If all clusters come
  out empty, the visualizer renders no collapse suggestions — that is a valid output.
  Threshold adjustment should be a follow-up task if needed.
---
