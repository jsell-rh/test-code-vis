---
task_id: task-065
round: 1
role: verifier
verdict: fail
---
# Review: task-065 — Orthogonal Independence Visualization

## Mandatory Pre-Review Checks

### CHECK SYNC
```
OK: All check scripts from main are present and content-identical in working tree (67 checked).
```
Local main is current (git fetch origin timed out due to network unavailability; local main HEAD 954cf3b matches origin/main). Check sync is clean.

## Scope Check Output
```
OK: No prohibited (not-in-scope) features detected.
```

### Rebase Check
```
OK: Branch 'hyperloop/task-065' is rebased onto origin/main (954cf3b).
```
The rebase issue from the prior review cycle is resolved. Branch is correctly rebased.

### Test Suite Count Checks
```
OK: _run_suite() count on branch (21) >= origin/main (20).
SKIP: origin/main has 0 test functions in extractor/tests/ — nothing to compare (pytest count check script arithmetic issue).
```
No test suite regression. 240 Godot tests pass; 254 Python tests pass.

## run-all-checks.sh Output (Summary)

All 66 checks exit 0. Key results:

```
check-aggregate-edge-impl.sh:              [EXIT 0] OK
check-branch-forked-from-main.sh:          [EXIT 0] OK
check-branch-has-commits.sh:              [EXIT 0] OK (2 commits above main)
check-branch-has-impl-files.sh:           [EXIT 0] OK (5 non-.hyperloop/ files)
check-checks-in-sync.sh:                  [EXIT 0] OK (67 checked)
check-commit-trailer-task-ref.sh:         [EXIT 0] OK
check-compute-functions-called-from-entry-point.sh: [EXIT 0] OK (7 compute_* functions)
check-directional-signchain-comments.sh:  [EXIT 0] OK
check-individual-edge-weight.sh:          [EXIT 0] OK
check-lod-level-tests.sh:                 [EXIT 0] OK
check-lod-opacity-animation.sh:           [EXIT 0] OK
check-no-gdscript-duplicate-functions.sh: [EXIT 0] OK
check-no-vacuous-iteration.sh:            [EXIT 0] OK
check-pytest-passes.sh:                   [EXIT 0] OK (254 passed)
check-rebased-onto-main.sh:               [EXIT 0] OK
check-run-tests-suite-count.sh:           [EXIT 0] OK (21 >= 20)
check-spec-ref-staleness.sh:              [EXIT 0] OK (no spec drift)
check-spec-ref-valid.sh:                  [EXIT 0] OK
check-tscn-no-dangling-references.sh:     [EXIT 0] OK
check-typeddict-fields-extractor-tested.sh: [EXIT 0] OK
extractor-lint.sh:                        [EXIT 0] OK (254 pytest, ruff clean)
godot-compile.sh:                         [EXIT 0] OK (compile successful)
godot-tests.sh:                           [EXIT 0] 240 PASS, 0 FAIL

=== Summary: 66 check(s) run ===
RESULT: ALL PASS
```

Note: `godot-compile.sh` emits runtime `ERROR: The tweened property "modulate:a" does not exist in object` messages during the LOD initialization. These errors are pre-existing on main (322 occurrences also present on main without this branch's changes) and are not introduced by this task. They originate in pre-existing `lod_manager.gd:71` (`_transition_visible`) which is not modified by this branch.

### Trailers
Both commits carry correct trailers:
- `Spec-Ref: specs/visualization/orthogonal-independence.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1` — resolves; file is identical at Spec-Ref hash and HEAD (no spec drift)
- `Task-Ref: task-065` — correct

### Onready Null-Guard Review
`highlight_independence()`, `clear_independence_highlight()`, `_animate_mesh_color()`, `_compute_context_independence()`, and `_highlight_cross_context_independence()` all access `_anchors` and `_graph`, which are populated by `build_from_graph()`. None are gated on `@onready var _camera`. The only `_camera == null` guard is in `_update_lod()` (line 236), which is called during `build_from_graph()` but is unrelated to independence highlighting. No null-guard short-circuits any independence test path.

---

## Spec Requirement Coverage

Spec file at Spec-Ref hash is identical to HEAD (no spec drift). All THEN-clauses scored against the committed spec.

### Requirement: Independence Detection

| THEN-clause | Implementation | GDScript Test | Extractor Test | Status |
|---|---|---|---|---|
| {A,B} and {C,D} identified as independent groups | `compute_independence_groups()` (pre-existing) | pre-existing on main | `test_connected_modules_share_group`, `test_isolated_module_has_own_group` | COVERED |
| Each module carries its group identifier in the scene graph | `independence_group` field on module nodes | `test_module_node_has_independence_group` (scene_graph_loader) | `test_independence_group_format`, `test_build_scene_graph_assigns_independence_groups` | COVERED |
| Fully connected context → single group | `compute_independence_groups()` (pre-existing) | — | pre-existing coverage on main | COVERED |
| No independence separation for single group | `apply_independence_spatial_layout()` (no-op for 1 group) | — | `test_single_group_positions_unchanged` | COVERED |

### Requirement: Spatial Separation of Independent Groups

#### Scenario: Visual gap between independent groups

| THEN-clause | Implementation | GDScript Test | Extractor Test | Status |
|---|---|---|---|---|
| Groups occupy distinct spatial regions | `apply_independence_spatial_layout()` sector layout | — | `test_two_groups_have_distinct_positions`, `test_build_scene_graph_spatially_separates_independent_groups` | COVERED |
| A visible gap separates the groups | 75% sector gap in `apply_independence_spatial_layout()` | — | `test_independent_groups_are_angularly_separated` (>5° angular gap) | COVERED |
| Modules within each group remain close (max intra < min inter) | Compact sector arc layout | — | `test_modules_within_group_remain_close` | COVERED |

#### Scenario: Smooth regrouping on data change

| THEN-clause | Implementation | GDScript Test | Status |
|---|---|---|---|
| **Nodes animate to their new positions on reload** | `_animate_node_to_position()` (Tween in-tree, direct in headless) — pre-existing | **MISSING** | **PARTIAL** |
| Transition smooth (slide not jump) — animated | Tween in `_animate_node_to_position()` when `is_inside_tree()` | UNTESTABLE in headless — architecturally correct | PASS-WITH-NOTE |

**This is the only failing requirement.** The implementation path is correct: `build_from_graph()` detects `is_reload = true` when anchors already exist, and calls `_animate_node_to_position()` for each node with changed positions. In headless mode it sets `anchor.position = new_pos` directly; in scene tree it uses `Tween.tween_property(anchor, "position", new_pos, 0.5)`. The prior implementation of this spec (task-022, commit 49c77aa0, subsequently deleted) included `test_smooth_regrouping_animates_position_on_reload()` that exercised exactly this path. The current branch does not.

### Requirement: Independence as Queryable Property

#### Scenario: Selecting a module shows its independent peers

| THEN-clause | Implementation | GDScript Test | Status |
|---|---|---|---|
| Modules in other independence groups highlighted (INDEPENDENT_PEER_COLOR) | `highlight_independence()` | `test_other_group_modules_highlighted_as_independent_peers`, `test_highlight_independence_covers_selected_nodes_complement` | COVERED |
| Own group visually distinguished as co-dependent (CODEPENDENT_COLOR) | `highlight_independence()` | `test_own_group_modules_highlighted_as_codependent` | COVERED |
| Colors are visually distinct | `INDEPENDENT_PEER_COLOR ≠ CODEPENDENT_COLOR` | `test_codependent_and_independent_colors_are_visually_distinct` | COVERED |
| Transition to highlighted state animated smoothly | `_animate_mesh_color()` Tween (in-tree) / direct (headless) | `test_highlight_changes_module_color_from_default`, `test_clear_independence_highlight_restores_original_colors` | COVERED (headless: color change confirmed; animation timing untestable) |

#### Scenario: Cross-context independence

| THEN-clause | Implementation | GDScript Test | Status |
|---|---|---|---|
| Contexts with no transitive dependency highlighted | `_compute_context_independence()` BFS, `_highlight_cross_context_independence()` | `test_compute_context_independence_finds_isolated_contexts`, `test_dependent_context_is_not_independent`, `test_independent_context_receives_highlight_color` | COVERED |
| ctx_a NOT in its own independent set | `_compute_context_independence()` explicit exclusion | `test_compute_context_independence_finds_isolated_contexts` | COVERED |
| Clear restores context colors | `clear_independence_highlight()` restores saved colors | `test_clear_restores_context_highlight` | COVERED |
| Highlight animates from selected module outward | Delay increment (0.05s per node) in `highlight_independence()` | UNTESTABLE in headless — architecturally correct | PASS-WITH-NOTE |

---

## Verdict: FAIL

**Blocking finding:** The "Smooth regrouping on data change" scenario (orthogonal-independence.spec.md § Spatial Separation) has no GDScript test asserting that anchor positions are updated when `build_from_graph()` is called a second time with different node positions. The spec says "THEN nodes animate smoothly to their new positions." The implementation (`_animate_node_to_position()`) is correct and the headless code path (direct `anchor.position = new_pos`) is fully testable. One test is missing.

**Actionable fix:** Add the following test to `godot/tests/test_independence_highlight.gd`:

```gdscript
## THEN nodes animate smoothly to their new positions (smooth regrouping).
## spec: orthogonal-independence.spec.md § Smooth regrouping on data change
## "When a new extraction produces different independence groups, nodes animate
##  smoothly to their new positions."
func test_smooth_regrouping_updates_anchor_positions() -> void:
    _test_failed = false
    var main := Main.new()

    # v1: initial positions from the standard fixture.
    var graph_v1: Dictionary = _make_independence_fixture()
    main.build_from_graph(graph_v1)

    # Record the anchor objects — identity must be preserved across reload.
    var anchor_before: Node3D = main.get_anchors().get("ctx_a.mod_isolated")
    _check(anchor_before != null, "Anchor must exist after first build_from_graph")
    if anchor_before == null:
        main.free()
        return
    var pos_before: Vector3 = anchor_before.position

    # v2: same nodes, positions shifted (+3 x, +1 z) to simulate regrouping.
    var graph_v2: Dictionary = _make_independence_fixture()
    for nd: Dictionary in graph_v2.get("nodes", []):
        var p: Dictionary = nd.get("position", {})
        p["x"] = float(p.get("x", 0.0)) + 3.0
        p["z"] = float(p.get("z", 0.0)) + 1.0

    main.build_from_graph(graph_v2)

    # Anchor identity preserved; position should have changed.
    var anchor_after: Node3D = main.get_anchors().get("ctx_a.mod_isolated")
    _check(anchor_after == anchor_before, "Anchor identity must be preserved on reload")
    _check(
        not anchor_after.position.is_equal_approx(pos_before),
        "Anchor position must update on reload — smooth regrouping must move nodes; "
        + "before: %s, after: %s" % [str(pos_before), str(anchor_after.position)]
    )

    main.free()
```

All other requirements are COVERED. No implementation changes are needed — only this one test addition.