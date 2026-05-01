---
task_id: task-075
round: 3
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — hyperloop/task-075
## Spec: specs/core/visual-primitives.spec.md
## Date: 2026-05-01

---

## Blocking Issue

**REBASE-FAIL**: `check-rebased-onto-main.sh` exits 1.

Branch fork point is `db76c82`; `origin/main` HEAD is `d3360db`.
Three commits on main are absent from this branch:

- `d3360db5` feat(schema): add depth field validation to validate_scene_graph (#217)
- `751ab608` feat(prototype): godot — node volume rendering (boxes at schema positions) (#220)
- `b37b6863` feat(core): schema — structural significance fields on nodes (#218)

Merging as-is would REVERT all three commits from main. This is the sole blocker.

Additionally, the implementer's check run concealed this failure: two check scripts
present on main (`check-rebased-onto-main.sh`, `check-run-tests-suite-count.sh`) were
missing from the branch at submission time, making the rebase failure invisible to their
run-all-checks.sh pass claim.

**Fix:** `git fetch origin main:main && git rebase origin/main`, resolve any conflicts by
keeping main's additions, re-run test suites and `run-all-checks.sh`, then resubmit.

---

## Requirement Status

| Requirement                                    | Status  | Notes                                                              |
|------------------------------------------------|---------|--------------------------------------------------------------------|
| Scope Nesting Extraction                       | COVERED | extractor, schema, pytest tests                                    |
| Scope Nesting — Containment tree scenario      | COVERED | test_scope_nesting_* in test_extractor.py                          |
| Scope Nesting — Extraction cost scenario       | COVERED | single-file AST parsing confirmed; no cross-file resolution        |
| Module Graph Extraction                        | COVERED | extract_imports(), import edges, tests                             |
| Module Graph — Import-based edges scenario     | COVERED | edges with import_count field, tests                               |
| Module Graph — Distinction from scope nesting  | COVERED | separate edge types in schema                                      |
| Symbol Table Extraction                        | COVERED | extract_symbols(), SymbolInfo TypedDict, tests                     |
| Symbol Table — Public vs. private symbols      | COVERED | visibility field, _ prefix detection, tests                        |
| Symbol Table — Symbol as labeling layer        | COVERED | symbol names/signatures carried on nodes                           |
| Type Topology Extraction                       | COVERED | extract_type_topology(), inherits/has_a edges, tests               |
| Type Topology — Inheritance chain scenario     | COVERED | inherits edge type emitted, tests                                  |
| Type Topology — Composition relationship       | COVERED | has_a edge type emitted, tests                                     |
| Type Topology — Extraction cost scenario       | COVERED | AST-only, no type inference                                        |
| Call Graph Extraction                          | COVERED | extract_call_graph(), direct_call/dynamic_call edges, tests        |
| Call Graph — Direct calls scenario             | COVERED | direct_call edges emitted, tests                                   |
| Call Graph — Indirect calls + param_name       | COVERED | dynamic_call edges carry param_name field (FAIL-7 fixed)           |
| Call Graph — Call frequency annotation         | COVERED | edge weight field, tests                                           |
| Data Flow Spine Extraction                     | MISSING | Explicitly NOT in prototype scope per specs/prototype/prototype-scope.spec.md — not a FAIL |
| Structural Significance — Hub detection        | COVERED | compute_structural_significance(), in_degree annotation, tests     |
| Structural Significance — Bridge detection     | COVERED | betweenness centrality, is_bridge flag, test_bridge_is_marked_landmark |
| Structural Significance — Peripheral detection | COVERED | peripheral flag for in_degree==0 and out_degree==1                 |
| Structural Significance — Community detection  | COVERED | compute_clusters(), community_drift flag, tests                    |
| Ubiquitous Dependency Detection                | COVERED | detect_ubiquitous_dependencies(), ubiquitous flag, threshold metadata, tests |
| Ubiquitous — Standard library suppression      | COVERED | ubiquitous: true on edges, suppressed by default                   |
| Ubiquitous — Threshold scenario                | COVERED | configurable threshold recorded in metadata                        |
| Container Primitive                            | COVERED | membrane alpha from public_ratio, tests                            |
| Container — Module as container scenario       | COVERED | public ports on membrane, private symbols interior                 |
| Container — Nested containers scenario         | COVERED | nesting depth in schema, Godot rendering                           |
| Container — Membrane permeability scenario     | COVERED | alpha = clampf(1.0 - public_ratio, 0.05, 0.55), tests (FAIL-5 fixed) |
| Node Primitive                                 | COVERED | visual_primitives.gd, badge attachment, tests                      |
| Node — Function node scenario                  | COVERED | pure badge, no special shape                                       |
| Node — Node without badges scenario            | COVERED | plain node renders without badges                                  |
| Badge Primitive                                | COVERED | 8 badge types implemented: pure, io, async, stateful, error_handling, test, entry_point, deprecated |
| Badge — Side-effect badge scenario             | COVERED | io badge, consistent top-right positioning                         |
| Badge — Multiple badges scenario               | COVERED | badge arrangement tested                                           |
| Badge — Badge vocabulary scenario              | COVERED | all 8 required types present; test_badge_vocabulary_stateful and test_badge_vocabulary_deprecated added (PARTIAL-C fixed) |
| Edge Primitive                                 | COVERED | CylinderMesh radius proportional to weight, line_style meta        |
| Edge — Weighted edge scenario                  | COVERED | radius scales with weight, test_edge_thickness_proportional_to_weight (FAIL-1 fixed) |
| Edge — Edge type distinction scenario          | COVERED | solid/dashed/dotted by edge type, 3 line style tests (FAIL-2 fixed)|
| Edge — Suppressed ubiquitous edges scenario    | COVERED | is_ubiquitous check, visible=false, _ubiquitous_edge_visuals (FAIL-3 fixed) |
| Port Primitive                                 | COVERED | ports on membrane for public functions                             |
| Port — Port placement scenario                 | COVERED | ports labeled, edges connect to ports                              |
| Port — Port direction scenario                 | COVERED | input/output port distinction                                      |
| Port — Port visibility at zoom levels          | COVERED | LOD Shell integration, ports hidden at FAR tier                    |
| Route Primitive                                | COVERED | Route composition primitives in schema                             |
| Route — Request path scenario                  | COVERED | highlighted labeled path, non-route de-emphasis                    |
| Route — Route classification scenario          | COVERED | distinct visual treatment per route type, ≤4 simultaneous routes  |
| Route — Route direction scenario               | COVERED | directional flow indicators, entry/terminus landmarks              |
| Landmark Primitive                             | COVERED | TorusMesh ring, persists across LOD levels                         |
| Landmark — Hub as landmark scenario            | COVERED | highest in_degree → is_landmark=True, visible at all LOD tiers     |
| Landmark — Entry point as landmark scenario    | COVERED | is_entry_point (in_degree==0, out_degree>1) → is_landmark=True (FAIL-6 fixed) |
| Landmark — Bridge as landmark scenario         | COVERED | high betweenness → is_landmark=True, test_bridge_is_marked_landmark (PARTIAL-B fixed) |
| Landmark — Landmark sources scenario           | COVERED | hubs, bridges, entry points, human-designated; LLM MAY add        |
| Tint Primitive                                 | COVERED | categorical fill color, 4-6 color palette                          |
| Tint — Domain tinting scenario                 | COVERED | desaturated fills, palette limit                                   |
| Tint — One tint dimension per view scenario    | COVERED | single tint channel, legend always visible when active             |
| Tint — Tint is the only symbolic primitive     | COVERED | legend requirement enforced                                        |
| LOD Shell Primitive                            | COVERED | lod_manager.gd, three-tier LOD, tests                              |
| LOD Shell — Three-tier LOD scenario            | COVERED | Near/Medium/Far tiers tested in test_spatial_structure.gd          |
| LOD Shell — LLM tier selection scenario        | COVERED | tier selection logic in lod_manager.gd                             |
| LOD Shell — Mixed tiers scenario               | COVERED | per-region tier selection                                          |
| LOD Shell — Opacity animation                  | COVERED | Tween/modulate.a in _transition_visible() (check-lod-opacity-animation passed) |
| Power Rail Notation                            | COVERED | _ubiquitous_edge_visuals, KEY_T toggle (FAIL-3, FAIL-4 fixed)      |
| Power Rail — Standard library scenario         | COVERED | edges hidden, rail indicator on node                               |
| Power Rail — Toggle scenario                   | COVERED | toggle_ubiquitous_edges() with Tween fade, KEY_T (FAIL-4 fixed)    |
| Power Rail — Multiple power rails scenario     | COVERED | consistent glyph/position across all ubiquitous deps               |
| Overlay/Facet Composition                      | COVERED | facet switching in schema and composition layer                    |
| Overlay — Switching views scenario             | COVERED | edge weights, tints, landmarks reassigned without topology change  |
| Overlay — Ownership view scenario              | COVERED | tint reassignment, ownership grouping                              |
| Overlay — Facet as LLM's primary act          | COVERED | LLM selects edges/tints/landmarks/routes/LOD; no spatial rearrange |
| Distortion Legend                              | COVERED | legend renders tint encoding, edge weight, suppressed count        |
| Distortion Legend — Legend contents scenario   | COVERED | legend updates on facet change                                     |
| Distortion Legend — What's hidden scenario     | COVERED | "showing X of Y modules" indicator present                         |
| Purpose-Level Annotation                       | COVERED | annotation field in schema, purpose text on containers             |
| Purpose — LLM-generated annotation scenario    | COVERED | purpose_annotation field, distinct from module names               |
| Purpose — Beacon recognition scenario (SHOULD) | COVERED | beacon_pattern field on nodes                                      |
| Purpose — Invariant annotation (SHOULD)        | COVERED | invariant_annotation field on aggregates                           |
| Primitives Compose, Not Interfere              | COVERED | distinct perceptual channels per primitive                         |
| Channel allocation scenario                    | COVERED | spatial/line/hue/glyph/size/luminance channels mapped correctly    |
| Maximum simultaneous primitives scenario       | COVERED | all six readable simultaneously per channel separation             |
| Primitive Set is Closed                        | COVERED | LLM cannot invent new primitives at runtime; fallback prose path   |
| Novel question scenario                        | COVERED | explicit "cannot compose" response path documented                 |
| Branch rebased onto origin/main                | MISSING | check-rebased-onto-main.sh exits 1 — BLOCKING                     |

---

## Summary

Implementation quality is high. All 7 prior FAIL items and 3 PARTIAL items from the
previous review cycle have been fully addressed:

- FAIL-1 (edge thickness): CylinderMesh radius scales with weight ✓
- FAIL-2 (edge line style): solid/dashed/dotted by edge type ✓
- FAIL-3 (ubiquitous suppression): edges hidden by default ✓
- FAIL-4 (power rail toggle): KEY_T toggles with Tween ✓
- FAIL-5 (membrane permeability): alpha from public_ratio ✓
- FAIL-6 (entry-point landmark): in_degree==0 → is_landmark ✓
- FAIL-7 (dynamic call param_name): edge carries param_name ✓
- PARTIAL-A: subsumed by FAIL-7 ✓
- PARTIAL-B (bridge landmark test): test_bridge_is_marked_landmark added ✓
- PARTIAL-C (badge vocabulary): stateful + deprecated tests added ✓

194 Python tests pass. 188 GDScript tests pass. No spec drift. No conflict markers.
No out-of-scope features. All mandatory checks pass except one.

**Sole blocking issue:** Branch is not rebased onto origin/main. Three main commits
(structural significance schema fields, node volume rendering, depth field validation)
are absent. check-rebased-onto-main.sh exits 1.

**Required fix:** Rebase onto origin/main, keep all incoming changes from main, re-run
test suites and run-all-checks.sh, then resubmit.