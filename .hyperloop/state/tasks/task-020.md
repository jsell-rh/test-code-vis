---
id: task-020
title: Implement Landmark Primitive renderer (hub/bridge persistence across LOD)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-011, task-012, task-014]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Landmark Primitive renderer with cross-LOD persistence"
pr_description: |
  ## What and Why

  At the far zoom tier, only aggregate bounded-context volumes are visible. When the
  user zooms into a context, modules fade in at medium distance. This means that
  structurally significant nodes — the ones the human most needs to orient around —
  are invisible at the overview level, exactly when spatial orientation matters most.

  The Landmark Primitive fixes this: it identifies high-significance nodes
  (hubs and entry points) in Godot from the loaded scene graph and renders them with a
  distinctive visual treatment that persists across ALL LOD tiers. A landmark is always
  visible, giving the human stable orientation anchors regardless of zoom level.

  ## Spec Requirements Satisfied

  From `specs/core/visual-primitives.spec.md` § Landmark Primitive:

  - Landmarks are visible at every zoom level, even when surrounding nodes are hidden
    by LOD.
  - Landmarks have a distinctive visual treatment (larger scale, brighter, or glyph).
  - Hub landmarks: derived from nodes with the highest in-degree (most imported by
    other modules).
  - Entry-point landmarks: nodes with no in-edges from application code (system entry
    points such as CLI handlers or HTTP entry points).
  - Bridge landmarks: nodes with high betweenness centrality (sit on many shortest
    paths between other nodes).
  - Landmarks serve as spatial reference ("the API gateway is to the north").

  ## Key Design Decisions

  - **Godot-side computation only**: Rather than requiring the extractor to flag
    landmarks (which would need a schema extension), Godot computes landmark status
    from the already-loaded edges. In-degree is trivially derived: count how many
    edges have each node as `target`. Entry points are nodes with in-degree 0 in the
    application scope (excluding edges from nodes typed "external"). A simplified
    betweenness heuristic (e.g. nodes that appear in many shortest paths via BFS) is
    used for bridges, or bridges are deferred to a follow-up if too expensive.
  - **LOD bypass**: The LOD Shell system (task-014) normally hides nodes below a
    camera-distance threshold. Landmark nodes set a `is_landmark = true` flag that
    the LOD system checks; landmark nodes skip the visibility cutoff and remain
    visible at all distances.
  - **Visual treatment**: Scale the landmark node's mesh by 1.4× and increase its
    emission strength. A small glyph (star or diamond shape) is placed above the
    node as a Label3D or billboard sprite. This uses the luminance/scale perceptual
    channel — distinct from the color (Tint) channel used by task-019.
  - **Landmark cap**: At most 5 landmarks per bounded context are shown to avoid
    over-crowding. Nodes are ranked by in-degree; top-N are promoted.

  ## Files / Areas Affected

  - `godot/` — new `landmark_classifier.gd`: computes landmark status from loaded
    scene graph edges; returns list of landmark node IDs with reason (hub/entry/bridge)
  - `godot/` — LOD Shell logic (from task-014) extended to check `is_landmark` flag
    and skip visibility cutoff for landmark nodes
  - `godot/` — Container or Node scene script updated to accept and apply landmark
    visual treatment (scale, emission, glyph)
  - No changes to `extractor/` or scene graph JSON format

  ## How to Verify

  1. Run the extractor on kartograph, launch the Godot application.
  2. At the far overview zoom tier, the 3–5 highest-in-degree module nodes (across all
     contexts) should be visible as slightly larger, brighter elements even though
     other module-level detail is hidden.
  3. Zoom out to maximum distance — landmark nodes must remain visible.
  4. Zoom into a context — landmark nodes should still be visually distinct (brighter/
     larger) compared to non-landmark module nodes.
  5. In the Godot output log, confirm `LandmarkClassifier` logs which nodes were
     promoted and their in-degree scores.
  6. Run `godot-tests.sh` — all existing tests pass.

  ## Caveats and Follow-up

  - Betweenness centrality (bridge detection) is O(V·E) and may be slow for large
    graphs in GDScript. The implementer should either: (a) compute it asynchronously
    on load, (b) use a faster approximation, or (c) defer bridge landmarks and only
    implement hub and entry-point landmarks for the prototype.
  - Human-designated landmarks are out of prototype scope (requires UI for designation).
  - The LLM-designated landmarks (per-query context) are out of prototype scope.
---

## Task

Identify structurally significant nodes (hubs and entry points) in Godot from the
loaded scene graph, render them with a distinctive visual treatment (larger scale,
brighter emission, small orientation glyph), and ensure they remain visible across
ALL LOD zoom tiers.

### Acceptance Criteria

1. At least the top-3 highest-in-degree nodes in the scene graph are promoted to
   landmark status and rendered with visibly distinct treatment (scale ≥ 1.3×,
   emission strength visibly higher than non-landmarks).
2. Entry-point nodes (in-degree = 0 from application nodes) are also promoted to
   landmark status.
3. Landmark nodes remain visible at ALL zoom levels — they do NOT fade out when the
   LOD Shell hides surrounding module-level nodes.
4. A small label or glyph above each landmark node identifies it as a landmark
   (e.g. a star sprite or "★" Label3D billboard).
5. All existing Container, Edge, and LOD rendering tests continue to pass.

### Implementation Notes

- Depends on task-011 (scene graph loader) for edge data, task-012 (Container renderer)
  for the node meshes to be scaled/brightened, and task-014 (LOD Shell) for the
  visibility-tier logic to extend.
- `LandmarkClassifier.gd`: stateless utility — takes nodes and edges arrays, returns
  `{ node_id: { reason: "hub"|"entry_point", rank: int } }`.
- LOD Shell integration: add a check `if node.is_landmark: return` before applying
  the visibility-cutoff fade-out.
- Use `BaseMaterial3D.emission_enabled` + `emission_energy_multiplier` for brightness.
