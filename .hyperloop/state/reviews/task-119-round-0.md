---
task_id: task-119
round: 0
role: verifier
verdict: fail
---
## Summary

**Branch:** `hyperloop/task-119`
**Commit:** `2aaeaac5` — "feat(schema): document metrics object and extend validator"
**Task:** task-119 — Schema: define `metrics` object (raw `loc` integer) on node entries
**Spec-Ref:** `specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959`
**Task-Ref:** task-119

---

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```

---

## Check Results

`run-all-checks.sh` returned **FAIL** (42 checks run, 2 failing):

### FAILING checks

**1. check-checks-in-sync.sh [EXIT 1 — FAIL]**

```
FAIL: 1 check script(s) present on main are missing from this working tree:
  check-assigned-spec-in-scope.sh

  These checks were added to main after this branch was created.
  Without syncing, they cannot fire — their FAILs are invisible to run-all-checks.sh.

  Fix: sync from main before re-running checks:
    git checkout main -- .hyperloop/checks/
    bash .hyperloop/checks/run-all-checks.sh

  This is a process violation (implementer did not sync checks as required
  by the re-attempt protocol, step 0). Every FAIL produced by missing or
  stale checks is still blocking regardless of when the change was made.
```

Root cause: `check-assigned-spec-in-scope.sh` was added to main after the branch
was created from merge-base `225845e6`. The implementer did not run
`git checkout main -- .hyperloop/checks/` before submitting.

The missing check — if run — would verify the assigned spec is in scope. The
implementation is a documentation-only schema task (schema.md + validator) which
is clearly in scope, so this check would almost certainly pass. However, the
process violation stands and is blocking per the protocol.

**2. check-report-scope-section.sh [EXIT 1 — FAIL]**

```
FAIL: .hyperloop/worker-result.yaml not found and git recovery from c8dda4e6 returned empty content.
```

This check validates that a `worker-result.yaml` (the verifier's report) contains
a `## Scope Check Output` section. At the time of the implementer's submission,
no `worker-result.yaml` existed in the working tree. This is a process violation:
the implementer should have drafted a self-report before submitting, or at minimum
the checks must not fail because the report is missing at submission time.

Note: This check is the verifier's self-report check; the verifier (not the
implementer) is responsible for writing `worker-result.yaml`. The failure here
reflects that the implementer submitted without a prior self-assessment report.
This check is not attributable as an implementation quality failure, but it does
cause run-all-checks.sh to exit non-zero.

### All other checks (40/42) PASS

Notable passing checks:
- check-not-in-scope.sh: OK — no prohibited features
- check-pytest-passes.sh: 170 passed
- check-godot-no-script-errors.sh: 154 passed, 0 failed
- check-compute-functions-called-from-entry-point.sh: all 5 compute_* functions called
- check-typeddict-fields-extractor-tested.sh: all Literal values covered
- check-spec-ref-staleness.sh: no drift — spec identical at Spec-Ref and HEAD
- check-spec-ref-valid.sh: commit and file both resolve
- check-commit-trailer-task-ref.sh: Task-Ref matches task-119
- check-ruff-format.sh: all files correctly formatted
- check-new-modules-wired.sh: extractor/schema.py is imported by production code
- check-lod-opacity-animation.sh: not applicable (no LOD files modified)
- check-aggregate-edge-impl.sh: not applicable
- check-tscn-no-dangling-references.sh: all resolved
- check-lod-level-tests.sh: not applicable

---

## Spec-Drift Detection

Spec at Spec-Ref (`67df14bc`) is **identical** to spec at HEAD. No drift.

Relevant spec requirement (LOD Shell Primitive, Scenario: Three-tier LOD):
> tier 0 (far): the context is a single Container with aggregate metrics
> (total LOC, total in-degree, total out-degree) and its Landmarks

This task documents the `metrics.loc` field that supplies the "total LOC"
value to the LOD tier-0 display. The spec does not change between Spec-Ref
and HEAD.

---

## Requirement Coverage

### Task-defined requirements

**R1 — Schema document: add `metrics` object to Node fields section**
Status: COVERED
The `extractor/schema.md` was created as a new authoritative schema document.
It includes a "### Metrics object" subsection defining:
- `loc` (integer, required when metrics present): raw source line count
- Per-type semantics: bounded_context = sum of descendants; module = direct;
  class/function = declaration block
- Non-negative integer constraint (>= 0)

**R2 — Schema document: clarify `size` field distinction**
Status: COVERED
The `size` field entry reads: "Normalised visual scale factor derived from
`metrics.loc`. ... Do NOT use `size` for display of raw line counts — use
`metrics.loc` instead."
A dedicated "Relationship between `metrics.loc` and `size`" paragraph makes
the distinction explicit.

Note: The task spec's illustrative formula for `size` was
`max(0.5, min(10.0, loc / LOC_SCALE_DIVISOR))` but `schema.md` documents the
actual extractor formula as `max(0.5, log1p(loc) / log(10))`. This diverges
from the task description's example but is consistent with the extractor's
actual implementation. This is acceptable since the task's formula was
illustrative of the loc/size distinction, not a hard constraint.

**R3 — Schema document: worked example showing both fields on same node**
Status: COVERED
Two worked examples are provided:
1. Bounded context node with `metrics: { "loc": 3200 }` and `size: 3.2`
2. Spec node without metrics (showing absent = not applicable)
The required example `{ "id": "iam", ..., "size": 3.2, "metrics": { "loc": 3200 } }`
matches the task specification exactly.

**R4 — Validator: metrics if present must be a dict**
Status: COVERED — implemented in `schema.py:validate_scene_graph()` and tested.
Rule 9: `if "metrics" in node: if not isinstance(metrics, dict): raise ValueError(...)`

**R5 — Validator: metrics.loc if present must be a non-negative integer**
Status: COVERED — implemented and tested.
Rule 10: checks `isinstance(loc, int)`, rejects `bool` (explicit guard), rejects
values `< 0`.

**R6 — Validator: metrics optional on all node types**
Status: COVERED — implementation uses `if "metrics" in node` guard; absent means
"not yet computed". Tested by `test_valid_graph_without_metrics_passes`.

**R7 — Validator: additive — no existing validation rules removed**
Status: COVERED — the diff shows only additions to `validate_scene_graph()`. All
prior validation rules are intact. Confirmed by all 170 tests passing.

**R8 — No extractor logic changes**
Status: COVERED — commit diff touches only `extractor/schema.md` (new file),
`extractor/schema.py` (additive validator extension), and
`extractor/tests/test_schema.py` (new test class). No extractor logic modified.

### Spec-level requirement (LOD Shell tier-0)

**Spec R1 — LOD Shell tier-0 SHALL display "total LOC" from aggregate metrics**
Status: COVERED (documentation contract)
The `metrics.loc` field is now formally defined in the schema document and
enforced by the validator. The actual emission of `metrics.loc` values is
task-120's responsibility (explicitly stated in task-119). This task fulfils
the schema contract that task-104 (LOD display) reads.

---

## Test Coverage

All 11 new tests in `TestNodeMetricsValidation` cover the spec scenarios:

| Test | Scenario |
|---|---|
| test_valid_graph_without_metrics_passes | absent metrics is valid |
| test_valid_graph_with_metrics_loc_passes | metrics with non-negative loc passes |
| test_metrics_zero_loc_passes | zero is a valid non-negative int |
| test_metrics_not_a_dict_raises | non-dict metrics raises ValueError |
| test_metrics_as_list_raises | list metrics raises ValueError |
| test_metrics_loc_negative_raises | negative loc raises ValueError |
| test_metrics_loc_float_raises | float loc raises ValueError |
| test_metrics_loc_bool_raises | bool rejected despite being int subtype |
| test_metrics_without_loc_passes | loc absent within metrics dict is valid |
| test_metrics_on_module_node_passes | metrics valid on module nodes |
| test_metrics_loc_distinguishable_from_size | loc is int; size is float; different purposes |

All 11 tests PASS.

---

## Commit Trailer Review

```
Spec-Ref: specs/core/visual-primitives.spec.md@67df14bc9137e80de5a60d12dad7f77c7d995959
Task-Ref: task-119
```

- Spec-Ref: VALID — commit resolves, file resolves, no spec drift.
- Task-Ref: VALID — matches branch task ID.

---

## Verdict Rationale

**FAIL** — `run-all-checks.sh` exits non-zero due to two failing checks:

1. **check-checks-in-sync.sh** — The implementer did not sync `check-assigned-spec-in-scope.sh`
   from main before submitting. This is a documented process violation. Per protocol, this
   is a blocking FAIL regardless of implementation correctness.

2. **check-report-scope-section.sh** — No `worker-result.yaml` was present at submission
   time. While this is the verifier's report (not the implementer's deliverable), the check
   fires during `run-all-checks.sh` and contributes to the non-zero exit code.

**Implementation quality:** The implementation is correct and complete. All task-119
requirements are COVERED. The 11 new tests exercise all specified validation scenarios.
No prohibited features are introduced. The commit is atomic and well-described.

**Required fix:** Sync checks from main and re-submit:
```
git checkout main -- .hyperloop/checks/
bash .hyperloop/checks/run-all-checks.sh
```
If `check-assigned-spec-in-scope.sh` passes (it almost certainly will for this in-scope
schema task), the only remaining blocker is the `check-report-scope-section.sh` which
requires `worker-result.yaml` to exist before running `run-all-checks.sh`.