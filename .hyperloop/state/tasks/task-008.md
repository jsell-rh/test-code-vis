---
id: task-008
title: Implement pre-computed layout algorithm
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-004, task-005, task-006, task-007]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement coupling-aware pre-computed layout"
pr_description: |
  ## What and Why

  Computes spatial positions for all nodes before the scene graph is written.
  The Godot application reads these positions and places nodes at them without
  running any layout algorithm of its own. The layout algorithm must satisfy two
  prototype-scope requirements: tightly coupled modules must be spatially close,
  and child nodes must be positioned within the bounds of their parent.

  This is the task that makes the visualization structurally meaningful rather than
  arbitrary — a well-laid-out scene lets a human form an accurate mental model of
  the codebase's architecture from a top-down view.

  ## Spec Requirements Satisfied

  `specs/extraction/scene-graph-schema.spec.md` — Requirement: Pre-Computed Layout

  - Each node's `position` field (`x`, `y`, `z`) is set by the extractor.
  - Tightly coupled nodes (high edge weight between them) have smaller distances.
  - Nodes in different independence groups within a context have a visible spatial
    gap (informed by task-005 groupings).
  - Child nodes are positioned within the spatial bounds of their parent node.
  - The Godot application renders nodes at these positions without recomputing.

  `specs/prototype/prototype-scope.spec.md` — "relative positions reflect their
  coupling (tightly coupled contexts are closer together)"

  ## Key Design Decisions

  - Use a force-directed algorithm (e.g. Fruchterman-Reingold) operating on the
    module graph edge weights. High-weight edges → stronger attraction.
  - Layout is computed in 2D (x, z plane); y is used for hierarchy depth
    (bounded contexts at y=0, modules at y=1, classes at y=2).
  - Independence groups from task-005 are used to add repulsive forces between
    groups within the same context, creating the visible spatial gap.
  - After global layout, child positions are scaled and translated to fit within
    their parent's bounding box.
  - Positions are written directly into the node dicts produced by task-006
    (mutating the `position` field in place).

  ## Files / Areas Affected

  - `extractor/layout.py` — new module implementing force-directed layout
  - `extractor/tests/test_layout.py` — unit tests covering:
    - two coupled nodes are closer than two uncoupled nodes
    - child nodes have positions within parent's bounding box
    - independent groups are spatially separated (gap > threshold)
    - layout is deterministic given the same input (fixed random seed)

  ## How to Verify

  1. Run `pytest extractor/tests/test_layout.py`.
  2. Run on `~/code/kartograph`; open the scene in Godot (task-011+) and
     visually confirm that bounded contexts with cross-context dependencies
     appear closer than contexts with no relationships.
  3. Confirm no child node has a position outside its parent's bounding box.

  ## Caveats / Follow-up

  Force-directed layout is non-deterministic without a fixed seed; use a
  configurable seed for reproducibility. The layout quality improves when
  structural significance metrics (task-004) are used to weight node repulsion
  — hubs should have more breathing room. If the stdlib-only constraint applies,
  the force-directed algorithm must be implemented from scratch without `networkx`
  or `scipy`.
---
