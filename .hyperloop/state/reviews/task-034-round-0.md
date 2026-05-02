---
task_id: task-034
round: 0
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-034

Branch: hyperloop/task-034
Reviewer: spec-alignment-reviewer (Gate 7)
Date: 2026-05-02

---

## Check Script Results (verbatim)

Nondirectional movement assertions check:
  OK: All directional test functions use signed comparison predicates

run-all-checks.sh summary:
  RESULT: FAIL — one or more checks exited non-zero

Failing checks:
  - check-individual-edge-weight.sh [EXIT 1 — FAIL]
  - check-rebased-onto-main.sh [EXIT 1 — FAIL]

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

Data flow visualization: not implemented (correctly excluded per prototype-scope.spec.md).
Conformance mode, evaluation mode, simulation mode, moldable views, spec extraction,
first-person navigation: none present in this branch.

---

## Requirement Coverage

### Requirement: Type Topology Extraction (primary task)

#### Scenario: Inheritance chain — COVERED
- `extract_type_topology()` walks `ast.ClassDef.bases` and emits `{"type": "inherits"}` edges.
- `TestTypeTopologyExtraction.test_inheritance_edge_emitted` verifies at least one `inherits`
  edge is produced from the `src_topology` fixture (PaymentProcessor(BaseProcessor)).
- `TestTypeTopologyExtraction.test_inheritance_edge_type_is_inherits` verifies edge type value.
- NOTE: Neither test asserts the edge direction (source=PaymentProcessor module,
  target=BaseProcessor module). The THEN clause specifies direction, but this is not
  flagged as a blocking failure since the nondirectional-movement check passes and the
  direction concern here is structural correctness (edge source/target fields), not
  movement sign. The implementation code at lines 1010-1019 correctly emits
  source=source_id (containing class) and target=target_id (containing base class).

#### Scenario: Composition relationship — COVERED
- `extract_type_topology()` walks `ast.AnnAssign` nodes and emits `{"type": "has_a"}` edges.
- `TestTypeTopologyExtraction.test_composition_edge_emitted` verifies at least one `has_a`
  edge is produced.
- `TestTypeTopologyExtraction.test_composition_edge_type_is_has_a` verifies edge type value.
- NOTE: Same directional assertion gap as inheritance — source/target direction not
  tested in assertions (test only checks existence).

#### Scenario: Extraction cost — COVERED
- `test_extraction_cost_ast_only_no_type_inference` verifies that extraction with an
  external unresolvable base class completes without error (no type inference attempted).
- Implementation uses `ast.parse()` only; no cross-file type resolution.

Note on `implements` edge type: The MUST statement says "inheritance, implementation, and
composition (has-a)" but the spec defines no scenario for `implements` edges. The
implementation emits only `inherits` and `has_a`. Since there is no scenario to validate
against, this is not a scenario-level failure.

---

### Requirement: Module Graph Extraction — PARTIAL (blocking)

#### Scenario: Import-based edges — FAIL
- THEN edges A->B and A->C are emitted: COVERED (`build_dependency_edges` emits
  cross_context and internal edges).
- AND each edge carries the import count: MISSING on individual edges.

`build_dependency_edges()` at line 381 emits individual `cross_context` and `internal`
edges WITHOUT a `weight` field:
  `{"source": src, "target": tgt, "type": etype}`

Only `aggregate` edges (line 392) carry `weight`. The spec scenario says:
  "AND each edge carries the import count (number of individual import statements between
  the pair)"

The `raw_edges` data structure is a `set[tuple[str, str, EdgeType]]` — it deduplicates
edges but does not count occurrences. Individual edge weight accumulation is absent.

`check-individual-edge-weight.sh` reports:
  FAIL [Gate 1]: build_dependency_edges() does not emit 'weight' on individual
    cross_context / internal edges.
  FAIL [Gate 2]: No test in extractor/tests/test_extractor.py asserts 'weight' on a
    cross_context or internal edge.

#### Scenario: Distinction from scope nesting — COVERED (not changed on this branch)

---

### Requirement: Scope Nesting Extraction — COVERED (not changed on this branch)
All scenarios covered by prior work.

### Requirement: Symbol Table Extraction — COVERED (not changed on this branch)
`extract_symbols()` implemented; public/private visibility, signatures, badges.

### Requirement: Call Graph Extraction — COVERED (not changed on this branch)
`extract_call_graph()` implemented; direct_call, dynamic_call, weight by call site count.

### Requirement: Structural Significance Extraction — COVERED (not changed on this branch)
`compute_structural_significance()` implemented.

### Requirement: Ubiquitous Dependency Detection — COVERED (not changed on this branch)
`detect_ubiquitous_dependencies()` implemented.

### Requirement: Data Flow Spine Extraction — OUT OF SCOPE
Explicitly excluded per prototype-scope.spec.md: "AND data flow visualization is NOT
implemented."

---

### Composition Layer Requirements

All Composition Layer requirements (Container, Node, Badge, Edge, Port, Route, Landmark,
Tint, LOD Shell, Power Rail, Overlay/Facet, Distortion Legend, Purpose-Level Annotation,
Primitives Compose, Primitive Set is Closed) are NOT implemented in the extractor Python
code and are not part of this task's scope. They are addressed by separate Godot-side tasks.
The Godot tests pass (100 passed, 0 failed per godot-tests.sh).

---

## Blocking Failures

### F1 — check-individual-edge-weight.sh: FAIL (blocking)

Spec: visual-primitives.spec.md — Requirement: Module Graph Extraction
Scenario: Import-based edges
THEN: "each edge carries the import count (number of individual import statements between the pair)"

Implementation gap:
- File: extractor/extractor.py, line 381
  `{"source": src, "target": tgt, "type": etype}` — no `weight` key

Required fix:
1. Change `raw_edges: set[tuple]` to `raw_edge_count: dict[tuple, int]` and accumulate
   import counts per (source_id, target_id, etype).
2. Emit `weight` on each individual edge:
   `{"source": src, "target": tgt, "type": etype, "weight": count}`
3. Add a test asserting `weight >= 1` on cross_context and internal edges.

### F2 — check-rebased-onto-main.sh: FAIL (blocking)

Branch hyperloop/task-034 is not rebased onto origin/main.
Fork point: 31af938
origin/main HEAD: e3a4620
2 commits on main are not in this branch.

Required fix: `git fetch origin main:main && git rebase origin/main`

---

## THEN→Test Mapping (Type Topology Scenarios)

| THEN-clause | Test | Verdict |
|---|---|---|
| THEN an inheritance edge is emitted from PaymentProcessor to BaseProcessor | test_inheritance_edge_emitted (existence); test_inheritance_edge_type_is_inherits (type) | PASS (existence+type; direction not asserted but impl correct) |
| AND the edge type is 'inherits' | test_inheritance_edge_type_is_inherits | PASS |
| THEN a composition edge is emitted from Order to PaymentInfo | test_composition_edge_emitted (existence) | PASS (existence; direction not asserted) |
| AND the edge type is 'has_a' | test_composition_edge_type_is_has_a | PASS |
| THEN it requires only AST parsing (no type inference) | test_extraction_cost_ast_only_no_type_inference | PASS |
| AND each edge carries the import count (Module Graph scenario) | NO TEST; implementation missing weight on individual edges | FAIL |