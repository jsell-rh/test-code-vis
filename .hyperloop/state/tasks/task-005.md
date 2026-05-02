---
id: task-005
title: Python extractor — coupling-aware pre-computed layout
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-004]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): compute coupling-aware node positions for 3D layout"
pr_description: |
  ## What and Why

  The Godot application renders nodes at positions stored in the scene graph.
  Those positions must encode structural meaning: tightly coupled modules should
  be spatially close, loosely coupled modules spatially distant. Without this,
  the 3D space is positionally arbitrary and provides no comprehension benefit
  over a flat list.

  This task implements the layout algorithm in the extractor (not in Godot),
  satisfying the schema requirement that Godot is a pure renderer: it reads
  positions, it does not compute them.

  ## Spec Requirements Satisfied

  From `specs/extraction/scene-graph-schema.spec.md`:
  - **Pre-Computed Layout**: each node's `position` field contains x, y, z
    coordinates computed by a layout algorithm where tightly coupled nodes are
    closer together.
  - **Pre-Computed Layout — child positioning**: child nodes are positioned
    within the spatial bounds of their parent.

  ## Key Design Decisions

  - Layout algorithm: force-directed layout (e.g. Fruchterman-Reingold) on the
    module graph. Edge weight (from task-003) serves as the attraction force.
    Uses `networkx` for graph operations and force-directed layout, or a
    stdlib-only implementation if the NFR "no deps beyond stdlib and ast" is
    strictly applied. Decision: use `networkx` as it is a widely available
    pure-Python library; the NFR permits tree-sitter as an example, indicating
    minimal third-party deps are acceptable.
  - Bounded contexts are laid out at the top level. Their children are then
    positioned within the bounding box of their parent context using a
    sub-layout pass.
  - Y-axis is used for hierarchy depth (bounded contexts at y=0, inner modules
    at y > 0), leaving the XZ plane for the top-down camera's primary view.
  - Positions are normalized so the entire scene fits in a
    [-50, 50] × [0, 10] × [-50, 50] bounding box.

  ## Files Affected

  - `extractor/layout.py` — force-directed layout implementation
  - `extractor/cli.py` — wired after metrics, before write
  - `extractor/tests/test_layout.py` — tests: tightly-coupled nodes closer
    than loosely-coupled nodes; children within parent bounds

  ## How to Verify

  ```bash
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json
  python -c "
  import json
  d = json.load(open('/tmp/kg.json'))
  # All positions should be non-zero after layout
  zeros = [n for n in d['nodes'] if n['position'] == {'x':0,'y':0,'z':0}]
  print('Nodes with zero position (should be 0 after layout):', len(zeros))
  "
  ```

  `python -m pytest extractor/tests/test_layout.py`

  ## Caveats

  The prototype uses a top-down camera looking at the XZ plane, so layout
  quality in X and Z is more important than Y separation. The layout does not
  need to be aesthetically perfect — it needs to be structurally meaningful.
  Beauty is a follow-up concern.
---
