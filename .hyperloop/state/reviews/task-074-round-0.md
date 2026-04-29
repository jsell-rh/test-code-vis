---
task_id: task-074
round: 0
role: spec-reviewer
verdict: fail
---
# Visual Primitives Spec Alignment Review

## Summary

The implementation covers **Extraction Layer requirements** well for scope nesting,
module graph, structural significance, and ubiquitous dependency detection.
However, **four Extraction Layer requirements** (Symbol Table, Type Topology,
Call Graph, Data Flow Spine) have NO implementation and NO tests.
The **Composition Layer** is partially implemented — only Container (partial),
Node (partial), Edge (partial), LOD Shell (partial), Landmark, and Power Rail
have code. Badge, Port, Route, Tint, Overlay/Facet Composition, Distortion
Legend, Purpose-Level Annotation, Primitives Compose Not Interfere, and
Primitive Set is Closed are all MISSING implementation and tests.

---

## Extraction Layer Requirements

### Requirement: Scope Nesting Extraction
**Status: COVERED**

Implementation: `extractor.py` discovers bounded contexts (`discover_bounded_contexts`),
submodules (`discover_submodules`), and records `parent` references forming a containment
tree. Every node carries a `parent` field, tree root has `parent=None`, leaves are modules.

Tests: `TestModuleDiscovery` in `test_extractor.py` covers bounded context discovery,
submodule discovery, parent references, and type fields. `TestSceneGraphOutput` confirms
nodes include both BCs and modules.

Note: The spec also requires containment to include classes and methods ("modules contain
classes, classes contain methods"). The extractor only goes 2 levels deep (bounded_context →
module). There is no class/function-level containment. The spec says "leaves are atomic
declarations (function, method, constant)" but the implementation stops at module level.
However, the immediate requirement ("at any depth") is partially met and the prototype
scope likely limits this. This is noted but treated as PARTIAL rather than MISSING since
the two-level containment hierarchy does form a tree with parent references.

**Revised Status: PARTIAL** — Containment tree is implemented for BC/module levels only;
class/method level containment (atomic declarations as leaves) is absent. No test covers
class-level or function-level scope nesting. The spec mandates every leaf is an "atomic
declaration (function, method, constant)" which is not true in this implementation.

### Requirement: Module Graph Extraction
**Status: COVERED**

Implementation: `build_dependency_edges` in `extractor.py` parses imports via
`extract_imports_from_file` (AST-based), produces directed edges A→B and A→C for
`import B` and `from C import foo`. Each edge carries `type` (cross_context/internal).
Import count (weight) is tracked for aggregate edges.

Tests: `TestDependencyExtraction` covers cross-context edge creation/type, internal edge
creation/type, no self-edges, required keys, aggregate edge emission and weight.

### Requirement: Symbol Table Extraction
**Status: MISSING**

No implementation found in `extractor.py` or `schema.py` for:
- Extracting named entities (functions, types, constants, variables) per scope
- Recording public vs. private visibility (e.g. `_validate_input` → private)
- Recording signatures (parameter names, type hints, return types)
- Any `symbols` field in `Node` or `SceneGraph` schema

No tests found for symbol table extraction in `test_extractor.py` or any other test file.

The spec MUST requirement: "The extractor MUST produce the named entities in each scope
— functions, types, constants, variables — with their signatures and visibility."

**This is a FAIL condition.**

### Requirement: Type Topology Extraction
**Status: MISSING**

No implementation found in `extractor.py` or `schema.py` for:
- Inheritance edges (inherits edge type)
- Composition edges (has_a edge type)
- Class declaration, field type, or base class analysis

`EdgeType` in schema.py is `Literal["cross_context", "internal", "aggregate"]` — no
`inherits` or `has_a` edge types exist.

No tests found for type topology extraction in any test file.

The spec MUST requirement: "The extractor MUST produce the graph of type relationships:
inheritance, implementation, and composition (has-a)."

**This is a FAIL condition.**

### Requirement: Call Graph Extraction
**Status: MISSING**

No implementation found in `extractor.py` or `schema.py` for:
- Function-to-function call edges (`direct_call` or `dynamic_call` edge types)
- Call site analysis within function bodies
- Call frequency annotation (weight per call count)
- Dynamic call detection (parameter-based dispatch)

`EdgeType` does not include `direct_call` or `dynamic_call`. No function-level call
analysis is performed anywhere in the extractor.

No tests found for call graph extraction in any test file.

The spec MUST requirement: "The extractor MUST produce the directed graph of
function-to-function invocations."

**This is a FAIL condition.**

### Requirement: Data Flow Spine Extraction
**Status: MISSING**

No implementation found in `extractor.py` or `schema.py` for:
- Intraprocedural data flow chain extraction
- Parameter-to-return-value tracing within function bodies
- One-call-deep interprocedural flow (A's x → B's parameter → B's return → A's y)
- Any `data_flow` or `spine` fields in the schema

No tests found for data flow spine extraction in any test file.

The spec MUST requirement: "The extractor MUST produce intraprocedural data flow chains
showing how values produced in one place are consumed in another, scoped to function
parameters and return values."

**This is a FAIL condition.**

### Requirement: Structural Significance Extraction
**Status: COVERED**

Implementation: `compute_structural_significance` in `extractor.py` computes:
- `in_degree` / `out_degree`: raw edge counts
- `is_hub`: True when in_degree > 2× mean AND in_degree ≥ 2
- `is_bridge`: articulation point via DFS (bridges that disconnect graph)
- `is_peripheral`: in_degree == 0 AND out_degree ≤ 1
- `community_id`: connected-component index
- `community_drift`: True when community spans multiple bounded contexts

Note on community detection: The spec says "Louvain/Leiden" but implementation uses
connected-components BFS. This is a weaker algorithm that does not find clusters within
a connected component — it only finds disconnected subgraphs. The spec says "annotated
with its detected community identifier AND modules whose detected community differs from
their declared package are flagged as community_drift." The community_drift logic works
but community_id does not match the Louvain/Leiden requirement.

Tests: `TestStructuralSignificance` in `test_extractor.py` comprehensively covers
in-degree, out-degree, hub detection, non-hub detection, peripheral detection,
non-peripheral detection, bridge detection, non-bridge detection, community_id
assignment, connected nodes share community, disconnected nodes have different
communities, community_drift for cross-context components, no drift within single context,
and integration via `build_scene_graph`.

**Revised Status: PARTIAL** — Community detection uses connected-components rather than
Louvain/Leiden as specified. All other scenarios are fully covered.

### Requirement: Ubiquitous Dependency Detection
**Status: COVERED**

Implementation: `compute_ubiquitous_flags` in `extractor.py` counts fraction of module
nodes that import each target; flags edges with `ubiquitous=True` when fraction exceeds
threshold (default 0.5). `Metadata` schema carries `ubiquity_threshold`. Called from
`build_scene_graph`.

Tests: `TestUbiquitousFlags` in `test_extractor.py` covers edge marked ubiquitous above
threshold, not marked below threshold, custom threshold, return value mapping, no module
nodes returns empty, non-ubiquitous edges unchanged, threshold recorded in metadata, and
integration via `build_scene_graph`.

---

## Composition Layer Requirements

### Requirement: Container Primitive
**Status: PARTIAL**

Implementation: `_create_volume` in `main.gd` creates bounded regions with visual
distinction: bounded_context → large translucent box (membrane = translucent boundary),
module → smaller opaque box nested inside parent. Containment via scene tree parenting
matches the "bounded region representing scope" concept.

However, the spec requires:
- Membrane visual density reflecting encapsulation strength (permeability) — NOT
  implemented. All contexts have the same alpha regardless of public/private ratio.
- 3+ levels of nesting (package → module → class → method) — only 2 levels exist.
- Ports on the membrane representing public symbols — NOT implemented.

Tests (Godot): `test_containment_rendering.gd` covers translucency, opacity of modules,
module parented inside context, size comparison (BC larger than module), and cull_disabled.
`test_spatial_structure.gd` covers distinct regions, translucent boundary, containment as
scene tree parenting, opaque module boundary.

What is missing: No test for membrane permeability (public/private ratio affecting visual
density). No test for 3+ nesting depth. These are MUST requirements.

**Revised Status: PARTIAL** — Core bounded region / nesting implemented and tested.
Membrane permeability (continuous visual property from public/private ratio) and deeper
nesting are absent.

### Requirement: Node Primitive
**Status: PARTIAL**

Implementation: `_create_volume` creates nodes with identity (name label, position). All
nodes are uniform boxes with no type-specific shape. Badges are referenced in task backlog
(task-077, task-084, task-087) but not implemented.

Tests (Godot): `test_node_renderer.gd` verifies nodes render at JSON positions and become
scene-tree children. `test_size_encoding.gd` covers proportional mesh sizes.

What is missing: Badge attachment (zero or more Badges). The spec says "Nodes do not have
baked-in types — their visual identity comes entirely from their Badges." Without Badges,
the Node primitive is incomplete.

**Revised Status: PARTIAL** — Node creation and identity implemented and tested. Badge
support (which gives Nodes their visual identity per spec) is absent.

### Requirement: Badge Primitive
**Status: MISSING**

No implementation found in `extractor.py`, `schema.py`, or any Godot script for:
- Badge schema fields (`badges` array on nodes)
- Badge vocabulary (pure, io, async, stateful, error_handling, test, entry_point, deprecated)
- Badge glyph rendering on Node
- Badge positioning (consistent dock position)
- Multiple badge ordering

Task backlog entries (task-077, task-084, task-087) confirm this is planned but not done.

No tests found in any test file for Badge primitive behavior.

The spec MUST requirement: "The system MUST support a Badge primitive: a small glyph
docked to a Node indicating an aspect or cross-cutting property." Badge vocabulary MUST
include at minimum: pure, io, async, stateful, error_handling, test, entry_point, deprecated.

**This is a FAIL condition.**

### Requirement: Edge Primitive
**Status: PARTIAL**

Implementation: `_create_edge` in `main.gd` creates directed connection lines with:
- ImmediateMesh for line visual
- CylinderMesh arrowhead (direction indicator)
- Color distinction: orange (cross_context) vs grey (internal)
- LOD visibility management

What is missing:
- Weight encoding as visual thickness — aggregate edges use scale but individual edges do
  not encode weight as line thickness. The spec requires "visual thickness is proportional
  to the weight." ImmediateMesh lines have no thickness control in Godot (they render as
  1-pixel-wide lines regardless of weight).
- Line style by type (solid/dashed/dotted): only color distinguishes edge types, not line
  style. The spec requires "solid for calls, dashed for imports, dotted for inheritance."
  ImmediateMesh in Godot doesn't support dashed/dotted lines natively.
- The suppressed ubiquitous edges scenario is implemented and tested.

Tests (Godot): `test_dependency_rendering.gd` covers line mesh creation, direction cone,
cone near target, orange color for cross_context. `test_visual_primitives.gd` covers
ubiquitous edge suppression and power rail indicator.

**Revised Status: PARTIAL** — Core edge creation with direction implemented and tested.
Weight-encoded thickness and line-style-by-type (solid/dashed/dotted) are absent.

### Requirement: Port Primitive
**Status: MISSING**

No implementation found in any script for:
- Port visual elements on Container membranes
- Port placement (public functions as ports)
- Port direction (input vs output)
- Port LOD visibility (hidden at far, fade in closer)
- Edges connecting to Ports rather than Container body

No tests found in any test file for Port primitive.

The spec MUST requirement: "The system MUST support a Port primitive: a small visual
element anchored to a Container's membrane, representing an interface point."

**This is a FAIL condition.**

### Requirement: Route Primitive
**Status: MISSING**

No implementation found in any Godot script for:
- Named highlighted path through the graph
- Route rendering with distinct visual treatment (color, dash pattern)
- Route direction (animated particles, gradient, arrow heads)
- Entry/terminus visual distinction
- De-emphasis of non-Route elements
- Maximum 4 simultaneous Routes

No tests found for Route primitive.

The spec MUST requirement: "The system MUST support a Route primitive: a named,
highlighted path through the graph representing a unit of work."

**This is a FAIL condition.**

### Requirement: Landmark Primitive
**Status: COVERED**

Implementation: `main.gd` implements Landmark via `is_hub` flag:
- Hub nodes not registered in `_lod_node_entries` → never hidden by LOD manager
- Hub nodes use `landmark_sz = sz * 1.5` → larger mesh
- Hub nodes get bright yellow material with `emission_enabled = true`
- Structural significance computation provides `is_hub` from extractor

Tests (Godot): `test_visual_primitives.gd` comprehensively covers:
- `test_hub_node_has_larger_mesh_than_regular_node` — distinctive size
- `test_hub_node_has_bright_emission_material` — distinctive brightness
- `test_hub_node_not_registered_in_lod_entries` — persists at all zoom levels
- `test_hub_node_visible_after_far_lod_applied` — visible at FAR LOD

Landmark sources spec: "hubs (high in-degree), bridges (high betweenness centrality),
entry points, and human-designated Landmarks." Implementation only uses `is_hub`;
bridges and entry points do not get Landmark treatment. This is PARTIAL coverage of
Landmark sources requirement.

**Revised Status: PARTIAL** — Hub-as-landmark fully implemented and tested. Bridge-as-
landmark and entry-point-as-landmark are absent (no `is_bridge` path to Landmark
visual treatment, no entry-point detection leading to Landmark).

### Requirement: Tint Primitive
**Status: MISSING**

No implementation found in any Godot script for:
- Categorical background color encoding on Containers
- One-dimension-at-a-time constraint
- 4-6 color palette limit
- Tint legend always visible when Tint active
- LLM Tint reassignment per query

`understanding_overlay.gd` applies colors to nodes but this is for overlay/analysis modes
(alignment: green/red/grey; quality: red/orange), not for the categorical Tint primitive
which requires a named dimension and a visible legend.

No tests found for Tint primitive.

The spec MUST requirement: "The system MUST support a Tint primitive: a background color
on a Container encoding one categorical dimension."

**This is a FAIL condition.**

### Requirement: LOD Shell Primitive
**Status: PARTIAL**

Implementation: `lod_manager.gd` implements three tiers:
- FAR (> 80 units): only bounded_context visible, all edges hidden
- MEDIUM (20-80 units): bounded_context + module visible, cross_context edges visible
- NEAR (≤ 20 units): everything visible

The LOD system uses distance-based thresholds and `_lod_node_entries` / `_lod_edge_entries`.

What is missing:
- Precomputed summaries at each tier (aggregate metrics — total LOC, total in-degree,
  total out-degree — for tier 0). The LOD manager hides/shows nodes but does NOT display
  precomputed summary text at FAR tier.
- Mixed-tier selection (LLM selects tier 0 for background contexts, tier 1+ for
  relevant ones). Currently distance is uniform for all nodes.
- Smooth opacity transitions for individual nodes — LOD sets `visible = true/false`
  (binary). Aggregate edges use Tween animation, but individual nodes snap.
- Aggregate edge LOD is implemented (shown only at FAR) and does fade in with Tween.

Tests (Godot): `test_spatial_structure.gd` covers far/medium/near LOD scenarios with
exact threshold values and specific assertions. `test_visual_primitives.gd` covers FAR
LOD hub visibility and module hiding.

**Revised Status: PARTIAL** — Three-tier LOD tiers implemented and tested. Precomputed
summary display at tier 0 and smooth opacity transitions for individual nodes are absent.

### Requirement: Power Rail Notation
**Status: COVERED**

Implementation: `_create_edge` in `main.gd` returns early for `ubiquitous=True` edges
(no line drawn). `_add_power_rail_indicator` adds a `MeshInstance3D` named
"PowerRailIndicator" (bright magenta sphere) to source anchor. Duplicate indicators are
deduplicated. `_build_aggregate_edges` also suppresses ubiquitous edges.

Tests (Godot): `test_visual_primitives.gd` covers:
- `test_ubiquitous_edge_produces_no_line_mesh` — edge NOT drawn
- `test_ubiquitous_edge_adds_power_rail_indicator_to_source` — indicator present
- `test_non_ubiquitous_edge_still_drawn` — normal edge still visible
- `test_non_ubiquitous_source_has_no_rail_indicator` — no spurious indicators

Power rail toggle (spec: "the human can toggle ubiquitous edges on if needed") — NOT
implemented. This is a SHOULD scenario but affects the coverage completeness.

### Requirement: Overlay/Facet Composition
**Status: MISSING**

The `understanding_overlay.gd` implements specific analysis overlays (alignment, quality,
failure impact) that change color assignments. However, this does NOT implement the
Overlay/Facet Composition requirement as specified:

The spec requires:
- Projecting different lenses over the SAME structural geography WITHOUT changing topology
- Edge weights shifting to encode different dimensions (blast radius vs import count)
- Tints shifting to encode different dimensions per facet
- Landmarks shifting to highlight different nodes per facet
- LLM selects which Edges to show, which Tints to assign, which LOD tier per region

The existing overlay system is hardcoded to three fixed modes (alignment, quality,
failure). It does not support arbitrary facet selection, does not change edge weight
encoding, does not shift Landmarks, and does not support LLM-directed facet composition.

No tests found that test the facet/overlay composition architecture as specified.

The spec MUST requirement: "The system MUST support projecting different lenses over the
same structural geography without changing the underlying topology."

**This is a FAIL condition.**

### Requirement: Distortion Legend
**Status: MISSING**

No implementation found for:
- A legend component showing what Tint encodes
- What Edge weight encodes
- What is suppressed (power rails, LOD-hidden elements)
- What Landmarks are active
- Count of hidden nodes and edges ("showing 12 of 147 modules")

The spec MUST requirement: "Every composed view MUST include a legend that makes the
current distortion explicit."

**This is a FAIL condition.**

### Requirement: Purpose-Level Annotation
**Status: MISSING**

No implementation found in any script for:
- LLM-generated purpose annotations on Containers or clusters
- Beacon pattern recognition annotations on Nodes
- Invariant annotations on Containers

Task backlog entries (task-084, task-085, task-087) reference "badge extractor" and
"badge Godot rendering" but those are Badge vocabulary items, not purpose-level
annotations. No implementation for cluster-level or purpose-level text.

No tests found for purpose-level annotations.

The spec MUST requirement: "The system MUST support attaching purpose-level annotations
to structural elements, bridging the gap between mechanism and meaning."

**This is a FAIL condition.**

### Requirement: Primitives Compose, Not Interfere
**Status: MISSING**

No implementation found for a formal channel allocation scheme:
- The code does use position (spatial containment), line (edges), and color (Tint-like
  via understanding overlays), but these overlap — overlay colors conflict with Landmark
  colors (both use albedo/material on the same mesh child).
- No design enforcement prevents two primitives from competing for the same perceptual
  channel.
- When alignment overlay applies green/red colors, it overwrites the Landmark bright
  yellow, defeating the Landmark's perceptual channel.

No tests found that verify distinct perceptual channel allocation or that simultaneous
primitives are independently readable.

The spec MUST requirement: "Visual encodings of different primitives MUST use distinct
perceptual channels so that simultaneous primitives are independently readable."

**This is a FAIL condition.**

### Requirement: Primitive Set is Closed
**Status: MISSING**

No implementation found for:
- Runtime enforcement that only defined primitives are instantiated
- Detection or rejection of novel primitive invention
- LLM interface that exposes exactly the defined primitive set

The system has no formal primitive registry or closed-set enforcement mechanism.

No tests found verifying the closed-set property.

The spec MUST requirement: "No primitive is invented at runtime. The LLM selects from
this set; it does not extend it."

**This is a FAIL condition.**

---

## Verdict: FAIL

### MUST requirements that are MISSING (each is a fail by itself):

1. **Symbol Table Extraction** — No implementation, no tests
2. **Type Topology Extraction** — No implementation, no tests
3. **Call Graph Extraction** — No implementation, no tests
4. **Data Flow Spine Extraction** — No implementation, no tests
5. **Badge Primitive** — No implementation, no tests
6. **Port Primitive** — No implementation, no tests
7. **Route Primitive** — No implementation, no tests
8. **Tint Primitive** — No implementation, no tests
9. **Overlay/Facet Composition** — No spec-conforming implementation, no tests
10. **Distortion Legend** — No implementation, no tests
11. **Purpose-Level Annotation** — No implementation, no tests
12. **Primitives Compose, Not Interfere** — No formal channel enforcement, no tests
13. **Primitive Set is Closed** — No enforcement mechanism, no tests

### MUST requirements that are PARTIAL (implementation exists but incomplete or missing
full test coverage):

1. **Scope Nesting Extraction** — Stops at module level; class/function leaves absent
2. **Structural Significance Extraction** — Connected-components used instead of Louvain/Leiden
3. **Container Primitive** — Membrane permeability absent; deeper nesting absent
4. **Node Primitive** — Badge support absent
5. **Edge Primitive** — Weight-encoded thickness absent; line style by type absent
6. **Landmark Primitive** — Only hub-as-landmark; bridge/entry-point landmark absent
7. **LOD Shell Primitive** — Precomputed summaries absent; smooth per-node transitions absent

### MUST requirements that are COVERED:

1. **Module Graph Extraction** — Full implementation and tests
2. **Ubiquitous Dependency Detection** — Full implementation and tests
3. **Power Rail Notation** — Full implementation and tests