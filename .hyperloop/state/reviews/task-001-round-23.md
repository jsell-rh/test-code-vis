---
task_id: task-001
round: 23
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — Scene Graph Schema Specification

Branch: hyperloop/task-001

---

### Requirement: Schema Structure
**Status: COVERED**

- Implementation: `extractor/schema.py` defines `SceneGraph` as a `TypedDict` with exactly the fields `nodes`, `edges`, `metadata`. `extractor/extractor.py::build_scene_graph()` returns `{"nodes": nodes, "edges": edges, "metadata": metadata}` — exactly three top-level fields.
- Python test: `extractor/tests/test_schema.py::TestSchemaStructure::test_scene_graph_has_no_extra_top_level_fields` asserts `set(graph.keys()) == {"nodes", "edges", "metadata"}`. Additional tests cover each key's type.
- Godot test: `godot/tests/test_scene_graph_loader.gd` fixture `_make_fixture()` uses exactly three top-level keys; `test_nodes_list_is_returned`, `test_edges_list_is_returned`, `test_metadata_is_returned` verify each is present and correctly typed.

---

### Requirement: Node Schema — Scenario: Bounded context node
**Status: COVERED**

- Implementation: `extractor/extractor.py::discover_bounded_contexts()` produces nodes with `id` (directory name), `name` (prettified), `type="bounded_context"`, `position` (x/y/z populated by `compute_layout`), `size` derived from `size_from_loc(loc)`, and `parent=None`.
- Python tests: `test_schema.py::TestNodeSchema::test_bounded_context_node_*` (id, name, type, position xyz, size numeric, parent=null). `test_extractor.py::TestModuleDiscovery::test_bounded_context_*`.
- Godot tests: `test_scene_graph_loader.gd` fixture includes IAM bounded context; `test_node_has_id_field`, `test_node_has_name_field`, `test_node_has_type_field`, `test_node_top_level_has_null_parent`, `test_node_has_position_field`, `test_node_has_size_field` all pass on the fixture.

---

### Requirement: Node Schema — Scenario: Module node inside a bounded context
**Status: FAIL**

**Contract**: schema.py line 48 states: `"""Pre-computed 3D position. Coordinates are relative to the parent node."""`

**Bug — Python stores absolute world coordinates, not relative offsets.**

In `extractor/extractor.py::compute_layout()` (lines 228–235):
```python
px, py, pz = bc_pos_map.get(parent_id, (0.0, 0.0, 0.0))
for child, pos in zip(children, mod_positions):
    child["position"] = {
        "x": px + pos[0],   # ABSOLUTE: parent world pos + local offset
        "y": py + pos[1],
        "z": pz + pos[2],
    }
```
The stored value is `parent_world_position + local_offset`, not `local_offset` alone.

**Bug — Godot consumes the stored value as a relative offset, causing double-counting.**

In `godot/scripts/main.gd::_resolve_world_pos()` (lines 146–162):
```gdscript
var local := Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
...
return _world_positions[parent_id] + local   # adds parent world pos to stored value
```
And in `_create_volume()` (line 175), the anchor is positioned at the raw stored value, then added as a child of the parent anchor — so Godot's scene tree adds the parent's world position again automatically.

Result: `rendered_world_pos = parent_world + stored = parent_world + (parent_world + local_offset) = 2 * parent_world + local_offset`. Child nodes are rendered at incorrect positions whenever the parent is at a non-zero location.

**Test gap — `test_child_nodes_are_near_parent_position` is a vacuous proximity test.**

`extractor/tests/test_extractor.py` (lines 406–435) checks `|child_stored - parent_stored| < bc_radius`. Because `child_stored = parent_stored + local_offset` (absolute), this distance equals `|local_offset|` (typically 1.5–2.7 units) — always well below `bc_radius`. The test passes for BOTH relative and absolute storage and cannot distinguish them. No parent fixture is placed at a non-zero location then checked for `child["position"]["x"] == local_offset_x`.

**What is needed to fix:**
1. In `compute_layout()`, store only `pos[0], pos[1], pos[2]` (the local offset) without adding `px, py, pz` for child nodes.
2. Add a test that places a parent BC at a non-zero world position (e.g. `(10, 0, 0)`), runs `compute_layout`, and asserts `child["position"]["x"] == approx(local_offset_x)` — NOT proximity to parent.

**Note:** `extractor/layout.py` is dead code (never called by `build_scene_graph()`; the function `compute_layout` there is shadowed by the one defined in `extractor.py`). Its child placement also stores absolute values. This module should either be removed or wired in as a replacement.

---

### Requirement: Edge Schema — Scenario: Cross-context dependency edge
**Status: COVERED**

- Implementation: `extractor/extractor.py::build_dependency_edges()` emits `{"source": edge_src, "target": edge_tgt, "type": "cross_context"}` when source and target belong to different bounded contexts (normalised to BC level).
- Python tests: `test_extractor.py::TestDependencyExtraction::test_cross_context_edge_created`, `test_cross_context_edge_type`; `test_schema.py::TestEdgeSchema::test_cross_context_edge_*`.
- Godot tests: `test_scene_graph_loader.gd::test_cross_context_edge_type_is_cross_context`, `test_edge_direction_preserved_source_to_target`.

---

### Requirement: Edge Schema — Scenario: Internal dependency edge
**Status: COVERED**

- Implementation: `build_dependency_edges()` emits `{"source": source_id, "target": target_id, "type": "internal"}` when both endpoints share the same bounded context.
- Python tests: `test_extractor.py::TestDependencyExtraction::test_internal_edge_created`, `test_internal_edge_type`; `test_schema.py::TestEdgeSchema::test_internal_edge_*`.
- Godot tests: `test_scene_graph_loader.gd::test_internal_edge_type_is_internal`, `test_edge_types_are_distinguishable`.

---

### Requirement: Metadata
**Status: COVERED**

- Implementation: `build_scene_graph()` (lines 475–479) sets `source_path = str(src_path)` and `timestamp = datetime.now(timezone.utc).isoformat()`.
- Python tests: `test_extractor.py::TestSceneGraphOutput::test_metadata_has_source_path`, `test_metadata_has_timestamp`; `test_schema.py::TestMetadataSchema::test_metadata_has_source_path`, `test_metadata_has_timestamp`.
- Godot tests: `test_scene_graph_loader.gd::test_metadata_is_returned` checks `source_path` and `timestamp`.

---

### Requirement: Pre-Computed Layout
**Status: PARTIAL**

The layout algorithm runs in Python (`compute_layout()` called from `build_scene_graph()`; Godot does not run a layout algorithm). The coupling-aware ordering and tightly-coupled-nodes-closer guarantee are implemented and tested (`test_coupled_bcs_are_closer_than_uncoupled` passes). All nodes receive x/y/z fields.

However, the sub-contract "child nodes are positioned within the spatial bounds of their parent" cannot be verified correctly:
- **Python side**: the proximity test passes vacuously (see Module Node finding above).
- **Godot side**: because Python stores absolute positions and Godot adds parent world position at render time, child nodes are rendered at `2 * parent_world + local_offset`. When the parent is not at the origin, children appear outside their parent's spatial bounds in the rendered scene.

This scenario's rendered-correctness is blocked by the same root cause as the Module Node coordinate-frame bug. Fix the extractor to store relative offsets; then the Godot scene tree's automatic parent-transform accumulation will naturally position children within bounds.

---

## Summary

| Requirement | Scenario | Status |
|---|---|---|
| Schema Structure | Top-level structure | COVERED |
| Node Schema | Bounded context node | COVERED |
| Node Schema | Module node — position relative to parent | **FAIL** |
| Edge Schema | Cross-context dependency edge | COVERED |
| Edge Schema | Internal dependency edge | COVERED |
| Metadata | Extraction metadata | COVERED |
| Pre-Computed Layout | Layout in JSON | PARTIAL |

**Verdict: FAIL**

The single blocking defect (third review, same root cause): `compute_layout()` in `extractor.py` stores absolute world coordinates for child (module) nodes instead of parent-relative offsets, contradicting the schema contract. Godot's renderer adds the parent world position on top, producing double-offset rendering. The only existing test (`test_child_nodes_are_near_parent_position`) is a proximity test that passes for both absolute and relative storage and cannot catch this bug.