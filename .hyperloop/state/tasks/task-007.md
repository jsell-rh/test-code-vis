---
id: task-007
title: Python extractor — orthogonal independence group detection
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-004]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): detect orthogonal independence groups within bounded contexts"
pr_description: |
  ## What and Why

  Within a bounded context, some modules may be structurally independent of each
  other — sharing no direct or transitive import relationship. Making this
  independence visible in the 3D space (task-015) lets the human immediately
  identify safe change boundaries and concurrent development opportunities.

  The extractor performs the independence analysis and annotates each node with
  an `independence_group` identifier. The Godot renderer (task-015) uses this
  to spatially separate groups.

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:
  - **Independence Detection — Two independent module clusters**: given modules
    {A,B} and {C,D} with no cross-group imports, identifies them as separate
    independence groups and annotates each node with its group identifier.
  - **Independence Detection — Fully connected context**: when every module
    transitively depends on every other, the entire context is group "0" and
    no spatial separation is applied.

  From `specs/extraction/scene-graph-schema.spec.md`:
  - **Node Schema — independence_group**: the `independence_group` field (e.g.
    `"iam:0"`, `"iam:1"`) is added to module nodes by this task.

  ## Key Design Decisions

  - Algorithm: connected-components analysis on the **undirected** version of
    the intra-context dependency subgraph. Each connected component is one
    independence group. (Undirected because independence is symmetric: A
    depending on B means B's changes can affect A, so they are co-dependent
    regardless of direction.)
  - Group identifier format: `"{context_id}:{component_index}"` (e.g. `"iam:0"`).
    Contexts with only one component assign `"iam:0"` to all members (single
    group, no separation needed).
  - Bounded context nodes themselves do not get an `independence_group` field
    (only module-level nodes do).
  - Uses `networkx.connected_components` on the undirected projection of the
    intra-context subgraph.

  ## Files Affected

  - `extractor/independence.py` — connected-components analysis
  - `extractor/cli.py` — wired after dependency extraction, before write
  - `extractor/tests/test_independence.py` — tests for two-group, one-group,
    and single-module cases

  ## How to Verify

  ```bash
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json
  python -c "
  import json
  d = json.load(open('/tmp/kg.json'))
  groups = {}
  for n in d['nodes']:
      g = n.get('independence_group')
      if g:
          groups.setdefault(g, []).append(n['id'])
  print('Independence groups:', list(groups.keys()))
  "
  ```

  `python -m pytest extractor/tests/test_independence.py`

  ## Caveats

  Independence is computed per bounded context, not globally. Two modules in
  different bounded contexts are always "independent" by definition (different
  contexts). Cross-context independence is a display concern handled at the
  Godot level (task-015).
---
