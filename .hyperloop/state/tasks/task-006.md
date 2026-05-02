---
id: task-006
title: Python extractor — aggregate edges and cluster detection
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-004]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): emit aggregate edges and cluster suggestions"
pr_description: |
  ## What and Why

  Two related enrichment steps that prepare the scene graph for the Godot
  application's LOD rendering (task-013) and cluster-collapsing UI (task-014):

  1. **Aggregate edges**: at far zoom, the Godot app shows one thick edge per
     context pair rather than many thin module-level edges. The extractor
     pre-computes these with a combined weight so Godot doesn't have to.

  2. **Cluster suggestions**: groups of tightly-coupled modules within a bounded
     context that the human may choose to collapse into a single supernode.
     Pre-computing them in the extractor keeps Godot a pure renderer.

  ## Spec Requirements Satisfied

  From `specs/extraction/scene-graph-schema.spec.md`:
  - **Edge Schema — Weighted edge / aggregate edge**: for each pair of bounded
    contexts with at least one module-level edge between them, emits one
    `type: "aggregate"` edge with `weight` equal to the sum of all individual
    edge weights.
  - **Cluster Schema — Cluster suggestion**: identifies module groups within a
    context with mutual coupling above a threshold and emits them in `clusters`.
  - **Cluster Schema — No clusters found**: emits an empty `clusters` array
    when no pairs exceed the threshold.

  ## Key Design Decisions

  - Aggregate edges are added to the same `edges` array as module-level edges,
    distinguished by `type: "aggregate"`. Godot uses `type` to decide which
    edges to show at which zoom distance.
  - Cluster detection: within each bounded context, build a subgraph of
    module-level edges, compute pairwise coupling scores (number of edges
    between each pair), and apply a configurable threshold (default: ≥ 3
    edges between a pair). Modules sharing above-threshold coupling with any
    cluster member are added to the cluster. This is a simple greedy grouping,
    not Louvain — sufficient for the prototype scale (~50 modules).
  - Cluster `aggregate_metrics` are computed as: `total_loc` = sum of member
    LOC, `in_degree` = edges entering any member from outside the cluster,
    `out_degree` = edges leaving any member to outside the cluster.

  ## Files Affected

  - `extractor/aggregate.py` — aggregate edge computation
  - `extractor/clusters.py` — cluster detection logic
  - `extractor/cli.py` — wired after metrics, before write
  - `extractor/tests/test_aggregate.py`
  - `extractor/tests/test_clusters.py`

  ## How to Verify

  ```bash
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json
  python -c "
  import json
  d = json.load(open('/tmp/kg.json'))
  agg = [e for e in d['edges'] if e['type'] == 'aggregate']
  print('Aggregate edges:', len(agg))
  print('Clusters:', len(d['clusters']))
  for c in d['clusters']:
      print(' ', c['id'], '->', c['members'])
  "
  ```

  `python -m pytest extractor/tests/test_aggregate.py extractor/tests/test_clusters.py`

  ## Caveats

  Cluster suggestions are advisory — Godot (task-014) uses them to offer visual
  collapse hints but never auto-collapses. The coupling threshold is a prototype
  constant; a future task could expose it as a CLI flag.
---
