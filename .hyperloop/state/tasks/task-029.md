---
id: task-029
title: Implement Node primitive renderer in Godot
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-011, task-012]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Node primitive renderer (abstract volume for non-container entities)"
pr_description: |
  ## What and Why

  This PR implements the **Node primitive** as defined in `specs/core/visual-primitives.spec.md`
  (Composition Layer § Node Primitive). The Container primitive (task-012) renders bounded contexts
  and modules as bounded regions. The Node primitive renders *entities within* those containers —
  functions, classes, constants — as abstract geometric volumes (spheres or small boxes) at near
  zoom (LOD tier 2). Without the Node primitive, zooming into a module shows nothing inside it.

  The spec is explicit: Nodes do NOT have baked-in types. Their visual identity comes from their
  name label and, in the future, from Badges. A function Node and a class Node look identical
  except for their name; type information is encoded by future Badge attachments, not by shape.

  ## Spec Requirements Satisfied

  - A Node is an abstract labeled volume (sphere or small box — the specific geometry is an
    implementer decision, consistent with the prototype scope's "abstract volumes" mandate).
  - Nodes are rendered inside their parent Container at LOD tier 2 (near zoom) using positions
    derived from the scene graph JSON (pre-computed by the extractor).
  - Nodes without any notable aspects render as plain labeled volumes with no additional decoration.
  - Node positions come from the `symbols` array in module nodes (added by task-023). Each
    symbol entry represents one Node entity. If the `symbols` field is absent or empty, the module
    Container renders as before (no Nodes inside).
  - Nodes use a distinct perceptual channel from Containers: they are smaller and positioned
    *inside* the Container boundary (spatial containment channel), not competing with the
    Container's boundary visual.

  ## Design Notes

  The Node primitive is intentionally minimal: identity (name label) + geometry only. The Badge
  primitive (future task) adds cross-cutting property glyphs. The Port primitive (future task)
  renders public functions on the Container membrane. This task creates the base Node scene object
  that both future primitives will extend.

  ## Files / Areas Affected

  - `godot/` — new scene file or script for the Node primitive (sphere/box mesh + Label3D).
  - The module Container scene (task-012) gains logic to instantiate Node children when the
    JSON `symbols` field is present and LOD tier is 2.
  - Node rendering is gated on LOD tier (task-014): Nodes are hidden at tier 0 and tier 1,
    fade in at tier 2.

  ## How to Verify

  1. Run the extractor (with task-023 implemented) to produce `scene_graph.json` with `symbols`.
  2. Load the scene in Godot.
  3. Zoom into a module at near distance (tier 2): labeled Node volumes should appear inside the
     Container boundary.
  4. Zoom back to medium distance (tier 1): Nodes should fade out.
  5. Confirm that all visible Nodes carry their function/class name as a readable label.
  6. Confirm no crashes or GDScript errors in the Godot output log.
  7. Run the Godot test suite.

  ## Caveats / Follow-up

  - This task does NOT implement Badges (cross-cutting property glyphs). Nodes render as plain
    labeled volumes. Badges are a future enhancement.
  - This task does NOT implement Ports (public functions on Container membrane). Port rendering
    is a separate future task.
  - Node positions inside their Container are pre-computed by the extractor layout algorithm
    (task-008). If task-008 does not yet compute symbol-level positions, Nodes can be initially
    laid out using a simple grid inside the Container boundary, with the expectation that
    task-008 will be updated to provide pre-computed positions.
---
