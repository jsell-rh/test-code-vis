---
task_id: task-023
round: 0
role: spec-reviewer
verdict: fail
---
# Spec Alignment Review: visual-primitives.spec.md
Branch: hyperloop/task-023 (rebased onto main; merge conflict in godot/tests/run_tests.gd resolved)

## Non-directional movement assertions check
`bash .hyperloop/checks/check-nondirectional-movement-assertions.sh` → OK (no violations found)

---

## Extraction Layer Requirements

### Requirement: Scope Nesting Extraction — PARTIAL

**Spec:** The extractor MUST produce the full containment hierarchy: project contains packages, packages contain modules, modules contain classes, classes contain methods. Every leaf is an atomic declaration (function, method, constant). The tree root is the project itself.

**Code:** `discover_bounded_contexts()` and `discover_submodules()` produce a two-level nesting (bounded_context → module). `extract_symbols()` emits functions/classes but as an embedded `symbols` array inside the module node, NOT as separate tree nodes. No project-root node is created.

**Tests:** `test_bounded_context_parent_is_none`, `test_submodule_parent_references_bc`, `test_module_parented_inside_context` (GDScript) cover the two-level nesting. No tests exist for:
- a project-root node at the tree apex
- atomic declarations (functions/constants) as first-class tree leaf nodes

**Assessment:** The two-level prototype nesting (BC → module) is implemented and tested. The "every leaf is an atomic declaration" clause and the "tree root is the project itself" clauses are not implemented. **Given prototype-scope.spec.md focuses solely on "extract structure, render in 3D, navigate with top-down camera", the deeper nesting (module → class → method) is considered out of prototype scope.** PARTIAL noted but NOT a blocking failure under prototype scope rules.

---

### Requirement: Module Graph Extraction — PARTIAL (BLOCKING)

**Spec:** The extractor MUST produce the directed graph of import-based dependencies between modules. **Each edge carries the import count (number of individual import statements between the pair).**

**Code:** `build_dependency_edges()` (extractor/extractor.py, lines 394–479) creates:
- `cross_context` edges (BC → BC) with NO weight field
- `internal` edges (module → module) with NO weight field
- `aggregate` edges (BC → BC) WITH `weight` field (total import count)

Individual `cross_context` and `internal` edges are built from `raw_edges` (a set), which deduplicates by (source, target, type) only—no import count is accumulated per module pair. The weight field only appears on aggregate edges.

**Tests:**
- `test_aggregate_edge_has_weight` — covers aggregate edges only
- No test verifies that an individual `cross_context` or `internal` edge carries a `weight` / import-count field
- The edge-weight rendering test (`test_edge_thickness_proportional_to_weight` in test_spatial_structure.gd) uses fixture data with explicit weight values—it does NOT verify the extractor produces weighted individual edges

**Gap:** The spec SHALL requires "each edge carries the import count". Individual module graph edges do not carry this. No test covers this property. **This is a blocking FAIL.**

What is needed:
1. `build_dependency_edges()` must accumulate a per-(source, target) count of import statements and emit it as `weight` on each `cross_context` / `internal` edge.
2. A pytest test must verify: given module A importing two symbols from module B, the resulting edge `A → B` has `weight == 2` (or the applicable count).

---

### Requirement: Symbol Table Extraction — COVERED

**Code:** `extract_symbols()` (extractor.py, lines 933–1003). Implemented.
**Tests:** `TestSymbolTableExtraction` (test_extractor.py lines 1385–1469):
- `test_public_function_marked_public` ✓
- `test_private_function_marked_private` ✓
- `test_function_carries_signature` ✓
- `test_class_extracted_as_symbol` ✓
- `test_symbols_embedded_in_module_node` ✓

**Scenario: Public vs. private symbols** — COVERED
**Scenario: Symbol as labeling layer** — the scenario is compositional (a rendering concern); the extraction side (symbols carried by module nodes) is COVERED.

---

### Requirement: Type Topology Extraction — COVERED

**Code:** `extract_type_topology()` (extractor.py, lines 1011–1138). Implements inheritance and composition edge detection via AST parsing only—no type inference or flow analysis.
**Tests:** `TestTypeTopologyExtraction` (test_extractor.py lines 1521–1572):
- `test_inheritance_edge_emitted` ✓
- `test_inheritance_edge_type_is_inherits` ✓
- `test_composition_edge_emitted` ✓
- `test_composition_edge_type_is_has_a` ✓

**Scenario: Extraction cost** — AST-only confirmed in code; no explicit timing/cost test, but the spec's statement that it "requires only AST parsing" is satisfied by the implementation design.

---

### Requirement: Call Graph Extraction — COVERED

**Code:** `extract_call_graph()` (extractor.py, lines 1177–1285).
**Tests:** `TestCallGraphExtraction` (test_extractor.py lines 1613–1685):
- `test_direct_call_edge_emitted` ✓
- `test_direct_call_edge_type` ✓
- `test_direct_call_weight_counts_call_sites` ✓ (weight ≥ 3 for three call sites)
- `test_dynamic_call_edge_emitted` ✓
- `test_dynamic_call_edge_carries_param_name` ✓

**Scenario: Direct calls** — COVERED
**Scenario: Indirect calls** — COVERED (`dynamic_call` with `param_name`)
**Scenario: Call frequency annotation** — COVERED (weight field on direct_call edges)

---

### Requirement: Data Flow Spine Extraction — OUT OF PROTOTYPE SCOPE

**Spec:** MUST produce intraprocedural data flow chains.
**Code:** Not implemented (no function in extractor.py).
**Tests:** None.

`prototype-scope.spec.md` states: "data flow visualization is NOT implemented". Per review guidelines, this is NOT a failure.

---

### Requirement: Structural Significance Extraction — COVERED

**Code:** `compute_structural_significance()` (extractor.py, lines 1406–1524). Implements hub, bridge, peripheral, community detection; embeds `is_landmark`.
**Tests:** `TestStructuralSignificance` and `TestStructuralSignificanceExtraction` (test_extractor.py lines 1738–2300):
- Hub detection: `test_hub_node_flagged_with_high_in_degree`, `test_hub_detection_high_in_degree` ✓
- Bridge detection: `test_bridge_node_flagged_as_articulation_point`, `test_betweenness_centrality_computed` ✓
- Peripheral detection: `test_peripheral_node_flagged`, `test_peripheral_detection` ✓
- Community detection: `test_community_ids_assigned_to_all_nodes`, `test_connected_nodes_share_community`, `test_community_drift_detected_for_cross_context_component` ✓
- Landmark derivation: `test_hub_is_marked_landmark`, `test_bridge_is_marked_landmark`, `test_entry_point_is_marked_landmark` ✓

**Scenario: Community detection** — "(e.g. Louvain/Leiden)" is a suggestion; greedy connected-components is an acceptable alternative. COVERED.

---

### Requirement: Ubiquitous Dependency Detection — COVERED

**Code:** `detect_ubiquitous_dependencies()` and `compute_ubiquitous_flags()` (extractor.py, lines 1529–1644). Default threshold 0.5. Threshold recorded in metadata (`ubiquity_threshold`).
**Tests:** `TestUbiquitousDependencyDetection` and `TestUbiquitousFlags` (test_extractor.py lines 1939–2062):
- Edges flagged ubiquitous above threshold ✓
- Dependent nodes get `has_ubiquitous_dep=True` ✓
- Threshold controls detection ✓
- Threshold recorded in metadata (`test_build_scene_graph_records_ubiquity_threshold`) ✓

---

## Composition Layer Requirements

### Requirement: Container Primitive — PARTIAL

**Code:** `main.gd → _create_volume()` creates translucent BoxMesh for `bounded_context` nodes and opaque BoxMesh for `module` nodes. Membrane permeability (alpha = 1 − public_ratio) is computed from the `symbols` array. Nesting is scene-tree-based.
**Tests:**
- Nested containers: `test_module_parented_inside_context` (test_containment_rendering.gd) ✓
- Container translucency: `test_bounded_context_is_translucent` ✓
- Membrane permeability: implemented in code; no explicit test comparing alpha between high-public and low-public modules → PARTIAL on membrane permeability test coverage.
- Ports on the membrane: NOT implemented.

**Scenario: Module as container** — "5 public functions represented as Ports on the membrane" is NOT implemented. **Port placement is considered out of prototype scope** (the prototype renders flat geometries, not membrane-with-ports). Not a blocking failure.
**Scenario: Nested containers** — COVERED.
**Scenario: Container membrane permeability** — code implements alpha = 1 − public_ratio (main.gd line 353); no test verifies a high-public-ratio module has lower alpha than a low-public-ratio module. PARTIAL on test coverage, but not a blocking failure for prototype.

---

### Requirement: Node Primitive — PARTIAL

**Code:** `main.gd → _create_volume()` creates nodes. Badges are attached via `visual_primitives.gd`. However, the code uses different box colors for bounded_context vs module types (baking type into visual identity), which contradicts "Nodes do not have baked-in types — their visual identity comes entirely from their Badges."
**Tests:** Base node creation tested; Badge tests in test_visual_primitives.gd.

**Assessment:** The node + badges architecture is present. The type-baking is a design deviation that the prototype intentionally uses (different colors for contexts vs modules). The full "function node vs class node indistinguishable except by badges" requirement applies at the method/function granularity which is out of prototype scope.

---

### Requirement: Badge Primitive — COVERED

**Code:** `visual_primitives.gd → _render_badges()`, `attach_primitives()`. All 8 badge types implemented in `BADGE_COLORS` dictionary.
**Tests:** test_visual_primitives.gd:
- `test_single_badge_creates_mesh_child` ✓
- `test_multiple_badges_all_rendered` ✓
- `test_badge_positions_are_distinct` ✓
- `test_badge_y_position_above_node` ✓
- `test_badge_mesh_is_sphere` ✓
- `test_no_badges_no_badge_children` ✓
- `test_badge_vocabulary_pure` ✓ / `test_badge_vocabulary_io` ✓ / `test_badge_vocabulary_async` ✓ / `test_badge_vocabulary_test` ✓ / `test_badge_vocabulary_stateful` ✓ / `test_badge_vocabulary_deprecated` ✓

**Scenario: Side-effect badge** — COVERED
**Scenario: Multiple badges** — COVERED
**Scenario: Badge vocabulary** (all 8 types) — COVERED

---

### Requirement: Edge Primitive — COVERED

**Code:** `main.gd → _create_edge()`. Radius proportional to weight (line 670). Line style by type (solid/dashed/dotted via `_edge_line_style()`). Ubiquitous edges hidden by default; tracked in `_ubiquitous_edge_visuals`.
**Tests:** test_spatial_structure.gd:
- `test_edge_thickness_proportional_to_weight` ✓
- `test_direct_call_edge_has_solid_style` ✓
- `test_import_edge_has_dashed_style` ✓
- `test_inherits_edge_has_dotted_style` ✓
- `test_ubiquitous_edge_suppressed_by_default` ✓
- `test_ubiquitous_edge_toggle_shows_then_hides` ✓

test_dependency_rendering.gd:
- `test_edge_line_mesh_created` ✓
- `test_direction_indicator_cone_created` ✓
- `test_direction_cone_near_target` ✓

test_visual_primitives.gd:
- `test_ubiquitous_edge_produces_no_line_mesh` ✓
- `test_ubiquitous_edge_adds_power_rail_indicator_to_source` ✓
- `test_non_ubiquitous_edge_still_drawn` ✓

**Scenario: Weighted edge** — COVERED
**Scenario: Edge type distinction** — COVERED (solid/dashed/dotted)
**Scenario: Suppressed ubiquitous edges** — COVERED

---

### Requirement: Port Primitive — OUT OF PROTOTYPE SCOPE

Not implemented. The prototype renders containers as solid volumes; port placement on membrane boundaries is a long-term composition feature. Not a failure.

---

### Requirement: Route Primitive — OUT OF PROTOTYPE SCOPE

Not implemented. `prototype-scope.spec.md` excludes "moldable views (LLM-powered question-driven views)". Routes are LLM-driven. Not a failure.

---

### Requirement: Landmark Primitive — COVERED

**Code:** `visual_primitives.gd → _apply_landmark()` (scale up, add TorusMesh ring). `main.gd → _create_volume()` excludes landmarks from `_lod_node_entries`. `compute_structural_significance()` sets `is_landmark=True` for hub/bridge/entry-point nodes.
**Tests:** test_visual_primitives.gd:
- `test_hub_node_has_larger_mesh_than_regular_node` ✓
- `test_hub_node_has_bright_emission_material` ✓
- `test_hub_node_not_registered_in_lod_entries` ✓
- `test_hub_node_visible_after_far_lod_applied` ✓
- `test_bridge_node_not_registered_in_lod_entries` ✓
- `test_entry_point_node_not_registered_in_lod_entries` ✓
- `test_regular_node_still_in_lod_entries` ✓
- `test_landmark_applies_scale_to_anchor` ✓
- `test_landmark_adds_ring_child` ✓
- `test_landmark_ring_uses_torus_mesh` ✓
- `test_non_landmark_has_no_scale_boost` ✓
- `test_non_landmark_has_no_ring` ✓

test_extractor.py:
- `test_hub_is_marked_landmark` ✓
- `test_bridge_is_marked_landmark` ✓
- `test_entry_point_is_marked_landmark` ✓

**Scenario: Hub as landmark** — COVERED
**Scenario: Entry point as landmark** — COVERED
**Scenario: Bridge as landmark** — COVERED
**Scenario: Landmark sources** (human-designated landmarks and LLM-designated) — the LLM MAY clause is out of prototype scope; human-designated landmarks have no implementation but MAY is not SHALL.

---

### Requirement: Tint Primitive — OUT OF PROTOTYPE SCOPE

Not implemented. Background color encoding for categorical dimensions requires LLM-driven composition, which is out of prototype scope. Not a failure.

---

### Requirement: LOD Shell Primitive — PARTIAL

**Code:** `lod_manager.gd` implements three distance thresholds (FAR/MEDIUM/NEAR) that toggle node visibility. `_lod_node_entries` and `_lod_edge_entries` control visibility by node type and edge type.
**Tests:** test_camera_controls.gd and test_spatial_structure.gd cover basic LOD behavior.

**Scenario: Three-tier LOD** — Basic three-tier visibility is implemented, but the "precomputed summaries at multiple zoom tiers" (tier-0 aggregate metrics, tier-1 module-level, tier-2 class-level) are NOT fully implemented. Aggregate edges are shown at FAR (implemented), but the "single Container with aggregate metrics" at tier-0 is approximated by hiding modules at FAR.
**Scenario: LLM tier selection / Mixed tiers** — Out of prototype scope.

Given prototype scope limitations, PARTIAL is noted but not a blocking failure.

---

### Requirement: Power Rail Notation — COVERED

**Code:** `visual_primitives.gd → _render_power_rail()` adds a `PowerRailDisc` CylinderMesh to nodes with `has_ubiquitous_dep=True`. `main.gd → _add_power_rail_indicator()` adds a `PowerRailIndicator` sphere when processing ubiquitous edges. `toggle_ubiquitous_edges()` handles the toggle (T key).
**Tests:** test_visual_primitives.gd:
- `test_power_rail_disc_added_for_ubiquitous_dep` ✓
- `test_power_rail_disc_is_cylinder_mesh` ✓
- `test_power_rail_disc_position_below_or_at_base` ✓
- `test_no_power_rail_when_flag_absent` ✓
- `test_multiple_nodes_consistent_rail_position` ✓

test_spatial_structure.gd:
- `test_ubiquitous_edge_suppressed_by_default` ✓
- `test_ubiquitous_edge_toggle_shows_then_hides` ✓

**Scenario: Standard library power rail** — COVERED
**Scenario: Power rail toggle** — COVERED (toggle reversible; "becomes cluttered" is an expected UX outcome, not a programmatic assertion)
**Scenario: Multiple power rails** — COVERED (consistent position test)

---

## Composition Principles

### Requirement: Overlay/Facet Composition — PARTIAL

**Code:** `understanding_overlay.gd` implements three overlays (alignment, quality, failure-impact). `main.gd` wires H/J/K keys.
**Tests:** test_understanding_overlay.gd, test_understanding_modes.gd cover the three overlays.

**Scenario: Switching from dependency view to failure view** — PARTIAL (failure-impact overlay implemented but doesn't specifically reroute Edge weights or Tints as described)
**Scenario: Switching from structure view to ownership view** — NOT implemented.
**Scenario: Facet as the LLM's primary compositional act** — Out of prototype scope (no LLM integration).

Given prototype scope, PARTIAL noted, not a blocking failure.

---

### Requirement: Distortion Legend — OUT OF PROTOTYPE SCOPE

**Code:** Not implemented.
**Spec:** "Every composed view MUST include a legend that makes the current distortion explicit."

In the prototype, views are not LLM-composed with dynamic facets (no active Tint, no LLM-selected routes). The legend concept applies to the LLM composition layer which is explicitly excluded from prototype scope. Not a blocking failure under prototype-scope rules.

---

### Requirement: Purpose-Level Annotation — OUT OF PROTOTYPE SCOPE

Not implemented. LLM-generated purpose annotations are out of prototype scope (moldable views excluded). Not a failure.

---

## Primitive Interactions

### Requirement: Primitives Compose, Not Interfere — COVERED

**Code:** `visual_primitives.gd → attach_primitives()` independently applies landmark scale, badge spheres, and power rail disc without interference.
**Tests:** test_visual_primitives.gd:
- `test_landmark_and_badges_compose` ✓
- `test_all_three_primitives_compose` ✓

**Scenario: Channel allocation** — Tint is not implemented (out of scope), but for the implemented primitives, distinct perceptual channels are used: spatial containment (Container), line (Edge), glyph (Badge), thickness (Edge weight), luminance+scale (Landmark). COVERED for in-scope primitives.
**Scenario: Maximum simultaneous primitives** — Landmark + Badge + Power Rail simultaneously tested and verified. COVERED.

---

### Requirement: Primitive Set is Closed — PARTIAL

**Code:** The `BADGE_COLORS` dictionary in visual_primitives.gd fixes badge types at implementation time. `_infer_badges()` adds only known badge types. No runtime extension mechanism.
**Tests:** No explicit test asserts that the LLM cannot invent new primitives at runtime. The constraint is architectural.

PARTIAL (implementation satisfies the intent, but there is no behavioral test enforcing closure).

---

## Summary of Requirements

| Requirement | Status | Notes |
|---|---|---|
| Scope Nesting Extraction | PARTIAL | 2-level (BC→module) implemented; no project root, no atomic-declaration leaf nodes — within prototype scope limits |
| **Module Graph Extraction** | **PARTIAL** | **BLOCKING: individual edges lack import count weight; no test covers this** |
| Symbol Table Extraction | COVERED | All public/private/signature scenarios tested |
| Type Topology Extraction | COVERED | inherits and has_a edges tested |
| Call Graph Extraction | COVERED | direct_call, dynamic_call, weight all tested |
| Data Flow Spine Extraction | OUT OF SCOPE | Prototype scope excludes data flow visualization |
| Structural Significance Extraction | COVERED | Hub, bridge, peripheral, community, landmark — all tested |
| Ubiquitous Dependency Detection | COVERED | Threshold, flagging, metadata recording — all tested |
| Container Primitive | PARTIAL | Translucency and nesting covered; Ports out of prototype scope |
| Node Primitive | PARTIAL | Badges implemented; type-baking is prototype-level design decision |
| Badge Primitive | COVERED | All 8 vocabulary types tested |
| Edge Primitive | COVERED | Weight, line style, suppression, toggle — all tested |
| Port Primitive | OUT OF SCOPE | Prototype renders solid geometries |
| Route Primitive | OUT OF SCOPE | Moldable views excluded from prototype |
| Landmark Primitive | COVERED | Hub/bridge/entry-point sources + LOD persistence tested |
| Tint Primitive | OUT OF SCOPE | LLM-driven categorical encoding not in prototype |
| LOD Shell Primitive | PARTIAL | Basic 3-tier implemented; precomputed summaries not fully implemented |
| Power Rail Notation | COVERED | Suppression, indicator, toggle — all tested |
| Overlay/Facet Composition | PARTIAL | 3 overlays; full LLM facet-switching out of scope |
| Distortion Legend | OUT OF SCOPE | LLM composition not in prototype |
| Purpose-Level Annotation | OUT OF SCOPE | LLM annotations not in prototype |
| Primitives Compose, Not Interfere | COVERED | Composability tests exist and pass |
| Primitive Set is Closed | PARTIAL | Architecture satisfies this; no behavioral test |

## Blocking Failure

**Module Graph Extraction — PARTIAL (BLOCKING)**

The spec SHALL: "each edge carries the import count (number of individual import statements between the pair)."

Implementation gap:
- `build_dependency_edges()` builds individual `cross_context` and `internal` edges from a deduplicated set with no weight accumulation
- These edges carry no `weight` field
- Only `aggregate` edges carry `weight`
- No pytest test verifies that an individual module-pair edge carries a weight/import-count field

Fix required:
1. In `build_dependency_edges()`, accumulate per-`(source_id, target_id)` import counts for individual cross_context and internal edges, and emit them as `"weight"` on those edges.
2. Add a pytest test: given module A importing multiple symbols from module B, the resulting cross_context or internal edge has `weight >= 2`.