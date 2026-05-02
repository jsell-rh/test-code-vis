---
id: task-038
title: Implement Port primitive renderer in Godot (public interface points on Container
  membrane)
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: in_progress
phase: verify
deps:
- task-023
- task-012
- task-014
round: 1
branch: hyperloop/task-038
pr: https://github.com/jsell-rh/test-code-vis/pull/240
pr_title: 'feat(godot): render Port primitives on Container membrane (public symbol
  interface points)'
pr_description: "## What and Why\n\nImplements the Port primitive renderer in Godot.\
  \ A Port is a small visual element\nanchored to a Container's membrane that represents\
  \ an interface point — a public\nfunction, API endpoint, or event emitter. Ports\
  \ make a module's public API visible\nwithout opening it, and Edges connect to Ports\
  \ rather than to the Container body,\nmaking the entry/exit points of a dependency\
  \ explicit.\n\nThis task reads public symbol data from the scene graph (produced\
  \ by task-023's symbol\ntable extraction) and renders them as Ports on the Container\
  \ membrane (established by\ntask-012).\n\n## Spec Requirements Satisfied\n\n`specs/core/visual-primitives.spec.md`\
  \ — Requirement: Port Primitive\n\n- Public functions rendered as labeled Ports\
  \ on Container membrane\n- Edges connect to Ports, not directly to Container body\n\
  - Input/output Port direction distinction (parameters = input, return values = output)\n\
  - Port visibility is LOD-driven: hidden at tier-0 (far), fade in at tier-2 (near)\n\
  \n## Key Design Decisions\n\n### Data source: symbols field, no schema extension\
  \ required\n\nThe symbol table extraction (task-023) adds a `symbols` array to each\
  \ node, with each\nsymbol carrying `name`, `visibility`, and `signature` (parameters\
  \ + return type). No\nadditional extractor pass is needed. The Port renderer filters\
  \ symbols where\n`visibility == \"public\"` and treats each as a Port.\n\n```\n\
  symbols[*]{visibility: \"public\"}  →  Port on membrane\n```\n\nPort direction is\
  \ derived from the symbol signature:\n- **Input Port**: one per parameter in the\
  \ function signature (parameters represent\n  accepted dependencies/data)\n- **Output\
  \ Port**: one per distinct non-`None` return type in the signature (return\n  values\
  \ represent emitted data/events)\n\nFor the prototype, a simplified form is used:\
  \ one input-side Port and one output-side\nPort per public function (full per-parameter\
  \ ports are tier-2 enhancement).\n\n### Port placement on membrane\n\nPorts are\
  \ distributed evenly around the Container's bounding surface:\n- Input ports appear\
  \ on the left/bottom face of the Container volume\n- Output ports appear on the\
  \ right/top face\n- Each Port is a small labeled sphere or disc (`MeshInstance3D`)\
  \ anchored to the\n  membrane surface at a computed offset\n- Port label (`Label3D`)\
  \ shows the function name, oriented toward the camera\n\n### LOD integration\n\n\
  Ports are a tier-2 (near) detail. At tier-0 and tier-1:\n- Port meshes: alpha =\
  \ 0 (hidden)\n- Port labels: alpha = 0\n\nAt tier-2 (near), ports fade in using\
  \ the same animated opacity system as the LOD\nShell (task-014). This matches the\
  \ spec: \"As the human zooms in, Ports fade in on\nthe membrane.\"\n\n### Edge routing\
  \ to Ports\n\nThe existing Edge renderer (task-013) currently connects Edges to\
  \ Container centroids.\nThis task extends the Edge renderer to look up Port positions\
  \ and route Edge endpoints\nto the closest Port on the source/target Container:\n\
  - If a Port position is available, the Edge's endpoint snaps to the Port\n- If no\
  \ Ports are present (tier-0/1 LOD), the Edge falls back to Container centroid\n\n\
  This is a non-breaking extension: the fallback preserves existing Edge rendering\n\
  behavior when Ports are not visible.\n\n### Container membrane permeability integration\n\
  \nThe membrane permeability visual (task-033) and Port rendering are independent\
  \ features\nthat both render on the Container membrane surface. This task does NOT\
  \ require task-033\nto be complete. Ports are rendered as discrete anchored elements\
  \ regardless of membrane\nvisual state. Coordinate with task-033 implementer to\
  \ avoid overlapping surface anchors.\n\n## Files / Areas Affected\n\n- `godot/rendering/port_renderer.gd`\
  \ — new GDScript; reads public symbols from a node's\n  symbol table; computes Port\
  \ positions on the Container membrane; instantiates Port\n  mesh and label nodes;\
  \ manages LOD opacity; exposes Port world positions for Edge routing\n- `godot/rendering/container_renderer.gd`\
  \ — extended to instantiate `port_renderer`\n  per Container; store Port position\
  \ map keyed by symbol name\n- `godot/rendering/edge_renderer.gd` — extended to query\
  \ Port positions when routing\n  Edge endpoints; fall back to Container centroid\
  \ when Ports are hidden/unavailable\n- `godot/tests/test_port_renderer.gd` — Godot\
  \ behavioral tests covering:\n  - Container with 4 public symbols displays 4 Port\
  \ elements on its membrane\n  - Container with 0 public symbols displays no Port\
  \ elements\n  - Port labels match the function names from the symbol table\n  -\
  \ At tier-0 LOD all Port meshes and labels have alpha = 0\n  - At tier-2 LOD Port\
  \ meshes and labels have alpha > 0\n  - Edge endpoints route to Port positions rather\
  \ than Container centroid when Ports visible\n  - Input and output Ports appear\
  \ on opposing faces of the Container\n\n## How to Verify\n\n1. Run the extractor\
  \ on `~/code/kartograph` (with task-023 symbol table data present).\n2. Load the\
  \ scene graph in Godot.\n3. Zoom in to a module Container — confirm small labeled\
  \ Port elements appear on its\n   membrane, one per public function.\n4. Confirm\
  \ Edges from other modules terminate at Port positions, not at Container centers.\n\
  5. Zoom out to tier-0 — confirm Ports disappear and Edges route back to Container\
  \ centroids.\n6. Run Godot behavioral tests: all test suites pass, including port-specific\
  \ suites.\n\n## Caveats / Follow-up\n\n- Prototype renders one Port per public function\
  \ (not per parameter). Full per-parameter\n  Port rendering is a future enhancement\
  \ once the visual is validated.\n- Port placement algorithm distributes ports evenly\
  \ around the membrane. For Containers\n  with many public functions (e.g. 20+),\
  \ ports may become crowded. A future task can\n  implement port-count-aware spacing\
  \ or grouping.\n- Edge routing to Ports is an extension to the existing Edge renderer\
  \ (task-013). If\n  task-013 is still in-flight when this task begins, coordinate\
  \ to avoid merge conflicts\n  in `edge_renderer.gd`.\n- The Port primitive spec\
  \ states that Ports are labeled and that Edges connect to Ports.\n  Full conformance\
  \ requires both mesh placement AND edge routing. Both are in scope here."
---
