---
task_id: task-034
round: 2
role: spec-reviewer
verdict: fail
---
## Spec Alignment Review — task-034

Branch: hyperloop/task-034
Spec: specs/core/visual-primitives.spec.md
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
  237 passed in 3.77s
  OK: All pytest tests passed.
  [EXIT 0]

check-spec-ref-matches-task.sh:
  OK: Spec-Ref path 'specs/core/visual-primitives.spec.md' matches task definition spec_ref.
  FAIL: Spec-Ref path mismatch.
    Committed Spec-Ref path : specs/prototype/prototype-scope.spec.md
    Task definition spec_ref: specs/core/visual-primitives.spec.md  (from .hyperloop/state/tasks/task-034.md)
  [EXIT 1 — FAIL]

check-rebased-onto-main.sh:
  OK: Branch 'hyperloop/task-034' is rebased onto origin/main (0d32239).
  [EXIT 0]

check-not-in-scope.sh:
  OK: No prohibited (not-in-scope) features detected.
  [EXIT 0]

run-all-checks.sh:
  RESULT: FAIL — one or more checks exited non-zero
  Only failing check: check-spec-ref-matches-task.sh
```

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

Data flow visualization: not implemented (correctly excluded per prototype-scope.spec.md).

---

## Requirement Coverage

### Requirement: Type Topology Extraction (primary task) — COVERED

#### Scenario: Inheritance chain — COVERED
- Implementation: `extract_type_topology()` in `extractor/extractor.py` (line 944) walks
  `ast.ClassDef.bases` and emits edges with `{"type": "inherits"}` (line 1028–1034).
  Unresolvable external bases are silently skipped (lines 1019–1024).
- Tests:
  - `TestTypeTopologyExtraction.test_inheritance_edge_emitted` (line 1321):
    asserts at least one `inherits` edge is produced from the `src_topology`
    fixture (PaymentProcessor(BaseProcessor)).
  - `TestTypeTopologyExtraction.test_inheritance_edge_type_is_inherits` (line 1334):
    asserts all type topology edge types are `"inherits"` or `"has_a"` (no other values).

#### Scenario: Composition relationship — COVERED
- Implementation: `extract_type_topology()` walks `ast.AnnAssign` nodes in class bodies
  and emits edges with `{"type": "has_a"}` (lines 1037–1068).
- Tests:
  - `TestTypeTopologyExtraction.test_composition_edge_emitted` (line 1346):
    asserts at least one `has_a` edge is produced from the `src_topology` fixture
    (Order has field `payment: PaymentInfo`).
  - `TestTypeTopologyExtraction.test_composition_edge_type_is_has_a` (line 1359):
    asserts all type topology edge types are `"inherits"` or `"has_a"`.

#### Scenario: Extraction cost — COVERED
- Implementation: uses only `ast.parse()` (lines 979, 1001); no cross-file type
  resolution or type inference attempted. Unresolvable external bases are silently
  skipped (check at lines 1019–1024 requires `target_id` to be a known module ID).
- Test:
  - `TestTypeTopologyExtraction.test_extraction_cost_ast_only_no_type_inference`
    (line 1371): places `pydantic.BaseModel` (an external unresolvable base) in the
    fixture, asserts extraction completes without error, and asserts no edge is
    emitted for the external base (`target != "BaseModel"`).

---

### Requirement: Module Graph Extraction — COVERED

#### Scenario: Import-based edges (weight) — COVERED
- Implementation: `build_dependency_edges()` uses `raw_edge_count: dict[tuple[str, str,
  EdgeType], int]` to accumulate per-pair import counts. Individual edges emitted at
  line 396 include `"weight": count`.
- Tests:
  - `test_cross_context_edge_has_weight` (line 417): asserts `"weight" in e` and
    `e["weight"] >= 1` for all cross_context edges.
  - `test_internal_edge_has_weight` (line 437): asserts `"weight" in e` and
    `e["weight"] >= 1` for all internal edges.

---

### Composition Layer Requirements — NOT IN SCOPE FOR THIS TASK
All Composition Layer requirements (Container, Node, Badge, Edge, Port, Route,
Landmark, Tint, LOD Shell, Power Rail, Overlay/Facet, Distortion Legend,
Purpose-Level Annotation, Primitives Compose, Primitive Set is Closed) are
addressed by separate Godot-side tasks. Not reviewed here.

### Other Extraction Layer Requirements — NOT CHANGED ON THIS BRANCH
Scope Nesting, Symbol Table, Call Graph, Structural Significance, Ubiquitous
Dependency Detection: implementations pre-exist on main; no changes on this branch;
not re-reviewed.

Data Flow Spine Extraction: OUT OF SCOPE per prototype-scope.spec.md.

---

## THEN→Test Mapping

| Spec THEN-clause | Test | Verdict |
|---|---|---|
| THEN an inheritance edge is emitted from PaymentProcessor to BaseProcessor | test_inheritance_edge_emitted (line 1321) | COVERED |
| AND the edge type is 'inherits' | test_inheritance_edge_type_is_inherits (line 1334) | COVERED |
| THEN a composition edge is emitted from Order to PaymentInfo | test_composition_edge_emitted (line 1346) | COVERED |
| AND the edge type is 'has_a' | test_composition_edge_type_is_has_a (line 1359) | COVERED |
| THEN it requires only AST parsing (no type inference) | test_extraction_cost_ast_only_no_type_inference (line 1371) | COVERED |
| AND each edge carries the import count (Module Graph scenario) | test_cross_context_edge_has_weight; test_internal_edge_has_weight | COVERED |

---

## Blocking Failure

### F1 — check-spec-ref-matches-task.sh: FAIL (blocking)

The branch contains many commits (all review/chore/fix commits before the two
final implementation commits) with the trailer:

  `Spec-Ref: specs/prototype/prototype-scope.spec.md@12e8314c64416c10c5268a9d0f3ec54edb221c07`

The task definition (`task-034.md`) specifies:

  `spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd`

The two actual implementation commits (`b1ad0578`, `68ee9e72`) correctly use
`Spec-Ref: specs/core/visual-primitives.spec.md@...` — those are fine. But the
many preceding review/fix commits use the wrong spec path, and the check treats
any mismatched Spec-Ref in any commit above origin/main as a failure.

NOTE: task-034 is marked `status: closed` (duplicate of task-025). The
orchestrator should determine whether this branch requires action or can be
superseded by task-025's work. If the task is truly closed, the Spec-Ref
mismatch in historical commits is moot — but the automated check still blocks.

Required fix (if the orchestrator wants a clean pass):
  The old commits with wrong Spec-Ref must be rebased/amended to use
  `specs/core/visual-primitives.spec.md@...`, OR the orchestrator must
  close this task and not require a passing check-spec-ref result.

All spec requirements that ARE in scope for this task are COVERED with
implementation and test evidence. The only failure is the automated
check-spec-ref-matches-task.sh gate.