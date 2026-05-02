---
task_id: task-070
round: 0
role: verifier
verdict: fail
---
# Review — task-070 — Orthogonal Independence Visualization

## Pre-flight Checks

### Check Sync
`git fetch origin main:main` — timed out (no network). Proceeded with local main
(which was already current). `check-checks-in-sync.sh` → OK (67 scripts present
and content-identical).

### Rebased
`check-rebased-onto-main.sh` → OK: branch is rebased onto origin/main (954cf3b).

### Suite Count (GDScript)
`check-run-tests-suite-count.sh` → OK: 21 suites on branch ≥ 20 on origin/main.
(new suite: test_orthogonal_independence.gd)

### Python Test Count
`check-pytest-test-count.sh` → SKIP: origin/main has 0 test functions in
extractor/tests/ — nothing to compare. (255 tests pass locally.)

### Scope Check Output
OK: No prohibited (not-in-scope) features detected.

### Spec-Ref Match
`check-spec-ref-matches-task.sh` → SKIP: task-070.md not in tasks directory
(the file does not exist on this branch's hyperloop/state). The Spec-Ref trailer
in the commit is:
  `specs/visualization/orthogonal-independence.spec.md@7a839cc34dd...`

### Spec-Ref Staleness
`check-spec-ref-staleness.sh` → OK (no drift): spec is identical at Spec-Ref
hash and HEAD.

---

## run-all-checks.sh Output Summary

All 66 checks: **ALL PASS**

Notable individual results:
- check-not-in-scope.sh → EXIT 0
- check-branch-has-impl-files.sh → OK (5 non-.hyperloop/ files changed)
- check-commit-trailer-task-ref.sh → OK (Task-Ref: task-070 present)
- check-compute-functions-called-from-entry-point.sh → OK (7 compute_* functions called from entry point)
- check-individual-edge-weight.sh → OK (Gate 1 + Gate 2 confirmed)
- check-no-vacuous-iteration.sh → OK
- check-no-gdscript-duplicate-functions.sh → OK
- check-tscn-no-dangling-references.sh → OK
- check-godot-no-script-errors.sh → 241 passed, 0 failed
- check-pytest-passes.sh → SKIP (pytest not found in check's PATH; manual run: 255 passed)
- check-typeddict-fields-extractor-tested.sh → OK
- Ruff lint: All checks passed. Ruff format: 8 files already formatted.
- Type hints: All top-level functions in extractor.py carry return-type annotations.

---

## Deliverable Verification

Files changed on branch (git diff --name-only main..HEAD):
- `extractor/extractor.py` (+158/-31) — Python extractor
- `extractor/tests/test_extractor.py` (+332) — Python tests
- `godot/scripts/independence_query.gd` (+261) — Godot module
- `godot/tests/run_tests.gd` (+7) — test runner wiring
- `godot/tests/test_orthogonal_independence.gd` (+498) — Godot tests

Both components (Python extractor + Godot) have deliverables. ✓

---

## Spec-Drift Detection

Committed spec (at 7a839cc) is identical to HEAD. No spec drift detected.
All THEN-clauses scored below are present in the committed spec.

---

## THEN-Clause Coverage Audit

### Requirement: Independence Detection

**Scenario: Two independent module clusters**

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| {A,B} and {C,D} are identified as independent groups | COVERED | `test_two_independent_clusters_identified` — asserts `groups[alpha]==groups[beta]`, `groups[gamma]==groups[delta]`, `groups[alpha]!=groups[gamma]` |
| each module carries its group identifier in the scene graph | COVERED | `test_each_module_carries_group_id_in_scene_graph` (full pipeline), `test_independence_group_preserved_on_node` (GDScript fixture) — both assert field presence and `<ctx>:<idx>` format |

**Scenario: Fully connected context**

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| the entire context is a single group | COVERED | `test_fully_connected_context_is_single_group` — cycle A→B→C→A, asserts `len(group_values)==1` |
| no independence separation is applied | COVERED | Implied: single group triggers single-circle layout in `compute_layout()` (the `num_groups <= 1` branch) |

---

### Requirement: Spatial Separation of Independent Groups

**Scenario: Visual gap between independent groups**

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| groups occupy distinct spatial regions within the context's volume | COVERED | `test_independent_groups_are_spatially_separated` — asserts `cross_min > intra_max` |
| a visible gap separates the groups | COVERED | Same test — `cross_min > intra_max` mathematically guarantees a gap |
| modules within each group remain close to each other | COVERED | Same test — `d_alpha_gamma > d_alpha_beta` and `> d_gamma_delta` (intra-group is tighter) |

**Scenario: Smooth regrouping on data change**

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| nodes animate smoothly to their new positions | COVERED (PASS-WITH-NOTE) | `_animate_node_to_position()` in main.gd: `if is_inside_tree(): Tween.tween_property(anchor, "position", new_pos, 0.5)` — correct architecture. Test `test_smooth_regrouping_anchor_slides_not_jumps` verifies position changes after reload (Tween itself is untestable in headless, but architecture is correct). |
| the transition preserves spatial continuity — nodes slide rather than jump | COVERED | `test_smooth_regrouping_anchor_identity_preserved` — same Node3D object before/after reload; same anchor enables Tween-based sliding |

---

### Requirement: Independence as Queryable Property

**Scenario: Selecting a module shows its independent peers**

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| all modules in other independence groups within the same bounded context are highlighted | COVERED | `test_independent_modules_highlighted` — selects ctx.alpha, asserts `independent.has("ctx.gamma")` and `independent.has("ctx.delta")`, and `gamma_color.g > 0.7` (green INDEPENDENT_COLOR) |
| modules in A's own group are visually distinguished as "co-dependent" | COVERED | `test_codependent_modules_colored_orange` — asserts `codependent.has("ctx.beta")` and `beta_color.r > 0.7` (orange CODEPENDENT_COLOR) |
| **the transition between default and independence-highlighted states is animated smoothly** | **PARTIAL** | See Finding 1 below |

**Scenario: Cross-context independence**

| THEN-clause | Status | Evidence |
|-------------|--------|---------|
| bounded contexts with no transitive dependency on context X are highlighted as fully independent | COVERED | `test_context_independent_peers_highlighted` (asserts "other" in independent, "shared_kernel" not in), `test_context_independent_colors_applied` (asserts blue/cyan on "other"), `test_transitive_dependency_excludes_from_independent` (chain ctx→middle→leaf; only "isolated" is independent) |
| **the highlight animates in from the selected module outward** | **PARTIAL** | See Finding 2 below |

---

## Findings

### Finding 1 — PARTIAL: Highlight transition not animated (smooth-state transition)

**THEN-clause:** "AND the transition between default and independence-highlighted states is animated smoothly"

**Test claim:** Header maps this to `test_highlight_colors_are_distinct`. That test only asserts perceptual color channel separation (`independent_color.g > 0.7`, `codependent_color.r > 0.7`, `diff_ind_codep > 0.3`). It does NOT assert a Tween-animated transition — it tests the steady-state distinguishability, not the animation between states.

**Implementation gap:** `_apply_node_color()` in `independence_query.gd` sets the material albedo_color directly with no Tween:
```gdscript
var mat := StandardMaterial3D.new()
mat.albedo_color = color
(child as MeshInstance3D).material_override = mat
```
There is no `if is_inside_tree(): tween.tween_property(...)` pattern — compare this with `_animate_node_to_position()` in main.gd, which correctly branches on scene-tree availability. The comment in `clear_independence_highlight()` acknowledges the gap ("the caller should Tween"), but no caller in main.gd applies a Tween when invoking `apply_independence_highlight()`.

**Why not PASS-WITH-NOTE:** PASS-WITH-NOTE requires the architecture to be correct and only the test to be impossible in headless mode. Here the architecture is incomplete — no Tween code exists anywhere in the highlight path.

**Fix required:**
- Add a Tween branch to `_apply_node_color()` (or to a new `_apply_node_color_animated()` wrapper):
  ```gdscript
  if is_inside_tree():
      var tween := create_tween()
      tween.tween_property(child, "material_override:albedo_color", color, 0.3)
  else:
      mat.albedo_color = color
  ```
- OR add a Tween wrapper in the caller (main.gd) before invoking `apply_independence_highlight()`.
- Update `test_highlight_colors_are_distinct` comment to clarify it covers perceptual distinctness; add an architectural test (e.g., assert the function calls `create_tween` when inside the scene tree, or verify the distinct-color steady state is reached after the animated transition).

---

### Finding 2 — PARTIAL: Outward highlight animation not implemented

**THEN-clause:** "AND the highlight animates in from the selected module outward"

**Test claim:** Header maps this to `test_context_independent_colors_applied`. That test asserts:
- "other" appears in `independent`
- `other_color.b > 0.7` (CONTEXT_INDEPENDENT_COLOR is applied)
- "dep" does not appear in `independent`

It does NOT test that the highlight propagates outward from the selected module (i.e., closer independent contexts light up before farther ones, with staggered delay).

**Implementation gap:** `apply_context_independence_highlight()` applies the same color to all independent contexts in a single loop with no delay or BFS-ordered Tween:
```gdscript
for ctx_id: String in independent_contexts:
    var anchor: Node3D = anchors.get(ctx_id) as Node3D
    _apply_node_color(anchor, CONTEXT_INDEPENDENT_COLOR)
```
All contexts highlight simultaneously — there is no "in from the selected module outward" propagation animation.

**Fix required:** Implement BFS-ordered highlighting with staggered Tween delays proportional to graph-hop distance from the selected context. For example:
```gdscript
# For each context, compute its hop distance from context_id and delay accordingly.
var hop_distance := compute_hop_distances(context_id, nodes_data, edges_data)
for ctx_id: String in independent_contexts:
    var delay := hop_distance.get(ctx_id, 0) * 0.15  # 150ms per hop
    var tween := create_tween()
    tween.tween_interval(delay)
    tween.tween_callback(func(): _apply_node_color(anchors.get(ctx_id), CONTEXT_INDEPENDENT_COLOR))
```
The test would need to inject anchors and assert that the color application order/timing reflects outward propagation (or, since headless Tween is untestable, at minimum verify the architecture exists).

---

## Commit Trailers

- `Spec-Ref: specs/visualization/orthogonal-independence.spec.md@7a839cc...` ✓
- `Task-Ref: task-070` ✓

---

## Summary

| Check | Result |
|-------|--------|
| run-all-checks.sh (66 checks) | ALL PASS |
| Rebased onto main | PASS |
| GDScript suite count ≥ main | PASS (21 ≥ 20) |
| Python tests (255) | ALL PASS |
| Ruff lint + format | PASS |
| Type hints | PASS |
| Spec trailers | PASS |
| Finding 1: animated highlight transition | PARTIAL — no Tween |
| Finding 2: outward animation for context independence | PARTIAL — no BFS propagation |

**Verdict: FAIL**

Two THEN-clauses from the committed spec are PARTIAL — they have no animation
implementation (no Tween) in the implementation path. The test assertions for both
cover only the static/steady-state visual outcome, not the animated transition
the spec requires. Both gaps are implementation issues (not just headless test
limitations), because the architecture for these animations is absent, unlike the
correctly-implemented spatial smooth-regrouping animation in `_animate_node_to_position()`.