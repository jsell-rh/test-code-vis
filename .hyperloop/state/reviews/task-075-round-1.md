---
task_id: task-075
round: 1
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — visual-primitives.spec.md
**Branch**: hyperloop/task-075
**Spec-Ref**: specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959
**Pytest**: 191 passed, 0 failed
**Godot tests**: 179 passed, 0 failed
**Check scripts**: 51/51 EXIT 0 (all pass — the FOREIGN-TRAILER issue from the prior round is resolved; commit 99968adc is now an ancestor of main)

---

## Verdict Rationale

FAIL. Multiple SHALL requirement scenarios lack correct implementation or test coverage.
The prior round's two FAIL check scripts (commit trailer mismatch, foreign-trailer branch
check) are now clean — commit 99968adc is confirmed as an ancestor of main, so the branch
has only 5 task-075 commits, all with correct trailers. However, fresh examination of the
spec reveals seven distinct implementation/coverage gaps across SHALL requirements.

---

## Requirement Status

### Extraction Layer

| Requirement | Status | Evidence |
|---|---|---|
| Scope Nesting Extraction | COVERED | discover_bounded_contexts(), discover_submodules(), parent refs; TestModuleDiscovery (9 tests) covers containment tree, AST-only cost. |
| Module Graph Extraction | COVERED | build_dependency_edges(), import count, cross_context/internal distinction; TestDependencyExtraction (9 tests). |
| Symbol Table Extraction | COVERED | extract_symbols(), public/private visibility, signatures; TestSymbolTableExtraction (5 tests). |
| Type Topology Extraction | COVERED | extract_type_topology(), inherits/has_a edges, AST-only; TestTypeTopologyExtraction (4 tests). |
| Call Graph Extraction | PARTIAL | extract_call_graph() emits direct_call (with weight) and dynamic_call, but the dynamic_call edge does NOT carry the parameter name or type hints as required by the "Indirect calls" scenario THEN-clause ("the call site carries the parameter name and any type hints"). Emitted edge: `{"source": src, "target": "dynamic", "type": "dynamic_call"}` — no param_name field. TestCallGraphExtraction.test_dynamic_call_edge_emitted() only checks the edge type, not the param payload. |
| Data Flow Spine Extraction | SPEC-DRIFT | Explicitly NOT IN SCOPE per prototype-scope.spec.md §Not In Scope. Not a FAIL. |
| Structural Significance Extraction | PARTIAL | Hub detection (COVERED), peripheral detection (COVERED), community detection (COVERED), betweenness centrality computed (COVERED). PARTIAL: (a) bridges are correctly flagged is_bridge=True AND is_landmark=True in code but there is no test that asserts bridge→is_landmark (only test_hub_is_marked_landmark exists); (b) entry points (in_degree=0, out_degree>1) are NOT flagged as landmarks — compute_structural_significance() sets is_landmark only for `is_hub or is_bridge`; no entry-point landmark path exists. |
| Ubiquitous Dependency Detection | COVERED | detect_ubiquitous_dependencies(), threshold, edge marking, node marking; TestUbiquitousDependencyDetection (5 tests). |

### Composition Layer

| Requirement | Status | Evidence |
|---|---|---|
| Container Primitive | PARTIAL | Nested containers: COVERED (test_containment_expressed_as_scene_tree_parenting). Module as container: COVERED for LOD. Container membrane permeability: MISSING — the spec requires the membrane's visual density to reflect the public/private symbol ratio (a continuous property); main.gd uses a fixed alpha of 0.18 for every bounded-context regardless of symbol counts. No implementation, no test. |
| Node Primitive | COVERED | Anchor volumes per node; test_node_renderer.gd covers node rendered at position, badge attachment. |
| Badge Primitive | PARTIAL | All 8 badge types are defined in BADGE_COLORS. Scenarios "Side-effect badge" and "Multiple badges" are COVERED. Badge vocabulary scenario: PARTIAL — stateful and deprecated badge types have no behavioral test (no test_badge_vocabulary_stateful or test_badge_vocabulary_deprecated). The test file header claims coverage of all 8 types but only 4 have explicit vocabulary tests (pure, io, async, test); error_handling covered via test_multiple_badges_all_rendered; entry_point via test_landmark_and_badges_compose; stateful and deprecated have zero behavioral coverage. |
| Edge Primitive | PARTIAL | Three scenarios, two PARTIAL, one MISSING: (1) Weighted edge — PARTIAL: spec says "visual thickness is proportional to the weight" and "a single-import Edge is visibly thinner than a 12-import Edge". Implementation uses color brightness (weight_scale applied to Color components) instead of line thickness. ImmediateMesh PRIMITIVE_LINES renders 1-pixel lines regardless of weight. No test verifies thickness varies with weight. (2) Edge type distinction — PARTIAL: spec says "edge type is encoded by line style (solid for calls, dashed for imports, dotted for inheritance)". Implementation uses color (orange for cross_context, grey for internal, gold for aggregate). No dashed or dotted lines. No test for line-style encoding. (3) Suppressed ubiquitous edges — MISSING: spec says "the Edge is NOT drawn" for edges to ubiquitous modules. main.gd._create_edge() does NOT check ed.get("ubiquitous", false) and draws every edge. No test verifies ubiquitous edges are suppressed. |
| Port Primitive | SPEC-DRIFT | LLM/moldable views — NOT IN SCOPE per prototype-scope.spec.md. |
| Route Primitive | SPEC-DRIFT | LLM/moldable views — NOT IN SCOPE per prototype-scope.spec.md. |
| Landmark Primitive | PARTIAL | Hub as landmark: COVERED (test_landmark_applies_scale_to_anchor, test_landmark_adds_ring_child, test_landmark_ring_uses_torus_mesh). Landmark sources scenario: PARTIAL — hubs are sourced (is_hub→is_landmark, tested); bridges are sourced in code (is_bridge→is_landmark) but have no test asserting is_landmark=True for a bridge-only node; entry points (no in-edges from application code, out_degree>1) are NOT sourced — compute_structural_significance() has no entry-point branch. The spec says "Landmarks are derived from: hubs (high in-degree), bridges (high betweenness centrality), entry points (no in-edges from application code)". Entry-point landmark is missing both implementation and test. |
| Tint Primitive | SPEC-DRIFT | LLM-driven categorical assignment — NOT IN SCOPE per prototype-scope.spec.md. |
| LOD Shell Primitive | COVERED | lod_manager.gd: FAR/MEDIUM/NEAR tiers; aggregate edges at FAR; test_spatial_structure.gd (8 tests including test_far_distance_shows_aggregate_edges, test_medium_distance_shows_modules, test_near_distance_shows_internal_edges_as_fine_detail). LLM tier-selection and mixed-tier scenarios are SPEC-DRIFT. |
| Power Rail Notation | PARTIAL | Standard library power rail scenario: PARTIAL — nodes with has_ubiquitous_dep get a PowerRailDisc (COVERED by 5 tests in test_visual_primitives.gd), but "no edges to `logging` are drawn" is NOT implemented: main.gd._create_edge() draws all edges unconditionally, ignoring the ubiquitous flag. Power rail toggle scenario: MISSING — no keyboard binding, no toggle logic, no test. Multiple power rails scenario: COVERED (test_multiple_nodes_consistent_rail_position verifies Y-position consistency). |

### Composition Principles

| Requirement | Status | Evidence |
|---|---|---|
| Overlay/Facet Composition | SPEC-DRIFT | LLM-driven, NOT IN SCOPE. |
| Distortion Legend | SPEC-DRIFT | LLM-driven, NOT IN SCOPE. |
| Purpose-Level Annotation | SPEC-DRIFT | LLM-driven, NOT IN SCOPE. |

### Primitive Interactions

| Requirement | Status | Evidence |
|---|---|---|
| Primitives Compose, Not Interfere | COVERED | test_landmark_and_badges_compose, test_all_three_primitives_compose verify independent coexistence of Badge+Landmark+Power Rail. |
| Primitive Set is Closed | COVERED | Fixed vocabulary in BADGE_COLORS; no runtime primitive invention path exists. |

---

## Blocking Issues (required for PASS)

### FAIL-1 — Edge Primitive: Weighted edge uses wrong perceptual channel
**Spec**: "its visual thickness is proportional to the weight (12)" and "a single-import Edge is visibly thinner than a 12-import Edge"
**Code**: `main.gd:294` — `weight_scale = clampf(float(agg_weight) / 10.0, 0.4, 1.0)` applied to Color channels only. ImmediateMesh PRIMITIVE_LINES ignores thickness.
**Fix needed**: Use a mesh that supports thickness (e.g., tube/quad mesh per edge, or `RenderingServer.canvas_item_add_line` with width) scaled proportionally to weight. Add a test that asserts a weight-12 edge visual is detectably wider than a weight-1 edge.

### FAIL-2 — Edge Primitive: Edge type encoded by color, not line style
**Spec**: "edge type is encoded by line style (solid for calls, dashed for imports, dotted for inheritance)"
**Code**: `main.gd:301-303` — colors used (orange, grey, gold) instead of line styles. No dashed/dotted rendering.
**Fix needed**: Encode edge type via line style. Add tests that assert direct_call edges use one style and inherits edges use another (e.g., via a `line_style` property or separate geometry pattern).

### FAIL-3 — Edge Primitive: Ubiquitous edges are drawn (not suppressed)
**Spec**: "the Edge is NOT drawn" for edges to ubiquitous modules
**Code**: `main.gd._create_edge()` — no check for `ed.get("ubiquitous", false)`. All edges are drawn.
**Fix needed**: In `_create_edge()`, return early (skip rendering) when `ed.get("ubiquitous", false) == true`. Add a test: build a graph with a node marked `has_ubiquitous_dep=true` and an edge with `ubiquitous=true`; assert no ImmediateMesh child corresponds to that edge.

### FAIL-4 — Power Rail Notation: Ubiquitous edges not suppressed (same root as FAIL-3)
**Spec**: "no edges to `logging` are drawn" in standard library power rail scenario.
**Code**: Same as FAIL-3. Fix FAIL-3 to resolve this.

### FAIL-5 — Power Rail Notation: Power rail toggle not implemented
**Spec**: "WHEN the human toggles power rails to visible THEN all suppressed ubiquitous edges fade in AND the toggle is reversible"
**Code**: No keyboard binding or toggle in main.gd. No test.
**Fix needed**: Add a toggle action (e.g., T key or UI button) that flips ubiquitous edge visibility and animates the transition. Add a test asserting that after toggling, previously-suppressed edges become visible, and toggling again hides them.

### FAIL-6 — Container Primitive: Membrane permeability not implemented
**Spec**: "the membrane appears thick/opaque (strong encapsulation — few openings relative to interior)" with "permeability is a continuous visual property, not a binary toggle"
**Code**: `main.gd:207` — fixed `Color(0.25, 0.45, 0.85, 0.18)` for all bounded contexts. The alpha never varies with public/private symbol ratio.
**Fix needed**: In `_create_volume()`, read `nd.get("symbols", [])` (populated by extract_symbols) to compute public/private ratio, then map it to alpha: e.g., `alpha = clampf(public_count / max(total_count, 1), 0.05, 0.40)` so modules with few public symbols are more opaque. Add a test with two containers of different ratios and assert their alpha values differ.

### FAIL-7 — Landmark Primitive: Entry-point nodes not flagged as landmarks
**Spec**: "Landmarks are derived from: hubs (high in-degree), bridges (high betweenness centrality), entry points (no in-edges from application code)"
**Code**: `extractor.py:1483` — `if is_hub or is_bridge: node["is_landmark"] = True`. No entry-point branch. A node with in_degree=0 and out_degree>1 is peripheral (not a hub), so it never gets is_landmark=True.
**Fix needed**: In `compute_structural_significance()`, add: `is_entry_point = (ind == 0 and outd > 1); if is_hub or is_bridge or is_entry_point: node["is_landmark"] = True`. Add a test that constructs a node with in_degree=0 and out_degree=2 and asserts is_landmark=True.

---

## Non-blocking Partial Issues (should be addressed but do not drive FAIL)

### PARTIAL-A — Call Graph: dynamic_call edge missing parameter name
**Spec**: "the call site carries the parameter name and any type hints"
**Code**: `extractor.py:1268` — `edges.append({"source": src, "target": "dynamic", "type": "dynamic_call"})` — no param_name field.
**Fix**: Add `"param_name": callee_name` to the dynamic_call edge dict. Update TestCallGraphExtraction to assert `edge["param_name"]` is present and non-empty.

### PARTIAL-B — Landmark Primitive: bridge→is_landmark not tested
**Spec**: "bridges (high betweenness centrality)" as landmark source
**Code**: `extractor.py:1483` — correctly sets is_landmark for bridges, but only `test_hub_is_marked_landmark` exists; no parallel test for bridge→is_landmark.
**Fix**: Add `test_bridge_is_marked_landmark` in TestStructuralSignificanceExtraction using the existing bridge fixture (A→bridge→B), asserting `bridge.get("is_landmark") is True`.

### PARTIAL-C — Badge vocabulary: stateful and deprecated not tested
**Spec**: "the system supports at minimum: pure, io, async, stateful, error_handling, test, entry_point, deprecated"
**Code**: BADGE_COLORS has all 8 types, but no `test_badge_vocabulary_stateful` or `test_badge_vocabulary_deprecated` GDScript test functions.
**Fix**: Add `test_badge_vocabulary_stateful()` and `test_badge_vocabulary_deprecated()` to test_visual_primitives.gd following the pattern of the existing vocabulary tests.