---
id: task-004
title: Force-directed layout algorithm for node positioning
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): compute pre-laid-out 3D positions via force-directed algorithm"
pr_description: |
  ## What and Why

  The schema spec requires that node positions be computed in the extractor — Godot renders
  at the given coordinates without re-running any layout. This task implements the layout
  algorithm that places tightly-coupled nodes closer together in 3D space and keeps child
  nodes spatially contained within their parent's bounds.

  ## Spec Requirements Satisfied

  From `specs/extraction/scene-graph-schema.spec.md`:

  - **Pre-Computed Layout**: each node's `position` (x, y, z) is set by the extractor
  - Tightly coupled nodes have smaller distances between them
  - Child nodes are positioned within the spatial bounds of their parent

  ## Key Design Decisions

  - Two-level layout: (1) top-level force-directed layout for bounded-context nodes using
    cross-context edge weights as attraction forces; (2) per-context local layout for
    module nodes using internal edge weights as attraction forces.
  - Uses a simple spring-repulsion model (Fruchterman–Reingold style) implemented in pure
    Python — no third-party graph libraries. Stdlib `math` only.
  - Y-axis is used as a vertical separation layer: bounded-context nodes sit at y=0,
    child module nodes sit at y=1 (elevated) so they don't z-fight with the parent plane.
  - Child node positions are expressed relative to the parent's position but stored as
    absolute world coordinates in the JSON (Godot positions directly, no offset math
    needed at render time).
  - Bounded-context `size` (from LOC) scales the repulsion radius so larger contexts
    occupy more space and do not overlap their neighbours.
  - Iteration count is fixed (e.g. 300 iterations) with a cooling schedule — deterministic
    layout for reproducible output given the same input graph.

  ## Files Affected

  - `extractor/layout.py` — new file:
    `compute_layout(nodes: list[Node], edges: list[Edge]) -> list[Node]`
    (returns nodes with `position` fields populated)
  - `extractor/tests/test_layout.py` — tests: coupled nodes closer than uncoupled nodes;
    child positions within parent bounds

  ## Verification

  1. `pytest extractor/tests/test_layout.py` passes.
  2. After layout, all child node positions are within their parent node's bounding box
     (parent_pos ± parent_size/2 in x and z).
  3. Two nodes with an edge are closer than two nodes with no edge (on a controlled fixture).

  ## Caveats

  Force-directed layout is non-trivial to tune. The prototype uses fixed iteration count
  and spring constants; a future task can expose these as CLI parameters.
  Independence group separation (spatial gap between orthogonal groups) is handled in
  task-005 after group assignment, not here.
---
