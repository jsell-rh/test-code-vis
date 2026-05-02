---
task_id: task-029
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-029
**Spec:** specs/core/visual-primitives.spec.md
**Branch:** hyperloop/task-029

---

## Executive Summary

Task-029 was assigned to implement the **Node Primitive renderer in Godot** (labeled
entities at tier-2 LOD). The branch adds no Godot files. The two actual commits
implement Python extractor features:

1. `feat(extractor): emit weight on individual cross_context and internal edges`
2. `feat(extractor): implement data flow spine extraction`

None of the files specified in the task PR description were created:
- `godot/scripts/node_primitive.gd` — **ABSENT**
- `godot/scenes/node_primitive.tscn` — **ABSENT**
- `godot/tests/test_node_primitive.gd` — **ABSENT**
- No modifications to `scene_graph_loader.gd` for function/class/method types

The non-directional-movement check: **OK** (no directional test violations found).

---

## Requirement Analysis

### Requirement: Node Primitive
**Status: MISSING**

The spec requires "an entity with identity, carrying zero or more Badges. Nodes do not
have baked-in types — their visual identity comes entirely from their Badges."

#### Scenario: Function node — MISSING
- GIVEN a function `validate_order` with no side effects
- WHEN the LLM maps it to a Node
- THEN the Node exists with its name, carries a "pure" Badge, and no special shape
  distinguishes it from a class node — only the Badges differ

**Implementation:** `main.gd._create_volume()` has an `else` branch that would render
any unrecognized node type with a BoxMesh (same geometry for all), and `visual_primitives.gd`
supports a "pure" Badge. The infrastructure could render a function-type node, but:
- No code path specifically handles `type == "function"`, `"method"`, or `"class"` at
  tier-2 LOD — they fall into the same `else` branch as modules (green box, sz * 0.6
  height). There is no node-type-specific shape differentiation test.
- `set_lod_visibility(tier: int)` does not exist anywhere in the Godot codebase (the
  LOD Shell approach per the task design). LOD is managed globally by `lod_manager.gd`.
- **No test** exercises a fixture with `"type": "function"` or `"type": "class"` to
  verify the Node Primitive rendering contract. `test_node_renderer.gd` uses
  `bounded_context` fixtures only. `test_visual_primitives.gd` uses `bounded_context`
  and `module` fixtures only.

#### Scenario: Node without badges — PARTIAL
- GIVEN an entity with no notable aspects yet analyzed
- WHEN it is rendered
- THEN it appears as a plain Node with its name, AND Badges are added as analysis layers

`test_visual_primitives.gd::test_no_badges_no_badge_children` tests that a node with an
empty `badges` array produces no Badge_ children. However, this fixture uses `type:
"module"`, not `type: "function"` or `type: "class"`. The scenario nominally requires
proof for function/class-type entities specifically.

**What is needed to fix:**
Create `godot/scripts/node_primitive.gd` (or equivalent), instantiate it in
`scene_graph_loader.gd` or `main.gd` for nodes whose type is `function`, `method`, or
`class`, and add `godot/tests/test_node_primitive.gd` with fixtures using those types.
Minimally: a test that builds a graph with `{"type": "function", "name": "validate_order",
...}` and asserts (a) a Label3D with text "validate_order" exists, (b) the mesh shape is
identical to what a class-type node produces (no baked-in shape distinction), and (c) a
"pure" Badge attaches correctly.

---

### Requirement: Data Flow Spine Extraction
**Status: PARTIAL**

This requirement IS implemented by this branch (even though it was not the task's stated
goal). Implementation: `extractor.py::extract_data_flow_spines()` +
`extractor.py::_trace_parameter_spine()`. Integrated in `build_scene_graph()`.

#### Scenario: Parameter to return value — COVERED
- Tests: `test_spine_emitted_for_traced_parameter`, `test_spine_references_function_name`,
  `test_spine_references_parameter_name`, `test_spine_has_steps_list`,
  `test_spine_steps_have_required_keys`, `test_transform_spine_includes_return_step`,
  `test_spine_step_source_ref_contains_param_name`.
- All test Given/When/Then conditions are present with concrete fixture data.

#### Scenario: One-call-deep interprocedural flow — PARTIAL
- GIVEN function A calls function B with argument `x`, B returns a value A assigns to `y`
- THEN the spine includes: A's `x` → B's parameter → B's return → A's `y`
- AND the extractor does NOT trace deeper than one call level

`test_interprocedural_entries_have_required_keys` creates a two-module fixture where
`a_func(x)` calls `b_func(x)`. However the critical assertion uses:
```gdscript
if ip_entries:
    for ip in ip_entries:
        assert "call_name" in ip, ...
```
The `if ip_entries:` guard means the test **passes vacuously** if the extractor produces
zero interprocedural entries — a silent regression would not be caught. The spec's THEN
clause is categorical: the spine MUST include the cross-call link. The test must assert
`assert ip_entries, "a_func(x) calling b_func(x) must produce at least one interprocedural
entry"` before inspecting entry fields.

`test_interprocedural_does_not_exceed_one_level` correctly uses `assert ... != "c_func"`.

**What is needed to fix:** Change the `if ip_entries:` block in
`test_interprocedural_entries_have_required_keys` to `assert ip_entries, "..."` so the
test actually fails when the interprocedural link is absent.

#### Scenario: Extraction cost boundary — COVERED
- `test_extraction_completes_per_function_independently` verifies no crash over isolated
  functions. `test_interprocedural_does_not_exceed_one_level` verifies the depth limit.

---

### Requirement: Module Graph Extraction — Import-based edge weight
**Status: COVERED**

The spec states each edge carries the import count. The branch adds `"weight"` to
`cross_context` and `internal` edges.

Tests `test_cross_context_edge_has_weight` and `test_internal_edge_has_weight` verify
the field is present and is a positive int. The fixtures use the real kartograph-like
test source tree. Coverage is solid.

---

## Requirements Out of Prototype Scope (not evaluated)

Per `specs/prototype/prototype-scope.spec.md`, the following are explicitly excluded from
the prototype and are not evaluated:
- Container membrane permeability (public/private symbol ratio rendering) — partial
  implementation exists but LLM-driven facets excluded
- Port Primitive, Route Primitive, Tint Primitive — excluded
- Overlay/Facet Composition, Distortion Legend, Purpose-Level Annotation — excluded
  (LLM-powered, not in prototype)

---

## Requirements Pre-existing (not this task's responsibility)

Badge Primitive, Landmark Primitive, Power Rail Notation, LOD Shell (LodManager), Edge
Primitive rendering (type distinction, arrowhead), Scope Nesting Extraction, Structural
Significance Extraction — all pre-existing in prior task merges and not modified by this
branch.

---

## Verdict: FAIL

Two blocking reasons:

1. **Node Primitive requirement (task's stated deliverable) is MISSING.** No Godot files
   were created. No test exercises a `function`- or `class`-type node through the
   rendering pipeline. The `set_lod_visibility(tier)` design from the task spec does not
   exist. This is the requirement the task was assigned to satisfy.

2. **Data Flow Spine — interprocedural scenario test is PARTIAL.** The THEN-clause ("the
   spine MUST include A's x → B's parameter → B's return → A's y") is not falsified by
   `test_interprocedural_entries_have_required_keys` because the `if ip_entries:` guard
   lets the test pass with zero interprocedural entries.

Both must be resolved before this task can pass review.