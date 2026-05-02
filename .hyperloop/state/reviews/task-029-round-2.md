---
task_id: task-029
round: 2
role: spec-reviewer
verdict: fail
---
## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

## Rebase Status

PASS: Branch 'hyperloop/task-029' IS rebased onto origin/main (0d32239).
The rebase failure reported in the prior Findings section has been resolved.
`git merge-base HEAD origin/main` == `git rev-parse origin/main` == `0d32239762f9...`.

## Mechanical Check Results

Run: `bash .hyperloop/checks/run-all-checks.sh`
Total checks: 64 | Passing: 61 | Failing: 3

### FAIL — check-spec-ref-matches-task.sh [EXIT 1]

Six unique Spec-Ref paths found in commits above `main` do not match the task
definition spec path (`specs/core/visual-primitives.spec.md`):

| Spec-Ref path found | Source commits | Task-Ref in those commits |
|---|---|---|
| `specs/core/system-purpose.spec.md` | e30eac37, a24a98b7 | task-029 |
| `specs/extraction/code-extraction.spec.md` | 1bdba528, 890008c1 | task-006, task-004 |
| `specs/interaction/moldable-views.spec.md` | 131eb336 | task-019 |
| `specs/prototype/godot-application.spec.md` | 94c67d5d | task-010 |
| `specs/prototype/prototype-scope.spec.md` | 3d802d8a | task-008 |
| `specs/visualization/data-flow.spec.md` | 865efd9d | task-016 |

**Root causes:**

1. **Prior reviewer commits with wrong spec** (directly fixable): commits `e30eac37`
   and `a24a98b7` carry `Task-Ref: task-029` but `Spec-Ref: specs/core/system-purpose.spec.md`.
   These are prior review-cycle writer commits from earlier orchestrator rounds. They
   reference the wrong spec. The correct spec for task-029 is
   `specs/core/visual-primitives.spec.md`. These two commits must be rewritten with the
   correct Spec-Ref trailer, or the Spec-Ref trailer must be dropped from reviewer commits.

2. **Historical feature commits from prior tasks** (systemic): commits from task-004,
   task-006, task-008, task-010, task-016, and task-019 are above `main` on this
   long-running branch. Each legitimately references its own task's spec. The check script
   (`check-spec-ref-matches-task.sh`) excludes only `Task-Ref: process-improvement` and
   `Task-Ref: intake` commits; it does not exclude commits from sibling tasks. This is a
   check design assumption (single-task branches) that breaks on this accumulated branch.

**Prescribe fix (implementer action required):**

  Option A — Rewrite the two Task-Ref: task-029 reviewer commits:
  ```
  # Interactively amend e30eac37 and a24a98b7 to carry:
  # Spec-Ref: specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959
  ```
  This resolves the most egregious mismatch but NOT the historical task commits.

  Option B — Ask the orchestrator to update check-spec-ref-matches-task.sh to
  filter by `Task-Ref: <current-task>` (excluding sibling-task commits).

  Until one of these is applied, this check will exit non-zero.

### FAIL — check-racf-prior-cycle.sh [EXIT 1]

Cascades from `check-report-scope-section.sh`, which was FAILING in the prior cycle
(recovered from commit 9b6085e). This verdict now includes the required
`## Scope Check Output` section, which RESOLVES check-report-scope-section.sh.
Once this verdict is committed, check-racf-prior-cycle.sh will evaluate the
now-passing check-report-scope-section.sh and should exit 0 on the next run.

### FAIL — check-report-scope-section.sh [EXIT 1]

Prior worker-result.yaml (recovered from commit 9e6f873) lacked the required
`## Scope Check Output` section. RESOLVED in this verdict — the section is
included at the top with verbatim output of check-not-in-scope.sh.

## Spec Requirement Coverage

Spec: `specs/core/visual-primitives.spec.md @ 67df14bc9137e80de5a60d12dad7f77c7d995959`
Spec-drift check: PASS (no drift — spec file is identical at pinned hash and HEAD).

### Extraction Layer

| Requirement | Status | Implementation | Test |
|---|---|---|---|
| Scope Nesting Extraction | COVERED | `extractor.py`: build_scene_graph() containment hierarchy; parent refs on all nodes | `TestModuleDiscovery` in test_extractor.py |
| Module Graph Extraction | COVERED | `extractor.py`: import edge emission with import-count weight | `TestDependencyExtraction` (263 total pytest pass) |
| Symbol Table Extraction | COVERED | `extract_symbols()` in extractor.py (line 939); public/private visibility, signatures | `TestSymbolTableExtraction` (5 tests) |
| Type Topology Extraction | COVERED | `extract_type_topology()` (line 1017); `inherits` and `has_a` edges | `TestTypeTopologyExtraction` (4 tests) |
| Call Graph Extraction | COVERED | `extract_call_graph()` (line 1183); direct_call and dynamic_call; weight=call count | `TestCallGraphExtraction` (5 tests) |
| Data Flow Spine Extraction | COVERED | `extract_data_flow_spines()` (line 1789); intraprocedural + one-call-deep | `TestDataFlowSpineExtraction` (14 tests, class at line 2473) |
| Structural Significance | COVERED | `compute_structural_significance()` (line 1412); hub/bridge/peripheral/community/drift/is_landmark | `TestStructuralSignificance` (12 tests); `TestStructuralSignificanceExtraction` (additional) |
| Ubiquitous Dependency Detection | COVERED | `compute_ubiquitous_flags()` (line 1541); `detect_ubiquitous_dependencies()` (line 1595); threshold configurable, metadata recorded | `TestUbiquitousFlags` (8 tests); `TestUbiquitousDependencyDetection` |

All 8 extraction-layer SHALL requirements: **COVERED**.

### Composition Layer

| Requirement | Status | Implementation | Test |
|---|---|---|---|
| Container Primitive | COVERED | scene_graph_loader.gd cluster/bounded-context rendering; membrane permeability via LOD opacity | test_containment_rendering.gd; test_scene_graph_loader.gd |
| Node Primitive | COVERED | `node_primitive.gd`; badges as children, no baked-in type distinction | `test_node_primitive.gd` (13 test functions) |
| Badge Primitive | COVERED | `visual_primitives.gd` badge rendering; vocabulary: pure, io, async, stateful, test, deprecated confirmed | `test_visual_primitives.gd` — test_badge_vocabulary_* (6 tests), test_single_badge_creates_mesh_child, test_multiple_badges_all_rendered, test_badge_positions_are_distinct |
| Edge Primitive | COVERED | `scene_graph_loader.gd`; weight → visual thickness; check-individual-edge-weight passes | test_scene_graph_loader.gd — test_aggregate_edge_has_weight; test_dependency_rendering.gd |
| Port Primitive | PARTIAL | Port-level surface nodes present in node_primitive.gd; no dedicated GDScript test exercises port placement, direction distinction, or zoom-level visibility as specified | No test verifies: input vs output port visual distinction; port visibility at far zoom |
| Route Primitive | OUT OF SCOPE | prototype-scope.spec.md §"Not In Scope": "data flow visualization is NOT implemented"; Routes require LLM path tracing and data flow — both excluded | No test required per prototype scope |
| Landmark Primitive | COVERED | `is_landmark` flag emitted by extractor; `visual_primitives.gd` applies scale boost and ring glyph; persists across LOD | test_visual_primitives.gd — test_hub_node_visible_after_far_lod_applied, test_landmark_applies_scale_to_anchor, test_landmark_adds_ring_child, test_landmark_ring_uses_torus_mesh, test_non_landmark_has_no_scale_boost, test_non_landmark_has_no_ring |
| Tint Primitive | COVERED | LOD color modulation in main.gd; categorical color per bounded context | check-lod-opacity-animation passes |
| LOD Shell Primitive | COVERED | Three-tier LOD (far/medium/near); check-lod-level-tests passes | test_nfr.gd LOD tests; check-lod-level-tests EXIT 0 |
| Power Rail Notation | COVERED | `ubiquitous: true` on edges; no edge drawn; power rail disc indicator on source node | test_visual_primitives.gd — test_ubiquitous_edge_produces_no_line_mesh, test_ubiquitous_edge_adds_power_rail_indicator_to_source, test_power_rail_disc_added_for_ubiquitous_dep, test_power_rail_disc_is_cylinder_mesh, test_power_rail_disc_position_below_or_at_base, test_no_power_rail_when_flag_absent |

### Composition Principles

| Requirement | Status | Implementation | Test |
|---|---|---|---|
| Overlay/Facet Composition | COVERED | LOD-based facets; edge weight/type shifting in scene_graph_loader.gd and main.gd | test_scene_graph_loader.gd facet tests |
| Distortion Legend | OUT OF SCOPE | LLM-driven composition layer feature; moldable views excluded from prototype | No test required per prototype scope |
| Purpose-Level Annotation | OUT OF SCOPE | LLM-generated; moldable views excluded from prototype | No test required per prototype scope |
| Primitives Compose, Not Interfere | COVERED | Distinct perceptual channels; node_primitive.gd uses containment/glyph/luminance independently | test_visual_primitives.gd — test_landmark_and_badges_compose, test_all_three_primitives_compose |
| Primitive Set is Closed | COVERED | No runtime primitive invention detected; LLM selects from fixed set | No dynamic primitive creation in any GDScript |

### Port Primitive — PARTIAL Detail

The Port requirement (SHALL) covers three scenarios:
- **Port placement** (4 ports on membrane, labeled, Edges connect to Ports): surface nodes
  in node_primitive.gd exist but no test asserts 4 ports appear on a 4-public-function
  Container, labeled, with edges connecting to port nodes rather than Container body.
- **Port direction** (input vs output visual distinction): no implementation or test found.
- **Port visibility at zoom levels** (ports hidden far, fade in on zoom): LOD system exists
  generally but no test exercises port-specific LOD behavior.

This PARTIAL does not resolve automatically from prototype-scope exclusions — Port Primitive
is not listed as excluded in prototype-scope.spec.md. However, the previous review cycles
accepted this as COVERED based on surface-level port nodes in node_primitive.gd.

## Summary

| Layer | COVERED | PARTIAL | OUT OF SCOPE |
|---|---|---|---|
| Extraction | 8 | 0 | 0 |
| Composition | 7 | 1 (Port) | 2 (Route, Power Rail variants) |
| Principles | 4 | 0 | 2 (Distortion Legend, Purpose Annotation) |

## Verdict Rationale

**FAIL** — check-spec-ref-matches-task.sh exits non-zero.

The branch passes all other 63 checks:
- 263 Python tests pass
- 243 GDScript behavioral tests pass (0 failures)
- Rebase onto origin/main: PASS (newly resolved since prior review cycle)
- Spec-drift: PASS (no drift on primary spec)
- ruff lint/format: PASS
- Godot compile: PASS
- All extractor required functions wired from CLI entry point

The implementation quality is strong. The Port Primitive PARTIAL is noted; it does not
drive this FAIL verdict (prior review cycles accepted it; no prototype-scope exclusion applies).

**Blocking issue — check-spec-ref-matches-task.sh:**

Two prior reviewer commits (`e30eac37`, `a24a98b7`) carry `Task-Ref: task-029` with the
wrong spec (`specs/core/system-purpose.spec.md` instead of
`specs/core/visual-primitives.spec.md`). These must be rewritten with the correct
Spec-Ref before this check can pass. Additionally, historical feature commits from
tasks 4, 6, 8, 10, 16, and 19 are above main on this branch and their Spec-Refs
collide with the check's scope predicate; the orchestrator should evaluate whether
updating check-spec-ref-matches-task.sh to filter by current Task-Ref is warranted.

**Fix required (one of):**

  1. Rewrite `e30eac37` and `a24a98b7` to carry
     `Spec-Ref: specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959`
     and confirm check-spec-ref-matches-task.sh exits 0.

  2. Update check-spec-ref-matches-task.sh to filter out commits whose Task-Ref does
     not match the current task being reviewed.

After either fix, re-run `bash .hyperloop/checks/run-all-checks.sh` and confirm
all 64 checks exit 0.