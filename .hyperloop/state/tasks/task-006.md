---
id: task-006
title: Python extractor — aggregate edges and cluster detection
spec_ref: specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21
status: not_started
phase: null
deps:
- task-004
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): emit aggregate edges and cluster suggestions'
pr_description: "## What and Why\n\nTwo related enrichment steps that prepare the\
  \ scene graph for the Godot\napplication's LOD rendering (task-013) and cluster-collapsing\
  \ UI (task-014):\n\n1. **Aggregate edges**: at far zoom, the Godot app shows one\
  \ thick edge per\n   context pair rather than many thin module-level edges. The\
  \ extractor\n   pre-computes these with a combined weight so Godot doesn't have\
  \ to.\n\n2. **Cluster suggestions**: groups of tightly-coupled modules within a\
  \ bounded\n   context that the human may choose to collapse into a single supernode.\n\
  \   Pre-computing them in the extractor keeps Godot a pure renderer.\n\n## Spec\
  \ Requirements Satisfied\n\nFrom `specs/extraction/scene-graph-schema.spec.md`:\n\
  - **Edge Schema — Weighted edge / aggregate edge**: for each pair of bounded\n \
  \ contexts with at least one module-level edge between them, emits one\n  `type:\
  \ \"aggregate\"` edge with `weight` equal to the sum of all individual\n  edge weights.\n\
  - **Cluster Schema — Cluster suggestion**: identifies module groups within a\n \
  \ context with mutual coupling above a threshold and emits them in `clusters`.\n\
  - **Cluster Schema — No clusters found**: emits an empty `clusters` array\n  when\
  \ no pairs exceed the threshold.\n\n## Key Design Decisions\n\n- Aggregate edges\
  \ are added to the same `edges` array as module-level edges,\n  distinguished by\
  \ `type: \"aggregate\"`. Godot uses `type` to decide which\n  edges to show at which\
  \ zoom distance.\n- Cluster detection: within each bounded context, build a subgraph\
  \ of\n  module-level edges, compute pairwise coupling scores (number of edges\n\
  \  between each pair), and apply a configurable threshold (default: ≥ 3\n  edges\
  \ between a pair). Modules sharing above-threshold coupling with any\n  cluster\
  \ member are added to the cluster. This is a simple greedy grouping,\n  not Louvain\
  \ — sufficient for the prototype scale (~50 modules).\n- Cluster `aggregate_metrics`\
  \ are computed as: `total_loc` = sum of member\n  LOC, `in_degree` = edges entering\
  \ any member from outside the cluster,\n  `out_degree` = edges leaving any member\
  \ to outside the cluster.\n\n## Files Affected\n\n- `extractor/aggregate.py` — aggregate\
  \ edge computation\n- `extractor/clusters.py` — cluster detection logic\n- `extractor/cli.py`\
  \ — wired after metrics, before write\n- `extractor/tests/test_aggregate.py`\n-\
  \ `extractor/tests/test_clusters.py`\n\n## How to Verify\n\n```bash\npython extractor/cli.py\
  \ --target ~/code/kartograph --output /tmp/kg.json\npython -c \"\nimport json\n\
  d = json.load(open('/tmp/kg.json'))\nagg = [e for e in d['edges'] if e['type'] ==\
  \ 'aggregate']\nprint('Aggregate edges:', len(agg))\nprint('Clusters:', len(d['clusters']))\n\
  for c in d['clusters']:\n    print(' ', c['id'], '->', c['members'])\n\"\n```\n\n\
  `python -m pytest extractor/tests/test_aggregate.py extractor/tests/test_clusters.py`\n\
  \n## Caveats\n\nCluster suggestions are advisory — Godot (task-014) uses them to\
  \ offer visual\ncollapse hints but never auto-collapses. The coupling threshold\
  \ is a prototype\nconstant; a future task could expose it as a CLI flag."
---
