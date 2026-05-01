---
task_id: task-119
round: 4
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-119
**Spec:** specs/core/visual-primitives.spec.md
**Branch:** hyperloop/task-119
**Task scope:** Schema — define `metrics` object (raw `loc` integer) on node entries; extend `validate_scene_graph`.

---

## Task-119 Direct Scope

Task-119 covers the **LOD Shell Primitive / Scenario: Three-tier LOD** — specifically the "aggregate metrics (total LOC, total in-degree, total out-degree)" clause at tier 0 (far). It delivers schema documentation and validator changes only; no extractor logic and no Godot rendering.

### NodeMetrics TypedDict (schema.py)
**COVERED**
- `NodeMetrics` TypedDict defined with `loc: int` at `extractor/schema.py:25–29`.
- `Node` carries `metrics: NotRequired[NodeMetrics]` at line 56–57.
- `validate_scene_graph` validates: (a) `metrics` must be a dict when present, (b) `metrics.loc` must be a non-negative integer when present — lines 321–344.

### Test coverage (TestNodeMetricsValidation)
**COVERED** — 11 tests in `extractor/tests/test_schema.py`:
- `test_valid_graph_without_metrics_passes` — absent field valid.
- `test_valid_graph_with_metrics_loc_passes` — non-negative integer accepted.
- `test_metrics_zero_loc_passes` — loc == 0 boundary.
- `test_metrics_not_a_dict_raises` — dict enforcement.
- `test_metrics_as_list_raises` — list rejected.
- `test_metrics_loc_negative_raises` — negative rejected.
- `test_metrics_loc_float_raises` — float rejected.
- `test_metrics_loc_bool_raises` — bool-as-int rejected.
- `test_metrics_without_loc_passes` — empty metrics dict valid.
- `test_metrics_on_module_node_passes` — valid on module type.
- `test_metrics_loc_distinguishable_from_size` — conceptual separation documented.

### schema.md update
**COVERED** — `extractor/schema.md` lines 33–74 document the `metrics` object, the `loc` field, the relationship to `size`, and provide a worked example.

### Nondirectional-movement assertions check
**OK** — `bash .hyperloop/checks/check-nondirectional-movement-assertions.sh` exits 0.

---

## Full Spec Coverage — All Requirements

The spec ref is the complete Visual Primitives spec. The following assesses every SHALL requirement. Requirements out of prototype scope (per `specs/prototype/prototype-scope.spec.md`) are noted but do NOT drive the verdict.

---

### EXTRACTION LAYER

#### Requirement: Scope Nesting Extraction — PARTIAL
- Scenario: Containment tree — **PARTIAL**. Extractor discovers bounded contexts and modules (two levels). Classes, methods, and atomic declarations (functions, constants) are NOT extracted. "Every leaf is an atomic declaration" and "tree root is the project itself" are not satisfied.
  - Code: `extractor.py` discovers BC and module nodes; no class/method level.
  - Tests: Discovery tests exist for BC and module; no class/method tests.
  - Prototype scope: The prototype views only show BC+module; class/method extraction is not needed for the prototype top-down view. **Not a FAIL.**
- Scenario: Extraction cost — **COVERED**. Single-file AST parsing with no cross-file resolution.

#### Requirement: Module Graph Extraction — COVERED
- Scenario: Import-based edges — **COVERED**. `extract_imports()` emits edges with `weight`. Tests: `TestEdgeExtraction` class.
- Scenario: Distinction from scope nesting — **COVERED**. Containment is `parent` field; dependency is an edge. Both represented distinctly.

#### Requirement: Symbol Table Extraction — MISSING (out of prototype scope)
- No public/private symbol extraction. No signature annotation. No test coverage.
- Prototype scope: Prototype shows BC+module structure only; function-level symbol tables are not needed. **Not a FAIL per prototype scope exclusion.**

#### Requirement: Type Topology Extraction — MISSING (out of prototype scope)
- No inheritance or composition relationship extraction. No tests.
- Prototype scope: Not needed for basic structural view. **Not a FAIL.**

#### Requirement: Call Graph Extraction — MISSING (out of prototype scope)
- No call edge extraction. No tests.
- Prototype scope: Not needed. **Not a FAIL.**

#### Requirement: Data Flow Spine Extraction — MISSING (explicitly excluded from prototype)
- Explicitly out of scope: prototype-scope.spec.md states "data flow visualization is NOT implemented."
- **Not a FAIL.**

#### Requirement: Structural Significance Extraction — PARTIAL ← **CAUSES FAIL**
- Scenario: Hub detection — **COVERED**. `compute_structural_significance()` sets `in_degree`, flags `is_hub`. Tests: `test_hub_node_flagged_with_high_in_degree`, `test_non_hub_node_not_flagged`.
- Scenario: Bridge detection — **PARTIAL — missing betweenness centrality score.**
  - **Spec THEN clause:** "the module is annotated with its betweenness centrality score AND it is flagged as a bridge."
  - **Implementation:** `is_bridge` boolean (articulation point detection) — no betweenness centrality score is computed or stored. `schema.py` explicitly documents "articulation point" rather than betweenness centrality, making this a known deviation.
  - **Tests:** `test_bridge_node_flagged_as_articulation_point` and `test_non_bridge_in_cycle_not_flagged` verify the boolean flag but do NOT exercise betweenness centrality scoring.
  - The THEN clause "annotated with its betweenness centrality score" is **NOT implemented and NOT tested.** The prototype uses `is_bridge` for Landmark identification (which works), but the spec requires the numeric score annotation.
  - This IS within prototype scope (structural significance extraction is needed for "extract structure"). **This is a FAIL item.**
- Scenario: Peripheral detection — **COVERED**. `is_peripheral` set for in_degree=0, out_degree≤1. Tests: `test_peripheral_node_flagged`, `test_non_peripheral_node_not_flagged`.
- Scenario: Community detection — **PARTIAL** (not a FAIL). Spec says "(e.g. Louvain/Leiden)"; implementation uses connected components. The "e.g." makes the algorithm non-prescriptive. `community_id` and `community_drift` are assigned. Tests: `test_community_ids_assigned_to_all_nodes`, `test_connected_nodes_share_community`, `test_community_drift_detected_for_cross_context_component`. Coverage is adequate for the scenario's THEN clauses.

#### Requirement: Ubiquitous Dependency Detection — COVERED
- Scenario: Standard library suppression — **COVERED**. `compute_ubiquitous_flags()` marks edges with `ubiquitous=True` when fraction > threshold. Tests: `test_edge_marked_ubiquitous_above_threshold`.
- Scenario: Threshold — **COVERED**. Default 0.5 configurable; `ubiquity_threshold` recorded in metadata. Tests: `test_build_scene_graph_records_ubiquity_threshold`, `test_custom_threshold_respected`.

---

### COMPOSITION LAYER

#### Requirement: Container Primitive — PARTIAL (mostly out of prototype scope)
- Containers (volumes) exist for bounded contexts and modules. Nesting is visible.
- Membrane density, port placement, private-visibility-at-close-zoom: NOT implemented.
- Prototype scope: Basic volumes are in scope; membrane semantics are not.
- Test: `test_containment_rendering.gd` covers basic container rendering.
- **Not a FAIL.**

#### Requirement: Node Primitive — PARTIAL (out of prototype scope for function nodes)
- Module and BC nodes rendered as volumes without baked-in type shapes.
- Badges: NOT implemented.
- Function-level nodes: NOT in prototype scope.
- **Not a FAIL.**

#### Requirement: Badge Primitive — MISSING (out of prototype scope)
- No badge/glyph system. No tests. **Not a FAIL.**

#### Requirement: Edge Primitive — PARTIAL
- Edges drawn with weight; ubiquitous suppression; edge types vary by line style.
- Scenario: Weighted edge — **PARTIAL**. Aggregate edges scale by import count (`main.gd:503–504`). Individual edge line thickness does NOT vary by `weight` field; all individual edges render at the same thickness. Test covers aggregate weight but not individual edge thickness variation.
- Scenario: Edge type distinction — **PARTIAL**. Cross_context/internal distinction exists but "calls/imports/inheritance" style distinctions are not needed in prototype (no call or inheritance edges).
- Scenario: Suppressed ubiquitous edges — **COVERED** (`test_visual_primitives.gd`).
- **Not a FAIL** (edge type distinction and individual weight encoding are advanced features beyond prototype scope).

#### Requirement: Port Primitive — MISSING (out of prototype scope)
- No port/membrane-anchor system. No tests. **Not a FAIL.**

#### Requirement: Route Primitive — MISSING (out of prototype scope)
- Moldable views explicitly excluded from prototype. **Not a FAIL.**

#### Requirement: Landmark Primitive — PARTIAL
- Scenario: Hub as landmark — **COVERED**. `test_hub_node_not_registered_in_lod_entries`, `test_hub_node_visible_after_far_lod_applied`, `test_hub_node_has_larger_mesh_than_regular_node`, `test_hub_node_has_bright_emission_material`.
- Scenario: Entry point as landmark — **COVERED**. `test_entry_point_node_not_registered_in_lod_entries`.
- Scenario: Bridge as landmark — **COVERED**. `test_bridge_node_not_registered_in_lod_entries`.
- Scenario: Landmark sources — **PARTIAL**. Hub, bridge, and entry-point sources implemented. Human-designated landmarks NOT implemented. LLM-designated landmarks out of prototype scope.
- **Not a FAIL** (human-designated landmarks are a UI feature; LLM out of prototype scope).

#### Requirement: Tint Primitive — PARTIAL
- Quality, alignment, and failure overlays apply tinting. Formal Tint primitive with legend not implemented.
- One-tint-dimension enforcement not implemented.
- Prototype scope: Basic overlays are in scope; formal Tint primitive semantics are advanced.
- **Not a FAIL.**

#### Requirement: LOD Shell Primitive — PARTIAL
- Scenario: Three-tier LOD — **PARTIAL**.
  - FAR/MEDIUM/NEAR tiers exist in `lod_manager.gd`. Landmarks always visible (excluded from LOD entries).
  - Schema defines `metrics.loc` (task-119 ✓), `in_degree`, `out_degree` on nodes.
  - **Gap:** Godot does NOT display aggregate metrics labels ("LOC: 12,400") on tier-0 containers. This display is task-104's responsibility, not task-119's. The schema contract is fulfilled; the render consuming it is pending.
  - Tests: `test_far_distance_shows_only_bounded_contexts`, `test_far_distance_hides_all_edges`, LOD integration tests in `test_spatial_structure.gd`.
- Scenario: LLM tier selection — MISSING (LLM out of prototype scope).
- Scenario: Mixed tiers — MISSING. All regions use the same LOD tier based on uniform camera distance.
- **Not a FAIL** (task-119's schema contribution is complete; rendering features are other tasks' responsibility; LLM features out of prototype scope).

#### Requirement: Power Rail Notation — PARTIAL
- Scenario: Standard library power rail — **COVERED**. Edge suppression, `PowerRailIndicator` child node added to source. Tests: `test_ubiquitous_edge_produces_no_line_mesh`, `test_ubiquitous_edge_adds_power_rail_indicator_to_source`, `test_non_ubiquitous_source_has_no_rail_indicator`.
- Scenario: Power rail toggle — **MISSING**. No UI toggle to reveal suppressed edges. Test absent.
- Scenario: Multiple power rails — **COVERED**. Each source with a ubiquitous outgoing edge gets its own indicator.
- Power rail toggle is a UI interaction feature; probably beyond basic prototype scope. **Not a FAIL.**

---

### COMPOSITION PRINCIPLES

#### Requirement: Overlay/Facet Composition — PARTIAL
- Alignment, quality, and failure impact overlays implemented (H/J/K keys). Underlying topology unchanged between overlays.
- Ownership overlay and LLM-directed faceting: NOT implemented (LLM out of prototype scope).
- **Not a FAIL.**

#### Requirement: Distortion Legend — MISSING
- No visible legend documenting what tint encodes, what is suppressed, node/edge counts.
- Probably out of prototype scope for the basic "render in 3D" prototype.
- **Not a FAIL** (no explicit coverage clause in prototype scope spec, but legend is a display feature beyond the prototype's stated focus).

#### Requirement: Purpose-Level Annotation — MISSING (out of prototype scope)
- LLM-generated annotations excluded from prototype. **Not a FAIL.**

---

### PRIMITIVE INTERACTIONS

#### Requirement: Primitives Compose, Not Interfere — PARTIAL
- Implemented primitives use distinct channels (containment, lines, scale/brightness, rail indicators).
- Full channel-allocation table not formally validated (many primitives missing).
- **Not a FAIL.**

#### Requirement: Primitive Set is Closed — PARTIAL
- No LLM integration in prototype; no runtime primitive invention can occur.
- No formal primitive registry enforcing closure.
- **Not a FAIL.**

---

## Summary Table

| Requirement | Status | Notes |
|---|---|---|
| Scope Nesting Extraction | PARTIAL | BC+module only; prototype scope covers this |
| Module Graph Extraction | COVERED | ✓ |
| Symbol Table Extraction | MISSING | Out of prototype scope |
| Type Topology Extraction | MISSING | Out of prototype scope |
| Call Graph Extraction | MISSING | Out of prototype scope |
| Data Flow Spine Extraction | MISSING | Explicitly excluded from prototype |
| Structural Significance Extraction | **PARTIAL — FAIL** | `is_bridge` boolean exists; betweenness centrality SCORE annotation missing per spec THEN clause; test covers articulation-point behavior only |
| Ubiquitous Dependency Detection | COVERED | ✓ |
| Container Primitive | PARTIAL | Basic volumes; membrane/ports out of prototype scope |
| Node Primitive | PARTIAL | Volumes; badges out of prototype scope |
| Badge Primitive | MISSING | Out of prototype scope |
| Edge Primitive | PARTIAL | Weight encoding partial; type distinction partial |
| Port Primitive | MISSING | Out of prototype scope |
| Route Primitive | MISSING | LLM excluded from prototype |
| Landmark Primitive | PARTIAL | Hub/bridge/entry-point covered; human-designated missing |
| Tint Primitive | PARTIAL | Overlays exist; formal Tint primitive not distinct |
| LOD Shell Primitive | PARTIAL | Three tiers exist; aggregate metrics display is task-104; LLM tier selection out of scope |
| Power Rail Notation | PARTIAL | Suppression + indicator covered; toggle missing |
| Overlay/Facet Composition | PARTIAL | Three overlays; LLM direction out of scope |
| Distortion Legend | MISSING | Beyond prototype focus |
| Purpose-Level Annotation | MISSING | LLM excluded |
| Primitives Compose, Not Interfere | PARTIAL | Implemented primitives use distinct channels |
| Primitive Set is Closed | PARTIAL | No LLM, no runtime invention; no formal registry |

---

## Verdict: FAIL

**Blocking issue:**

**Requirement: Structural Significance Extraction / Scenario: Bridge detection**

The spec's THEN clause reads:
> "the module is annotated with its betweenness centrality score AND it is flagged as a bridge"

**What is implemented:** `is_bridge: bool` (articulation-point detection). No betweenness centrality score is computed, stored, or annotated on any node. The schema explicitly documents articulation points, not betweenness centrality.

**What is tested:** `test_bridge_node_flagged_as_articulation_point` and `test_non_bridge_in_cycle_not_flagged` verify the boolean flag only. No test exercises a numeric betweenness centrality score.

**Why this fails:** The "annotated with its betweenness centrality score" THEN clause is within prototype scope (Structural Significance Extraction feeds the Landmark system, which is explicitly implemented in the prototype). The annotation is absent from the data model (no `betweenness_centrality` field in `Node` TypedDict or `schema.py`), and no test verifies it.

**What is needed to fix:**
1. Add `betweenness_centrality: NotRequired[float]` to the `Node` TypedDict in `schema.py`.
2. Implement betweenness centrality computation in `compute_structural_significance()` (or accept that the articulation-point proxy suffices and get a spec amendment to remove the score annotation requirement).
3. Add a pytest test that verifies: GIVEN a graph where node B sits on shortest paths between A and C, WHEN significance is computed, THEN `B["betweenness_centrality"]` is a float > 0.

**All other MISSING/PARTIAL items are either out of prototype scope or are pending tasks (task-104 for LOD tier-0 display; task-120 for extractor emission). Task-119's own deliverable (NodeMetrics TypedDict, validator, schema.md, TestNodeMetricsValidation tests) is complete and correctly implemented.**