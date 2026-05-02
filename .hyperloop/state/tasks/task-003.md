---
id: task-003
title: Implement module graph extraction
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement module graph extraction"
pr_description: |
  ## What and Why

  Implements import analysis to build the directed dependency graph between modules.
  This graph is the raw material for coupling-aware layout (who is close to whom),
  structural significance metrics (who is a hub or bridge), independence detection
  (who can change without affecting whom), and the dependency arrows rendered in
  the Godot scene. Without module-level edges, the visualization has no topology —
  only a bag of unrelated boxes.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Module Graph Extraction

  - For each module, parse `import X` and `from X import Y` statements using AST.
  - Emit a directed edge A → B for every import of B from within A.
  - Each edge carries `weight` = the count of individual import statements between
    the pair (e.g. `from B import foo` and `from B import bar` in the same module
    = weight 2).
  - Module-level edges are distinct from containment relationships (parent/child
    in the scope nesting tree).
  - Extraction is single-file AST only — no cross-file name resolution.

  ## Key Design Decisions

  - Resolves import targets to canonical dotted IDs matching those produced by the
    scope nesting pass (task-002). Unresolvable imports (third-party, stdlib) are
    recorded with a `external: true` flag and retained in the graph but excluded
    from internal dependency layout.
  - Returns a list of `(source_id, target_id, weight)` tuples. Serialization to
    edge schema fields happens in task-007.

  ## Files / Areas Affected

  - `extractor/module_graph.py` — new module implementing AST import traversal
  - `extractor/tests/test_module_graph.py` — unit tests covering:
    - simple `import B` produces edge A→B with weight 1
    - two `from B import` statements produce edge A→B with weight 2
    - `from C import foo` produces edge A→C
    - external/stdlib imports marked as external
    - module with no imports produces no edges

  ## How to Verify

  1. Run `pytest extractor/tests/test_module_graph.py`.
  2. Run the extractor on `~/code/kartograph`.
  3. In the output JSON, find the `edges` array and confirm directed edges with
     weights between bounded context modules.

  ## Caveats / Follow-up

  This task produces module-level edges only. Context-level aggregate edges (one
  edge per context pair summarizing total cross-context import weight) are added
  by task-007 (edge schema serialization). Ubiquitous dependency detection (e.g.
  suppressing `logging` edges) is deferred to a future phase.
---
