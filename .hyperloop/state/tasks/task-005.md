---
id: task-005
title: Extractor — layout algorithm (pre-compute node positions)
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-003, task-004]
round: 0
branch: null
pr: null
---

Implement the layout algorithm that assigns `position` (x, y, z) and `size` to every node.
The Godot application renders positions as-is; it does NOT recompute layout.

Covers:
- Assign `size` to each node proportional to its `metrics.loc` value (normalised within
  the node population so the largest node has a reasonable max size).
- Assign `position` to top-level bounded-context nodes so that tightly coupled contexts
  (high edge count between them) are placed closer together. A force-directed or simple
  spring layout using only stdlib / numpy is acceptable; keeping it dependency-light is
  preferred (stdlib only if possible).
- Assign `position` to child (module) nodes relative to their parent's position, ensuring
  child volumes fit spatially within the parent's extents.
- All positions are 3D (x, y, z); for the prototype, z may be 0 for a flat top-down layout.
- The result is the same node list with `position` and `size` fields populated.
