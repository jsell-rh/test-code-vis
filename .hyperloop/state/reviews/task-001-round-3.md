---
task_id: task-001
round: 3
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — Scene Graph Schema Specification

Branch: hyperloop/task-001
All 156 pytest tests pass. Non-directional movement assertions check: OK.

---

### Req 1: Schema Structure — Top-level fields (nodes, edges, metadata, clusters, no extras)

Status: COVERED

- `SceneGraph` TypedDict defines exactly the four required fields.
- `validate_scene_graph()` rejects extra top-level keys (`ValueError`).
- `TestSchemaStructure` in `test_schema.py` asserts all four keys present and no extras.
- `TestSceneGraphOutput.test_build_scene_graph_has_required_keys` in `test_extractor.py` verifies `build_scene_graph()` produces all four keys.

---

### Req 2: Node Schema — id, name, type, position (x/y/z), size, parent, optional independence_group

Status: COVERED

**Bounded context node scenario:**
- `Node` TypedDict and `validate_scene_graph()` enforce id/name/type/position/size/parent.
- `TestNodeSchema` tests all required fields, correct types, and parent=null for BC nodes.
- `discover_bounded_contexts()` produces compliant nodes; covered by `TestModuleDiscovery`.

**Module node inside bounded context scenario:**
- `discover_submodules()` produces dotted id, type="module", parent=bc_id, position with x/y/z.
- `test_module_node_parent_references_context` and `test_submodule_parent_references_bc` verify parent reference.

**Module with independence_group scenario:**
- `compute_independence_groups()` assigns `independence_group` to every module node in format `<context_id>:<index>`.
- `TestIndependenceGroups` in `test_extractor.py` verifies connected modules share group, isolated modules get own group, format is correct.
- `TestIndependenceGroup` in `test_schema.py` verifies field can be set and format is valid.

---

### Req 3: Edge Schema — source, target, type; optional weight

Status: PARTIAL

**Cross-context dependency edge scenario:** COVERED
- `build_dependency_edges()` emits type="cross_context" for inter-BC imports.
- `TestDependencyExtraction` verifies cross-context edges are produced with correct source/target/type.

**Internal dependency edge scenario:** COVERED
- `build_dependency_edges()` emits type="internal" for intra-BC module imports.
- `TestDependencyExtraction` verifies internal edges are produced.

**Weighted edge scenario:** MISSING in extractor implementation
- `Edge` TypedDict defines `weight: NotRequired[int]` and type includes `"aggregate"`.
- `test_schema.py::TestWeightedEdge` tests the TypedDict with hand-crafted fixtures only.
- `build_dependency_edges()` in `extractor.py` NEVER emits a `weight` field on any edge.
- `build_dependency_edges()` NEVER emits an edge with `type="aggregate"`.
- No test in `test_extractor.py` verifies that the extractor produces weighted edges or aggregate edges.
- The spec requires: individual module-level edges carry `weight=1` (or weight omitted) AND the extractor emits an aggregate edge with `type="aggregate"` and `weight=<total>` for each BC-pair. The extractor only deduplicates cross-context edges into a single edge per BC-pair with no weight.

---

### Req 4: Metadata — source codebase path and extraction timestamp

Status: COVERED

- `Metadata` TypedDict has `source_path: str` and `timestamp: str`.
- `build_scene_graph()` populates both fields; `timestamp` is an ISO-8601 UTC string.
- `TestMetadataSchema` and `TestSceneGraphOutput.test_metadata_has_*` verify presence and types.
- Godot `test_scene_graph_loader.gd::test_metadata_is_returned` verifies Godot reads both fields.

---

### Req 5: Pre-Computed Layout — positions computed by Python, child within parent bounds, coupled closer

Status: COVERED

- `compute_layout()` runs before returning from `build_scene_graph()`.
- Module nodes receive LOCAL offsets relative to parent; Godot adds parent world position at render time.
- `test_child_position_is_local_offset` verifies stored value equals local offset directly (not proximity check) with parent at non-zero world position — satisfies coordinate frame contract.
- `test_coupled_bcs_are_closer_than_uncoupled` verifies coupled BCs are spatially closer.
- `test_child_nodes_are_near_parent_position` verifies local offset magnitude is within BC orbit radius.
- Godot `test_scene_graph_loading.gd::test_anchor_positions_match_json` verifies Godot renders at JSON positions without recomputing.

---

### Req 6: Cluster Schema — id, members, context, aggregate_metrics (total_loc, in_degree, out_degree); no position prescribed

Status: COVERED

- `Cluster` TypedDict and `AggregateMetrics` TypedDict define all required fields.
- `compute_clusters()` emits clusters with id (`<context>:cluster_N`), members, context, aggregate_metrics.
- Comment in `compute_clusters()` explicitly states "does NOT prescribe a collapsed position."
- `TestComputeClusters` covers: coupled modules form cluster, id format, empty-when-no-coupling, aggregate_metrics keys.
- `TestClusterSchema` in `test_schema.py` covers all required fields and empty clusters case.
- `validate_scene_graph()` enforces cluster structure including aggregate_metrics sub-keys.

---

### Req 7: Cascade Depth — affected nodes MUST carry depth value (hop distance)

Status: PARTIAL

- `compute_cascade_depth()` function is implemented with correct BFS logic.
- `TestCascadeDepth` in `test_extractor.py` verifies: direct dependent=depth 1, transitive=depth 2, minimum depth used, origin excluded, unrelated nodes excluded.
- `TestCascadeDepth` in `test_schema.py` verifies `depth` field can be set on nodes and is an int.
- MISSING: `build_scene_graph()` does NOT call `compute_cascade_depth()` and does NOT embed `depth` into any node dict. The function is a standalone utility, not integrated into the simulation output path.
- MISSING: Godot `apply_failure_overlay()` runs BFS itself but does NOT read `depth` from node data, does NOT annotate nodes with their depth value (only marks all as "AFFECTED"), and does NOT expose depth for gradient encoding or wave animation.
- MISSING: No GDScript behavioral test verifies that affected nodes carry a `depth` field with value 1 or 2 from known fixture data.
- The spec says "depth values are available to the visualization for gradient encoding and wave animation" — this is not implemented in any Godot script.

---

## Summary of Failures

1. **Req 3 / Weighted edge scenario — MISSING**: `build_dependency_edges()` never emits `weight` fields or `type="aggregate"` edges. The spec requires aggregate edges per BC-pair with total weight. No extractor test covers this.

2. **Req 7 / Cascade depth in simulation output — PARTIAL**: `compute_cascade_depth()` logic is correct and tested in isolation, but: (a) `build_scene_graph()` does not embed `depth` into simulation output nodes; (b) Godot `apply_failure_overlay()` does not read or assert depth values; (c) no GDScript test verifies depth=1 or depth=2 on affected nodes from known fixture data.