---
task_id: task-029
round: 6
role: verifier
verdict: fail
---
## Scope Check Output

```
NOTE: Pre-existing prohibited spec-extraction code in extractor/extractor.py (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
NOTE: Pre-existing prohibited spec-extraction tests in extractor/tests/ (NOT introduced by this branch).
  Informational only — does NOT count as FAIL. Another task is responsible for removal.
OK: No prohibited (not-in-scope) features detected.
```

---

## Check Sync

```
OK: All check scripts from main are present and content-identical in working tree (71 checked).
```

---

## Rebase Status

```
FAIL: Branch 'hyperloop/task-029' is NOT rebased onto origin/main.

  Fork point (merge-base): 51d1aaf
  origin/main HEAD:        354babd
  Commits on main not in branch: 1
```

Missing commit:
```
354babde feat(godot): render Port primitives on Container membrane (public symbol interface points) (#240)
  Task-Ref: task-038
  Files: extractor/tests/test_extractor.py, godot/scripts/main.gd,
         godot/scripts/port_renderer.gd, godot/tests/run_tests.gd,
         godot/tests/test_port_renderer.gd
```

Classification: **STANDARD REBASE FAIL** (not REBASE-ONLY FAIL). The missing commit touches implementation files in extractor/ and godot/.

---

## ORCHESTRATOR NOTE — Feature Supersession

Commit `354babde` (task-038, PR #240) on origin/main implements Port Primitive rendering
using `port_renderer.gd` with a Tween-based LOD opacity architecture. This branch (task-029)
independently implements Port Primitive rendering using `port_primitive.gd` with a
LodManager-registration architecture. Both touch `godot/scripts/main.gd` and
`godot/tests/run_tests.gd` significantly.

**Conflict regions:**

- `main.gd` — task-038 adds `const PortRenderer`, `_port_renderers`, `_port_world_positions`,
  `_last_lod_tier` state vars, and a per-frame Port LOD tier update in `_update_lod()`.
  task-029 removes these and adds `const NodePrimitive`, `const PortPrimitive`,
  `_node_primitive`, `_port_primitive`, `_node_data_map` state vars, and
  `get_world_positions()`. These regions are **overlapping** — manual block-by-block merge
  is required.

- `run_tests.gd` — task-038 adds `_run_suite(preload("res://tests/test_port_renderer.gd").new())`.
  task-029 **replaces** this line with two new suites (`test_node_primitive.gd` and
  `test_port_primitive.gd`). After rebase, all three suites must be present.

- `extractor/tests/test_extractor.py` — task-038 added two accumulation tests
  (`test_cross_context_edge_weight_accumulates_for_multiple_imports`,
  `test_internal_edge_weight_accumulates_for_multiple_imports`). This branch adds 15 new
  data-flow-spine and symbol-table tests. These are in different class scopes and should
  merge without conflict, but the implementer must verify.

**Decision for orchestrator:** After the implementer rebases and resolves conflicts,
evaluate whether `port_primitive.gd` should coexist alongside `port_renderer.gd` (they
use different architectures — PortPrimitive uses LodManager registration; PortRenderer
uses Tween-based per-object LOD), or whether one supersedes the other. Both implementations
correctly satisfy the Port Primitive spec scenarios.

---

## Test Suite Counts

```
check-run-tests-suite-count.sh:
  OK: _run_suite() count on branch (23) >= origin/main (22).

check-pytest-test-count.sh:
  OK: Python test count on branch (8) >= origin/main (8).

check-class-test-count.sh:
  OK: All-test count (class-method-inclusive) on branch (279) >= origin/main (266).

Godot tests: 283 passed, 0 failed (all mechanical checks report OK)
Pytest: 279 passed (all tests pass)
```

---

## run-all-checks.sh — Complete Output Summary

70 checks run. 1 failed: `check-rebased-onto-main.sh`.

All other checks: EXIT 0, including:
- check-checks-in-sync.sh: OK (71 scripts)
- check-branch-has-impl-files.sh: OK (9 non-.hyperloop files changed)
- check-no-gdscript-duplicate-functions.sh: OK
- check-tscn-no-dangling-references.sh: OK
- check-godot-no-script-errors.sh: OK (zero failures, zero SCRIPT ERRORs)
- check-commit-trailer-task-ref.sh: OK (all trailers match task-029)
- check-spec-ref-matches-task.sh: OK (correct spec path)
- check-badge-vocabulary-tests.sh: OK (all 8 badge types)
- check-lod-level-tests.sh: OK (Near/Medium/Far all covered)
- check-compute-functions-called-from-entry-point.sh: OK (all 7 compute_* called)
- check-class-test-count.sh: OK (279 >= 266)
- check-no-vacuous-iteration.sh: OK
- check-racf-prior-cycle.sh: OK (prior check-report-scope-section.sh failure resolved)
- check-no-zero-commit-reattempt.sh: OK (5 impl commits since prior FAIL)

---

## Spec-Ref Verification

- Task definition: `specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd`
  (blob hash)
- Implementation commits: `specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959`
  (commit hash where spec was authored)
- Content check: **identical** — both hashes resolve to the same spec file content
- `check-spec-ref-staleness.sh`: No drift for `specs/core/visual-primitives.spec.md`

---

## Spec Section Audit

Task title: "Implement Node Primitive renderer in Godot"  
Branch implements: Node Primitive (primary) + Port Primitive (secondary, gap-fill from prior cycle) + REQ-EX3 symbol labeling layer + REQ-C7 bridge position tests

This matches the assigned spec sections. No wrong-feature issue.

---

## Onready Null Guard Assessment

`@onready var _camera: Camera3D = $Camera3D` — guarded at line 276:
`if _camera == null or not _camera.has_method("get_distance"): return`

This gate is in `_update_lod()`. The Port LOD tests bypass this entirely by calling
`LodManager.update_lod()` directly — they never call `_update_lod()` at all. The LOD
THEN-clauses for ports are correctly covered by injecting LodManager directly. No
null-guard coverage gap for this task's THEN-clauses.

---

## Implementation Quality Findings

Spec: `specs/core/visual-primitives.spec.md`

### REQ-C2: Node Primitive — COVERED (primary task deliverable)

**Scenario: Function node**
- `test_function_node_has_label_with_name`: Label3D.text == "validate_order" ✓
- `test_function_node_with_pure_badge_has_badge_child`: Badge_pure MeshInstance3D present ✓
- `test_function_and_class_nodes_have_identical_mesh_size`: identical BoxMesh dims ✓
- `test_function_node_label_is_billboarded`: billboard=ENABLED, pixel_size > 0.0 ✓
- `test_node_primitive_handles_function/method/class`: routing correct ✓

**Scenario: Node without badges**
- `test_class_node_without_badges_has_no_badge_children`: no Badge_ children ✓
- `test_method_node_has_label_with_name`: method name in label ✓

Unit-level (`NodePrimitive.populate_anchor()` directly):
- `test_populate_anchor_creates_box_mesh` ✓
- `test_populate_anchor_creates_label_with_name` (with billboard and pixel_size) ✓
- `test_function_and_class_use_same_box_dimensions` ✓

### REQ-C5: Port Primitive — COVERED (gap-fill from prior cycle)

**Scenario: Port placement** — 4 port tests using NON-ZERO parent world pos (x=5, z=3):
- `test_four_public_functions_produce_four_ports`: 4 Port_ children ✓
- `test_port_labels_match_function_names`: all 4 names present ✓
- `test_ports_are_on_membrane_not_interior`: port.position.x == sz * 0.5 (direct equality) ✓
- `test_no_ports_for_private_symbols_only`: zero ports for private-only module ✓

**Edges connect to Ports, not Container body:**
- `test_edge_target_overridden_to_port_world_position`: fn_world.x == 4.0 (membrane,
  not interior 3.5); uses module at world x=3.0 (non-zero) ✓
- `test_function_world_pos_not_equal_to_container_center` ✓

**Scenario: Port direction** — input/output distinction:
- `test_input_port_color_differs_from_output_port_color` ✓
- `test_input_port_uses_input_color` (teal = INPUT_PORT_COLOR) ✓
- `test_output_port_uses_output_color` (amber = OUTPUT_PORT_COLOR) ✓

**Scenario: Port visibility at zoom levels:**
- `test_ports_hidden_at_far_lod` (LodManager.update_lod directly) ✓
- `test_ports_visible_at_near_lod` ✓
- `test_ports_hidden_at_medium_lod` ✓

### REQ-EX3: Symbol Labeling Layer — COVERED (gap-fill from prior cycle)

`test_symbol_table_provides_names_for_call_graph_edge_endpoints`:
- Calls `build_scene_graph()` on a real codebase fixture
- Finds a `direct_call` edge
- Asserts the source node's `symbols` list is non-empty
- Asserts `caller_func` appears in symbol names
- Asserts target node's `symbols` list is also non-empty
This is a real extractor call, not a schema-level stub. ✓

### REQ-C7: Bridge Landmark position — COVERED (gap-fill from prior cycle)

`test_bridge_landmark_world_position_is_between_two_subsystems`:
- Places subsystem_a at x=2.0, subsystem_b at x=8.0 (both non-zero, distinct)
- Calls `build_from_graph()`, reads `get_world_positions()`
- Asserts `min(pos_a, pos_b) < pos_bridge < max(pos_a, pos_b)` (strictly between)
- Uses `get_world_positions()` getter exposed in this commit ✓

---

## What the Implementer Must Do

**REQUIRED for pass:**

1. **Rebase onto origin/main:**
   ```
   git fetch origin
   git rebase origin/main
   ```

2. **Resolve conflicts (manual, non-trivial):**

   **`godot/scripts/main.gd`** — keep BOTH architectures:
   - KEEP task-038's incoming: `const PortRenderer`, `_port_renderers`, `_port_world_positions`,
     `_last_lod_tier`, and the Port LOD tier update block in `_update_lod()`.
   - KEEP this branch's: `const NodePrimitive`, `const PortPrimitive`, `_node_primitive`,
     `_port_primitive`, `_node_data_map`, `get_world_positions()`.
   - Merge the build_from_graph() body to include BOTH the PortRenderer.attach_ports()
     call (task-038) and the NodePrimitive/PortPrimitive calls (task-029).

   **`godot/tests/run_tests.gd`** — include ALL three suites:
   ```gdscript
   _run_suite(preload("res://tests/test_port_renderer.gd").new())   # task-038
   _run_suite(preload("res://tests/test_node_primitive.gd").new())  # task-029
   _run_suite(preload("res://tests/test_port_primitive.gd").new())  # task-029
   ```

   **`extractor/tests/test_extractor.py`** — keep ALL tests. task-038 added two tests
   in the cross-context/internal edge weight accumulation class; this branch adds data flow
   spine tests. Both sets must be present.

3. **After rebase:**
   ```
   bash .hyperloop/checks/check-run-tests-suite-count.sh   # must show >= 24 suites
   bash .hyperloop/checks/run-all-checks.sh                # must exit 0
   ```

**No implementation quality changes needed.** The Node Primitive, Port Primitive,
REQ-EX3, and REQ-C7 implementations are correct and well-tested.

---

## Summary Table (Implementation Quality Only)

| Requirement | Status | Notes |
|---|---|---|
| REQ-C2: Node Primitive | COVERED | Primary task — fully implemented and tested |
| REQ-C5: Port Primitive | COVERED | Gap-fill from prior cycle — fully implemented and tested |
| REQ-EX3: Symbol Labeling | COVERED | Gap-fill — real extractor test with assertion |
| REQ-C7: Bridge Landmark position | COVERED | Gap-fill — non-zero parent test with strict between assertion |

All other spec requirements (REQ-EX1 through REQ-I2) were established in prior cycles
and remain covered on this branch (no regression detected).