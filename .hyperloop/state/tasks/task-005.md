---
id: task-005
title: Independence group detection and node annotation
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): detect structural independence groups and annotate nodes"
pr_description: |
  ## What and Why

  Identifies which module nodes within each bounded context are structurally independent
  of each other — sharing no direct or transitive internal dependencies. Each module is
  annotated with an `independence_group` identifier so the Godot renderer can visually
  separate orthogonal groups. This is the extractor-side half of the orthogonal
  independence feature; the rendering half is task-020.

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:

  - **Independence Detection**: groups modules within each bounded context by connected
    components in the internal dependency graph
  - Each module node receives an `independence_group` field (e.g. `"iam:0"`, `"iam:1"`)
  - Modules with no internal dependencies to any peer each form their own singleton group
  - A fully-connected context produces a single group (`"ctx:0"`)

  From `specs/extraction/scene-graph-schema.spec.md` (Node Schema scenario):

  - `independence_group` field populated per the schema definition

  ## Key Design Decisions

  - Algorithm: build an undirected graph of internal edges within each bounded context,
    then find connected components using BFS/DFS. Each component becomes one group.
  - Group ids use the format `"{context_id}:{component_index}"` where index is assigned
    in order of discovery (largest component first so the primary group is always `:0`).
  - Top-level bounded-context nodes receive `independence_group: null` (groups are a
    within-context concept).
  - The function mutates the `Node` dicts in-place and returns the updated list.
  - Implemented in pure Python stdlib.

  ## Files Affected

  - `extractor/independence.py` — new file:
    `assign_independence_groups(nodes: list[Node], edges: list[Edge]) -> list[Node]`
  - `extractor/tests/test_independence.py` — tests: two isolated clusters produce two
    groups; fully-connected context produces one group; singleton module is its own group

  ## Verification

  1. `pytest extractor/tests/test_independence.py` passes.
  2. Running against kartograph: at least one bounded context shows ≥2 independence groups
     (or all are single groups — either is valid; the test asserts group ids are well-formed).
  3. All module nodes have a non-null `independence_group` in the output JSON.

  ## Caveats

  Independence is computed on **direct and transitive** internal edges only. Cross-context
  edges are ignored for the within-context grouping calculation. If a bounded context has
  zero internal edges, every module is its own singleton group.
---
