---
task_id: task-108
round: 14
role: spec-reviewer
verdict: fail
---
## Review: task-108 (tenth round)

Spec: specs/visualization/spatial-structure.spec.md@7a839cc34dd84819b28b93d8a6ffe88aa0dce0f1
Branch: hyperloop/task-108

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

---

## Branch State

- Branch fork point: 86907e1c (old origin/main)
- Current origin/main: 1e336897 (1 commit ahead of fork point)
- Local main: 86907e1c (behind origin/main by 1 — environment state at time of review)

The branch is NOT rebased onto the current origin/main tip (1e336897). The origin/main
advanced during this review cycle with commit `1e336897` ("fix(process): address
task-029 and task-063 failure patterns"), which also updated `check-individual-edge-weight.sh`
and added `check-no-vacuous-iteration.sh`.

---

## Check Suite Summary

| Check | Result |
|---|---|
| check-aggregate-edge-impl.sh | PASS |
| check-branch-forked-from-main.sh | PASS (after local main updated by check-rebased-onto-main.sh fetch) |
| check-branch-has-commits.sh | PASS |
| check-branch-has-impl-files.sh | PASS |
| check-checks-in-sync.sh | **FAIL** — 1 missing (check-no-vacuous-iteration.sh), 1 stale (check-individual-edge-weight.sh) |
| check-circular-position-y-axis.sh | PASS |
| check-clamp-boundary-tests.sh | PASS |
| check-commit-trailer-task-ref.sh | PASS |
| check-compute-functions-called-from-entry-point.sh | PASS |
| check-directional-signchain-comments.sh | PASS |
| check-extractor-cli-tested.sh | PASS |
| check-gdscript-only-test.sh | PASS |
| check-godot-no-script-errors.sh | PASS |
| check-individual-edge-weight.sh | **FAIL** — Gate 1 and Gate 2 both fail |
| check-kartograph-integration-test.sh | PASS |
| check-layout-radius-bound.sh | PASS |
| check-lod-level-tests.sh | PASS |
| check-lod-opacity-animation.sh | PASS |
| check-main-local-vs-remote.sh | PASS (local main updated mid-session by fetch) |
| check-nondirectional-movement-assertions.sh | PASS |
| check-no-duplicate-toplevel-functions.sh | PASS |
| check-no-gdscript-duplicate-functions.sh | PASS |
| check-no-prohibited-tasks-open.sh | PASS |
| check-not-in-scope.sh | PASS |
| check-pass-report-no-raw-fail-lines.sh | PASS |
| check-pytest-passes.sh | PASS — 260 passed |
| check-rebased-onto-main.sh | **FAIL** — fork point 86907e1c ≠ origin/main 1e336897 |
| check-relative-position-tests.sh | PASS |
| check-report-scope-section.sh | PASS (once this report is written) |
| check-ruff-format.sh | PASS |
| check-run-tests-suite-count.sh | PASS — _run_suite count 20 ≥ origin/main 20 |
| check-spec-ref-staleness.sh | PASS |
| check-spec-ref-valid.sh | PASS |
| check-sync-divergence-impact.sh | PASS |
| check-typeddict-fields-extractor-tested.sh | PASS |
| godot-tests.sh | PASS — 172 passed, 0 failed |

---

## BLOCKING FAILURE 1: check-individual-edge-weight.sh

### Gate 1 — Implementation

`build_dependency_edges()` in `extractor/extractor.py` (lines 461–465) constructs
individual cross_context and internal edges from a raw SET with no per-pair count:

```python
# Individual cross-context and internal edges.
edges: list[Edge] = [
    {"source": src, "target": tgt, "type": etype}
    for src, tgt, etype in sorted(raw_edges)
]
```

The `raw_edges` is a `set[tuple[str, str, EdgeType]]` — all duplicate imports between
the same pair are discarded by deduplication, and no count is accumulated. The resulting
individual edge dicts have no `"weight"` key.

Aggregate edges DO carry weight (lines 470–476), but individual cross_context and
internal edges do NOT.

### Gate 2 — Test Coverage

`extractor/tests/test_extractor.py` has `test_aggregate_edge_has_weight` which covers
aggregate edges only. No test asserts `"weight"` on a `cross_context` or `internal`
edge.

### Required Fix

**In `build_dependency_edges()` (`extractor/extractor.py`):**

Replace the `raw_edges: set[tuple[str, str, EdgeType]]` with a dict that accumulates
import count per (source_id, target_id, etype) triple:

```python
raw_edge_count: dict[tuple[str, str, EdgeType], int] = {}
```

When adding edges, replace `.add(...)` with:
```python
key = (edge_src, edge_tgt, "cross_context")
raw_edge_count[key] = raw_edge_count.get(key, 0) + 1
```
and:
```python
key = (source_id, target_id, "internal")
raw_edge_count[key] = raw_edge_count.get(key, 0) + 1
```

Then emit weight on each individual edge:
```python
edges: list[Edge] = [
    {"source": src, "target": tgt, "type": etype, "weight": count}
    for (src, tgt, etype), count in sorted(raw_edge_count.items())
]
```

**In `extractor/tests/test_extractor.py`:**

Add a test that asserts `"weight"` is present on cross_context or internal edges
and uses a PRESENCE assertion (not `"weight" not in e`):

```python
def test_cross_context_edge_has_weight(self, src: Path) -> None:
    """Every cross_context edge carries a weight field (import count)."""
    edges = build_dependency_edges(src, nodes)
    cc_edges = [e for e in edges if e["type"] == "cross_context"]
    assert cc_edges, "Expected at least one cross_context edge"
    for e in cc_edges:
        assert "weight" in e, f"cross_context edge missing weight: {e}"
        assert e["weight"] >= 1, f"weight must be >= 1: {e}"
```

---

## BLOCKING FAILURE 2: check-rebased-onto-main.sh + check-checks-in-sync.sh

### Root Cause

Origin/main advanced by 1 commit during this review cycle:
- `1e336897` — "fix(process): address task-029 and task-063 failure patterns"

This commit:
1. Added `check-no-vacuous-iteration.sh` (new check, not present on branch)
2. Updated `check-individual-edge-weight.sh` content (stricter proximity logic)
3. Removed DataFlowSpine code from extractor/extractor.py and tests

The branch fork point (86907e1c) is no longer origin/main.

### Required Fix

```sh
git fetch origin main:main
git checkout main -- .hyperloop/checks/
git rebase origin/main    # apply task-108 commits on top of new origin/main
# Resolve any conflicts — keep main's additions, apply task-108 changes on top
bash .hyperloop/checks/check-checks-in-sync.sh   # must exit 0
bash .hyperloop/checks/run-all-checks.sh          # must pass
```

The `check-no-vacuous-iteration.sh` check needs to pass as well — run it after
syncing and rebase:
```sh
bash .hyperloop/checks/check-no-vacuous-iteration.sh
```

---

## Spec Requirement Analysis (spatial-structure.spec.md)

| Requirement | Scenario | Status | Notes |
|---|---|---|---|
| 3D Interactive Navigation | First-person exploration | COVERED | Orbit camera; zoom/orbit/pan behavioral tests pass in godot/tests/test_spatial_structure.gd |
| Structure as Persistent Geography | Structural elements have spatial presence | COVERED | Anchors, positions, containment, translucency all tested |
| Scale Through Zoom | Far — aggregate edges, weight, individual hidden | COVERED | aggregate_edge_renderer.gd; behavioral tests confirm one-per-pair, count, visibility at FAR/MEDIUM, individual hidden at FAR |
| Scale Through Zoom | Medium — module fade, animated edge opacity | PRE-EXISTING GAP | Binary .visible in lod_manager.gd is pre-existing on main; not this branch's remit |
| Scale Through Zoom | Near — all detail | COVERED | _apply_near() tested |
| Scale Through Zoom | Smooth transitions | PARTIAL | Tween on albedo_color:a confirmed for aggregate edges; lod_manager.gd uses binary .visible (pre-existing) |
| Cluster Collapsing (all 4 scenarios) | All | OUT OF PROTOTYPE SCOPE | Not evaluated per prototype-scope.spec.md |

All spatial-structure.spec.md SHALL requirements that are in prototype scope have
code coverage. The two FAIL verdicts above are process/check failures (individual
edge weight and stale check scripts), not spec requirement failures.

---

## Summary: What Needs To Change

1. **Rebase onto current origin/main (1e336897)**:
   ```sh
   git fetch origin main:main
   git checkout main -- .hyperloop/checks/
   git rebase origin/main
   ```

2. **Add weight to individual edges** in `extractor/extractor.py`:
   Replace `raw_edges: set` with `raw_edge_count: dict` that accumulates per-pair
   import count. Emit `"weight": count` on each individual cross_context and
   internal edge dict.

3. **Add test** in `extractor/tests/test_extractor.py`:
   A test that asserts `"weight" in e` for cross_context (or internal) edges,
   using a PRESENCE assertion (not absence). The updated check-individual-edge-weight.sh
   on origin/main will reject proximity hits where all "weight" lines are `not in`
   assertions.

4. **Run new check** `check-no-vacuous-iteration.sh` after syncing — ensure it passes.

5. **Run all checks**:
   ```sh
   bash .hyperloop/checks/run-all-checks.sh
   ```