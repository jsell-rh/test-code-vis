---
id: task-007
title: Python extractor — orthogonal independence group detection
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: not_started
phase: null
deps:
- task-004
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): detect orthogonal independence groups within bounded contexts'
pr_description: "## What and Why\n\nWithin a bounded context, some modules may be\
  \ structurally independent of each\nother — sharing no direct or transitive import\
  \ relationship. Making this\nindependence visible in the 3D space (task-015) lets\
  \ the human immediately\nidentify safe change boundaries and concurrent development\
  \ opportunities.\n\nThe extractor performs the independence analysis and annotates\
  \ each node with\nan `independence_group` identifier. The Godot renderer (task-015)\
  \ uses this\nto spatially separate groups.\n\n## Spec Requirements Satisfied\n\n\
  From `specs/visualization/orthogonal-independence.spec.md`:\n- **Independence Detection\
  \ — Two independent module clusters**: given modules\n  {A,B} and {C,D} with no\
  \ cross-group imports, identifies them as separate\n  independence groups and annotates\
  \ each node with its group identifier.\n- **Independence Detection — Fully connected\
  \ context**: when every module\n  transitively depends on every other, the entire\
  \ context is group \"0\" and\n  no spatial separation is applied.\n\nFrom `specs/extraction/scene-graph-schema.spec.md`:\n\
  - **Node Schema — independence_group**: the `independence_group` field (e.g.\n \
  \ `\"iam:0\"`, `\"iam:1\"`) is added to module nodes by this task.\n\n## Key Design\
  \ Decisions\n\n- Algorithm: connected-components analysis on the **undirected**\
  \ version of\n  the intra-context dependency subgraph. Each connected component\
  \ is one\n  independence group. (Undirected because independence is symmetric: A\n\
  \  depending on B means B's changes can affect A, so they are co-dependent\n  regardless\
  \ of direction.)\n- Group identifier format: `\"{context_id}:{component_index}\"\
  ` (e.g. `\"iam:0\"`).\n  Contexts with only one component assign `\"iam:0\"` to\
  \ all members (single\n  group, no separation needed).\n- Bounded context nodes\
  \ themselves do not get an `independence_group` field\n  (only module-level nodes\
  \ do).\n- Uses `networkx.connected_components` on the undirected projection of the\n\
  \  intra-context subgraph.\n\n## Files Affected\n\n- `extractor/independence.py`\
  \ — connected-components analysis\n- `extractor/cli.py` — wired after dependency\
  \ extraction, before write\n- `extractor/tests/test_independence.py` — tests for\
  \ two-group, one-group,\n  and single-module cases\n\n## How to Verify\n\n```bash\n\
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json\npython\
  \ -c \"\nimport json\nd = json.load(open('/tmp/kg.json'))\ngroups = {}\nfor n in\
  \ d['nodes']:\n    g = n.get('independence_group')\n    if g:\n        groups.setdefault(g,\
  \ []).append(n['id'])\nprint('Independence groups:', list(groups.keys()))\n\"\n\
  ```\n\n`python -m pytest extractor/tests/test_independence.py`\n\n## Caveats\n\n\
  Independence is computed per bounded context, not globally. Two modules in\ndifferent\
  \ bounded contexts are always \"independent\" by definition (different\ncontexts).\
  \ Cross-context independence is a display concern handled at the\nGodot level (task-015)."
---
