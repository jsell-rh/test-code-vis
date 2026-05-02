---
id: task-029
title: Implement Node primitive renderer in Godot
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: in_progress
phase: implement
deps:
- task-011
- task-012
round: 7
branch: hyperloop/task-029
pr: https://github.com/jsell-rh/test-code-vis/pull/237
pr_title: 'feat(godot): implement Node primitive renderer (abstract volume for non-container
  entities)'
pr_description: "## What and Why\n\nThis PR implements the **Node primitive** as defined\
  \ in `specs/core/visual-primitives.spec.md`\n(Composition Layer § Node Primitive).\
  \ The Container primitive (task-012) renders bounded contexts\nand modules as bounded\
  \ regions. The Node primitive renders *entities within* those containers —\nfunctions,\
  \ classes, constants — as abstract geometric volumes (spheres or small boxes) at\
  \ near\nzoom (LOD tier 2). Without the Node primitive, zooming into a module shows\
  \ nothing inside it.\n\nThe spec is explicit: Nodes do NOT have baked-in types.\
  \ Their visual identity comes from their\nname label and, in the future, from Badges.\
  \ A function Node and a class Node look identical\nexcept for their name; type information\
  \ is encoded by future Badge attachments, not by shape.\n\n## Spec Requirements\
  \ Satisfied\n\n- A Node is an abstract labeled volume (sphere or small box — the\
  \ specific geometry is an\n  implementer decision, consistent with the prototype\
  \ scope's \"abstract volumes\" mandate).\n- Nodes are rendered inside their parent\
  \ Container at LOD tier 2 (near zoom) using positions\n  derived from the scene\
  \ graph JSON (pre-computed by the extractor).\n- Nodes without any notable aspects\
  \ render as plain labeled volumes with no additional decoration.\n- Node positions\
  \ come from the `symbols` array in module nodes (added by task-023). Each\n  symbol\
  \ entry represents one Node entity. If the `symbols` field is absent or empty, the\
  \ module\n  Container renders as before (no Nodes inside).\n- Nodes use a distinct\
  \ perceptual channel from Containers: they are smaller and positioned\n  *inside*\
  \ the Container boundary (spatial containment channel), not competing with the\n\
  \  Container's boundary visual.\n\n## Design Notes\n\nThe Node primitive is intentionally\
  \ minimal: identity (name label) + geometry only. The Badge\nprimitive (future task)\
  \ adds cross-cutting property glyphs. The Port primitive (future task)\nrenders\
  \ public functions on the Container membrane. This task creates the base Node scene\
  \ object\nthat both future primitives will extend.\n\n## Files / Areas Affected\n\
  \n- `godot/` — new scene file or script for the Node primitive (sphere/box mesh\
  \ + Label3D).\n- The module Container scene (task-012) gains logic to instantiate\
  \ Node children when the\n  JSON `symbols` field is present and LOD tier is 2.\n\
  - Node rendering is gated on LOD tier (task-014): Nodes are hidden at tier 0 and\
  \ tier 1,\n  fade in at tier 2.\n\n## How to Verify\n\n1. Run the extractor (with\
  \ task-023 implemented) to produce `scene_graph.json` with `symbols`.\n2. Load the\
  \ scene in Godot.\n3. Zoom into a module at near distance (tier 2): labeled Node\
  \ volumes should appear inside the\n   Container boundary.\n4. Zoom back to medium\
  \ distance (tier 1): Nodes should fade out.\n5. Confirm that all visible Nodes carry\
  \ their function/class name as a readable label.\n6. Confirm no crashes or GDScript\
  \ errors in the Godot output log.\n7. Run the Godot test suite.\n\n## Caveats /\
  \ Follow-up\n\n- This task does NOT implement Badges (cross-cutting property glyphs).\
  \ Nodes render as plain\n  labeled volumes. Badges are a future enhancement.\n-\
  \ This task does NOT implement Ports (public functions on Container membrane). Port\
  \ rendering\n  is a separate future task.\n- Node positions inside their Container\
  \ are pre-computed by the extractor layout algorithm\n  (task-008). If task-008\
  \ does not yet compute symbol-level positions, Nodes can be initially\n  laid out\
  \ using a simple grid inside the Container boundary, with the expectation that\n\
  \  task-008 will be updated to provide pre-computed positions."
---
