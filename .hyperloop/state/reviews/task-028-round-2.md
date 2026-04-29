---
task_id: task-028
round: 2
role: implementer
verdict: fail
---
## Assignment Invalidity — Spec Prohibited by Scope Authority

This task assignment is **INVALID**. The very first required action — running
`check-assigned-spec-in-scope.sh` before reading the spec or writing any code —
returned exit 1 with the following output:

```
FAIL: INVALID ASSIGNMENT — 'specs/core/understanding-modes.spec.md' is a permanently prohibited spec.
  This spec describes a feature explicitly excluded from the prototype phase.
  Prohibited feature: conformance/evaluation/simulation modes (understanding modes overlay)
  Authority: specs/prototype/prototype-scope.spec.md lines 89-91

  Do NOT read the spec further.  Do NOT write any implementation code.
  Write a FAIL report that quotes this output verbatim and stop.
```

Per the guidelines, no implementation code was written beyond syncing the
check scripts themselves from main (which `check-checks-in-sync.sh` requires
as step 0 of any re-attempt).

---

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

---

## Root Cause

`specs/prototype/prototype-scope.spec.md` (the PROTOTYPE-SCOPE AUTHORITY with
VETO POWER over every other spec) explicitly prohibits all three MUST-level
requirements of the assigned spec:

- Conformance mode (spec overlay comparison) — NOT implemented per scope §"Not In Scope"
- Evaluation mode (architectural quality assessment) — NOT implemented per scope §"Not In Scope"
- Simulation mode (hypothetical change impact) — NOT implemented per scope §"Not In Scope"

This is an irresolvable spec conflict. Only the orchestrator can resolve it,
by taking one of these actions before any re-assignment:

**Option A** — Remove `specs/core/understanding-modes.spec.md` from the
prohibited list in `prototype-scope.spec.md` and update
`check-assigned-spec-in-scope.sh` and `check-not-in-scope.sh` accordingly.
This unblocks the implementer to build the overlay.

**Option B** — Accept that this spec is permanently out of scope for the
prototype phase and close/defer `task-028` without further re-assignment.
The system-purpose spec requirements (which overlap partially with the goals
of this spec) are already fully implemented and passing.

---

## RACF Resolution

The prior-cycle RACF failure was `check-report-scope-section.sh`, caused by the
orchestrator cleanup commit leaving `worker-result.yaml` empty in git history,
which caused `check-report-scope-section.sh` to be unable to find the required
`## Scope Check Output` section.

This report includes the required `## Scope Check Output` section (above) with
the verbatim stdout of `check-not-in-scope.sh`, resolving the RACF.

---

## What Is Correctly Implemented (Not Disputed)

All non-conflicted requirements verified passing in this cycle:

- Python extractor: all tests pass; `compute_layout()` and `compute_loc()`
  called from entry point; all Literal TypedDict values tested.
- GDScript tests: all test suites pass.
- Label3D readability: `billboard == BILLBOARD_ENABLED` and `pixel_size > 0.0`
  set and tested.
- Camera controls: pan, zoom, orbit with signed derivation comments.
- TSCN scene integrity: no dangling ext_resource references.
- Commit trailers: Spec-Ref and Task-Ref present on all implementation commits.
- `check-not-in-scope.sh`: EXIT 0 — no prohibited features in codebase.