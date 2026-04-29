---
task_id: task-024
round: 3
role: verifier
verdict: fail
---
# Task-024: Moldable Views — INVALID ASSIGNMENT (Prohibited Spec)

## Scope Check Output

```
OK: No prohibited (not-in-scope) features detected.
```
(`check-not-in-scope.sh` — examines implementation files, EXIT 0)

```
FAIL: INVALID ASSIGNMENT — 'specs/interaction/moldable-views.spec.md' is a permanently prohibited spec.
  This spec describes a feature explicitly excluded from the prototype phase.
  Prohibited feature: moldable views (LLM-powered question-driven views)
  Authority: specs/prototype/prototype-scope.spec.md line 93

  Do NOT read the spec further.  Do NOT write any implementation code.
  Write a FAIL report that quotes this output verbatim and stop.
```
(`check-assigned-spec-in-scope.sh specs/interaction/moldable-views.spec.md` — EXIT 1)

## run-all-checks.sh Output (verbatim summary)

All 43 automated checks pass (EXIT 0 on every check). Key results:

| Check | Result |
|-------|--------|
| check-aggregate-edge-impl.sh | OK: branch does not modify LOD/visualization files |
| check-assigned-spec-in-scope.sh | SKIP (no path provided to run-all-checks.sh — run manually) |
| check-branch-has-commits.sh | OK: 7 commit(s) above main |
| check-checks-in-sync.sh | OK: all 44 check scripts present and content-identical |
| check-circular-position-y-axis.sh | OK |
| check-clamp-boundary-tests.sh | OK: all 4 clamped variables have boundary-asserting tests |
| check-commit-trailer-task-ref.sh | OK: all Task-Ref trailers match task-024 |
| check-compute-functions-called-from-entry-point.sh | OK: all 5 compute_*() called from entry point |
| check-directional-signchain-comments.sh | OK |
| check-extractor-cli-tested.sh | OK |
| check-extractor-stdlib-only.sh | OK |
| check-gdscript-only-test.sh | OK |
| check-godot-no-script-errors.sh | Results: 154 passed, 0 failed |
| check-pytest-passes.sh | 159 passed in 0.27s |
| check-racf-prior-cycle.sh | SKIP: no prior committed FAIL report found |
| check-spec-ref-staleness.sh | OK: no drift (moldable-views.spec.md identical at Spec-Ref and HEAD) |
| check-spec-ref-valid.sh | OK: both Spec-Ref hashes resolve |
| check-tscn-no-dangling-references.sh | OK: all [ext_resource] paths resolve |
| check-typeddict-fields-extractor-tested.sh | OK: all 6 Literal values covered in test_extractor.py |
| check-lod-opacity-animation.sh | OK: branch does not modify LOD files |
| check-lod-level-tests.sh | OK: branch does not modify LOD files |
| … (all remaining checks) | EXIT 0 |

`=== Summary: 43 check(s) run ===` — **All pass.**

## compute_*() Pipeline Verification

```
Entry point file: extractor/extractor.py
OK: compute_cascade_depth() is called from extractor/extractor.py
OK: compute_clusters() is called from extractor/extractor.py
OK: compute_independence_groups() is called from extractor/extractor.py
OK: compute_layout() is called from extractor/extractor.py
OK: compute_loc() is called from extractor/extractor.py
```

## Spec-Ref Staleness Check

```
OK (no drift): specs/interaction/moldable-views.spec.md is identical at
  Spec-Ref (e2cac130819f13929ab13e324411ac7a23d66b33) and HEAD.
OK (no drift): specs/prototype/ux-polish.spec.md is identical at
  Spec-Ref (7392ee4176c1f464f5e7c34a11077a5a93cb7e7f) and HEAD.
SUMMARY: No spec drift detected across all Spec-Ref references.
```

## Commit Trailers

Trailers are present on all implementation commits:
- `Spec-Ref: specs/interaction/moldable-views.spec.md@e2cac130819f13929ab13e324411ac7a23d66b33`
- `Spec-Ref: specs/prototype/ux-polish.spec.md@7392ee4176c1f464f5e7c34a11077a5a93cb7e7f`
- `Task-Ref: task-024` (confirmed by check-commit-trailer-task-ref.sh, EXIT 0)

## Branch Diff Summary

The branch differs from main in exactly two files:

```
.hyperloop/checks/check-compute-functions-called-from-entry-point.sh  (execute bit sync)
.hyperloop/checks/check-typeddict-fields-extractor-tested.sh           (execute bit sync)
```

No implementation code for moldable-views was written. No implementation code for
anything was written — the UX Polish implementation (from a prior valid task-024
assignment) is already on main.

## Prototype-Scope Authority

`specs/prototype/prototype-scope.spec.md` line 93 explicitly prohibits this spec:

```
AND moldable views (LLM-powered question-driven views) is NOT implemented
```

This prohibition is unconditional. The assigned spec cannot be implemented in the
prototype phase.

## Requirements Table

| Requirement | Status | Notes |
|-------------|--------|-------|
| Question-Driven View Generation (MUST) | MISSING | Correctly not implemented — PROHIBITED |
| View Specs as Intermediate Representation (MUST) | MISSING | Correctly not implemented — PROHIBITED |
| Fixed Visual Primitive Set (MUST) | MISSING | Correctly not implemented — PROHIBITED |

All three MUST requirements lack implementation and test coverage. This is the
**correct behavior** given the prohibition, but per verdict rules, FAIL is the
only valid verdict when MUST requirements from the committed spec are unimplemented.

## Reason for FAIL

The assigned spec `specs/interaction/moldable-views.spec.md` is permanently
prohibited by `specs/prototype/prototype-scope.spec.md`. `check-assigned-spec-in-scope.sh`
exits 1. The implementer correctly wrote no code, but this means all three MUST
requirements are unimplemented.

**The assignment is invalid.** The orchestrator must retire task-024 or re-assign
it with a different spec. Do NOT re-assign this spec to any implementer.

## Recommended Orchestrator Action

1. **Permanently retire task-024** — the spec is prohibited by prototype-scope
   authority and cannot be implemented in the current phase.
2. **Do not re-assign** `specs/interaction/moldable-views.spec.md` until the
   prototype-scope spec is explicitly revised.
3. The pre-existing UX Polish work (already merged to main) is unaffected.
4. The two check script execute-bit syncs on this branch are harmless; they
   may be merged or discarded at the orchestrator's discretion.