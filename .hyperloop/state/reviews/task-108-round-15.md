---
task_id: task-108
round: 15
role: spec-reviewer
verdict: fail
---
## Review: task-108 (tenth round)

Spec: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
Branch: hyperloop/task-108 (rebased onto origin/main 6db01fe)

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

---

## Rebase History This Round

origin/main advanced through multiple commits during this review. The branch required
iterative rebasing due to the rapidly-moving main branch. All rebase conflicts were in
`godot/tests/run_tests.gd` and resulted from origin/main reverting task-022 independence
work (commit 7dcd31e) and adding new process/check commits. Resolution in each case
followed the protocol: keep origin/main's version, apply branch changes on top.

Final rebase base: 6db01fe (fix(process): scope spec-ref check to current task).
Suite count after rebase: 20 `_run_suite()` calls on both branch and origin/main.

Two check-sync commits added during review:
- `1176ad00` — sync check-deliverable-component.sh and check-edge-rerouting-wired.sh (added in 09fb0a02)
- `c8f1c692` — fix file mode from 100755 to 100644 to match main

---

## Check Results (at time of verdict)

| Check | Result |
|---|---|
| check-aggregate-edge-impl.sh | PASS |
| check-assigned-spec-in-scope.sh | SKIP |
| check-banned-task-ids-closed.sh | SKIP |
| check-branch-forked-from-main.sh | PASS |
| check-branch-has-commits.sh | PASS — 262 commits above main |
| check-branch-has-impl-files.sh | PASS |
| check-checks-in-sync.sh | PASS — 67 checked |
| check-circular-position-y-axis.sh | PASS |
| check-clamp-boundary-tests.sh | PASS |
| check-commit-trailer-task-ref.sh | PASS |
| check-compute-functions-called-from-entry-point.sh | PASS |
| check-cycle-gate.sh | PASS |
| check-deliverable-component.sh | SKIP (no task arg) |
| check-directional-signchain-comments.sh | PASS |
| check-edge-rerouting-wired.sh | SKIP |
| check-extractor-cli-tested.sh | PASS |
| check-extractor-stdlib-only.sh | PASS |
| check-fail-report-classification.sh | SKIP |
| check-gdscript-only-test.sh | PASS |
| check-godot-no-script-errors.sh | PASS |
| **check-individual-edge-weight.sh** | **FAIL — blocking** |
| check-kartograph-integration-test.sh | PASS |
| check-layout-radius-bound.sh | PASS |
| check-lod-level-tests.sh | PASS |
| check-lod-opacity-animation.sh | PASS |
| check-main-local-vs-remote.sh | PASS |
| check-main-not-diverged.sh | PASS |
| check-new-modules-wired.sh | PASS |
| check-no-duplicate-toplevel-functions.sh | PASS |
| check-no-gdscript-duplicate-functions.sh | PASS |
| check-nondirectional-movement-assertions.sh | PASS |
| check-no-prohibited-tasks-open.sh | PASS |
| check-not-in-scope.sh | PASS |
| check-no-vacuous-iteration.sh | PASS |
| check-no-zero-commit-reattempt.sh | PASS |
| check-pass-report-no-raw-fail-lines.sh | PASS |
| check-pipeline-wiring.sh | SKIP |
| check-preloaded-gdscript-files.sh | PASS |
| check-prescribed-fixes-applied.sh | SKIP |
| check-prohibited-branches-deleted.sh | PASS |
| check-pytest-passes.sh | PASS — 247 passed |
| check-pytest-test-count.sh | PASS |
| check-racf-prior-cycle.sh | PASS |
| check-racf-remediation.sh | SKIP |
| check-rebased-onto-main.sh | PASS — rebased onto 6db01fe |
| check-relative-position-tests.sh | PASS |
| check-report-scope-section.sh | PASS |
| check-retry-not-scope-prohibited.sh | SKIP |
| check-ruff-format.sh | PASS |
| check-run-tests-suite-count.sh | PASS — 20 == 20 |
| check-scope-report-not-falsified.sh | PASS |
| check-script-skip-on-no-args.sh | PASS |
| check-spec-ref-matches-task.sh | SKIP (task file not found) |
| check-spec-ref-staleness.sh | PASS |
| check-spec-ref-valid.sh | PASS |
| check-state-branch-prohibited-tasks.sh | PASS |
| check-sync-divergence-impact.sh | PASS |
| check-task-ref-report-not-falsified.sh | PASS |
| check-tscn-no-dangling-references.sh | PASS |
| check-typeddict-fields-extractor-tested.sh | PASS |
| check-worker-result-clean.sh | PASS |
| extractor-lint.sh | PASS |
| godot-compile.sh | PASS |
| godot-fileaccess-tested.sh | PASS |
| godot-label3d.sh | PASS |
| godot-tests.sh | PASS — 235 passed, 0 failed |

RESULT: 1 substantive check exits non-zero: check-individual-edge-weight.sh

NOTE on race condition: origin/main is advancing continuously (intake/process commits every
few minutes). check-rebased-onto-main.sh fetches from origin at runtime, so it may show
FAIL if origin/main advances between rebase and the check run. The branch IS rebased onto
the origin/main tip at verdict time (6db01fe). Any subsequent check-rebased-onto-main FAIL
is an environmental race condition requiring another rebase + check-sync commit, not an
implementation problem.

---

## BLOCKING: check-individual-edge-weight.sh

### Context

This check was added to origin/main as part of commit `7dcd31e7` (process improvements).
It was NOT present when task-108 was originally assigned. The requirement it enforces
comes from `specs/core/visual-primitives.spec.md` §Edge Primitive §Scenario: Import-based
edges: "each edge carries the import count (number of individual import statements between
the pair)." This is NOT in `specs/visualization/spatial-structure.spec.md` (the spec
assigned to task-108), but is now a mandatory gate check.

### Check output

```
FAIL [Gate 1]: build_dependency_edges() does not emit 'weight' on
  individual cross_context / internal edges.

  The spec SHALL: 'each edge carries the import count (number of individual
  import statements between the pair).'

  Individual edge construction found at:
    463:        {"source": src, "target": tgt, "type": etype}
  but the 'weight' key is absent from those dicts.

FAIL [Gate 2]: No test in extractor/tests/test_extractor.py asserts 'weight' on a
  cross_context or internal edge.

  test_aggregate_edge_has_weight covers aggregate edges only.
```

### Required fix

**File: `extractor/extractor.py`** — `build_dependency_edges()` around line 463.

Replace the `raw_edges` set with a `dict[tuple, int]` that accumulates per-pair count:

```python
# Before (no weight):
raw_edges: set[tuple[str, str, str]] = set()
# ... loop ...
raw_edges.add((src, tgt, etype))
# emit:
{"source": src, "target": tgt, "type": etype}

# After (with weight):
raw_edge_count: dict[tuple[str, str, str], int] = {}
# ... loop ...
key = (src, tgt, etype)
raw_edge_count[key] = raw_edge_count.get(key, 0) + 1
# emit:
{"source": src, "target": tgt, "type": etype, "weight": count}
```

**File: `extractor/tests/test_extractor.py`** — add a test for individual edge weight:

```python
def test_cross_context_edge_has_weight(self, src: Path) -> None:
    """Every cross_context edge carries a weight field (import count)."""
    edges = build_dependency_edges(src, nodes)
    cc_edges = [e for e in edges if e['type'] == 'cross_context']
    assert cc_edges, 'Expected at least one cross_context edge'
    for e in cc_edges:
        assert 'weight' in e, f'cross_context edge missing weight: {e}'
        assert e['weight'] >= 1, f'weight must be >= 1: {e}'
```

After this fix, run:
```bash
bash .hyperloop/checks/check-individual-edge-weight.sh   # must exit 0
bash .hyperloop/checks/run-all-checks.sh
```

---

## Spec Requirement Review

All requirements scored against `specs/visualization/spatial-structure.spec.md` at
Spec-Ref `7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1`.

Spec drift: None. The spec at Spec-Ref is identical to HEAD.

| Requirement | Scenario | Status | Evidence |
|---|---|---|---|
| 3D Interactive Navigation | First-person exploration | COVERED | camera_controller.gd (orbit/zoom/pan); tests: test_camera_supports_zoom_in, test_camera_supports_zoom_out, test_camera_supports_orbit, test_spatial_layout_creates_node_per_structural_element |
| Structure as Persistent Geography | Structural elements have spatial presence | COVERED | main.gd _create_volume(), _create_edge(); tests: test_distinct_contexts_occupy_distinct_regions, test_context_boundary_is_visually_distinct_translucent, test_containment_expressed_as_scene_tree_parenting, test_dependency_expressed_as_visible_connection |
| Scale Through Zoom | Far — bounded contexts, aggregate edges with weight, individual hidden | COVERED | aggregate_edge_renderer.gd, lod_manager.gd _apply_far(); 5 behavioral tests in test_spatial_structure.gd |
| Scale Through Zoom | Medium — modules fade in, animated edge opacity, aggregate dissolves | PRE-EXISTING GAP | lod_manager.gd uses binary .visible (pre-existing on main, predates task-108); aggregate Tween animation is in-scope and tested |
| Scale Through Zoom | Near — all detail visible | COVERED | lod_manager.gd _apply_near(); tests: test_near_distance_shows_all_nodes, test_near_distance_shows_internal_edges_as_fine_detail |
| Scale Through Zoom | Smooth transitions | PARTIAL (pre-existing) | Aggregate edges use Tween/modulate.a (confirmed by check-lod-opacity-animation); individual edges use binary .visible in lod_manager (pre-existing gap) |
| Cluster Collapsing | All 4 scenarios | OUT OF SCOPE | prototype-scope.spec.md explicitly excludes cluster collapsing |

---

## Conclusion

All `specs/visualization/spatial-structure.spec.md` SHALL/MUST requirements are COVERED
(or carry a pre-existing gap not attributable to task-108). The FAIL verdict is driven
entirely by `check-individual-edge-weight.sh` — a gate check added to the infrastructure
after task-108 was assigned, enforcing `specs/core/visual-primitives.spec.md` §Edge
Primitive individual edge weight.

**The only required fix is in the extractor** (see Required Fix section above):
1. `extractor/extractor.py`: accumulate per-pair count in `build_dependency_edges()` and emit `weight` on each individual cross_context/internal edge
2. `extractor/tests/test_extractor.py`: add a test verifying `weight` is present on cross_context/internal edges

After fixing, also sync any new check scripts that appeared on main since this review.