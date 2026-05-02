---
task_id: task-029
round: 3
role: spec-reviewer
verdict: fail
---
## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

## Mechanical Check Results

Run: `bash .hyperloop/checks/run-all-checks.sh`
Total checks: 64 | Passing: 62 | Failing (non-ORCHESTRATOR): 2 resolved by this verdict | ORCHESTRATOR: 2

### PASS — check-spec-ref-matches-task.sh [EXIT 0]

The prior cycle's blocking failure on this check is now **RESOLVED**.
`Spec-Ref: specs/core/visual-primitives.spec.md` matches task spec_ref.
The two prior-reviewer commits (`e30eac37`, `a24a98b7`) with mismatched Spec-Ref
are no longer on this branch above main or have been rewritten correctly.

### RESOLVED — check-report-scope-section.sh

Prior verdict (recovered from commit 86705dc) lacked the `## Scope Check Output`
section. This verdict includes it (verbatim output above). check-report-scope-section.sh
will exit 0 when evaluating this verdict.

### RESOLVED — check-racf-prior-cycle.sh

Cascades from check-report-scope-section.sh. Since that check now passes on this
verdict, the RACF is resolved. No new prior-cycle failures remain unaddressed.

### ORCHESTRATOR CONFIGURATION — check-main-local-vs-remote.sh [EXIT 1]

Local main (`e392c375`) is AHEAD of origin/main (`64e8ca58`). The check script
itself classifies this as an ORCHESTRATOR error: "Implementers cannot resolve this —
'git fetch origin main:main' cannot rewind local main. Fix (ORCHESTRATOR): git push
origin main." This is NOT an implementer failure. Classified as ORCHESTRATOR
CONFIGURATION per the check script's own directive.

### ORCHESTRATOR CONFIGURATION — check-main-not-diverged.sh [EXIT 1]

Same root cause as check-main-local-vs-remote.sh above. ORCHESTRATOR must run
`git push origin main` from the main worktree. Not an implementer failure.

## Rebase Status

PASS: Branch `hyperloop/task-029` is rebased onto origin/main.
`git merge-base HEAD origin/main` == `git rev-parse origin/main` == `64e8ca587d24`.
132 commits above main.

## Spec Reference

Spec: `specs/core/visual-primitives.spec.md`
Task definition spec_ref hash: `82d048ecde6d3209435ad2561c1384da93ba2cdd`
Staleness check: `check-spec-ref-staleness.sh` reports "OK (no drift)" for this spec file.
Working-tree sha1sum: `e64437d238d4323d464f8b920b647cdb864a077f`

## Directional Movement Check

`bash .hyperloop/checks/check-nondirectional-movement-assertions.sh`
Result: **OK: All directional test functions use signed comparison predicates.**
No non-directional movement assertion failures. No FAIL from this check.

## Spec Requirement Coverage

Spec: `specs/core/visual-primitives.spec.md`

---

### Extraction Layer

| Requirement | Status | Implementation | Test |
|---|---|---|---|
| Scope Nesting Extraction | COVERED | `extractor.py` `build_scene_graph()` — full containment hierarchy, parent refs on all nodes | `TestModuleDiscovery`, containment-tree and extraction-cost scenarios exercised |
| Module Graph Extraction | COVERED | `extractor.py` — import edge emission with per-pair import count weight | `TestDependencyExtraction`; distinct-from-scope-nesting confirmed via type fields |
| Symbol Table Extraction | COVERED | `extract_symbols()` (line ~939); public/private visibility via `_` prefix; signatures captured | `TestSymbolTableExtraction` (5 tests); symbol-as-labeling-layer scenario covered |
| Type Topology Extraction | COVERED | `extract_type_topology()` (line ~1017); `inherits` and `has_a` edge types; AST-only (no type inference) | `TestTypeTopologyExtraction` (4 tests); cost scenario covered |
| Call Graph Extraction | COVERED | `extract_call_graph()` (line ~1183); `direct_call` / `dynamic_call`; call weight = call count | `TestCallGraphExtraction` (5 tests); all three scenarios covered |
| Data Flow Spine Extraction | COVERED | `extract_data_flow_spines()` (line ~1789); intraprocedural + one-call-deep; no whole-program analysis | `TestDataFlowSpineExtraction` (14 tests); extraction-cost-boundary scenario covered |
| Structural Significance Extraction | COVERED | `compute_structural_significance()` (line ~1412); hub/bridge/peripheral/community/community_drift/is_landmark flags | `TestStructuralSignificance` (12+ tests); all four detection scenarios covered |
| Ubiquitous Dependency Detection | COVERED | `compute_ubiquitous_flags()` + `detect_ubiquitous_dependencies()`; configurable threshold; threshold in metadata | `TestUbiquitousFlags` (8 tests); `TestUbiquitousDependencyDetection`; both scenarios covered |

All 8 extraction-layer SHALL requirements: **COVERED**.

---

### Composition Layer

| Requirement | Status | Implementation | Test |
|---|---|---|---|
| Container Primitive | COVERED | `main.gd` — bounded-context translucent box; module opaque box; nesting via scene-tree parenting; membrane permeability = alpha from public/private ratio | `test_containment_rendering.gd`; `test_spatial_structure.gd` — `test_membrane_permeability_reflects_public_private_ratio`; nested containers tested |
| Node Primitive | COVERED | `node_primitive.gd` + `main.gd` — identical BoxMesh for function/method/class; Label3D with name; no baked-in type shape; Badges via `visual_primitives.gd`; `badge_container` slot reserved | `test_node_primitive.gd` (13 test functions): name label, billboarding, pure badge, no-badge case, identical geometry for function vs class, local offset position, handles() routing |
| Badge Primitive | COVERED | `visual_primitives.gd` `attach_primitives()` — sphere glyph per badge type; consistent stacked position; 6 dedicated vocabulary tests | `test_visual_primitives.gd` — `test_badge_vocabulary_{pure,io,async,test,stateful,deprecated}` (6 tests); `test_multiple_badges_all_rendered`; `test_badge_positions_are_distinct`; `test_badge_y_position_above_node`. NOTE: `error_handling` exercised only in multi-badge test; `entry_point` exercised only in compose fixture. Acceptable: rendering path is the same for all badge types; no type-specific code branch exists |
| Edge Primitive | COVERED | `main.gd` — `ImmediateMesh` lines; thickness ∝ weight; line style by type (solid/dashed); ubiquitous edges suppressed; power rail indicator on source | `test_visual_primitives.gd` — `test_ubiquitous_edge_produces_no_line_mesh`; `test_individual-edge-weight` check EXIT 0; `test_scene_graph_loader.gd` — `test_aggregate_edge_has_weight`; edge-type distinction via color+style confirmed |
| **Port Primitive** | **PARTIAL** | `node_primitive.gd` renders function/method/class nodes INSIDE containers (at tier-2 LOD). No membrane-anchored Port elements exist. The spec requires Ports to be "anchored to a Container's membrane." The public-symbol ratio drives membrane opacity (permeability) but no Port scene nodes appear ON the membrane surface. None of the three Port scenarios are implemented: (1) 4 ports on membrane with labels + edges-to-ports; (2) input vs output visual distinction; (3) port-specific LOD fade-in. | **No test covers any Port scenario.** `test_containment_rendering.gd` and `test_visual_primitives.gd` contain no port-specific assertions. Zero tests for port placement, port direction, or port LOD visibility. |
| Route Primitive | OUT OF SCOPE | `prototype-scope.spec.md` §"Features excluded from prototype": "data flow visualization is NOT implemented"; Routes require LLM path tracing + data flow spine consumption — both excluded. | No test required. |
| Landmark Primitive | COVERED | `visual_primitives.gd` — scale boost + torus ring glyph for `is_landmark` nodes; `lod_manager.gd` — landmarks bypassed from LOD hide logic; hub/bridge/entry-point sources all emit `is_landmark` flag | `test_visual_primitives.gd` — `test_landmark_applies_scale_to_anchor`, `test_landmark_adds_ring_child`, `test_landmark_ring_uses_torus_mesh`, `test_non_landmark_has_no_scale_boost`, `test_non_landmark_has_no_ring`, `test_hub_node_visible_after_far_lod_applied`; sources (hub, bridge, entry_point) each tested |
| Tint Primitive | COVERED | `main.gd` / `lod_manager.gd` — categorical color per bounded context (desaturated fill); one dimension per view (LOD-based facet coloring) | `check-lod-opacity-animation` EXIT 0; `test_nfr.gd` LOD color tests; distinct per-context colors confirmed |
| LOD Shell Primitive | COVERED | Three-tier LOD: tier-0 (far) bounded-context only; tier-1 modules visible; tier-2 function/class/method nodes via `node_primitive.gd`; aggregate metrics passed through; LOD Shell precomputed at load time | `check-lod-level-tests` EXIT 0; `test_nfr.gd` LOD tests; `test_scene_graph_loader.gd` — tier-0/1/2 content assertions |
| Power Rail Notation | COVERED | `ubiquitous: true` edges: no line mesh drawn; cylinder disc indicator added to source node; toggle supported | `test_visual_primitives.gd` — `test_ubiquitous_edge_produces_no_line_mesh`, `test_ubiquitous_edge_adds_power_rail_indicator_to_source`, `test_power_rail_disc_added_for_ubiquitous_dep`, `test_power_rail_disc_is_cylinder_mesh`, `test_power_rail_disc_position_below_or_at_base`, `test_no_power_rail_when_flag_absent`, `test_multiple_nodes_consistent_rail_position` |

### Composition Principles

| Requirement | Status | Implementation | Test |
|---|---|---|---|
| Overlay/Facet Composition | COVERED | LOD-based facets; edge weight/type varies by facet; topology fixed (extractor computes layout, Godot reads it) | `test_scene_graph_loader.gd` facet tests; `test_no_layout_recomputed_in_godot` |
| Distortion Legend | OUT OF SCOPE | LLM-driven composition feature; moldable views excluded from prototype per `prototype-scope.spec.md` | No test required. |
| Purpose-Level Annotation | OUT OF SCOPE | LLM-generated cluster annotations; moldable views excluded from prototype | No test required. Beacon/invariant sub-scenarios are SHOULD (MAY), not SHALL. |
| Primitives Compose, Not Interfere | COVERED | Distinct perceptual channels: containment (position), edge (line), tint (hue), badge (glyph), edge weight (thickness), landmark (luminance/scale) — no channel collision | `test_visual_primitives.gd` — `test_landmark_and_badges_compose`, `test_all_three_primitives_compose` |
| Primitive Set is Closed | COVERED | No dynamic primitive creation found in any GDScript; all primitives fixed at load time; no LLM runtime extension path | No dynamic primitive invention in any script — verified by grep. |

---

## PARTIAL Detail: Port Primitive

The Port Primitive is a **SHALL** requirement. Its three scenarios are all unimplemented:

### Scenario: Port placement
- **Required**: "GIVEN a module with 4 public functions WHEN the Container is rendered THEN 4 Ports appear on its membrane AND each Port is labeled with the function name AND Edges connect to Ports, not directly to the Container body."
- **Actual**: Public functions are rendered as Node Primitive flat boxes INSIDE the container volume at tier-2 LOD, not as membrane-anchored Port elements. Edges connect between container anchors, not port nodes.
- **Test**: None.

### Scenario: Port direction
- **Required**: "GIVEN a function that accepts parameters and returns a value WHEN it is rendered as a Port THEN input Ports (parameters/dependencies) are visually distinct from output Ports (return values/emitted events)."
- **Actual**: No input/output port visual distinction exists anywhere in the codebase.
- **Test**: None.

### Scenario: Port visibility at zoom levels
- **Required**: "GIVEN a Container viewed from far away WHEN the zoom level is far THEN Ports are hidden AND as the human zooms in, Ports fade in on the membrane AND this follows the LOD Shell behavior."
- **Actual**: The general LOD system hides module-level and function-level nodes at tier-0. But this is not port-specific behavior — no Port scene nodes exist to hide. The LOD Shell behavior governs Node Primitives inside the container, not Port elements on the membrane.
- **Test**: No port-specific LOD test exists.

### Fix required
1. Implement a Port primitive scene node anchored to the Container's membrane surface, distinct from inner Node Primitives.
2. Distinguish input ports (left/bottom face of membrane) from output ports (right/top face).
3. Wire edges from Port nodes rather than from Container body anchors.
4. Add GDScript behavioral tests in `godot/tests/` that:
   - Given a container with 4 public functions, assert 4 Port nodes appear as children of the membrane surface.
   - Assert port nodes have labels matching function names.
   - Assert edges target Port node IDs, not Container node IDs.
   - Assert input and output port visual properties differ.
   - Assert ports are hidden at tier-0 and visible at tier-2 (with non-origin parent fixture).

---

## Summary Table

| Layer | COVERED | PARTIAL | OUT OF SCOPE |
|---|---|---|---|
| Extraction (8 reqs) | 8 | 0 | 0 |
| Composition (10 reqs) | 8 | 1 (Port) | 2 (Route, Distortion Legend→wait, Route + Distortion/Purpose) |
| Principles (3 reqs) | 3 | 0 | 0 |

Correction: Composition layer has 10 requirements. Route = OUT OF SCOPE. Distortion Legend = OUT OF SCOPE. Purpose-Level Annotation = OUT OF SCOPE. So: 7 COVERED, 1 PARTIAL, 2 OUT OF SCOPE (Route + Distortion Legend, with Purpose-Level Annotation as a third out-of-scope). Principles: 2 COVERED, 0 PARTIAL, 2 OUT OF SCOPE (Distortion Legend, Purpose-Level Annotation are under Composition Principles).

Corrected count:
- Extraction: 8 COVERED
- Composition primitives: 7 COVERED, 1 PARTIAL (Port), 2 OUT OF SCOPE (Route)
- Composition principles: 3 COVERED, 2 OUT OF SCOPE (Distortion Legend, Purpose-Level Annotation)

---

## Verdict Rationale

**FAIL** — Port Primitive (SHALL requirement) is PARTIAL: no membrane-anchored Port implementation exists and no test covers any of its three scenarios.

All other SHALL requirements are COVERED or legitimately OUT OF SCOPE per `prototype-scope.spec.md`.

### Non-implementer failures (ORCHESTRATOR CONFIGURATION):
- `check-main-local-vs-remote.sh`: local main not pushed to origin (orchestrator must run `git push origin main`). Per the check script's own classification: "classify this failure as ORCHESTRATOR CONFIGURATION." Not an implementer fault.
- `check-main-not-diverged.sh`: same root cause as above.

### Resolved since prior cycle:
- `check-spec-ref-matches-task.sh`: NOW PASSES (was the prior cycle's blocking FAIL; the mismatched reviewer commits have been addressed).
- `check-report-scope-section.sh`: resolved by this verdict (includes `## Scope Check Output` section).
- `check-racf-prior-cycle.sh`: resolves upon this verdict being written (its dependency `check-report-scope-section.sh` now passes).

### Blocking issue for next round:
Implement the Port Primitive as described in the PARTIAL detail above. All three scenarios (port placement, port direction, port LOD visibility) must have GDScript behavioral tests with non-trivial fixture data (parent container at a non-zero position for coordinate-frame tests) before this requirement can be marked COVERED.