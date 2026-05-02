---
id: task-004
title: Implement structural significance extraction
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement structural significance extraction"
pr_description: |
  ## What and Why

  Computes graph-theoretic significance measures for each module node: hub detection
  (high in-degree), bridge detection (high betweenness centrality), peripheral
  detection (low in/out degree), and community detection. These metrics serve two
  purposes in the prototype: (1) driving coupling-aware spatial layout so the most
  structurally important nodes are prominent, and (2) flagging which nodes should
  be treated as Landmarks in future rendering work. Without this pass, all nodes
  look equally important and layout has no basis for relative positioning.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Structural Significance
  Extraction

  - Compute in-degree for every module node in the module graph.
  - Flag nodes with high in-degree as `hub`.
  - Compute betweenness centrality; flag nodes with high betweenness as `bridge`.
  - Flag nodes with in-degree 0 and out-degree ≤ 1 as `peripheral`.
  - Run community detection (e.g. Louvain/Leiden or a simple connected-components
    heuristic if the full algorithm is too heavy for stdlib-only constraint).
  - Each module is annotated with: `in_degree`, `out_degree`, `betweenness`,
    `community_id`, and a `significance` label (`hub` | `bridge` | `peripheral`
    | `standard`).
  - Compare detected community to declared package structure; flag mismatches as
    `community_drift: true`.

  ## Key Design Decisions

  - Uses the module graph produced by task-003 as input. No new file parsing is
    required.
  - If the stdlib-only constraint (no third-party packages) applies to the
    extractor, implement a simplified betweenness approximation rather than
    importing `networkx`. Otherwise use `networkx` if it is listed as a permitted
    dependency.
  - Metrics are stored per-node in a dict keyed by node id. Serialization into the
    scene graph node schema happens in task-006.

  ## Files / Areas Affected

  - `extractor/structural_significance.py` — new module for metric computation
  - `extractor/tests/test_structural_significance.py` — unit tests covering:
    - single hub (high in-degree) correctly flagged
    - bridge (high betweenness) correctly flagged
    - peripheral (leaf) correctly flagged
    - community mismatch flagged as community_drift

  ## How to Verify

  1. Run `pytest extractor/tests/test_structural_significance.py`.
  2. Run on `~/code/kartograph`; inspect node annotations in the output JSON to
     confirm `shared_kernel` or similar highly-imported modules are flagged as hubs.

  ## Caveats / Follow-up

  Community detection quality depends on graph density. A simple Louvain
  implementation or connected-components heuristic is acceptable for the prototype.
  The `community_drift` flag is informational for this phase; no UI surfaces it yet.
  Landmark rendering (the visual treatment for hubs/bridges at all zoom levels) is
  deferred to a future phase.
---
