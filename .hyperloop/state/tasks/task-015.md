---
id: task-015
title: Godot app — orthogonal independence spatial separation and highlight
spec_ref: "specs/visualization/orthogonal-independence.spec.md@ca0ad7afad8d95361892fbfba84f55049cf288fd"
status: not-started
phase: null
deps: [task-009, task-007]
round: 0
branch: null
pr: null
pr_title: "feat(godot): render independence groups with spatial gaps and queryable highlight"
pr_description: |
  ## What and Why

  When two groups of modules within a bounded context share no dependencies,
  that independence is a first-class architectural fact: changes to one group
  cannot affect the other. Making this visible without interaction — through
  spatial separation alone — lets the human immediately identify safe change
  boundaries at a glance.

  The extractor (task-007) annotates each module node with an
  `independence_group` identifier. This task uses those identifiers to:
  1. Separate groups spatially within their parent context volume.
  2. Let the human click a module to highlight which peers are independent of it.

  ## Spec Requirements Satisfied

  From `specs/visualization/orthogonal-independence.spec.md`:
  - **Spatial Separation of Independent Groups**: groups occupy distinct spatial
    regions within the context's volume; a visible gap separates them; modules
    within each group remain coupled-close.
  - **Independence as Queryable Property — Selecting a module shows its
    independent peers**: clicking module A highlights all modules in other
    independence groups (safe to change) and visually distinguishes A's own
    group members as "co-dependent".
  - **Independence as Queryable Property — Cross-context independence** (partial):
    bounded contexts with no transitive dependency on the selected context are
    also highlighted.

  ## Key Design Decisions

  - **Spatial gap**: the layout from task-005 already clusters nodes by
    coupling. This task adds a post-load adjustment: within each bounded context,
    compute the centroid of each independence group and apply a push-apart
    offset (≈ 20% of context diameter) so groups are visibly separated. This
    is a Godot-side position adjustment — it modifies the rendered positions but
    does not rewrite the JSON.
  - **Gap visual cue**: a thin dashed plane (using `ImmediateMesh` or a
    semi-transparent `CSGBox3D` slab) is drawn between independence groups
    within each bounded context to make the boundary explicit.
  - **Click interaction**: `InputEventMouseButton` LEFT on a module node
    triggers `IndependenceHighlighter.gd`. It reads `independence_group` from
    the node's metadata, then:
    - Dims all nodes to 40% opacity.
    - Lights up the selected module's group to 100% with a neutral (white) tint.
    - Lights up other independence groups with a green tint (independent = safe).
    - Clicking again or pressing Escape restores default state.
  - Cross-context highlight: bounded context nodes with no edge paths reaching
    the selected context are also tinted green. (Simple reachability check on
    the loaded edge graph.)
  - Smooth animated transitions for all opacity and tint changes using `Tween`.

  ## Files Affected

  - `godot/scripts/IndependenceHighlighter.gd`
  - `godot/scripts/SceneGraphLoader.gd` — post-load independence group
    separation applied here
  - `godot/scripts/NodeRenderer.gd` — selection/highlight state added
  - `godot/tests/test_independence_highlighter.gd`

  ## How to Verify

  1. Load kartograph scene graph. Verify that contexts with multiple detected
     independence groups (from task-007 output) show a visible spatial gap
     and divider plane between groups.
  2. Click any module node: dimming and green-tinting animate in smoothly.
     Modules in other groups are green (independent); modules in the same group
     are white (co-dependent).
  3. Bounded contexts not reachable from the selected module are also green.
  4. Click again or press Escape: all nodes return to default state smoothly.

  `bash .hyperloop/checks/godot-compile.sh`

  ## Caveats

  If task-007 finds no independence groups in kartograph (all modules transitively
  connected), no gap is shown — this is correct behavior per the spec. Use a
  synthetic fixture with known independent groups to verify the feature. The
  cross-context reachability check is a simple BFS on loaded edges (not a full
  transitive-closure computation) for prototype performance; it is sufficient
  at kartograph scale.
---
