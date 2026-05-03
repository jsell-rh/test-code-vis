---
id: task-020
title: Independence group spatial separation rendering
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: not_started
phase: null
deps:
- task-011
round: 0
branch: null
pr: null
pr_title: 'feat(godot): render independence groups in distinct spatial regions with
  visible gap'
pr_description: "## What and Why\n\nWhen two module groups within a bounded context\
  \ share no dependencies, showing them\nspatially adjacent makes them look coupled.\
  \ Separating them with a visible gap makes\nindependence obvious without requiring\
  \ the user to read labels or click anything.\nThis is \"independence as first-class\
  \ visual concept\" from the orthogonal-independence spec.\n\n## Spec Requirements\
  \ Satisfied\n\nFrom `specs/visualization/orthogonal-independence.spec.md`:\n\n-\
  \ **Spatial Separation of Independent Groups**: groups occupy distinct spatial regions\n\
  \  within the context's volume; a visible gap separates them; modules within each\
  \ group\n  remain close to each other\n- **Smooth regrouping on data change**: when\
  \ a new scene graph is loaded with different\n  independence groups, nodes animate\
  \ smoothly to new positions (slide, don't jump)\n\n## Key Design Decisions\n\n-\
  \ The extractor's layout (task-004/005) already positions modules with independence-aware\n\
  \  spacing (layout respects group separation). Godot reads those positions from\
  \ JSON and\n  renders at them — no re-layout in Godot.\n- To make the gap *visible*,\
  \ each independence group within a bounded context gets a\n  subtle translucent\
  \ background plane (`MeshInstance3D` with `PlaneMesh` at y=0.05)\n  tinted with\
  \ a group-specific colour inside the parent's bounding box. This acts as a\n  \"\
  floor tile\" for the group, distinct from the parent's background.\n- Group tint\
  \ colours cycle through a fixed palette; groups within the same context use\n  adjacent\
  \ palette entries.\n- Smooth regrouping: when `SceneGraphLoader` reloads a new JSON\
  \ (future feature;\n  scaffold for it now), `NodeRenderer` runs a `Tween` on each\
  \ node's position from old\n  to new. The group background plane also tweens its\
  \ bounds. Duration ~0.5s.\n- The reload trigger is out of scope for this prototype\
  \ task; only the animation\n  infrastructure is scaffolded.\n\n## Files Affected\n\
  \n- `godot/scenes/IndependenceGroupPlane.tscn` + `IndependenceGroupPlane.gd` — new:\n\
  \  background plane for one independence group\n- `godot/scenes/NodeRenderer.gd`\
  \ — updated: `independence_group` field used to look up\n  group plane; group plane\
  \ created per unique group id within context\n- `godot/tests/test_independence_rendering.gd`\
  \ — GUT tests: two distinct groups have\n  separate planes; group planes are within\
  \ parent context bounds; nodes in different\n  groups have spatial separation >\
  \ nodes in same group\n\n## Verification\n\n1. GUT tests pass.\n2. In the running\
  \ app: within the IAM context, if the extractor outputs ≥2 groups,\n  a visible\
  \ colour-coded background separates them.\n3. Modules with the same `independence_group`\
  \ value are visually clustered together.\n\n## Caveats\n\nIf kartograph's IAM context\
  \ has only one independence group (all modules transitively\ncoupled), no separation\
  \ will appear — the background plane covers the entire context,\nwhich is correct\
  \ behaviour. The test should handle this case by using a fixture with\na known two-group\
  \ structure."
---
