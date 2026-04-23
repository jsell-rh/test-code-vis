---
task_id: task-005
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — scene-graph-schema.spec.md

Branch: hyperloop/task-005

---

### Requirement: Schema Structure
**Status: COVERED**

Implementation: `extractor/schema.py` defines `SceneGraph` as a TypedDict with exactly three
keys — `nodes`, `edges`, `metadata`. No other top-level fields are present.

Tests:
- Python (`test_schema.py`): `TestSchemaStructure` — 8 tests covering presence of each key,
  type of each value, no-extra-fields assertion, and JSON round-trip.
- Python (`test_extractor.py`): `TestSceneGraphOutput.test_build_scene_graph_has_required_keys`
  exercises a real extraction.
- GDScript (`test_scene_graph_loader.gd`): `test_nodes_list_is_returned`,
  `test_edges_list_is_returned`, `test_metadata_is_returned` — all PASS through
  `SceneGraphLoader.load_from_dict`.

---

### Requirement: Node Schema — Scenario: Bounded context node
**Status: COVERED**

Implementation: `schema.py` `Node` TypedDict declares `id`, `name`, `type`, `position` (with
x/y/z), `size`, `parent`. `extractor.py:discover_bounded_contexts` populates all fields;
`parent` is set to `None` and `type` to `"bounded_context"`. `size_from_loc` derives the
visual size from the LOC complexity metric.

Tests:
- `test_schema.py`: `TestNodeSchema` — 8 tests covering all required fields, value types,
  parent-is-null, and xyz coordinates for a bounded-context fixture node ("iam").
- `test_extractor.py`: `TestModuleDiscovery.test_bounded_context_node_has_required_keys`,
  `test_bounded_context_type`, `test_bounded_context_parent_is_none` cover the live extractor.
- GDScript: `test_node_has_id_field` (iam), `test_node_has_name_field` (IAM),
  `test_node_has_type_field` (bounded_context), `test_node_top_level_has_null_parent`,
  `test_node_has_position_field` (x/y/z present), `test_node_has_size_field`.

---

### Requirement: Node Schema — Scenario: Module node inside a bounded context
**Status: COVERED**

Implementation: `extractor.py:discover_submodules` creates nodes with `id="bc.module"`,
`parent="bc"`, `type="module"`. `compute_layout` positions children by adding a local circular
offset to the parent BC's absolute position, keeping children spatially close to their parent.

Tests:
- `test_schema.py`: `TestNodeSchema.test_module_node_*` — id "iam.domain", type "module",
  parent "iam".
- `test_extractor.py`: `TestModuleDiscovery.test_discovers_submodules_in_iam`,
  `test_submodule_parent_references_bc`, `test_submodule_type_is_module`,
  `test_submodule_id_is_dotted`.
- GDScript: `test_node_module_parent_references_bounded_context`.

---

### Requirement: Edge Schema — Scenario: Cross-context dependency edge
**Status: COVERED**

Implementation: `build_dependency_edges` emits `(source_bc, target_bc, "cross_context")`
edges when two bounded contexts are involved. `Edge` TypedDict has `source`, `target`, `type`.

Tests:
- `test_schema.py`: `TestEdgeSchema.test_cross_context_edge_*` — source "graph",
  target "shared_kernel", type "cross_context".
- `test_extractor.py`: `TestDependencyExtraction.test_cross_context_edge_created`,
  `test_cross_context_edge_type` — exercises real fixture codebase.
- GDScript: `test_edge_has_source_field`, `test_edge_has_target_field`,
  `test_edge_has_type_field`, `test_cross_context_edge_type_is_cross_context`,
  `test_edge_direction_preserved_source_to_target`.

---

### Requirement: Edge Schema — Scenario: Internal dependency edge
**Status: COVERED**

Implementation: `build_dependency_edges` emits `(source_module, target_module, "internal")`
when both ends are in the same bounded context at module level.

Tests:
- `test_schema.py`: `TestEdgeSchema.test_internal_edge_*` — source "iam.application",
  target "iam.domain", type "internal".
- `test_extractor.py`: `TestDependencyExtraction.test_internal_edge_created`,
  `test_internal_edge_type`.
- GDScript: `test_internal_edge_type_is_internal`, `test_edge_types_are_distinguishable`.

---

### Requirement: Metadata — Scenario: Extraction metadata
**Status: COVERED**

Implementation: `Metadata` TypedDict has `source_path` (str) and `timestamp` (str).
`build_scene_graph` sets `source_path=str(src_path)` and
`timestamp=datetime.now(timezone.utc).isoformat()`.

Tests:
- `test_schema.py`: `TestMetadataSchema.test_metadata_has_source_path`,
  `test_metadata_has_timestamp`, `test_metadata_source_path_is_str`,
  `test_metadata_timestamp_is_str`.
- `test_extractor.py`: `TestSceneGraphOutput.test_metadata_has_source_path` (checks
  str(src) is in the path), `test_metadata_has_timestamp` (checks ISO-8601 "T" present).
- GDScript: `test_metadata_is_returned` (checks source_path and timestamp keys).

---

### Requirement: Pre-Computed Layout — Scenario: Layout in JSON
**Status: PARTIAL**

#### Sub-clauses 1–3: COVERED

1. "each node's `position` field contains x, y, z coordinates"
   - Code: `compute_layout` sets all node positions. `_circular_positions` produces (x,y,z).
   - Tests: `TestPreComputedLayout.test_every_node_has_a_position`,
     `TestLayout.test_all_nodes_have_positions_after_layout`,
     `TestSceneGraphOutput.test_every_node_has_position`.
   - GDScript: `test_node_has_position_field`.

2. "tightly coupled nodes have smaller distances between them"
   - Code: `_order_by_coupling` reorders BC nodes by coupling score before laying them out
     on a circle, so coupled pairs end up adjacent (smaller arc distance).
   - Tests: `TestLayout.test_coupled_bcs_are_closer_than_uncoupled` — fixture with 4 BCs
     (auth↔shared_kernel coupled, billing uncoupled to auth) asserts
     `dist(auth, shared_kernel) < dist(auth, billing)`.
     `TestLayout.test_order_by_coupling_places_coupled_adjacent` — unit test verifying
     greedy ordering puts coupled "b" adjacent to "a".

3. "child nodes are positioned within the spatial bounds of their parent"
   - Code: `compute_layout` offsets child positions by the parent BC's absolute position
     so children cluster around the parent.
   - Tests: `TestLayout.test_child_nodes_are_near_parent_position` — asserts
     `dist(child, parent) < bc_radius` for every module node.

#### Sub-clause 4: MISSING

"the Godot application renders nodes at these positions without recomputing layout"

- `godot/scripts/scene_graph_loader.gd` correctly reads and preserves the `position` dict
  from JSON via `raw.get("position", default)` — it does not recompute anything.
- **However, `godot/scripts/main.gd` is an empty stub** (`_ready` and `_process` do
  nothing). No Godot Node3D instances are ever created, positioned, or placed in the
  scene tree using the pre-computed positions from the JSON.
- There is no GDScript behavioral test that verifies scene-tree nodes are instantiated at
  the JSON-specified positions. The existing `test_node_has_position_field` only checks
  that the `position` dict keys (x/y/z) survive `SceneGraphLoader.load_from_dict` — it
  does not assert actual rendered node positions in the scene tree (no `position.x == 1.0`
  assertion, no scene-tree node instantiation check), which the guidelines require for
  Godot behavioral coverage.

---

## Summary

| Requirement                                   | Status  |
|-----------------------------------------------|---------|
| Schema Structure / Top-level structure        | COVERED |
| Node Schema / Bounded context node            | COVERED |
| Node Schema / Module node inside BC           | COVERED |
| Edge Schema / Cross-context dependency edge   | COVERED |
| Edge Schema / Internal dependency edge        | COVERED |
| Metadata / Extraction metadata                | COVERED |
| Pre-Computed Layout / Layout in JSON (1–3)    | COVERED |
| Pre-Computed Layout / Godot renders at positions (4) | MISSING |

## What the implementer must do to fix the MISSING item

1. **Implement rendering in `main.gd`**: When the scene loads the JSON scene graph, iterate
   over the parsed nodes and create a `MeshInstance3D` (or similar Node3D) for each one,
   setting its `position` directly from `node["position"]["x"]`, `node["position"]["y"]`,
   `node["position"]["z"]` — without running any layout algorithm in GDScript.

2. **Add a GDScript behavioral test**: In `godot/tests/` (discovered by `run_tests.gd`),
   add a test that:
   - Loads a fixture dictionary with known node positions (e.g., `iam` at x=1, y=0, z=0).
   - Calls the loader / scene-builder function.
   - Asserts that the resulting scene-tree node for "iam" has `position.x == 1.0`,
     `position.y == 0.0`, `position.z == 0.0`.
   - Does NOT call any layout function; confirms that the only position source is the JSON.