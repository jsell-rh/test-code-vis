---
task_id: task-038
round: 2
role: spec-reviewer
verdict: fail
---
# Spec Alignment Review — task-038
**Spec:** specs/core/visual-primitives.spec.md
**Branch:** hyperloop/task-038
**Changed files:** godot/scripts/port_renderer.gd (new), godot/scripts/main.gd (extended), godot/tests/test_port_renderer.gd (new), godot/tests/run_tests.gd (extended), extractor/tests/test_extractor.py (ruff style fix + weight accumulation test)

## Directional-assertion check (mandatory)
```
OK: All directional test functions use signed comparison predicates
```
No blocking failures from check-nondirectional-movement-assertions.sh.

---

## Extraction Layer Requirements

All extraction-layer requirements below were implemented in prior tasks and are assessed
on the basis of code + tests present on main (included in this branch).

### Requirement: Scope Nesting Extraction — COVERED
Implementation: `discover_bounded_contexts`, `discover_submodules` in extractor.py.
Tests: `test_discovers_bounded_contexts`, `test_bounded_context_parent_is_none`,
`test_discovers_submodules_in_iam`, `test_submodule_parent_references_bc`,
`test_submodule_type_is_module`, `test_all_nodes_have_positions_after_layout`.

### Requirement: Module Graph Extraction — COVERED
Implementation: `build_dependency_edges` in extractor.py, emitting `cross_context` and
`internal` edge types with import-count weight.
Tests: `test_cross_context_edge_created`, `test_cross_context_edge_type`,
`test_internal_edge_created`, `test_individual_cross_context_edges_have_weight`,
`test_individual_internal_edges_have_weight`.
This branch also adds `test_cross_context_edge_weight_accumulates_for_multiple_imports`
and `test_internal_edge_weight_accumulates_for_multiple_imports` (ruff-formatted).

### Requirement: Symbol Table Extraction — COVERED
Implementation: `extract_symbols` in extractor.py (line 952).
Tests: `test_public_function_marked_public`, `test_private_function_marked_private`,
`test_function_carries_signature`, `test_class_extracted_as_symbol`,
`test_symbols_embedded_in_module_node`.

### Requirement: Type Topology Extraction — COVERED
Implementation: `extract_type_topology` in extractor.py (line 1030).
Tests: `test_inheritance_edge_emitted`, `test_inheritance_edge_type_is_inherits`,
`test_composition_edge_emitted`, `test_composition_edge_type_is_has_a`.

### Requirement: Call Graph Extraction — COVERED
Implementation: `extract_call_graph` in extractor.py (line 1196).
Tests: `test_direct_call_edge_emitted`, `test_direct_call_edge_type`,
`test_direct_call_weight_counts_call_sites`, `test_dynamic_call_edge_emitted`,
`test_dynamic_call_edge_carries_param_name`.

### Requirement: Data Flow Spine Extraction — OUT OF PROTOTYPE SCOPE
The prototype scope spec (specs/prototype/prototype-scope.spec.md §Scenario: Features
excluded from prototype) explicitly states "data flow visualization is NOT implemented".
No implementation required; no failure.

### Requirement: Structural Significance Extraction — COVERED
Implementation: `compute_structural_significance` in extractor.py (line 1425).
Tests: `test_hub_node_flagged_with_high_in_degree`, `test_bridge_node_flagged_as_articulation_point`,
`test_peripheral_node_flagged`, `test_community_ids_assigned_to_all_nodes`,
`test_community_drift_detected_for_cross_context_component`.

Note: The spec calls for Louvain/Leiden community detection; the implementation uses
greedy connected-components (acknowledged in the extractor docstring as a
"simplified alternative"). The community detection tests pass with this implementation.
This is a SHOULD-level algorithmic detail, not a blocking failure.

### Requirement: Ubiquitous Dependency Detection — COVERED
Implementation: `detect_ubiquitous_dependencies` in extractor.py (line 1608).
Configurable threshold (default 0.50) recorded in metadata.
Tests: `test_edge_marked_ubiquitous_above_threshold`, `test_returns_ubiquitous_target_fractions`,
`test_non_ubiquitous_edges_unchanged`, `test_build_scene_graph_records_ubiquity_threshold`.

---

## Composition Layer Requirements

### Requirement: Container Primitive — COVERED
Implementation: main.gd `_create_volume` creates BoxMesh containers for bounded_context
nodes; membrane alpha = 1 - public_ratio (continuous, not binary).
Tests: `test_membrane_permeability_reflects_public_private_ratio` in test_spatial_structure.gd;
`test_containment_rendering.gd` for nested containers.

### Requirement: Node Primitive — COVERED
Implementation: main.gd `_create_volume` for module-type nodes.
Tests: test_node_renderer.gd, test_containment_rendering.gd.

### Requirement: Badge Primitive — COVERED
Implementation: visual_primitives.gd `_render_badge`.
Badge vocabulary implemented: pure, io, async, stateful, error_handling, test,
entry_point, deprecated (all from BADGE_COLORS dict in visual_primitives.gd).
Tests: `test_single_badge_creates_mesh_child`, `test_multiple_badges_all_rendered`,
`test_badge_positions_are_distinct`, `test_badge_vocabulary_pure/io/async/test/stateful/deprecated`.

### Requirement: Edge Primitive — COVERED
Implementation: main.gd `_create_edge` with `_create_solid_body` (calls),
`_create_dashed_body` (imports), `_create_dotted_body` (inheritance). Weight encoded
as cylinder radius. Suppressed ubiquitous edges with power-rail indicator.
Tests: test_dependency_rendering.gd.

### Requirement: Port Primitive — PARTIAL → FAIL

This is the primary deliverable of task-038.

#### Scenario: Port placement — PARTIAL

Implementation: COVERED
- `port_renderer.gd` `attach_ports()` filters symbols for `visibility == "public"`
  and creates one input Port (negative-X face) and one output Port (positive-X face)
  per public symbol. For 4 public functions this yields 8 Port meshes (2 per function).
- `main.gd` `_create_volume` calls `pr.attach_ports(nd, anchor, sz)` for every
  `bounded_context` node and registers port world positions in `_port_world_positions`.
- Ports are labeled with the function name (plus a "▶"/"◀" direction indicator).

THEN-clause coverage:

1. "4 Ports appear on its membrane" — The spec says 4 Ports for 4 public functions.
   The implementation produces 8 Port meshes (4 input + 4 output). This divergence is
   consistent with the Port direction scenario (which requires input/output distinction)
   and is an acceptable design interpretation. The test `test_four_public_symbols_produce_four_port_meshes`
   correctly validates the 2-per-function design. **COVERED** (with design note).

2. "each Port is labeled with the function name" — `test_port_labels_contain_function_names`
   checks that function names appear in label text. **COVERED**.

3. "Edges connect to Ports, not directly to the Container body" — **PARTIAL — BLOCKING**

   The routing code exists: `_create_edge` calls `_find_port_or_centroid(src, true)` and
   `_find_port_or_centroid(tgt, false)`, which return a port world position when one is
   registered in `_port_world_positions`.

   The test `test_edge_endpoint_uses_port_position_when_available` is named to cover this
   contract but its assertions fall short: it only verifies that `port_world` contains
   output-port keys for ctx_a AND that those positions differ from the ctx_a centroid.
   It does NOT verify that the edge body's geometric endpoints match a port position.

   Specifically missing: no assertion calls `_find_port_or_centroid("ctx_a", true)` and
   checks the return value is a port position (not the centroid), or inspects the actual
   edge visual's from/to geometry.

   **What the implementer must add to fix this:**
   Expose `_find_port_or_centroid` as a testable method (it already has no underscore
   convention barrier in GDScript) and add a test that:
   ```gdscript
   var root := Main.new()
   root.build_from_graph(_make_full_graph_with_ports())
   var port_world := root.get_port_world_positions()
   var world_pos := root.get("_world_positions")
   # Call _find_port_or_centroid and verify it returns port position, not centroid
   var ctx_a_centroid: Vector3 = world_pos.get("ctx_a", Vector3.ZERO)
   var from_pos: Vector3 = root._find_port_or_centroid("ctx_a", true)
   _check(
       not from_pos.is_equal_approx(ctx_a_centroid),
       "find_port_or_centroid must return port position, not centroid, when ports exist"
   )
   # Additionally verify it matches a registered port world position
   var found_match: bool = false
   for key in port_world:
       if key.begins_with("ctx_a/") and key.ends_with("_out"):
           if from_pos.is_equal_approx(port_world[key]):
               found_match = true
   _check(found_match, "from_pos returned by find_port_or_centroid must match a registered port position")
   ```
   This directly tests the routing contract, not just its prerequisites.

#### Scenario: Port direction — COVERED

Implementation: Input ports placed at negative-X (INPUT_PORT_COLOR = cyan), output
ports at positive-X (OUTPUT_PORT_COLOR = orange). Visually distinct by both position
and color.

Tests:
- `test_input_ports_on_negative_x_face` — asserts position.x < 0 for `_in` ports ✓
- `test_output_ports_on_positive_x_face` — asserts position.x > 0 for `_out` ports ✓
- `test_input_and_output_ports_on_opposing_faces` — asserts both directions simultaneously ✓

All use signed predicates (pos.x < 0.0 / pos.x > 0.0). **COVERED**.

#### Scenario: Port visibility at zoom levels — COVERED

Implementation: `set_lod_tier()` in port_renderer.gd drives mesh alpha via
`material_override.albedo_color.a` (MeshInstance3D) and `modulate.a` (Label3D).
Main.gd `_update_lod()` propagates tier transitions to all `_port_renderers`.

Tests:
- `test_ports_have_alpha_zero_at_tier_0` — albedo_color.a == 0 and modulate.a == 0 at FAR ✓
- `test_ports_have_alpha_zero_at_tier_1` — albedo_color.a == 0 and modulate.a == 0 at MEDIUM ✓
- `test_ports_have_alpha_gt_zero_at_tier_2` — alpha > 0 at NEAR ✓
- `test_ports_start_invisible_before_lod_applied` — default alpha == 0 before any LOD call ✓

All tests use direct numeric predicates (== 0.0, > 0.0). **COVERED**.

### Requirement: Route Primitive — OUT OF PROTOTYPE SCOPE
Prototype scope spec excludes moldable views (LLM-powered question-driven views).
No implementation required; no failure.

### Requirement: Landmark Primitive — COVERED
Implementation: main.gd `_create_volume` classifies hubs, bridges, and entry points as
landmarks (omitted from `_lod_node_entries`). visual_primitives.gd `_apply_landmark`
adds ring and scale. Hub Landmark = hub node with is_hub=true from extractor.
Tests: `test_hub_node_has_larger_mesh_than_regular_node`,
`test_hub_node_has_bright_emission_material`, `test_hub_node_not_registered_in_lod_entries`,
`test_hub_node_visible_after_far_lod_applied`, `test_bridge_node_not_registered_in_lod_entries`,
`test_entry_point_node_not_registered_in_lod_entries`.

### Requirement: Tint Primitive — OUT OF PROTOTYPE SCOPE
Prototype scope spec excludes moldable views. No implementation required; no failure.

### Requirement: LOD Shell Primitive — COVERED
Implementation: lod_manager.gd implements 3-tier LOD (FAR/MEDIUM/NEAR thresholds).
Tests: test_spatial_structure.gd LOD tier tests.

### Requirement: Power Rail Notation — COVERED
Implementation: `_create_edge` suppresses ubiquitous edges (body.visible = false) and
adds a power-rail indicator to source node. `toggle_ubiquitous_edges()` implements T-key
toggle with fade animation.
Tests: `test_ubiquitous_edge_produces_no_line_mesh`, `test_ubiquitous_edge_adds_power_rail_indicator_to_source`,
`test_non_ubiquitous_edge_still_drawn`.

---

## Composition Principles

### Requirement: Overlay/Facet Composition — OUT OF PROTOTYPE SCOPE
Requires LLM. Excluded from prototype.

### Requirement: Distortion Legend — OUT OF PROTOTYPE SCOPE
Requires LLM. Excluded from prototype.

### Requirement: Purpose-Level Annotation — OUT OF PROTOTYPE SCOPE
Requires LLM/moldable views. Excluded from prototype.

### Requirement: Primitives Compose, Not Interfere — COVERED
Each primitive uses a distinct perceptual channel: Containers (spatial containment),
Edges (line channel), Badges (glyph channel), Edge weight (thickness), Landmarks (scale
+ luminance), Ports (membrane position + color direction). No channel conflicts.

### Requirement: Primitive Set is Closed — COVERED
No runtime primitive invention. All composition primitives are pre-declared.

---

## Summary Table

| Requirement | Status |
|---|---|
| Scope Nesting Extraction | COVERED |
| Module Graph Extraction | COVERED |
| Symbol Table Extraction | COVERED |
| Type Topology Extraction | COVERED |
| Call Graph Extraction | COVERED |
| Data Flow Spine Extraction | OUT OF PROTOTYPE SCOPE |
| Structural Significance Extraction | COVERED |
| Ubiquitous Dependency Detection | COVERED |
| Container Primitive | COVERED |
| Node Primitive | COVERED |
| Badge Primitive | COVERED |
| Edge Primitive | COVERED |
| Port Primitive — Port placement (ports + labels) | COVERED |
| Port Primitive — Port placement (edge routing test) | PARTIAL (BLOCKING) |
| Port Primitive — Port direction | COVERED |
| Port Primitive — Port visibility at zoom levels | COVERED |
| Route Primitive | OUT OF PROTOTYPE SCOPE |
| Landmark Primitive | COVERED |
| Tint Primitive | OUT OF PROTOTYPE SCOPE |
| LOD Shell Primitive | COVERED |
| Power Rail Notation | COVERED |
| Overlay/Facet Composition | OUT OF PROTOTYPE SCOPE |
| Distortion Legend | OUT OF PROTOTYPE SCOPE |
| Purpose-Level Annotation | OUT OF PROTOTYPE SCOPE |
| Primitives Compose, Not Interfere | COVERED |
| Primitive Set is Closed | COVERED |

---

## Blocking Failure — What the Implementer Must Fix

**Requirement:** Port Primitive § Scenario: Port placement
**THEN-clause:** "Edges connect to Ports, not directly to the Container body"
**Status:** PARTIAL — routing code exists but test does not verify it

The test `test_edge_endpoint_uses_port_position_when_available` asserts only that
`_port_world_positions` contains output-port keys for ctx_a that differ from the
centroid. It does NOT call `_find_port_or_centroid` and assert the return value is a
port position rather than the centroid — which is the actual contract being tested.

**Fix required:** Add a test that directly calls `_find_port_or_centroid("ctx_a", true)`
on a `Main` instance whose `build_from_graph` has been called with a graph containing
public symbols, and asserts:
1. The returned position is NOT equal to the Container centroid.
2. The returned position matches one of the registered port world positions in
   `get_port_world_positions()`.

This is a one-test addition to `test_port_renderer.gd` and unblocks the verdict.