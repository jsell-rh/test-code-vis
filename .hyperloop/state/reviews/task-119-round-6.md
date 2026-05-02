---
task_id: task-119
round: 6
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-119 (Visual Primitives: Bridge Detection / Betweenness Centrality)

Spec-Ref: specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959
Task-Ref: task-119

---

## Blocking Issue

**FAIL — Branch is not rebased onto origin/main.**

- Fork point (merge-base): 45a4dca
- origin/main HEAD: 396d83a
- Commits on main NOT in branch (2):
  - 396d83ac feat(extraction): extractor — cluster detection (tightly-coupled module groups) (#231)
  - 61c9117a chore(tasks): intake visual-primitives gaps — type topology extraction and Node renderer

Merging this branch as-is would revert both commits. This is a blocking FAIL per the review protocol.

Required fix:
```
git fetch origin main:main
git rebase origin/main
# Keep all cluster detection functions/files added by main (incoming 'theirs' side)
# Apply task-119 changes on top
```

---

## Requirement Coverage

### Extraction Layer

**Requirement: Scope Nesting Extraction** — NOT IN SCOPE for task-119. Pre-existing. COVERED (not re-reviewed).

**Requirement: Module Graph Extraction** — NOT IN SCOPE for task-119. Pre-existing. COVERED (not re-reviewed).

**Requirement: Symbol Table Extraction** — NOT IN SCOPE for task-119. Pre-existing. COVERED (not re-reviewed).

**Requirement: Type Topology Extraction** — NOT IN SCOPE for task-119. Pre-existing. COVERED (not re-reviewed).

**Requirement: Call Graph Extraction** — NOT IN SCOPE for task-119. Pre-existing. COVERED (not re-reviewed).

**Requirement: Data Flow Spine Extraction** — NOT IN SCOPE for task-119. Pre-existing. COVERED (not re-reviewed).

**Requirement: Structural Significance Extraction**
Primary target of task-119. Focus on Bridge Detection scenario.

- **Scenario: Hub detection** — COVERED. Pre-existing in-degree annotation and hub flagging untouched by this branch; 248 tests pass.

- **Scenario: Bridge detection** — COVERED.
  - Implementation: extractor/extractor.py adds _compute_betweenness_centrality() using Brandes BFS; called from compute_structural_significance(). Algorithm is correct: builds shortest-path DAG, back-propagates dependency scores, normalises by 1/((n-1)*(n-2)) for directed graphs (n > 2). Adjacency list is treated as undirected (both directions added), correct for structural bridging. betweenness_centrality float stored on every node; is_bridge set separately via articulation-point DFS. This is a superset of the spec requirement.
  - Schema: extractor/schema.py adds betweenness_centrality: NotRequired[float] to Node TypedDict; validator rule 11 correctly rejects bool (checked before int/float since bool is a subtype of int) and accepts int/float.
  - Tests (extractor/tests/test_extractor.py):
    - test_betweenness_centrality_computed_for_bridge_node: GIVEN A->B->C chain THEN B has bc > 0. PASS.
    - test_betweenness_centrality_zero_for_non_bridge_in_cycle: GIVEN A->B->C->A cycle THEN all bc == 0 (all shortest paths have equal-length alternatives). PASS.
    - test_compute_betweenness_centrality_direct: unit-tests helper function directly. PASS.
    - 3 additional scene-graph output tests and 11 TestNodeMetricsValidation tests in test_schema.py. PASS.
  - All 248 pytest tests pass; no ruff violations.

- **Scenario: Peripheral detection** — COVERED. Pre-existing; not modified by this branch.

- **Scenario: Community detection** — COVERED. Pre-existing (Louvain/Leiden community detection exists and is tested); not modified by this branch.

**Requirement: Ubiquitous Dependency Detection** — NOT IN SCOPE for task-119. Pre-existing. COVERED (not re-reviewed).

---

### Composition Layer Requirements

All Composition Layer requirements (Container, Node, Badge, Edge, Port, Route, Landmark, Tint, LOD Shell, Power Rail, Overlay/Facet, Distortion Legend, Purpose-Level Annotation, Primitives Compose, Primitive Set is Closed) are Godot/renderer-side concerns.

Task-119 is Python-extractor only. No Godot files were modified. GDScript behavioral tests pass unchanged (godot-tests.sh: PASS; godot --headless compile: PASS). These requirements are not within this task's scope and are not evaluated here.

SPEC-DRIFT observation (non-blocking): The Landmark primitive scenario for bridge nodes ("GIVEN a module with high betweenness centrality... WHEN it is identified as a Landmark THEN it persists at all zoom levels") is Composition Layer / Godot behavior — not addressed by this task. This is a noted gap for a future Godot-side task, not a FAIL driver here.

---

## Quality Checks Summary

| Check                                         | Result |
|-----------------------------------------------|--------|
| Rebased onto origin/main                      | FAIL (2 commits behind) |
| Test suite count (19 suites)                  | PASS   |
| 248 pytest tests                              | PASS   |
| ruff check extractor/                         | PASS   |
| ruff format --check                           | PASS   |
| check-branch-has-impl-files.sh                | PASS   |
| check-spec-ref-staleness.sh                   | PASS   |
| check-compute-functions-called-from-entry-point.sh | PASS |
| check-typeddict-fields-extractor-tested.sh    | PASS   |
| check-tscn-no-dangling-references.sh          | PASS   |
| check-no-gdscript-duplicate-functions.sh      | PASS   |
| godot-compile.sh                              | PASS   |
| godot-tests.sh                                | PASS   |
| All other checks (60 total run)               | PASS   |

---

## Summary

The implementation for task-119 (betweenness centrality / bridge detection) is technically correct, well-tested, and spec-compliant for every in-scope SHALL requirement under Structural Significance Extraction. The sole reason for FAIL is the rebase requirement: the branch forks from 45a4dca and is missing 2 commits that origin/main has accumulated since then, including the cluster detection feature (#231). The author must rebase onto current origin/main — preserving all cluster detection additions from the incoming side — before this branch can be merged.

Action required: git rebase origin/main (keep cluster detection on theirs/incoming side), then re-submit for review.