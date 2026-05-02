---
id: task-015
title: Godot app — orthogonal independence spatial separation and highlight
spec_ref: specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd
status: not_started
phase: null
deps:
- task-009
- task-007
round: 0
branch: null
pr: null
pr_title: 'feat(godot): render independence groups with spatial gaps and queryable
  highlight'
pr_description: "## What and Why\n\nWhen two groups of modules within a bounded context\
  \ share no dependencies,\nthat independence is a first-class architectural fact:\
  \ changes to one group\ncannot affect the other. Making this visible without interaction\
  \ — through\nspatial separation alone — lets the human immediately identify safe\
  \ change\nboundaries at a glance.\n\nThe extractor (task-007) annotates each module\
  \ node with an\n`independence_group` identifier. This task uses those identifiers\
  \ to:\n1. Separate groups spatially within their parent context volume.\n2. Let\
  \ the human click a module to highlight which peers are independent of it.\n\n##\
  \ Spec Requirements Satisfied\n\nFrom `specs/visualization/orthogonal-independence.spec.md`:\n\
  - **Spatial Separation of Independent Groups**: groups occupy distinct spatial\n\
  \  regions within the context's volume; a visible gap separates them; modules\n\
  \  within each group remain coupled-close.\n- **Independence as Queryable Property\
  \ — Selecting a module shows its\n  independent peers**: clicking module A highlights\
  \ all modules in other\n  independence groups (safe to change) and visually distinguishes\
  \ A's own\n  group members as \"co-dependent\".\n- **Independence as Queryable Property\
  \ — Cross-context independence** (partial):\n  bounded contexts with no transitive\
  \ dependency on the selected context are\n  also highlighted.\n\n## Key Design Decisions\n\
  \n- **Spatial gap**: the layout from task-005 already clusters nodes by\n  coupling.\
  \ This task adds a post-load adjustment: within each bounded context,\n  compute\
  \ the centroid of each independence group and apply a push-apart\n  offset (≈ 20%\
  \ of context diameter) so groups are visibly separated. This\n  is a Godot-side\
  \ position adjustment — it modifies the rendered positions but\n  does not rewrite\
  \ the JSON.\n- **Gap visual cue**: a thin dashed plane (using `ImmediateMesh` or\
  \ a\n  semi-transparent `CSGBox3D` slab) is drawn between independence groups\n\
  \  within each bounded context to make the boundary explicit.\n- **Click interaction**:\
  \ `InputEventMouseButton` LEFT on a module node\n  triggers `IndependenceHighlighter.gd`.\
  \ It reads `independence_group` from\n  the node's metadata, then:\n  - Dims all\
  \ nodes to 40% opacity.\n  - Lights up the selected module's group to 100% with\
  \ a neutral (white) tint.\n  - Lights up other independence groups with a green\
  \ tint (independent = safe).\n  - Clicking again or pressing Escape restores default\
  \ state.\n- Cross-context highlight: bounded context nodes with no edge paths reaching\n\
  \  the selected context are also tinted green. (Simple reachability check on\n \
  \ the loaded edge graph.)\n- Smooth animated transitions for all opacity and tint\
  \ changes using `Tween`.\n\n## Files Affected\n\n- `godot/scripts/IndependenceHighlighter.gd`\n\
  - `godot/scripts/SceneGraphLoader.gd` — post-load independence group\n  separation\
  \ applied here\n- `godot/scripts/NodeRenderer.gd` — selection/highlight state added\n\
  - `godot/tests/test_independence_highlighter.gd`\n\n## How to Verify\n\n1. Load\
  \ kartograph scene graph. Verify that contexts with multiple detected\n   independence\
  \ groups (from task-007 output) show a visible spatial gap\n   and divider plane\
  \ between groups.\n2. Click any module node: dimming and green-tinting animate in\
  \ smoothly.\n   Modules in other groups are green (independent); modules in the\
  \ same group\n   are white (co-dependent).\n3. Bounded contexts not reachable from\
  \ the selected module are also green.\n4. Click again or press Escape: all nodes\
  \ return to default state smoothly.\n\n`bash .hyperloop/checks/godot-compile.sh`\n\
  \n## Caveats\n\nIf task-007 finds no independence groups in kartograph (all modules\
  \ transitively\nconnected), no gap is shown — this is correct behavior per the spec.\
  \ Use a\nsynthetic fixture with known independent groups to verify the feature.\
  \ The\ncross-context reachability check is a simple BFS on loaded edges (not a full\n\
  transitive-closure computation) for prototype performance; it is sufficient\nat\
  \ kartograph scale."
---
