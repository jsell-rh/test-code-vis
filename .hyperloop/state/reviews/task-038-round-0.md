---
task_id: task-038
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review: visual-primitives.spec.md — branch hyperloop/task-038

**Task assignment**: task-038 — "Implement Port primitive renderer in Godot (public interface points on Container membrane)"

**Rebase**: Completed successfully (`git rebase main` applied cleanly).

**All pytest tests**: 249 passed, 0 failed.

---

## Critical Failure

**Requirement: Port Primitive** — MISSING

Task-038 is described as implementing the Port Primitive renderer in Godot. The task description specifies:

- `godot/rendering/port_renderer.gd` — new GDScript for Port rendering
- `godot/rendering/container_renderer.gd` — extended with Port instantiation
- `godot/rendering/edge_renderer.gd` — extended to route Edge endpoints to Ports
- `godot/tests/test_port_renderer.gd` — Godot behavioral tests

**None of these files exist on this branch.** The Godot scripts directory contains only:
`camera_controller.gd`, `lod_manager.gd`, `main.gd`, `scene_graph_loader.gd`,
`understanding_analyzer.gd`, `understanding_overlay.gd`, `visual_primitives.gd`

No `port_renderer.gd` exists. No `test_port_renderer.gd` exists. The Port Primitive (SHALL) is entirely unimplemented. Every scenario under this requirement is MISSING.

**Scenarios MISSING**:
- Port placement: Container with 4 public functions displays 4 Port elements on its membrane
- Port direction: input Ports (parameters) visually distinct from output Ports (return values/emitted events)
- Port visibility at zoom levels: Ports hidden at tier-0, fade in at tier-2
- Edge routing: Edges connect to Ports, not directly to Container body

---

## What IS on this branch

The branch's single commit (`feat(extractor): emit weight on individual cross_context and internal edges`) implements `weight` emission on individual cross_context and internal edges in the Python extractor. This relates to a different requirement — **Module Graph Extraction** — and is correct work, but it is NOT the Port Primitive implementation task-038 requires.

---

## Full Requirement-by-Requirement Status

### Extraction Layer

**Requirement: Scope Nesting Extraction** — COVERED (pre-existing)
- Code: `discover_bounded_contexts()`, `discover_submodules()` in extractor.py
- Scenario "Containment tree": bounded_context → module hierarchy emitted; tree root is the project; leaves are atomic declarations; available to composition layer. Tests: `TestModuleDiscovery` (11 tests).
- Scenario "Extraction cost": single-file AST parsing only; no cross-file resolution. Implicit in implementation.

**Requirement: Module Graph Extraction** — PARTIAL
- Code: `build_dependency_edges()` now emits `weight` on cross_context and internal edges (new in this branch).
- Scenario "Import-based edges":
  - THEN edges A→B, A→C are emitted: ✓ (pre-existing, `test_cross_context_edge_created`, `test_internal_edge_created`)
  - AND each edge carries the import count: weight field emitted ✓, tests check weight >= 1 — but NO test verifies count accuracy with a multi-import fixture (e.g., 3 distinct imports between A and B → weight == 3). The test fixture has only 1 import per pair, making the `weight >= 1` assertion vacuous for count accuracy. `check-individual-edge-weight.sh` passes but tests do not prove the accumulator is correct for N>1. PARTIAL.
- Scenario "Distinction from scope nesting": architectural distinction between cross_context/internal edge types vs. parent field is correct, but no explicit test asserting "these two relationship types are distinct in the scene graph." PARTIAL (implicit coverage only).

**Requirement: Symbol Table Extraction** — COVERED (pre-existing)
- Code: `extract_symbols()` emits public/private symbols with kind and signature.
- Scenarios: `TestSymbolTableExtraction` (5 tests) cover public/private visibility, signature, class extraction, embedding in module node.

**Requirement: Type Topology Extraction** — COVERED (pre-existing)
- Code: `extract_type_topology()` emits `inherits` and `has_a` edges.
- Scenarios: `TestTypeTopologyExtraction` (4 tests) cover inheritance edge, composition edge, edge types. AST-only (no type inference).

**Requirement: Call Graph Extraction** — COVERED (pre-existing)
- Code: `extract_call_graph()` emits `direct_call` (weighted) and `dynamic_call` edges with `param_name`.
- Scenarios: `TestCallGraphExtraction` (5 tests) cover direct call edge, edge type, weight counts call sites (verified with fixture having 3 call sites → weight >= 3), dynamic call emission, param_name on dynamic call.

**Requirement: Data Flow Spine Extraction** — OUT OF SCOPE
- prototype-scope.spec.md explicitly excludes "data flow visualization". Not a failure.

**Requirement: Structural Significance Extraction** — COVERED (pre-existing)
- Code: `compute_structural_significance()` computes in/out-degree, betweenness, hub/bridge/peripheral flags, community detection with community_drift.
- Scenarios: `TestStructuralSignificance` and `TestStructuralSignificanceExtraction` (15 tests) cover hub detection, peripheral detection, bridge detection, betweenness centrality, community IDs, community drift, landmark derivation from hub/bridge/entry-point.

**Requirement: Ubiquitous Dependency Detection** — COVERED (pre-existing)
- Code: `detect_ubiquitous_dependencies()` and `compute_ubiquitous_flags()`.
- Scenarios: `TestUbiquitousDependencyDetection` and `TestUbiquitousFlags` (11 tests) cover ubiquitous edge flagging, node `has_ubiquitous_dep` annotation, configurable threshold, metadata embedding.

---

### Composition Layer

**Requirement: Container Primitive** — PARTIAL (pre-existing)
- Code: `main.gd` renders bounded_context nodes as translucent boxes with membrane opacity reflecting public/private symbol ratio. Container nesting implemented (modules nested inside context volumes).
- Scenario "Module as container": membrane permeability rendered (comment refs spec §Container membrane permeability), ports NOT rendered → PARTIAL (membrane done, ports MISSING).
- Scenario "Nested containers": nesting depth apparent from containment. Test `test_containment_rendering.gd` exists. COVERED for nesting.
- Scenario "Container membrane permeability": membrane opacity computed from symbol ratio. But no behavioral test with known fixture verifying the opacity value for known public/private counts. PARTIAL.

**Requirement: Node Primitive** — PARTIAL (pre-existing)
- Code: `main.gd` renders module nodes as boxes labeled with names. Badges attached via `visual_primitives.gd`.
- Tests in `test_node_renderer.gd` (see godot/tests). Badge vocabulary tested in `test_visual_primitives.gd`.
- Scenario "Function node": node exists with name, carries badges → COVERED.
- Scenario "Node without badges": plain node rendered → COVERED.

**Requirement: Badge Primitive** — COVERED (pre-existing)
- Code: `visual_primitives.gd._render_badges()` renders badge spheres above node volumes.
- Scenarios: `test_visual_primitives.gd` provides 11+ behavioral tests: single badge → MeshInstance3D child; multiple badges → all rendered in distinct X positions; SphereMesh verified; badge vocabulary (pure, io, async, stateful, test, deprecated) each tested. Composability (landmark + badge) tested.

**Requirement: Edge Primitive** — PARTIAL (pre-existing)
- Code: `main.gd._create_edge()` uses weight for radius (`BASE_RADIUS * (1 + weight / 10)`); line style by type (solid=direct_call, dashed=imports, dotted=inherits/has_a). Ubiquitous edge suppression implemented.
- Scenario "Weighted edge": radius encodes weight. Note: the new `weight` field on cross_context/internal edges (this branch) is now consumed by the renderer — previously those edges defaulted to weight=1. Rendering is consistent. But no behavioral test verifies that a known fixture with cross_context/internal edges of weight > 1 actually renders at greater thickness than a weight=1 edge. PARTIAL.
- Scenario "Edge type distinction": line styles present. Tests in `test_dependency_rendering.gd` cover this. COVERED.
- Scenario "Suppressed ubiquitous edges": ubiquitous edges hidden; power rail indicator added; toggle with T key. Tests in `test_visual_primitives.gd`. COVERED.

**Requirement: Port Primitive** — MISSING ← **BLOCKING FAIL**
See Critical Failure section above. No implementation, no tests.

**Requirement: Route Primitive** — OUT OF SCOPE
- Requires LLM trace through call graph (moldable views, out of prototype scope).

**Requirement: Landmark Primitive** — COVERED (pre-existing)
- Code: `visual_primitives.gd._apply_landmark()` scales anchor and adds TorusMesh ring. `main.gd` excludes landmarks from LOD entries.
- Scenarios: Hub as landmark (scale boost, torus ring, not in LOD, visible after FAR LOD applied), Bridge as landmark, Entry-point as landmark, regular node in LOD. All covered by `test_visual_primitives.gd` and `test_visual_primitives.gd` hub/bridge/entry-point tests (10+ tests).

**Requirement: Tint Primitive** — OUT OF SCOPE
- Categorical color overlay requires LLM/facet system (moldable views, out of prototype scope).

**Requirement: LOD Shell Primitive** — PARTIAL (pre-existing)
- Code: `lod_manager.gd` implements 3-tier LOD (FAR/MEDIUM/NEAR thresholds). Modules hidden at FAR, modules + edges visible at MEDIUM, all at NEAR.
- Scenario "Three-tier LOD": tier-0 (far) → context containers only; tier-1 (medium) → context + modules; tier-2 (near) → all. Implemented via `LodManager.update_lod()`.
- Scenario "LLM tier selection": LLM integration not in prototype, but LOD is applied by camera distance. PARTIAL (manual LOD by distance, not LLM-driven).
- Scenario "Mixed tiers": Not implemented (uniform distance-based LOD only). PARTIAL.
- Tests: `test_godot_app_spec.gd` and LOD-specific tests cover tier transitions.

**Requirement: Power Rail Notation** — COVERED (pre-existing)
- Code: `visual_primitives.gd._render_power_rail()`, `main.gd._add_power_rail_indicator()`, ubiquitous edge suppression + toggle (T key).
- All scenarios (Standard library power rail, Power rail toggle, Multiple power rails) tested in `test_visual_primitives.gd` (8+ behavioral tests).

---

### Composition Principles

**Requirement: Overlay/Facet Composition** — OUT OF SCOPE (moldable views)
**Requirement: Distortion Legend** — OUT OF SCOPE (moldable views)
**Requirement: Purpose-Level Annotation** — OUT OF SCOPE (moldable views)

---

### Primitive Interactions

**Requirement: Primitives Compose, Not Interfere** — PARTIAL (pre-existing)
- Code: each primitive uses distinct perceptual channels (position=containers, line=edges, hue=tint[out of scope], glyph=badges, size=edge weight, luminance=landmarks).
- Tests: `test_landmark_and_badges_compose`, `test_all_three_primitives_compose` cover Badge+Landmark+Power Rail simultaneous rendering. COVERED for implemented primitives.
- Port channel not testable (Port not implemented). PARTIAL.

**Requirement: Primitive Set is Closed** — Cannot verify (LLM not in prototype)

---

## Summary Table

| Requirement                       | Status  | Notes                                                |
|-----------------------------------|---------|------------------------------------------------------|
| Scope Nesting Extraction          | COVERED | Pre-existing; full test coverage                     |
| Module Graph Extraction           | PARTIAL | Weight field added (this branch); tests check >=1 but not exact count accuracy for N>1; distinction-from-scope-nesting not explicitly tested |
| Symbol Table Extraction           | COVERED | Pre-existing                                         |
| Type Topology Extraction          | COVERED | Pre-existing                                         |
| Call Graph Extraction             | COVERED | Pre-existing                                         |
| Data Flow Spine Extraction        | OUT OF SCOPE | Excluded by prototype-scope.spec.md               |
| Structural Significance Extraction| COVERED | Pre-existing                                         |
| Ubiquitous Dependency Detection   | COVERED | Pre-existing                                         |
| Container Primitive               | PARTIAL | Membrane permeability impl; no permeability behavioral test with known counts |
| Node Primitive                    | COVERED | Pre-existing                                         |
| Badge Primitive                   | COVERED | Pre-existing; full behavioral tests                  |
| Edge Primitive                    | PARTIAL | Weight rendering correct; no cross_context/internal thickness behavioral test for weight>1 |
| Port Primitive                    | MISSING | **No implementation. No tests. Task-038 deliverable absent.** |
| Route Primitive                   | OUT OF SCOPE | Moldable views excluded from prototype             |
| Landmark Primitive                | COVERED | Pre-existing; full behavioral tests                  |
| Tint Primitive                    | OUT OF SCOPE | Moldable views excluded from prototype             |
| LOD Shell Primitive               | PARTIAL | Distance-based 3-tier LOD implemented; LLM-driven/mixed tiers not in prototype |
| Power Rail Notation               | COVERED | Pre-existing; full behavioral tests                  |
| Overlay/Facet Composition         | OUT OF SCOPE | Moldable views excluded from prototype             |
| Distortion Legend                 | OUT OF SCOPE | Moldable views excluded from prototype             |
| Purpose-Level Annotation          | OUT OF SCOPE | Moldable views excluded from prototype             |
| Primitives Compose, Not Interfere | PARTIAL | Badge+Landmark+PowerRail composability tested; Port not testable (missing) |
| Primitive Set is Closed           | N/A     | Cannot verify without LLM integration               |

---

## What the Implementer Must Fix

**To pass this review, the implementer must implement task-038's stated deliverable:**

1. **Create `godot/scripts/port_renderer.gd`** (task description says `godot/rendering/port_renderer.gd` — confirm path with project conventions; current scripts are in `godot/scripts/`):
   - Reads `symbols` array from node data, filters where `visibility == "public"`
   - Computes Port positions evenly distributed on Container membrane surface
   - Instantiates labeled Port mesh (MeshInstance3D) + Label3D per public symbol
   - Input Ports on left/bottom face; output Ports on right/top face
   - LOD integration: Port alpha = 0 at tier-0/1; fades in at tier-2

2. **Extend `godot/scripts/main.gd`** (or create `container_renderer.gd`):
   - Instantiate port_renderer per Container after volume creation
   - Store Port world position map keyed by symbol name

3. **Extend edge rendering** to route Edge endpoints to Port positions when available, falling back to Container centroid when Ports are hidden/unavailable

4. **Create `godot/tests/test_port_renderer.gd`** with behavioral tests:
   - Container with 4 public symbols → 4 Port MeshInstance3D elements on membrane
   - Container with 0 public symbols → no Port elements
   - Port labels match function names from symbol table
   - At tier-0 LOD: all Port meshes + labels have alpha = 0
   - At tier-2 LOD: Port meshes + labels have alpha > 0
   - Edge endpoints route to Port positions rather than Container centroid when Ports visible
   - Input and output Ports appear on opposing faces of Container

Additionally, to fully resolve the PARTIAL findings:

5. **Add a multi-import weight test** to `extractor/tests/test_extractor.py` for cross_context/internal edges: fixture with 2+ distinct module imports between the same BC pair should verify `weight == N` (not just `>= 1`). This proves the accumulator is correct.