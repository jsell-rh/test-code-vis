---
id: task-005
title: Python extractor — coupling-aware pre-computed layout
spec_ref: specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21
status: not_started
phase: null
deps:
- task-004
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): compute coupling-aware node positions for 3D layout'
pr_description: "## What and Why\n\nThe Godot application renders nodes at positions\
  \ stored in the scene graph.\nThose positions must encode structural meaning: tightly\
  \ coupled modules should\nbe spatially close, loosely coupled modules spatially\
  \ distant. Without this,\nthe 3D space is positionally arbitrary and provides no\
  \ comprehension benefit\nover a flat list.\n\nThis task implements the layout algorithm\
  \ in the extractor (not in Godot),\nsatisfying the schema requirement that Godot\
  \ is a pure renderer: it reads\npositions, it does not compute them.\n\n## Spec\
  \ Requirements Satisfied\n\nFrom `specs/extraction/scene-graph-schema.spec.md`:\n\
  - **Pre-Computed Layout**: each node's `position` field contains x, y, z\n  coordinates\
  \ computed by a layout algorithm where tightly coupled nodes are\n  closer together.\n\
  - **Pre-Computed Layout — child positioning**: child nodes are positioned\n  within\
  \ the spatial bounds of their parent.\n\n## Key Design Decisions\n\n- Layout algorithm:\
  \ force-directed layout (e.g. Fruchterman-Reingold) on the\n  module graph. Edge\
  \ weight (from task-003) serves as the attraction force.\n  Uses `networkx` for\
  \ graph operations and force-directed layout, or a\n  stdlib-only implementation\
  \ if the NFR \"no deps beyond stdlib and ast\" is\n  strictly applied. Decision:\
  \ use `networkx` as it is a widely available\n  pure-Python library; the NFR permits\
  \ tree-sitter as an example, indicating\n  minimal third-party deps are acceptable.\n\
  - Bounded contexts are laid out at the top level. Their children are then\n  positioned\
  \ within the bounding box of their parent context using a\n  sub-layout pass.\n\
  - Y-axis is used for hierarchy depth (bounded contexts at y=0, inner modules\n \
  \ at y > 0), leaving the XZ plane for the top-down camera's primary view.\n- Positions\
  \ are normalized so the entire scene fits in a\n  [-50, 50] × [0, 10] × [-50, 50]\
  \ bounding box.\n\n## Files Affected\n\n- `extractor/layout.py` — force-directed\
  \ layout implementation\n- `extractor/cli.py` — wired after metrics, before write\n\
  - `extractor/tests/test_layout.py` — tests: tightly-coupled nodes closer\n  than\
  \ loosely-coupled nodes; children within parent bounds\n\n## How to Verify\n\n```bash\n\
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json\npython\
  \ -c \"\nimport json\nd = json.load(open('/tmp/kg.json'))\n# All positions should\
  \ be non-zero after layout\nzeros = [n for n in d['nodes'] if n['position'] == {'x':0,'y':0,'z':0}]\n\
  print('Nodes with zero position (should be 0 after layout):', len(zeros))\n\"\n\
  ```\n\n`python -m pytest extractor/tests/test_layout.py`\n\n## Caveats\n\nThe prototype\
  \ uses a top-down camera looking at the XZ plane, so layout\nquality in X and Z\
  \ is more important than Y separation. The layout does not\nneed to be aesthetically\
  \ perfect — it needs to be structurally meaningful.\nBeauty is a follow-up concern."
---
