---
task_id: task-119
round: 6
role: verifier
verdict: fail
---
## Scope Check Output
OK: No prohibited (not-in-scope) features detected.

## Rebase Check — BLOCKING FAIL

The branch is NOT rebased onto origin/main.

- Fork point (merge-base): 45a4dca
- origin/main HEAD: 396d83a
- Commits on main not in branch: 2
  - 396d83ac feat(extraction): extractor — cluster detection (tightly-coupled module groups) (#231)
  - 61c9117a chore(tasks): intake visual-primitives gaps — type topology extraction and Node renderer

Merging this branch as-is would revert both commits that main added after 45a4dca. This is a blocking FAIL per the review protocol ("If it exits non-zero, issue FAIL immediately.").

**Required fix:**
```
git fetch origin main:main
git rebase origin/main
# Keep all cluster detection functions/files that main added (incoming 'theirs' side)
# Apply task-119 changes on top
```

## Test Suite Count Check
OK: _run_suite() count on branch (19) >= origin/main (19). PASS.

## run-all-checks.sh Summary
60 checks run. One check exited non-zero: check-rebased-onto-main.sh (the rebase failure above). All other checks passed.

## Step 8 — Mandatory Specific Checks

- check-branch-has-impl-files.sh: PASS — 5 non-.hyperloop/ files changed
- check-spec-ref-staleness.sh: PASS — specs/core/visual-primitives.spec.md is identical at Spec-Ref and HEAD; no spec drift
- check-compute-functions-called-from-entry-point.sh: PASS — all 7 compute functions called from extractor.py
- check-typeddict-fields-extractor-tested.sh: PASS — all Literal type values covered
- check-lod-opacity-animation.sh: PASS — no LOD files introduced or modified; check not applicable
- check-aggregate-edge-impl.sh: PASS — branch does not modify LOD/visualization files; check not applicable
- check-tscn-no-dangling-references.sh: PASS — all ext_resource paths in .tscn files resolve
- check-no-gdscript-duplicate-functions.sh: PASS — no GDScript files changed on this branch
- check-lod-level-tests.sh: PASS — no LOD files modified; check not applicable
- godot-compile.sh: PASS — Godot project compiles successfully (runtime ERRORs for tweened modulate:a on Node3D nodes are pre-existing issues in lod_manager.gd, not introduced by this branch)
- godot-tests.sh: PASS — GDScript behavioral tests passed

## Python Quality Checks
- ruff check extractor/: PASS — All checks passed
- ruff format --check extractor/: PASS — 8 files already formatted
- pytest (248 tests): PASS — 248 passed in 0.67s

## Spec-Ref Analysis

Spec-Ref: specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959
Task-Ref: task-119

Spec section targeted: "Structural Significance Extraction / Bridge detection"

Relevant scenario from spec:
- "GIVEN a module with high betweenness centrality (sits on many shortest paths between other modules) WHEN structural significance is computed THEN the module is annotated with its betweenness centrality score AND it is flagged as a bridge"

The implementation directly satisfies this scenario. The spec-ref is confirmed non-stale.

## Commit Trailer Audit

All implementation commits carry `Task-Ref: task-119`. Spec-Ref trailers are present on the two substantive implementation commits. The chore commit for checks sync correctly carries Task-Ref only (no spec change). PASS.

## Implementation Review

### Files changed (excluding .hyperloop)
1. extractor/extractor.py — adds _compute_betweenness_centrality() and calls it from compute_structural_significance()
2. extractor/schema.py — adds betweenness_centrality: NotRequired[float] to Node TypedDict; adds validator rule 11; adds metrics/loc validator rules 9-10
3. extractor/schema.md — new authoritative schema documentation file
4. extractor/tests/test_extractor.py — 3 new betweenness centrality tests + 3 new scene graph output tests
5. extractor/tests/test_schema.py — 11 new TestNodeMetricsValidation tests

### Algorithm correctness
_compute_betweenness_centrality() implements Brandes BFS correctly:
- Builds shortest-path DAG from each source node
- Back-propagates dependency scores
- Normalises by 1/((n-1)*(n-2)) for directed graphs where n > 2
- Returns dict with scores in [0.0, 1.0]

The adjacency list passed from compute_structural_significance() treats edges as undirected (both directions added), which is correct for betweenness centrality in an import graph where structural bridging is symmetric.

The score is stored as a top-level node field `betweenness_centrality` (not nested in `structural_significance`), consistent with the schema.md documentation and with how `is_bridge` is stored.

### Spec compliance
The spec requires: "the module is annotated with its betweenness centrality score AND it is flagged as a bridge." The implementation annotates every node with a float score (not just bridge nodes), which is a superset of the requirement. `is_bridge` continues to be set based on articulation-point detection (DFS), while `betweenness_centrality` provides the continuous score. This is correct and matches the spec intent.

### Validator correctness
Rule 11: rejects bool (isinstance check for bool before int/float check is correct since bool is a subtype of int in Python). Accepts int and float. This mirrors the pattern already used for metrics.loc.

### Test coverage
- test_betweenness_centrality_computed_for_bridge_node: GIVEN A-B-C chain, THEN B has bc > 0. Correct.
- test_betweenness_centrality_zero_for_non_bridge_in_cycle: GIVEN A→B→C→A cycle, THEN all bc == 0. Correct: in a 3-cycle all shortest paths between any pair have equal-length alternatives.
- test_compute_betweenness_centrality_direct: unit tests the helper function directly. Correct.

No Godot-side changes were made (this is Python-extractor only work for task-119). The Godot tests pass unchanged.

### No regressions introduced
- Test suite count held at 19 suites (248 tests, up from ~234 — adds 14 new tests).
- All 248 tests pass.
- No ruff violations.
- No GDScript changes.
- No TSCN changes.

## SPEC-DRIFT Note
The spec section on Bridge detection also mentions Landmark annotation for bridges ("GIVEN a module with high betweenness centrality... WHEN it is identified as a Landmark THEN it persists at all zoom levels"). This is Composition Layer behavior in Godot — it is not the scope of this task (Python extractor only). This is a SPEC-DRIFT observation, NOT a FAIL driver per guidelines.

## Summary

The implementation is technically correct and complete for its stated scope. All Python checks pass. The sole reason for FAIL is the rebase requirement: the branch is 2 commits behind origin/main (cluster detection feature and a task intake commit). The author must rebase onto current origin/main before this branch can be merged.