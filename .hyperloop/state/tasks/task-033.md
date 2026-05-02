---
id: task-033
title: Implement Container membrane permeability renderer
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: not_started
phase: null
deps:
- task-012
- task-030
round: 0
branch: null
pr: null
pr_title: 'feat(godot): implement Container membrane permeability as continuous visual
  property'
pr_description: "## What and Why\n\nThe Container renderer (task-012) ships with a\
  \ placeholder for membrane\npermeability: every Container renders with the same\
  \ border regardless of how\nexposed its internals are. This task replaces that placeholder\
  \ with a real\ncontinuous visual encoding.\n\nThe spec requires: \"a module with\
  \ 2 public symbols and 30 private symbols has\na thick/opaque membrane; a module\
  \ with 25 public symbols and 5 private symbols\nhas a thin/porous membrane. Permeability\
  \ is a continuous visual property, not\na binary toggle.\"\n\nMembrane permeability\
  \ communicates encapsulation strength at a glance, without\nthe user needing to\
  \ read labels or open a detail panel. A tightly encapsulated\nmodule (few public\
  \ symbols) should look solid; a leaky one (many public symbols\nrelative to its\
  \ total) should look permeable. This lets an architect immediately\nspot modules\
  \ that are over-exposing their internals.\n\nThe raw data — `public_symbol_count`\
  \ and `private_symbol_count` per node —\nis produced by the symbol table extraction\
  \ pass (task-030). This task consumes\nthose fields from the loaded scene graph\
  \ and translates them into a visual\nproperty on the existing Container mesh.\n\n\
  ## Spec Requirements Satisfied\n\n`specs/core/visual-primitives.spec.md` — Requirement:\
  \ Container Primitive,\nScenario: Container membrane permeability\n\n- A module\
  \ with 2 public symbols and 30 private symbols renders with a thick,\n  nearly-opaque\
  \ border.\n- A module with 25 public symbols and 5 private symbols renders with\
  \ a thin,\n  near-transparent border.\n- The visual is continuous: the permeability\
  \ ratio drives a shader parameter\n  linearly, not with threshold steps.\n- Modules\
  \ where `public_symbol_count` and `private_symbol_count` are both 0\n  (e.g. `__init__.py`\
  \ with no symbols) render with a neutral mid-opacity border.\n\n## Key Design Decisions\n\
  \n- **Permeability ratio**: `p = public_symbol_count / max(1, public_symbol_count\
  \ + private_symbol_count)`.\n  `p` ranges from 0.0 (fully private) to 1.0 (fully\
  \ public).\n- **Visual encoding**: the Container box's border uses a ShaderMaterial\
  \ with a\n  `permeability` uniform. At `p = 0.0` the border is full opacity and\
  \ maximum\n  thickness. At `p = 1.0` the border is minimum thickness and partially\n\
  \  transparent (suggesting openings in the membrane). The shader linearly\n  interpolates\
  \ between these extremes based on `p`.\n- **Separation of concerns**: the permeability\
  \ shader is a separate\n  `ShaderMaterial` on the `border_mesh` (a `MeshInstance3D`\
  \ child of the\n  Container node), distinct from the main fill material. This avoids\
  \ coupling\n  the encapsulation visual to the Tint (fill color).\n- Nodes without\
  \ `public_symbol_count` / `private_symbol_count` fields (e.g.\n  pre-task-030 JSON\
  \ or non-module nodes) default to `p = 0.5` (neutral).\n- The permeability rendering\
  \ applies to module-level Containers. Bounded\n  context Containers do not show\
  \ membrane permeability (they are organizational\n  boundaries, not encapsulation\
  \ surfaces).\n\n## Files / Areas Affected\n\n- `godot/shaders/membrane.gdshader`\
  \ — new shader implementing continuous border\n  thickness and opacity based on\
  \ `permeability` uniform\n- `godot/scripts/container_renderer.gd` — updated to compute\
  \ permeability ratio\n  from node's `public_symbol_count` / `private_symbol_count`,\
  \ set the\n  `permeability` uniform on the border mesh's ShaderMaterial\n- `godot/scenes/container_node.tscn`\
  \ — updated to include a `border_mesh`\n  child `MeshInstance3D` alongside the existing\
  \ fill mesh\n- `godot/tests/test_membrane_permeability.gd` — tests covering:\n \
  \ - node with all-private symbols → permeability uniform close to 0.0\n  - node\
  \ with all-public symbols → permeability uniform close to 1.0\n  - node with equal\
  \ public/private → permeability uniform ≈ 0.5\n  - node with missing counts → permeability\
  \ uniform defaults to 0.5\n  - permeability shader uniform is a continuous float,\
  \ not a step value\n\n## How to Verify\n\n1. Run the extractor (with task-030 merged)\
  \ on `~/code/kartograph`.\n2. Launch the Godot project.\n3. Zoom to medium distance\
  \ inside a bounded context. Module Containers should\n   visibly differ in border\
  \ thickness/opacity — high-encapsulation modules\n   should look \"solid\" while\
  \ loosely-encapsulated modules should look \"porous.\"\n4. Confirm the variation\
  \ is continuous: modules with ratios in between extremes\n   should show intermediate\
  \ border weights.\n5. Confirm bounded context Containers do NOT show the membrane\
  \ effect (they\n   remain solid-bordered organizational volumes).\n6. Run `gdscript\
  \ tests/test_membrane_permeability.gd` — all assertions pass.\n\n## Caveats / Follow-up\n\
  \n- The membrane shader encodes permeability via border weight and opacity.\n  Future\
  \ work could add a \"pore\" pattern (small gaps or dots) at high\n  permeability\
  \ values for a more iconic membrane metaphor.\n- Port Primitive rendering (not in\
  \ prototype scope) would eventually place\n  individual Port markers on the membrane\
  \ at positions corresponding to each\n  public symbol. Membrane permeability as\
  \ implemented here is the prerequisite\n  visual infrastructure for that.\n- If\
  \ `task-030` has not run, `public_symbol_count` and `private_symbol_count`\n  will\
  \ be absent from the JSON, triggering the neutral-default fallback.\n  This is intentional:\
  \ the renderer degrades gracefully."
---
