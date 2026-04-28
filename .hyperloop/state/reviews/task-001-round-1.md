---
task_id: task-001
round: 1
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-001 / Scene Graph Schema

### Branch: hyperloop/task-001
### Spec: specs/extraction/scene-graph-schema.spec.md (assignment spec, 7 requirements)
### Repo spec file SHA: 3e5e297e216c7876224564ee099a38334e3dbd55

---

## Critical Finding: Assignment Spec vs. Repo Spec Mismatch

The assignment spec (provided to this verifier) contains **7 requirements**.
The repo spec file (`specs/extraction/scene-graph-schema.spec.md` at commit 3e5e297e,
which the implementer's Spec-Ref trailer correctly references) contains **5 requirements**.

The two additional MUST-level requirements in the assignment spec — Cluster Schema and
Cascade Depth — and the augmented Schema Structure (clusters MUST), augmented Node Schema
(independence_group MAY), and augmented Edge Schema (weight MAY) are **absent from the
spec file the implementer was working against**.

The implementer fully and correctly implemented all 5 requirements in their spec file.
The FAIL verdict is mechanically required by the assignment spec's MUST obligations —
not by implementer error.

---

## Automated Check Results

- `check-nondirectional-movement-assertions.sh`: OK (no movement scenarios in this spec)
- `check-relative-position-tests.sh`: OK — direct relative-offset assertion exists
- `check-ruff-format.sh`: OK — extractor/ passes ruff format and ruff check
- `check-pytest-passes.sh`: OK — 112 pytest tests pass
- `check-godot-no-script-errors.sh`: OK — all 16 GDScript test files PASS
- `check-report-scope-section.sh`: FAIL (pre-existing: prior worker-result.yaml was
  deleted by commit 8a5f2672; resolved by the present report)
- All other checks: OK or SKIP

---

## Findings per Assignment Spec Requirement

### Requirement 1: Schema Structure
SHALL: nodes array, edges array, metadata object, AND clusters array present.
AND no other top-level fields.

#### Scenario: Top-level structure
- `nodes`, `edges`, `metadata`: **COVERED**
  - `SceneGraph` TypedDict (`extractor/schema.py` line 83–93) defines exactly these three.
  - `validate_scene_graph()` (`schema.py` line 109–180) enforces their presence, types,
    and rejects extra keys.
  - Tests: `TestSchemaStructure` (8 tests in `test_schema.py`); `TestValidateSceneGraph`
    (14 tests) covering all field-presence invariants.
- `clusters` array (MUST): **MISSING**
  - `SceneGraph` TypedDict does not include a `clusters` field.
  - `_REQUIRED_GRAPH_KEYS` (`schema.py` line 106) is `{"nodes", "edges", "metadata"}` —
    no `clusters`.
  - `validate_scene_graph()` line 130–133 **actively rejects** any extra top-level key,
    meaning a `clusters` field would cause a `ValueError` on valid input.
  - No `Cluster` TypedDict exists anywhere in the codebase.
  - No tests for clusters present or absent.
  - STATUS: **MISSING** — requires adding `Cluster` TypedDict, `clusters: list[Cluster]`
    to `SceneGraph`, updating `_REQUIRED_GRAPH_KEYS`, updating validator, and adding tests.

---

### Requirement 2: Node Schema
SHALL: id, name, type, position, size, optional parent reference.
MAY: independence_group identifier on module nodes.

#### Scenario: Bounded context node
- **COVERED**
  - `Node` TypedDict (`schema.py` lines 32–57): id, name, type, position, size, parent all
    present and typed.
  - `make_bounded_context_node()` fixture in `test_schema.py` lines 32–41: id="iam",
    name="IAM", type="bounded_context", position with x/y/z, size=5.0, parent=None.
  - Tests: `TestNodeSchema` (13 tests) verify all required fields; `TestModuleDiscovery`
    tests `discover_bounded_contexts()` output has all keys with correct values.

#### Scenario: Module node inside a bounded context
- **COVERED**
  - `discover_submodules()` (`extractor.py` lines 266–285) sets parent=bc_name for all
    module nodes; id is `f"{bc_name}.{candidate.name}"`.
  - Relative position requirement: `test_child_position_is_local_offset_not_absolute()`
    (`test_extractor.py` lines 440–488) places a single BC (solo_bc) at non-zero world
    position (x=5.0, bc_radius=5.0, cos(0)*5.0) and asserts the child's stored x equals
    the local offset (1.5) directly, and explicitly asserts it does NOT equal the absolute
    world position (5.0+1.5=6.5). Parent is at non-zero position ✓; assertion is a direct
    equality check, not proximity ✓; explicitly rules out absolute storage ✓.
  - `test_submodule_parent_references_bc()`: asserts parent == "iam" for all iam modules.

#### Scenario: Module with independence_group (MAY)
- **MISSING** (note only — MAY, not a FAIL driver)
  - `Node` TypedDict has no `independence_group` field.
  - No clustering/independence algorithm in `extractor.py`.
  - No tests for this field.
  - Flagged as a gap for future implementation.

---

### Requirement 3: Edge Schema
SHALL: source, target, type.
MAY: weight field indicating number of individual imports.

#### Scenario: Cross-context dependency edge
- **COVERED**
  - `Edge` TypedDict (`schema.py` lines 60–71): source, target, type.
  - `make_cross_context_edge()` fixture: source="graph", target="shared_kernel",
    type="cross_context".
  - Tests: `TestEdgeSchema` (8 tests); `test_cross_context_edge_created()` and
    `test_cross_context_edge_type()` in `test_extractor.py` verify real edge production.

#### Scenario: Internal dependency edge
- **COVERED**
  - `build_dependency_edges()` (`extractor.py` lines 298–356) classifies intra-context
    edges as `"internal"`.
  - Tests: `test_internal_edge_created()`, `test_internal_edge_type()` in `test_extractor.py`.

#### Scenario: Weighted edge (MAY)
- **MISSING** (note only — MAY, not a FAIL driver)
  - No `weight` key in `Edge` TypedDict.
  - `EdgeType` is `Literal["cross_context", "internal"]` — no "aggregate" type.
  - `build_dependency_edges()` deduplicates via a set, producing at most one edge per
    (src, tgt, type) triple; no weight counting or aggregate edge emission.
  - Flagged as a gap for future implementation.

---

### Requirement 4: Metadata
SHALL: source_path and timestamp.

#### Scenario: Extraction metadata
- **COVERED**
  - `Metadata` TypedDict (`schema.py` lines 73–81): source_path (str), timestamp (str).
  - `build_scene_graph()` (`extractor.py` lines 391–395): sets source_path=str(src_path),
    timestamp=datetime.now(timezone.utc).isoformat().
  - Tests: `TestMetadataSchema` (4 tests); `test_metadata_has_source_path()` and
    `test_metadata_has_timestamp()` in `TestSceneGraphOutput`.

---

### Requirement 5: Pre-Computed Layout
MUST: positions computed by Python extractor; coupled nodes closer; child within parent bounds;
Godot renders at these positions without recomputing.

#### Scenario: Layout in JSON
- **COVERED** — all four THEN-clauses:
  1. *Each node's position has x,y,z*: `TestLayout.test_all_nodes_have_positions_after_layout()`
     calls `compute_layout()` then asserts x/y/z present on every node.
  2. *Tightly coupled nodes closer*: `test_coupled_bcs_are_closer_than_uncoupled()` builds a
     4-BC fixture with auth→shared_kernel coupling, runs `compute_layout()` with edges, and
     asserts `dist(auth, shared_kernel) < dist(auth, billing)`.
  3. *Child within parent bounds*: `test_child_nodes_are_near_parent_position()` asserts
     local-offset magnitude < bc_radius (mirrors extractor formula). Additionally confirmed
     by `check-layout-radius-bound.sh` (OK).
  4. *Godot renders, no recomputation*: `test_node_renderer.gd` — `test_node_rendered_at_json_position()`,
     `test_second_node_rendered_at_json_position()`, `test_no_layout_recomputed_in_godot()`,
     `test_each_json_node_becomes_a_scene_tree_child()` — all assert exact JSON coordinates
     appear as scene-tree positions; `main.gd` has no layout algorithm.
- **Relative coordinate contract**:
  - `test_child_position_is_local_offset_not_absolute()` uses a non-origin parent (x=5.0),
    asserts child stored x equals local offset (1.5) exactly, and explicitly asserts child x
    ≠ parent_x + local_offset (6.5). Satisfies all guidelines' anti-proximity requirements.
  - `main.gd` `_resolve_world_pos()` adds parent world position at render time, consistent
    with Python storing only local offsets.

---

### Requirement 6: Cluster Schema (MUST in assignment spec)
SHALL: clusters array with entries having id, members, context, aggregate_metrics.
Godot computes supernode position as centroid; no position prescribed in cluster entry.

#### Scenario: Cluster suggestion
- **MISSING**
  - No `Cluster` TypedDict.
  - No clustering algorithm in `extractor.py`.
  - No `clusters` field in `SceneGraph` or `build_scene_graph()` output.
  - No tests.
  - STATUS: **MISSING** — need: `Cluster` TypedDict with id/members/context/aggregate_metrics,
    clustering algorithm (mutual coupling threshold), `clusters: list[Cluster]` in `SceneGraph`,
    `build_scene_graph()` must run clustering and populate `clusters`, validator must accept
    and validate `clusters`, tests for both populated and empty `clusters` arrays.

#### Scenario: No clusters found (empty array)
- **MISSING** (follows from above)
  - STATUS: **MISSING**

---

### Requirement 7: Cascade Depth in Simulation Output (MUST in assignment spec)
MUST: affected nodes in failure cascade carry a depth value (hop distance from origin).

#### Scenario: Cascade with depth
- **MISSING**
  - No `depth` field in `Node` TypedDict or schema.
  - No failure cascade simulation logic in `extractor.py`.
  - No tests for cascade depth.
  - STATUS: **MISSING** — requires: `depth: NotRequired[int]` on `Node` (or a separate
    simulation-output schema), cascade computation logic, and tests asserting depth=1 for
    direct dependents and depth=2 for second-hop dependents.

---

## Summary Table

| # | Requirement / Scenario                               | Status   |
|---|------------------------------------------------------|----------|
| 1 | Schema Structure: nodes array                        | COVERED  |
| 2 | Schema Structure: edges array                        | COVERED  |
| 3 | Schema Structure: metadata object                    | COVERED  |
| 4 | Schema Structure: clusters array (MUST)              | MISSING  |
| 5 | Schema Structure: no extra top-level fields          | COVERED  |
| 6 | Node: id, name, type, position, size, parent (SHALL) | COVERED  |
| 7 | Node: bounded context scenario                       | COVERED  |
| 8 | Node: module inside bounded context (relative pos)   | COVERED  |
| 9 | Node: independence_group (MAY)                       | MISSING (note) |
|10 | Edge: source, target, type (SHALL)                   | COVERED  |
|11 | Edge: cross-context scenario                         | COVERED  |
|12 | Edge: internal scenario                              | COVERED  |
|13 | Edge: weight + aggregate type (MAY)                  | MISSING (note) |
|14 | Metadata: source_path                                | COVERED  |
|15 | Metadata: timestamp                                  | COVERED  |
|16 | Pre-Computed Layout: positions in JSON               | COVERED  |
|17 | Pre-Computed Layout: coupled nodes closer            | COVERED  |
|18 | Pre-Computed Layout: child within parent bounds      | COVERED  |
|19 | Pre-Computed Layout: Godot renders, no recompute     | COVERED  |
|20 | Cluster Schema: id/members/context/aggregate_metrics | MISSING  |
|21 | Cluster Schema: empty array when no clusters         | MISSING  |
|22 | Cascade Depth: depth on affected nodes (MUST)        | MISSING  |

---

## Verdict: FAIL

Three SHALL/MUST requirements from the assignment spec have zero implementation and zero
test coverage:

1. **`clusters` top-level field** in Schema Structure (MUST) — not in SceneGraph TypedDict;
   validator actively rejects it as an unexpected key.
2. **Cluster Schema** (MUST) — no Cluster TypedDict, no clustering algorithm, no tests.
3. **Cascade Depth** (MUST) — no depth field, no simulation logic, no tests.

**Root cause note**: The repo spec file (`specs/extraction/scene-graph-schema.spec.md` at
Spec-Ref 3e5e297e) contains only 5 requirements and does not include clusters or cascade
depth. The implementer correctly and completely satisfied all 5 requirements in their spec.
The three MUST failures arise from requirements that exist only in the assignment spec
provided to this verifier — not in the document the implementer was contracted against.

**Actionable remediation path**:
1. Update `specs/extraction/scene-graph-schema.spec.md` to add the Cluster Schema and
   Cascade Depth requirements (and `clusters` to Schema Structure, `independence_group` and
   `weight` as desired).
2. Commit the spec update with a new Spec-Ref hash.
3. Re-assign the task so the implementer can implement against the revised spec.

The not-in-scope audit found no prohibited features introduced by this branch
(understanding_overlay.gd pre-dates this branch, originating at commit a2f9d139).