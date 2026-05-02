---
task_id: task-076
round: 2
role: spec-reviewer
verdict: fail
---
# Spec Alignment Review — task-076
# Spec: specs/core/visual-primitives.spec.md
# Branch: hyperloop/task-076 (rebased onto origin/main a636711)

## Rebase Resolution

The branch had conflicts in `extractor/extractor.py` with origin/main. Conflicts were
resolved by:
1. Removing the spec_nodes paragraph from the `compute_layout` docstring (retaining the
   independence_group paragraph from HEAD/main).
2. Removing the `discover_spec_nodes` invocation from `build_scene_graph` (step 4 HEAD),
   replacing with the independence-groups comment. The non-conflicted
   `compute_independence_groups` + `compute_layout` calls after the conflict are correct.

All 294 pytest tests pass after rebase. check-not-in-scope.sh passes.

---

## Summary

**Verdict: FAIL**

One SHALL requirement (Port Primitive) is completely unimplemented with no test coverage.
Two badge vocabulary items (`error_handling`, `entry_point`) lack dedicated scenario
tests as required by the spec scenario. The remainder of extraction-layer and
composition-layer requirements are covered at the level of this prototype.

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Requirement-by-Requirement Findings

### EXTRACTION LAYER

---

#### Requirement: Scope Nesting Extraction — PARTIAL

**Spec**: The extractor MUST produce the full containment hierarchy: project → packages →
modules → classes → methods.

**Implementation**: `discover_bounded_contexts` + `discover_submodules` in `extractor.py`
implement BC → module containment with `parent` references. Classes and functions are
extracted as `SymbolInfo` entries embedded in module nodes (via `extract_symbols`) but
do NOT have their own node IDs or `parent` references.

**Scenario: Containment tree — PARTIAL**
- `test_bounded_context_parent_is_none` (line 261 test_extractor.py) covers BC parent=None.
- `test_submodule_parent_references_bc` (line 279) covers module→BC parent reference.
- MISSING: The spec says "every leaf is an atomic declaration (function, method, constant)"
  and "every code entity has a parent reference forming a tree." Functions and methods
  are embedded as SymbolInfo arrays on module nodes, not as tree nodes with IDs and
  parent refs. No test verifies that class or function entities carry a parent reference.
- NOTE: Within the prototype scope (extract structure, render in 3D, navigate), the BC →
  module level is implemented and tested. Class/method tree nodes are not in scope for
  the prototype rendering pipeline.

**Scenario: Extraction cost — COVERED**
- The implementation uses single-file AST parsing for all extractions (`ast.parse` per file).
- `test_extractor_uses_only_stdlib_imports` (line 2485) verifies no external dependencies.

---

#### Requirement: Module Graph Extraction — COVERED

**Implementation**: `build_dependency_edges` in `extractor.py` (line 372).

**Scenario: Import-based edges — COVERED**
- `test_cross_context_edge_created` (line 307) — A→B edges emitted.
- `test_cross_context_edge_has_weight` (line 417, also TestIndividualEdgeWeight line 2380)
  — edge carries import count weight.

**Scenario: Distinction from scope nesting — COVERED**
- Cross-context edges have `type="cross_context"` or `type="internal"`.
- Parent references encode containment; edges encode dependencies. Distinct structures,
  distinct tests.

---

#### Requirement: Symbol Table Extraction — COVERED

**Implementation**: `extract_symbols` in `extractor.py` (line 930).

**Scenario: Public vs. private symbols — COVERED**
- `test_public_function_marked_public` (line 1375): `process_order` → visibility=public.
- `test_private_function_marked_private` (line 1391): `_validate_input` → visibility=private.
- `test_function_carries_signature` (line 1409): parameter names, return types.
- `test_function_kind_is_function` (line 1458): kind="function".
- `test_constant_kind_is_constant` (line 1477): ALL_CAPS names → kind="constant".
- `test_variable_kind_is_variable` (line 1496): lowercase names → kind="variable".

**Scenario: Symbol as labeling layer — COVERED**
- `test_symbols_embedded_in_module_node` (line 1443): symbols array present on module node.
- `test_class_extracted_as_symbol` (line 1429): class entries in symbol table.

---

#### Requirement: Type Topology Extraction — COVERED

**Implementation**: `extract_type_topology` in `extractor.py` (line 1044).

**Scenario: Inheritance chain — COVERED**
- `test_inheritance_edge_emitted` (line 1570): edge emitted for `class Foo(Bar)`.
- `test_inheritance_edge_type_is_inherits` (line 1583): type="inherits".

**Scenario: Composition relationship — COVERED**
- `test_composition_edge_emitted` (line 1595): has-a edge emitted for typed fields.
- `test_composition_edge_type_is_has_a` (line 1608): type="has_a".

**Scenario: Extraction cost — PARTIAL**
- Implementation uses AST parsing only (no type inference). However, no test explicitly
  asserts that type inference is NOT performed. The `test_extractor_uses_only_stdlib_imports`
  check verifies no third-party type-inference libraries are used.
- A dedicated test for task-034 (`test_type_topology_ast_only_constraint`) was noted in
  the check system but the test coverage is implicit rather than an explicit assertion.

---

#### Requirement: Call Graph Extraction — COVERED

**Implementation**: `extract_call_graph` in `extractor.py` (line 1210).

**Scenario: Direct calls — COVERED**
- `test_direct_call_edge_emitted` (line 1662): direct_call edge emitted.
- `test_direct_call_edge_type` (line 1673): type="direct_call".

**Scenario: Indirect calls — COVERED**
- `test_dynamic_call_edge_emitted` (line 1701): dynamic_call edge for parameter callees.
- `test_dynamic_call_edge_carries_param_name` (line 1714): param_name field present.

**Scenario: Call frequency annotation — COVERED**
- `test_direct_call_weight_counts_call_sites` (line 1685): weight = number of call sites.

---

#### Requirement: Data Flow Spine Extraction — OUT OF SCOPE

The prototype-scope.spec.md explicitly excludes: "data flow visualization is NOT implemented."
No implementation exists; no tests exist. This is NOT a FAIL per reviewer protocol.

---

#### Requirement: Structural Significance Extraction — COVERED

**Implementation**: `compute_structural_significance` in `extractor.py` (line 1439).

**Scenario: Hub detection — COVERED**
- `test_hub_detection_high_in_degree` (line 2531): in-degree computed, hub flagged.
- `test_hub_node_flagged_with_high_in_degree` (line 1811): is_hub=True for high in-degree.

**Scenario: Bridge detection — COVERED**
- `test_bridge_node_flagged_as_articulation_point` (line 1868): articulation point detection.
- `test_betweenness_centrality_computed` (line 2570): betweenness_centrality field present.
- `test_bridge_is_marked_landmark` (line 2598): bridge→landmark.

**Scenario: Peripheral detection — COVERED**
- `test_peripheral_node_flagged` (line 1846): in_degree=0, out_degree=1 → peripheral.
- `test_peripheral_detection` (line 2549): peripheral flag set.

**Scenario: Community detection — COVERED**
- `test_community_ids_assigned_to_all_nodes` (line 1895).
- `test_connected_nodes_share_community` (line 1906).
- `test_community_drift_detected_for_cross_context_component` (line 1927).
- `test_community_id_assigned_to_modules` (line 2661).

---

#### Requirement: Ubiquitous Dependency Detection — COVERED

**Implementation**: `detect_ubiquitous_dependencies` / `compute_ubiquitous_flags` in
`extractor.py` (lines 1568, 1622).

**Scenario: Standard library suppression — COVERED**
- `test_edge_marked_ubiquitous_above_threshold` (line 2002): edges flagged ubiquitous=True.
- `test_ubiquitous_edges_flagged` (line 2703): edges present but marked ubiquitous.
- `test_build_scene_graph_embeds_ubiquitous_flag` (line 2749).

**Scenario: Threshold — COVERED**
- `test_custom_threshold_respected` (line 2032): configurable threshold.
- `test_build_scene_graph_records_ubiquity_threshold` (line 2085): threshold in metadata.

---

### COMPOSITION LAYER

---

#### Requirement: Container Primitive — COVERED (within prototype scope)

**Implementation**: `main.gd` renders bounded_context nodes as translucent boxes and
module nodes as opaque boxes. Nesting implemented via Godot scene-tree parenting.
Membrane permeability (public/private ratio) implemented in main.gd (line 370).

**Scenario: Module as container — PARTIAL**
- `test_context_boundary_is_visually_distinct_translucent` (test_spatial_structure.gd:193)
- `test_containment_expressed_as_scene_tree_parenting` (line 228)
- `test_membrane_permeability_reflects_public_private_ratio` (line 885)
- Public functions as Ports on membrane: NOT IMPLEMENTED (task-038 is not-started).
  The spec says "the 5 public functions are represented as Ports on the membrane."
  This sub-requirement is MISSING (tracked in Port Primitive below).

**Scenario: Nested containers — COVERED**
- `test_containment_expressed_as_scene_tree_parenting` (line 228): module parented
  inside context in scene tree.

**Scenario: Container membrane permeability — COVERED**
- `test_membrane_permeability_reflects_public_private_ratio` (line 885): opaque container
  has higher alpha than porous container.

---

#### Requirement: Node Primitive — COVERED

**Implementation**: main.gd renders each JSON node as a BoxMesh with a label. Badges
distinguish node aspects (via visual_primitives.gd).

**Scenario: Function node — COVERED**
- `test_node_rendered_at_json_position` (test_node_renderer.gd:65): nodes exist.
- `test_each_json_node_becomes_a_scene_tree_child` (line 155).
- Badges (via visual_primitives.gd) differentiate node aspects.

**Scenario: Node without badges — COVERED**
- `test_no_badges_no_badge_children` (test_visual_primitives.gd:720): plain node
  renders without Badge_ children.

---

#### Requirement: Badge Primitive — PARTIAL

**Implementation**: `visual_primitives.gd` — `attach_primitives` adds Badge_ MeshInstance3D
children per badge type string.

**Scenario: Side-effect badge — COVERED**
- `test_single_badge_creates_mesh_child` (line 607): badge renders as MeshInstance3D.
- `test_badge_y_position_above_node` (line 674): consistent positioning.

**Scenario: Multiple badges — COVERED**
- `test_multiple_badges_all_rendered` (line 627): 3 badges → 3 children.
- `test_badge_positions_are_distinct` (line 649): distinct X positions.

**Scenario: Badge vocabulary — PARTIAL**
The spec mandates: `pure`, `io`, `async`, `stateful`, `error_handling`, `test`,
`entry_point`, `deprecated`.
- Dedicated vocabulary tests (`test_badge_vocabulary_<type>`): `pure` ✓ (line 736),
  `io` ✓ (748), `async` ✓ (760), `stateful` ✓ (784), `test` ✓ (772), `deprecated` ✓ (797).
- **MISSING dedicated tests**: `error_handling` and `entry_point` have no
  `test_badge_vocabulary_error_handling` or `test_badge_vocabulary_entry_point` function.
  - `error_handling` appears in `test_multiple_badges_all_rendered` (line 633) as one of
    three badges but the test asserts count (3 children), NOT the specific name
    "Badge_error_handling".
  - `entry_point` appears in `test_landmark_and_badges_compose` (line 1051) as the badge,
    but the test asserts `begins_with("Badge_")`, NOT the specific name "Badge_entry_point".
  - These indirect tests do not satisfy the spec scenario THEN-clause: "the system supports
    at minimum: … error_handling … entry_point." A dedicated test asserting the specific
    Badge_<type> child name is required for each mandatory badge type.

**Needed**: Add `test_badge_vocabulary_error_handling` and `test_badge_vocabulary_entry_point`
matching the pattern of existing vocabulary tests (assert "Badge_error_handling" and
"Badge_entry_point" child names specifically).

---

#### Requirement: Edge Primitive — COVERED

**Implementation**: `main.gd` `_create_edge` function renders edges with CylinderMesh
thickness proportional to weight, and line_style metadata.

**Scenario: Weighted edge — COVERED**
- `test_edge_thickness_proportional_to_weight` (test_spatial_structure.gd:641).

**Scenario: Edge type distinction — COVERED**
- `test_direct_call_edge_has_solid_style` (line 664): solid for calls.
- `test_import_edge_has_dashed_style` (line 681): dashed for imports.
- `test_inherits_edge_has_dotted_style` (line 731): dotted for inheritance.

**Scenario: Suppressed ubiquitous edges — COVERED**
- `test_ubiquitous_edge_suppressed_by_default` (line 783): ubiquitous edge not drawn.
- `test_ubiquitous_edge_toggle_shows_then_hides` (line 814): toggle works.
- `test_ubiquitous_edge_produces_no_line_mesh` (test_visual_primitives.gd:294).
- `test_ubiquitous_edge_adds_power_rail_indicator_to_source` (line 320).

---

#### Requirement: Port Primitive — MISSING (FAIL)

**Spec**: The system MUST support a Port primitive: a small visual element anchored to a
Container's membrane, representing an interface point (public function, API endpoint,
event emitter).

**Implementation**: None. No `port_renderer.gd`, no Port-related code in `main.gd` or
`visual_primitives.gd`. Task-038 (Port Primitive renderer in Godot) has status
`not-started`.

**Scenario: Port placement — MISSING**
No code places Port elements on Container membranes. No test exercises Port placement.

**Scenario: Port direction — MISSING**
No code distinguishes input vs output Ports. No test covers Port direction.

**Scenario: Port visibility at zoom levels — MISSING**
No code hides Ports at tier-0 or fades them in at tier-2. No test covers Port LOD.

**What is needed**: Implement `port_renderer.gd` per task-038 specification. Add
`test_port_renderer.gd` covering all three scenarios. Wire Port position data into
edge routing so edges connect to Ports rather than Container centroids.

---

#### Requirement: Route Primitive — OUT OF SCOPE

Route requires LLM tracing of paths in response to user queries ("show me the order
submission path"). This is "moldable views (LLM-powered question-driven views)" which is
explicitly NOT in scope per prototype-scope.spec.md. Not a FAIL.

---

#### Requirement: Landmark Primitive — COVERED

**Implementation**: `visual_primitives.gd` (scale boost, LandmarkRing, emission material) +
`main.gd` (excludes landmarks from LOD entries) + extractor (is_landmark flag).

**Scenario: Hub as landmark — COVERED**
- `test_hub_node_has_larger_mesh_than_regular_node` (test_visual_primitives.gd:147).
- `test_hub_node_has_bright_emission_material` (line 185).
- `test_hub_node_not_registered_in_lod_entries` (line 221).
- `test_hub_node_visible_after_far_lod_applied` (line 250).

**Scenario: Entry point as landmark — COVERED**
- `test_entry_point_node_not_registered_in_lod_entries` (line 491).
- `test_entry_point_is_marked_landmark` (test_extractor.py:2622).

**Scenario: Bridge as landmark — COVERED**
- `test_bridge_node_not_registered_in_lod_entries` (test_visual_primitives.gd:463).
- `test_bridge_is_marked_landmark` (test_extractor.py:2598).

**Scenario: Landmark sources — COVERED**
- `test_hub_is_marked_landmark` (test_extractor.py:2585).
- `test_bridge_is_marked_landmark` (line 2598).
- `test_entry_point_is_marked_landmark` (line 2622).

---

#### Requirement: Tint Primitive — PARTIAL (within prototype scope)

**Implementation**: `apply_cluster_tints` in `main.gd` (line 995) applies a warm-amber
tint to pre-computed cluster members. This is a cluster-grouping tint, not the full
LLM-driven categorical Tint primitive.

The full Tint primitive (LLM assigns domain colors per query, one dimension at a time,
with a legend) requires LLM composition — out of prototype scope (moldable views).
Cluster tinting is a reasonable prototype approximation.

**Scenario: Domain tinting — PARTIAL**
- `test_cluster_suggestion_has_visual_tint` (test_spatial_structure.gd:1016): cluster
  members receive a visual tint.
- One palette limitation and legend requirements are not tested (out of prototype scope).

**Scenario: One tint dimension per view — NOT COVERED** (LLM feature, out of scope).
**Scenario: Tint is the only symbolic primitive — NOT COVERED** (LLM legend feature, out of scope).

---

#### Requirement: LOD Shell Primitive — COVERED (within prototype scope)

**Implementation**: `lod_manager.gd` implements three tiers: far (BCs only), medium
(BC + modules), near (all nodes + internal edges).

**Scenario: Three-tier LOD — COVERED**
- `test_far_distance_shows_only_bounded_contexts` (test_spatial_structure.gd:292).
- `test_medium_distance_shows_modules` (line 378).
- `test_near_distance_shows_all_nodes` (line 428).

**Scenario: LLM tier selection — OUT OF SCOPE** (moldable views).
**Scenario: Mixed tiers — OUT OF SCOPE** (LLM per-region tier selection).

---

#### Requirement: Power Rail Notation — COVERED

**Implementation**: `visual_primitives.gd` + `main.gd` suppress ubiquitous edges and add
PowerRailIndicator / PowerRailDisc glyphs.

**Scenario: Standard library power rail — COVERED**
- `test_ubiquitous_edge_produces_no_line_mesh` (test_visual_primitives.gd:294).
- `test_ubiquitous_edge_adds_power_rail_indicator_to_source` (line 320).
- `test_power_rail_disc_added_for_ubiquitous_dep` (line 920).

**Scenario: Power rail toggle — COVERED**
- `test_ubiquitous_edge_toggle_shows_then_hides` (test_spatial_structure.gd:814).

**Scenario: Multiple power rails — PARTIAL**
- `test_multiple_nodes_consistent_rail_position` (test_visual_primitives.gd:1003):
  two nodes with power rails both have consistent Y position.
- The "at most 5-7 power rails before becoming noise" limit is not enforced or tested.
  This is a SHOULD-level concern (visual quality guideline), not a strict SHALL.

---

### COMPOSITION PRINCIPLES

---

#### Requirement: Overlay/Facet Composition — OUT OF SCOPE

LLM-driven view projection. Moldable views not in prototype. Not a FAIL.

---

#### Requirement: Distortion Legend — OUT OF SCOPE

LLM-driven legend per composed view. Not in prototype. Not a FAIL.

---

#### Requirement: Purpose-Level Annotation — OUT OF SCOPE

LLM-generated annotations. Moldable views not in prototype. Not a FAIL.

---

#### Requirement: Primitives Compose, Not Interfere — COVERED

**Implementation**: visual_primitives.gd uses distinct perceptual channels:
- Badge: spherical glyph above node (glyph/icon channel).
- Landmark: scale boost + TorusRing at base (scale/luminance channel).
- Power Rail: flat disc at base (position/size channel).

**Scenario: Channel allocation — COVERED**
- `test_landmark_and_badges_compose` (test_visual_primitives.gd:1038): both present.
- `test_all_three_primitives_compose` (line 1070): all three coexist independently.

**Scenario: Maximum simultaneous primitives — COVERED**
- `test_all_three_primitives_compose` verifies all three decorations are independently
  readable on a single node.

---

#### Requirement: Primitive Set is Closed — COVERED

No LLM exists in the prototype to invent primitives at runtime. The extractor emits
only known edge types and symbol kinds as defined in schema.py.

---

## Verdict Summary

| Requirement                        | Status   | Notes                                                        |
|------------------------------------|----------|--------------------------------------------------------------|
| Scope Nesting Extraction           | PARTIAL  | BC→module tree covered; class/method as SymbolInfo not tree nodes |
| Module Graph Extraction            | COVERED  |                                                              |
| Symbol Table Extraction            | COVERED  |                                                              |
| Type Topology Extraction           | COVERED  |                                                              |
| Call Graph Extraction              | COVERED  |                                                              |
| Data Flow Spine Extraction         | OOS      | Explicitly excluded from prototype scope                     |
| Structural Significance Extraction | COVERED  |                                                              |
| Ubiquitous Dependency Detection    | COVERED  |                                                              |
| Container Primitive                | COVERED  | Port sub-requirement tracked under Port Primitive            |
| Node Primitive                     | COVERED  |                                                              |
| Badge Primitive                    | PARTIAL  | error_handling, entry_point lack dedicated vocab tests       |
| Edge Primitive                     | COVERED  |                                                              |
| Port Primitive                     | MISSING  | **FAIL** — task-038 not-started, no code, no tests          |
| Route Primitive                    | OOS      | LLM-driven, moldable views excluded from prototype           |
| Landmark Primitive                 | COVERED  |                                                              |
| Tint Primitive                     | PARTIAL  | Cluster tint approximation; LLM domain tinting out of scope  |
| LOD Shell Primitive                | COVERED  | LLM tier selection out of scope                              |
| Power Rail Notation                | COVERED  |                                                              |
| Overlay/Facet Composition          | OOS      | LLM-driven, excluded from prototype                          |
| Distortion Legend                  | OOS      | LLM-driven, excluded from prototype                          |
| Purpose-Level Annotation           | OOS      | LLM-driven, excluded from prototype                          |
| Primitives Compose, Not Interfere  | COVERED  |                                                              |
| Primitive Set is Closed            | COVERED  |                                                              |

**FAIL causes (blocking):**

1. **Port Primitive** — MISSING. The spec says MUST. Task-038 is not-started. No
   implementation in any Godot script, no tests. All three Port scenarios are uncovered.

**PARTIAL causes (non-blocking for PASS/FAIL but noted for implementer):**

2. **Badge vocabulary** — `error_handling` and `entry_point` lack dedicated
   `test_badge_vocabulary_<type>` tests asserting the specific "Badge_<type>" child name.

3. **Scope Nesting** — classes and methods are available as SymbolInfo data on module
   nodes but not as tree nodes with IDs and parent refs. Within prototype scope, this
   is acceptable but technically PARTIAL.

**Verdict: FAIL**