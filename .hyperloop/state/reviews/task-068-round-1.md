---
task_id: task-068
round: 1
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-068
Spec: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1

---

## Scope Check Output
OK: No prohibited (not-in-scope) features detected.

---

## Process Checks

| Check | Result |
|---|---|
| check-rebased-onto-main.sh | ✅ PASS — rebased onto origin/main (814d2f92) |
| check-run-tests-suite-count.sh | ✅ PASS — branch 20 >= main 20 |
| check-spec-ref-staleness.sh | ✅ PASS — no spec drift |
| check-nondirectional-movement-assertions.sh | ✅ PASS |
| check-directional-signchain-comments.sh | ✅ PASS |
| check-highlight-function-has-tween.sh | ✅ OK (no highlight/color functions) |
| check-edge-rerouting-wired.sh | ✅ PASS — _path_edge_entries iterated in collapse/expand |
| check-individual-edge-weight.sh | ✅ PASS |
| check-aggregate-edge-impl.sh | ✅ PASS |
| check-compute-functions-called-from-entry-point.sh | ✅ PASS |
| check-typeddict-fields-extractor-tested.sh | ✅ PASS |
| check-no-vacuous-iteration.sh | ✅ PASS |
| check-no-gdscript-duplicate-functions.sh | ✅ PASS |
| check-tscn-no-dangling-references.sh | ✅ PASS |
| check-lod-opacity-animation.sh | ✅ PASS |
| check-lod-level-tests.sh | ✅ PASS |
| pytest (249 tests) | ✅ PASS |
| Godot tests (239 tests) | ✅ PASS |

---

## Requirements Coverage Table

### Requirement: 3D Interactive Navigation
| Scenario | Status |
|---|---|
| First-person exploration | COVERED — build_from_graph() creates 3D anchors; LOD navigation implemented in lod_manager.gd |

### Requirement: Structure as Persistent Geography
| Scenario | Status |
|---|---|
| Structural elements have spatial presence | COVERED — anchors created per node with distinct positions; bounded contexts and modules occupy distinct regions; tests in test_spatial_structure.gd and test_scene_graph_loader.gd |

### Requirement: Scale Through Zoom (LOD)
| Scenario / THEN-clause | Status |
|---|---|
| Far — bounded context architecture | COVERED — check-lod-level-tests.sh confirmed; aggregate edges at far distance |
| Medium — module structure within contexts | COVERED — check-lod-level-tests.sh confirmed; inter-module edges fade in |
| Near — full detail | COVERED — check-lod-level-tests.sh confirmed |
| Smooth transitions between levels (opacity animation) | COVERED — check-lod-opacity-animation.sh confirmed; Tween/modulate.a used |

### Requirement: Cluster Collapsing
| Scenario / THEN-clause | Status | Evidence |
|---|---|---|
| modules animate together, converging smoothly | PASS-WITH-NOTE | collapse_cluster() has `if is_inside_tree(): tween.tween_property(anchor, "modulate:a", 0.0, 0.3)` (lines 1066-1070). Tween branch exists; opacity fade is the animation. |
| supernode displays aggregate metrics (total LOC, in-degree, out-degree) | COVERED | Label3D created with BILLBOARD_ENABLED, pixel_size=0.012; test_collapse_cluster_creates_supernode_with_metrics asserts Label3D present |
| edges re-routed to the supernode | COVERED | collapse_cluster() iterates _path_edge_entries (lines 1137-1174), calls _reposition_edge_visual(); test_collapse_cluster_reroutes_edges_to_supernode uses non-trivial fixture (mod_a at (-4,0,0), mod_b at (4,0,0)) and asserts `rerouted_to == Vector3(0.0, 0.0, 0.0)` exactly |
| **edge re-routing animates smoothly — endpoints SLIDE not jump** | **PARTIAL** | **See blocking finding below** |
| edges that entered/left member re-routed on collapse | COVERED | _path_edge_entries iterated; source/target checked against member_set; _reposition_edge_visual() called |
| collapse recorded in state | COVERED | _collapsed_clusters[cluster_id] = members; test asserts key present |

### Scenario: Expanding a supernode
| Scenario / THEN-clause | Status | Evidence |
|---|---|---|
| supernode smoothly expands back into constituent modules | PASS-WITH-NOTE | expand_cluster() has `if is_inside_tree(): tween.tween_property(anchor, "modulate:a", 1.0, 0.3)` (lines 1200-1203). Tween branch exists for opacity fade. |
| modules animate outward to their original positions | PASS-WITH-NOTE | Anchor visibility restored via Tween (opacity); position was never changed during collapse so restore is implicit. |
| edges re-route back to their original endpoints | COVERED | expand_cluster() reads _cluster_edge_reroutes[cluster_id], calls _reposition_edge_visual() with orig_from/orig_to; test_expand_cluster_restores_edge_endpoints asserts `restored_to == Vector3(-4.0, 0.0, 0.0)` exactly |
| **edges re-route back with smooth animation** | **PARTIAL** | **See blocking finding below** |

### Scenario: Pre-computed cluster suggestions
| Scenario / THEN-clause | Status |
|---|---|
| indicated visually (tint) | COVERED — _apply_cluster_suggestions() adds "ClusterTint" MeshInstance3D; test_cluster_suggestion_has_visual_tint asserts child exists |
| no auto-collapse | COVERED — _collapsed_clusters starts empty; test asserts members visible and dict empty |
| human can accept or ignore | COVERED — collapse_cluster() requires explicit call |

### Scenario: Nested collapsing
| Scenario / THEN-clause | Status |
|---|---|
| only selected cluster collapses | COVERED — test_nested_collapsing_only_collapses_selected asserts first cluster hidden, second cluster visible |
| uncollapsed modules remain in place | COVERED — same test |

---

## Blocking Finding: PARTIAL — Edge Re-routing Smooth Animation

**Spec clauses:**
- Cluster Collapsing: "edge re-routing animates smoothly — endpoints slide to the supernode **rather than jumping**"
- Expanding a supernode: "edges re-route back to their original endpoints **with smooth animation**"

**Responsible function:** `_reposition_edge_visual()` — main.gd lines 797–838.

**Animation clause audit (per process rules):**

```
grep -n "create_tween\|is_inside_tree" godot/scripts/main.gd
  223: var tween: Tween = create_tween()          ← LOD fade
  262: var tween := create_tween()                ← LOD fade
  861: var tween: Tween = create_tween()          ← power-rail toggle
 1067: var tween: Tween = create_tween()          ← anchor hide (collapse)
 1202: var tween: Tween = create_tween()          ← anchor show (expand)
```

`_reposition_edge_visual()` (lines 797–838): **zero** `create_tween` calls,
**zero** `is_inside_tree()` branches. The function sets positions directly with no Tween path.

The implementation comments confirm the gap:
- Line 1167 (collapse_cluster): `# Tween-based animation for geometry rebuild is a future improvement; set positions directly (works correctly in both headless and in-tree modes).`
- Line 1228 (expand_cluster): same comment.

The docstring on `_reposition_edge_visual()` at line 796 says "In scene-tree contexts a Tween slides the visual" — but that claim is **false**: no such branch exists in the function body.

**Per process rules (dd26a4b1 — ANIMATION CLAUSE AUDIT):**
> "No `create_tween` anywhere in the [responsible] function (only direct assignment, or comment 'caller should Tween') → architecture is INCOMPLETE. PARTIAL — not PASS-WITH-NOTE."

This is PARTIAL for both the collapse and expand smooth-animation THEN-clauses.
Both clauses are MUST requirements (they appear under "The human MUST be able to collapse…"),
so PARTIAL = FAIL.

---

## Required Fix

Add a `create_tween()` / `is_inside_tree()` branch to `_reposition_edge_visual()` (or inline it into collapse_cluster/expand_cluster) so that edge endpoint repositioning is animated when in the scene tree:

For solid bodies:
```gdscript
if is_inside_tree():
    var tween := create_tween()
    tween.tween_property(visual, "position", new_midpoint, 0.3)
    # plus a separate Tween for orientation (basis) if desired
else:
    visual.position = new_midpoint
```

For dashed/dotted bodies (which rebuild child nodes, not move a single position),
the animation strategy could be: fade old segments out while new segments fade in
using modulate.a, OR accept that "slide" means the container Node3D position slides
and the geometry inside it is rebuilt.

A simpler acceptable path: add an `is_inside_tree()` guard and a Tween that interpolates
only the arrow position (role == "arrow") with `tween_property(visual, "position", ...)`.
For body visuals, a brief opacity cross-fade (modulate.a 0→1) satisfies "not jumping"
semantically, since the visual rebuilds between old and new positions.

Tests for the animation path remain at PASS-WITH-NOTE (headless tests verify direct-assignment
path only; Tween path is untestable in CI). The test requirement is satisfied: the test
fixtures and position assertions already verify the correct endpoint values.

No new test is required — the existing tests (`test_collapse_cluster_reroutes_edges_to_supernode`
and `test_expand_cluster_restores_edge_endpoints`) already exercise and assert the endpoint
positions correctly. Only the implementation's in-tree animation path must be added.