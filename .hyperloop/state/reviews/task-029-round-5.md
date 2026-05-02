---
task_id: task-029
round: 5
role: spec-reviewer
verdict: fail
---
## Reviewer Summary — task-029 (Node Primitive + Port Primitive, visual-primitives.spec.md)

**Overall verdict: FAIL**

Three blocking process violations prevent this round from passing. Spec requirement
coverage is otherwise strong for the two new primitives (Node and Port), but the
process failures must be resolved first.

---

## Scope Check Output

```
NOTE: Pre-existing prohibited spec-extraction code in extractor/extractor.py (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
NOTE: Pre-existing prohibited spec-extraction tests in extractor/tests/ (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
OK: No prohibited (not-in-scope) features detected.
```

---

## Blocking Process Failures

### FAIL-P1 — Branch not rebased onto origin/main

`check-rebased-onto-main.sh` exits 1. The branch `hyperloop/task-029` is 7 commits
behind `origin/main`. Commits on main not in branch:

```
a6367113 process(task-078): add STOP PROTOCOL handling rule to orchestrator overlay
e6bfa2f2 feat(visualization): godot — independence group: spatial rendering and group tinting
323d135e process(task-034,task-078): add class-method-inclusive test count check
acbca690 chore(tasks): intake 5 modified specs — no new tasks
54b5ec49 chore(tasks): intake 5 modified specs — no new tasks (repeat pass)
e57454de chore(intake): twenty-eighth review — same five specs, no new tasks
e3f19ee3 process(task-038,task-078): add routing-contract and no-substitute-section rules
913e3cd1 chore(tasks): intake 5 specs — no new tasks, system-purpose deferred
```

**Fix:** `git fetch origin main:main && git rebase origin/main`. Resolve all conflicts
keeping main's incoming changes. After rebase run `bash .hyperloop/checks/run-all-checks.sh`.

### FAIL-P2 — Missing check script (check-class-test-count.sh)

`check-checks-in-sync.sh` exits 1. The check script `check-class-test-count.sh` was
added to main (commit `323d135e`) after this branch was forked and is absent from the
working tree. Its failures are invisible to `run-all-checks.sh`.

**Fix:** After rebasing (FAIL-P1 fix), sync check scripts:
```
git checkout main -- .hyperloop/checks/
bash .hyperloop/checks/check-checks-in-sync.sh
```

### FAIL-P3 — RACF: check-report-scope-section.sh still failing from prior cycle

`check-racf-prior-cycle.sh` recovered prior-cycle failure from commit `4cecdf6`.
`check-report-scope-section.sh` was failing in that cycle and still fails today —
the recovered worker-result.yaml (commit `0de6c42`) is missing the mandatory
`## Scope Check Output` section header.

**Fix:** The new worker-result.yaml written by this reviewer includes the required
`## Scope Check Output` section. Once the implementer's next round produces a
compliant worker-result.yaml (this file), `check-report-scope-section.sh` must
exit 0. Verify with:
```
bash .hyperloop/checks/check-report-scope-section.sh
```

---

## Spec Requirement Findings

Spec: `specs/core/visual-primitives.spec.md`

### EXTRACTION LAYER

**REQ-EX1: Scope Nesting Extraction — COVERED**
- Scenario: Containment tree → `test_discovers_bounded_contexts`,
  `test_submodule_parent_references_bc`, `test_bounded_context_parent_is_none`
- Scenario: Extraction cost → constraint enforced by `check-extractor-stdlib-only.sh`
  (stdlib-only imports, no cross-file resolution libraries). No standalone timing test,
  but the architectural constraint is verified. Acceptable.

**REQ-EX2: Module Graph Extraction — COVERED**
- Scenario: Import-based edges → `test_cross_context_edge_created`,
  `test_cross_context_edge_has_weight`, `test_internal_edge_created`,
  `test_internal_edge_has_weight`
- Scenario: Distinction from scope nesting → `test_internal_edge_distinguishable_from_cross_context`,
  `test_bounded_context_type`, `test_submodule_type_is_module`

**REQ-EX3: Symbol Table Extraction — PARTIAL**
- Scenario: Public vs. private symbols → `test_public_function_marked_public`,
  `test_private_function_marked_private`, `test_function_carries_signature` — COVERED
- Scenario: Symbol as labeling layer → "without the symbol table, the edge would
  connect anonymous nodes." No test verifies that the composition layer can resolve
  symbol names for edge endpoints. The symbol data is embedded in nodes
  (`test_symbols_embedded_in_module_node`) but there is no test verifying it is
  consumed for edge label rendering.
  **Needed:** A test that retrieves symbol name data for a call-graph edge endpoint
  and asserts the name is the one from the symbol table.

**REQ-EX4: Type Topology Extraction — COVERED**
- Scenario: Inheritance chain → `test_inheritance_edge_emitted`,
  `test_inheritance_edge_type_is_inherits`
- Scenario: Composition relationship → `test_composition_edge_emitted`,
  `test_composition_edge_type_is_has_a`
- Scenario: Extraction cost → stdlib-only constraint covers "no type inference or
  flow analysis". Acceptable.

**REQ-EX5: Call Graph Extraction — COVERED**
- Scenario: Direct calls → `test_direct_call_edge_emitted`, `test_direct_call_edge_type`
- Scenario: Indirect calls → `test_dynamic_call_edge_emitted`,
  `test_dynamic_call_edge_carries_param_name`
- Scenario: Call frequency annotation → `test_direct_call_weight_counts_call_sites`

**REQ-EX6: Data Flow Spine Extraction — COVERED**
- Scenario: Parameter to return value → `test_spine_emitted_for_traced_parameter`,
  `test_spine_references_function_name`, `test_transform_spine_includes_return_step`
- Scenario: One-call-deep interprocedural flow → `test_interprocedural_field_present`,
  `test_interprocedural_entries_have_required_keys`,
  `test_interprocedural_does_not_exceed_one_level`
- Scenario: Extraction cost boundary → `test_extraction_completes_per_function_independently`

**REQ-EX7: Structural Significance Extraction — COVERED**
- Scenario: Hub detection → `test_hub_node_flagged_with_high_in_degree`,
  `test_in_degree_counts_incoming_edges`
- Scenario: Bridge detection → `test_bridge_node_flagged_as_articulation_point`,
  `test_betweenness_centrality_computed`
- Scenario: Peripheral detection → `test_peripheral_node_flagged`
- Scenario: Community detection → `test_community_ids_assigned_to_all_nodes`,
  `test_community_drift_detected_for_cross_context_component`,
  `test_no_community_drift_within_single_context`

**REQ-EX8: Ubiquitous Dependency Detection — COVERED**
- Scenario: Standard library suppression → `test_edge_marked_ubiquitous_above_threshold`,
  `test_build_scene_graph_flags_ubiquitous_edges`
- Scenario: Threshold → `test_custom_threshold_respected`,
  `test_build_scene_graph_records_ubiquity_threshold`

---

### COMPOSITION LAYER

**REQ-C1: Container Primitive — COVERED**
- Scenario: Module as container → `test_containment_rendering.gd` suite,
  `test_context_boundary_is_visually_distinct_translucent`
- Scenario: Nested containers → `test_containment_expressed_as_scene_tree_parenting`
- Scenario: Container membrane permeability → `test_membrane_permeability_reflects_public_private_ratio`

**REQ-C2: Node Primitive — COVERED** ← PRIMARY TASK REQUIREMENT
- Scenario: Function node →
  - `test_function_node_has_label_with_name`: Label3D.text == "validate_order" ✓
  - `test_function_node_with_pure_badge_has_badge_child`: Badge_pure child present ✓
  - `test_function_and_class_nodes_have_identical_mesh_size`: same BoxMesh dimensions ✓
  - `test_node_primitive_handles_function/method/class`: routing logic correct ✓
- Scenario: Node without badges →
  - `test_class_node_without_badges_has_no_badge_children`: no Badge_ children ✓
  - `test_method_node_has_label_with_name`: method nodes render name label ✓

Note on position test: `test_function_node_position_is_local_offset` has the parent
bounded_context at origin (0,0,0), making it vacuous for the relative-coordinate
contract (absolute and relative values are numerically identical when parent is at
origin). However, no spec scenario explicitly states a position THEN-clause for
Node Primitive — position accuracy is covered by the Python extractor test
`test_child_position_is_local_offset` which correctly uses a non-zero parent
(BC placed at world x=5.0 by the layout algorithm).

**REQ-C3: Badge Primitive — COVERED**
- Scenario: Side-effect badge → `test_single_badge_creates_mesh_child`,
  `test_badge_vocabulary_io`, `test_badge_positions_are_distinct`
- Scenario: Multiple badges → `test_multiple_badges_all_rendered` (io + async + error_handling)
- Scenario: Badge vocabulary (all 8 types):
  - `pure` → `test_badge_vocabulary_pure` ✓
  - `io` → `test_badge_vocabulary_io` ✓
  - `async` → `test_badge_vocabulary_async` ✓
  - `stateful` → `test_badge_vocabulary_stateful` ✓
  - `test` → `test_badge_vocabulary_test` ✓
  - `deprecated` → `test_badge_vocabulary_deprecated` ✓
  - `error_handling` → tested via `test_multiple_badges_all_rendered` (badge_count == 3) ✓
  - `entry_point` → tested via `test_landmark_and_badges_compose` (found_badge check) ✓
  All 8 badge types render a Badge_ child without error.

**REQ-C4: Edge Primitive — COVERED**
- Scenario: Weighted edge → `test_edge_thickness_proportional_to_weight`
- Scenario: Edge type distinction → `test_direct_call_edge_has_solid_style`,
  `test_import_edge_has_dashed_style`, `test_inherits_edge_has_dotted_style`
- Scenario: Suppressed ubiquitous edges → `test_ubiquitous_edge_suppressed_by_default`,
  `test_ubiquitous_edge_toggle_shows_then_hides`

**REQ-C5: Port Primitive — COVERED** ← SECONDARY TASK REQUIREMENT
- Scenario: Port placement →
  - `test_four_public_functions_produce_four_ports`: 4 Port_ children ✓
  - `test_port_labels_match_function_names`: all 4 function names on ports ✓
  - `test_ports_are_on_membrane_not_interior`: port.position.x == sz*0.5 (direct equality,
    parent at NON-ZERO world pos (5.0, 0.0, 3.0)) ✓
  - `test_edge_target_overridden_to_port_world_position`: edge endpoint overridden
    to membrane position, not interior (parent at world x=3.0) ✓
  - `test_no_ports_for_private_symbols_only`: private-only → zero ports ✓
- Scenario: Port direction →
  - `test_input_port_color_differs_from_output_port_color` ✓
  - `test_input_port_uses_input_color` (teal) ✓
  - `test_output_port_uses_output_color` (amber) ✓
- Scenario: Port visibility at zoom levels →
  - `test_ports_hidden_at_far_lod` ✓
  - `test_ports_visible_at_near_lod` ✓
  - `test_ports_hidden_at_medium_lod` ✓

**REQ-C6: Route Primitive — OUT OF PROTOTYPE SCOPE (note, not FAIL)**
All three scenarios require LLM-powered view composition ("WHEN the LLM traces the
path"). The prototype scope spec explicitly excludes "moldable views (LLM-powered
question-driven views)". Not a failure.

**REQ-C7: Landmark Primitive — PARTIAL**
- Scenario: Hub as landmark →
  - `test_hub_node_has_larger_mesh_than_regular_node` (larger) ✓
  - `test_hub_node_has_bright_emission_material` (brighter) ✓
  - `test_hub_node_visible_after_far_lod_applied` / `test_hub_node_not_registered_in_lod_entries`
    (persists at all zoom levels) ✓
- Scenario: Entry point as landmark →
  - `test_entry_point_node_not_registered_in_lod_entries` (persists) ✓
  - "serves as a spatial reference" — no position assertion; usability concern acceptable
    for prototype scope.
- Scenario: Bridge as landmark →
  - `test_bridge_node_not_registered_in_lod_entries` (persists) ✓
  - "it is positioned between the two subsystems it connects" — NO test verifies that the
    bridge node's world position is between the two subsystems. The layout algorithm places
    bridges by structural significance, but no Godot test asserts the spatial relationship.
    **Needed:** A Godot test with a bridge node fixture (connects two subsystems at
    distinct world positions) that asserts bridge_world_pos.x is between the two
    subsystem positions. (Or a Python extractor test verifying bridge position is
    interpolated between connected clusters.)
- Scenario: Landmark sources → `test_hub_is_marked_landmark`,
  `test_bridge_is_marked_landmark`, `test_entry_point_is_marked_landmark` ✓

**REQ-C8: Tint Primitive — OUT OF PROTOTYPE SCOPE (note, not FAIL)**
All scenarios require LLM-assigned tints. The prototype scope excludes LLM-powered
views. ClusterTint exists for cluster suggestions (a different concern) but does not
implement the spec's categorical Tint primitive for domain encoding.

**REQ-C9: LOD Shell Primitive — COVERED (prototype tier)**
- Scenario: Three-tier LOD →
  - `test_far_distance_shows_only_bounded_contexts`,
    `test_far_distance_shows_aggregate_edges` (tier 0) ✓
  - `test_medium_distance_shows_modules` (tier 1) ✓
  - `test_near_distance_shows_all_nodes` (tier 2) ✓
- Scenario: LLM tier selection — OUT OF PROTOTYPE SCOPE (requires LLM)
- Scenario: Mixed tiers — OUT OF PROTOTYPE SCOPE (requires LLM)

**REQ-C10: Power Rail Notation — COVERED**
- Scenario: Standard library power rail →
  `test_ubiquitous_edge_produces_no_line_mesh`,
  `test_ubiquitous_edge_adds_power_rail_indicator_to_source` ✓
- Scenario: Power rail toggle → `test_ubiquitous_edge_toggle_shows_then_hides` ✓
- Scenario: Multiple power rails → `test_multiple_nodes_consistent_rail_position` ✓

---

### COMPOSITION PRINCIPLES

**REQ-P1: Overlay/Facet Composition — PARTIAL**
The understanding_overlay.gd provides alignment, quality, and failure-impact overlays
via H/J/K keyboard shortcuts. These are tested in `test_understanding_overlay.gd` and
`test_understanding_modes.gd`.

The spec's THEN-clause for failure-mode overlay says: "Edge weights shift to encode
blast radius AND Tints shift to encode resilience AND Landmarks shift to highlight
single points of failure." The current failure overlay colours nodes by cascade depth
but does NOT shift edge weights or Tint encoding — partial implementation of the
scenario's THEN-clauses. However, the LLM-composition aspect ("WHEN the human asks
'where is this system fragile?'") is out of prototype scope.
- "underlying topology (Container nesting, Node positions) does NOT change" — no
  explicit test verifying layout stability across overlay switches.
  **Needed:** Test asserting node world positions are unchanged after applying overlay.

**REQ-P2: Distortion Legend — OUT OF PROTOTYPE SCOPE (note, not FAIL)**
Requires LLM-composed views. No implementation expected.

**REQ-P3: Purpose-Level Annotation — OUT OF PROTOTYPE SCOPE (note, not FAIL)**
Requires LLM analysis. No implementation expected.

---

### PRIMITIVE INTERACTIONS

**REQ-I1: Primitives Compose, Not Interfere — COVERED**
- Scenario: Channel allocation → `test_landmark_and_badges_compose`,
  `test_all_three_primitives_compose` verify coexistence without interference ✓
- Scenario: Maximum simultaneous primitives — composition tests verify rendering
  coexistence; no explicit perceptual-independence assertion, but acceptable for
  prototype scope.

**REQ-I2: Primitive Set is Closed — COVERED (by architecture)**
`check-not-in-scope.sh` confirms no prohibited features introduced by this branch.
The visual primitives are instantiated only from `visual_primitives.gd`,
`node_primitive.gd`, and `port_primitive.gd` — no runtime primitive invention.

---

## Summary Table

| Requirement | Status | Notes |
|---|---|---|
| REQ-EX1: Scope Nesting | COVERED | |
| REQ-EX2: Module Graph | COVERED | |
| REQ-EX3: Symbol Table | PARTIAL | Labeling layer scenario lacks edge-label test |
| REQ-EX4: Type Topology | COVERED | |
| REQ-EX5: Call Graph | COVERED | |
| REQ-EX6: Data Flow Spine | COVERED | |
| REQ-EX7: Structural Significance | COVERED | |
| REQ-EX8: Ubiquitous Dependency | COVERED | |
| REQ-C1: Container Primitive | COVERED | |
| REQ-C2: Node Primitive | COVERED | Main task requirement |
| REQ-C3: Badge Primitive | COVERED | |
| REQ-C4: Edge Primitive | COVERED | |
| REQ-C5: Port Primitive | COVERED | Secondary task requirement |
| REQ-C6: Route Primitive | OUT OF SCOPE | LLM-powered views excluded |
| REQ-C7: Landmark Primitive | PARTIAL | Bridge position between subsystems not tested |
| REQ-C8: Tint Primitive | OUT OF SCOPE | LLM-powered views excluded |
| REQ-C9: LOD Shell | COVERED | LLM tier-selection scenarios out of scope |
| REQ-C10: Power Rail | COVERED | |
| REQ-P1: Overlay/Facet | PARTIAL | Layout stability across overlays not tested |
| REQ-P2: Distortion Legend | OUT OF SCOPE | LLM-powered views excluded |
| REQ-P3: Purpose-Level Annotation | OUT OF SCOPE | LLM-powered views excluded |
| REQ-I1: Primitives Compose | COVERED | |
| REQ-I2: Primitive Set Closed | COVERED | Architecture-enforced |

---

## What the Implementer Must Fix

**BLOCKING (must fix before any review can pass):**

1. **Rebase onto origin/main** — 7 commits behind. Run:
   ```
   git fetch origin main:main
   git rebase origin/main
   ```
   Resolve all conflicts keeping main's incoming additions.

2. **Sync check scripts** — After rebase, pull `check-class-test-count.sh` from main:
   ```
   git checkout main -- .hyperloop/checks/
   bash .hyperloop/checks/check-checks-in-sync.sh  # must exit 0
   ```

3. **Satisfy check-class-test-count.sh** — This check (added in commit `323d135e`)
   validates class-method-inclusive test counts. Run it after syncing and fix any
   failures it reports.

**SPEC GAPS (non-blocking for core task but should be addressed):**

4. **REQ-C7 Bridge Landmark position** — Add a Godot test with a bridge node fixture
   where two subsystems are at distinct non-zero world positions and assert the bridge
   node's world position is between them.

5. **REQ-EX3 Symbol labeling layer** — Add a test verifying that symbol name data is
   retrievable for a call-graph edge's source and target endpoints (i.e., the symbol
   table provides human-readable identity for edge rendering).