---
id: task-005
title: Implement independence group detection
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement independence group detection"
pr_description: |
  ## What and Why

  Identifies groups of modules within each bounded context that are structurally
  independent — sharing no direct or transitive internal dependencies. This is
  inspired by Harel's AND-decomposition in statecharts: orthogonal components are
  those whose internal behavior does not affect each other.

  The independence group identifier is written to each node's `independence_group`
  field in the scene graph. The Godot renderer uses this field (task-016) to place
  independent groups in visually distinct spatial regions within their shared context,
  making safe change boundaries visible without any user interaction.

  This analysis also makes the coupling-aware layout algorithm (task-008) more
  effective: within-group nodes can be positioned closer; between-group nodes need
  a visible gap.

  ## Spec Requirements Satisfied

  `specs/visualization/orthogonal-independence.spec.md` — Requirement: Independence
  Detection

  - For each bounded context, compute the connected components of the internal
    dependency subgraph (considering only edges within the context).
  - Each connected component is an independence group.
  - Modules with no internal dependencies at all are each their own singleton group.
  - A fully-connected context (every module transitively depends on every other)
    yields one group covering all modules.
  - Each module is annotated with a group identifier string, e.g. `"iam:0"`,
    `"iam:1"`.

  ## Key Design Decisions

  - Uses the module graph from task-003, filtered to intra-context edges only
    (source and target share the same bounded context ancestor).
  - Connected components are computed with a simple union-find or BFS; no external
    dependencies needed.
  - Group identifiers are `"{context_id}:{group_index}"` where group_index is
    assigned in descending order of group size (group 0 is the largest).
  - Modules in different bounded contexts are not compared — independence is
    always scoped to a single context.

  ## Files / Areas Affected

  - `extractor/independence.py` — new module implementing connected-components
    within each bounded context
  - `extractor/tests/test_independence.py` — unit tests covering:
    - two independent clusters → two groups
    - single node (no imports) → its own group
    - fully connected context → one group
    - cross-context edges do not affect intra-context grouping

  ## How to Verify

  1. Run `pytest extractor/tests/test_independence.py`.
  2. Run on `~/code/kartograph`; inspect `independence_group` fields in the output
     JSON nodes. Confirm that modules with no mutual imports have distinct group ids.

  ## Caveats / Follow-up

  Transitivity is computed at the module level only; fine-grained class-level
  independence is deferred. The "Independence as Queryable Property" interactive
  feature (highlight orthogonal complement on module selection) is deferred to a
  future phase — it is not referenced in `prototype-scope.spec.md`.
---
