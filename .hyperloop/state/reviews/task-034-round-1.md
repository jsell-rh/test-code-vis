---
task_id: task-034
round: 1
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-034

Branch: hyperloop/task-034
Spec: specs/visualization/visual-primitives.spec.md
Reviewer: spec-alignment-reviewer (Gate 7)
Date: 2026-05-02

---

## Check Script Results (verbatim)

```
check-individual-edge-weight.sh:
  OK [Gate 1]: Individual edge 'weight' field detected.
    ('weight' key in individual edge dict near line 396)
  OK [Gate 2]: Test coverage for individual edge weight found.
    (named test: test_cross_context_edge_has_weight at line 417)
    (weight assertion near cross_context/internal at line 428)
  OK: Individual cross_context/internal edges carry weight — implementation and tests confirmed.
  [EXIT 0]

check-nondirectional-movement-assertions.sh:
  OK: All directional test functions use signed comparison predicates
  [EXIT 0]

check-pytest-passes.sh:
  237 passed in 6.56s
  OK: All pytest tests passed.
  [EXIT 0]

check-rebased-onto-main.sh:
  FAIL: Branch 'hyperloop/task-034' is NOT rebased onto origin/main.
    Fork point (merge-base): 53b1865
    origin/main HEAD:        452593e
    Commits on main not in branch: 4
  [EXIT 1 — FAIL]

run-all-checks.sh:
  RESULT: FAIL — one or more checks exited non-zero
  Only failing check: check-rebased-onto-main.sh
```

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

Data flow visualization: not implemented (correctly excluded per prototype-scope.spec.md).
Conformance mode, evaluation mode, simulation mode, moldable views, spec extraction,
first-person navigation: none present in this branch.

---

## Requirement Coverage

### Requirement: Type Topology Extraction (primary task) — COVERED

#### Scenario: Inheritance chain — COVERED
- Implementation: `extract_type_topology()` in `extractor/extractor.py` walks
  `ast.ClassDef.bases` and emits edges with `{"type": "inherits"}`.
- Tests:
  - `TestTypeTopologyExtraction.test_inheritance_edge_emitted` (line 1321):
    asserts at least one `inherits` edge is produced from the `src_topology`
    fixture (PaymentProcessor(BaseProcessor)).
  - `TestTypeTopologyExtraction.test_inheritance_edge_type_is_inherits` (line 1334):
    asserts edge type value is exactly `"inherits"`.

#### Scenario: Composition relationship — COVERED
- Implementation: `extract_type_topology()` walks `ast.AnnAssign` nodes and
  emits edges with `{"type": "has_a"}`.
- Tests:
  - `TestTypeTopologyExtraction.test_composition_edge_emitted` (line 1346):
    asserts at least one `has_a` edge is produced.
  - `TestTypeTopologyExtraction.test_composition_edge_type_is_has_a` (line 1359):
    asserts edge type value is exactly `"has_a"`.

#### Scenario: Extraction cost — COVERED
- Implementation: uses `ast.parse()` only; no cross-file type resolution or
  type inference attempted. Unresolvable external bases are silently skipped.
- Test:
  - `TestTypeTopologyExtraction.test_extraction_cost_ast_only_no_type_inference`
    (line 1371): places an external unresolvable base class (`pydantic.BaseModel`)
    in the fixture, asserts extraction completes without error, and asserts no
    edge is emitted for the external base.

---

### Requirement: Module Graph Extraction — COVERED (F1 resolved)

#### Scenario: Import-based edges — COVERED
The previously-blocking F1 (individual edge weight missing) has been fixed in
commit `8b36185f fix(task-034): emit weight on individual cross_context/internal edges`.

- Implementation: `build_dependency_edges()` now uses
  `raw_edge_count: dict[tuple[str, str, EdgeType], int]` (line 330) to
  accumulate per-pair import counts. Individual edges are emitted at line 396:
  `{"source": src, "target": tgt, "type": etype, "weight": count}`.
- Tests:
  - `test_cross_context_edge_has_weight` (line 417): iterates all `cross_context`
    edges and asserts `"weight" in e` and `e["weight"] >= 1`.
  - `test_internal_edge_has_weight` (line 437): iterates all `internal` edges
    and asserts `"weight" in e` and `e["weight"] >= 1`.

NOTE: `check-individual-edge-weight.sh` reports EXIT 0 — both gates pass.

NOTE: Main branch commit `c6a13580` (task-040) landed an independent implementation
of the same fix. When the rebase occurs, `extractor/extractor.py` and
`extractor/tests/test_extractor.py` will have conflicts in the edge-weight area.
The implementer MUST keep main's implementation (task-040) and discard task-034's
duplicate, while preserving task-034's unique additions (type topology implementation
and tests).

#### Scenario: Distinction from scope nesting — COVERED (not changed on this branch)

---

### Requirement: Scope Nesting Extraction — COVERED (not changed on this branch)
### Requirement: Symbol Table Extraction — COVERED (not changed on this branch)
### Requirement: Call Graph Extraction — COVERED (not changed on this branch)
### Requirement: Structural Significance Extraction — COVERED (not changed on this branch)
### Requirement: Ubiquitous Dependency Detection — COVERED (not changed on this branch)
### Requirement: Data Flow Spine Extraction — OUT OF SCOPE
  (excluded per prototype-scope.spec.md)

### Composition Layer Requirements — NOT IN SCOPE FOR THIS TASK
All Composition Layer requirements (Container, Node, Badge, Edge, Port, Route,
Landmark, Tint, LOD Shell, Power Rail, Overlay/Facet, Distortion Legend,
Purpose-Level Annotation, Primitives Compose, Primitive Set is Closed) are
addressed by separate Godot-side tasks. The Godot test suite passes (100 passed,
0 failed per godot-tests.sh).

---

## THEN→Test Mapping

| Spec THEN-clause | Test | Verdict |
|---|---|---|
| THEN an inheritance edge is emitted from PaymentProcessor to BaseProcessor | test_inheritance_edge_emitted (existence) | COVERED |
| AND the edge type is 'inherits' | test_inheritance_edge_type_is_inherits | COVERED |
| THEN a composition edge is emitted from Order to PaymentInfo | test_composition_edge_emitted (existence) | COVERED |
| AND the edge type is 'has_a' | test_composition_edge_type_is_has_a | COVERED |
| THEN it requires only AST parsing (no type inference) | test_extraction_cost_ast_only_no_type_inference | COVERED |
| AND each edge carries the import count (Module Graph scenario) | test_cross_context_edge_has_weight; test_internal_edge_has_weight | COVERED |

---

## Blocking Failure

### F1 — check-rebased-onto-main.sh: FAIL (blocking)

Branch `hyperloop/task-034` is not rebased onto `origin/main`.

  Fork point: 53b1865
  origin/main HEAD: 452593e
  Commits on main not in this branch (4):
    452593ee feat(core): schema — define `metrics` object (raw `loc` integer) on node entries (#213)
    c6a13580 feat(core): add import-count weight to individual dependency edges (#238)
    058f1eb7 chore(intake): ninth review — same five specs, no new tasks (2026-05-02)
    20461a84 feat(extractor): add symbol table extraction and node symbols schema field (#234)

IMPORTANT: `c6a13580` (task-040) on main is a parallel implementation of the
same individual-edge-weight fix that task-034 applied. The rebase will produce
conflicts in `extractor/extractor.py` and `extractor/tests/test_extractor.py`.

Required fix:
  1. `git fetch origin main:main && git rebase origin/main`
  2. In extractor/extractor.py conflicts: KEEP main's implementation (task-040);
     DISCARD task-034's duplicate weight code. PRESERVE task-034's type topology
     additions (extract_type_topology, _position_spec_nodes, discover_spec_nodes,
     and related logic).
  3. In extractor/tests/test_extractor.py conflicts: KEEP main's weight tests;
     PRESERVE task-034's type topology tests (TestTypeTopologyExtraction class
     and src_topology fixture).
  4. After rebase: run `bash .hyperloop/checks/check-run-tests-suite-count.sh`
     then `bash .hyperloop/checks/run-all-checks.sh` to verify all checks pass.