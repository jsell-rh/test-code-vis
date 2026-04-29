---
task_id: task-031
round: 6
role: implementer
verdict: fail
---
## SCOPE-PROHIBITION FAIL — INVALID ASSIGNMENT (task-031)

### check-assigned-spec-in-scope.sh output (verbatim)

```
FAIL: INVALID ASSIGNMENT — 'specs/core/understanding-modes.spec.md' is a permanently prohibited spec.
  This spec describes a feature explicitly excluded from the prototype phase.
  Prohibited feature: conformance/evaluation/simulation modes (understanding modes overlay)
  Authority: specs/prototype/prototype-scope.spec.md lines 89-91

  Do NOT read the spec further.  Do NOT write any implementation code.
  Write a FAIL report that quotes this output verbatim and stop.
```

Exit code: 1

## Scope Check Output

OK: No prohibited (not-in-scope) features detected.

### Sync Point 1 and 2 Status

Checks were synced from origin/main before any action and again before final checks:

  git fetch origin main
  git checkout origin/main -- .hyperloop/checks/
  bash .hyperloop/checks/check-checks-in-sync.sh
  -> OK: All check scripts from main are present and content-identical in working tree (49 checked).

check-checks-in-sync.sh exits 0. All 49 checks including check-fail-report-classification.sh,
check-retry-not-scope-prohibited.sh, and check-main-local-vs-remote.sh are present.

### Branch Hygiene

check-branch-forked-from-main.sh exits 0 — no inherited foreign-task commits.

### No Implementation Code Written

Per the protocol, the scope check was the first action after check sync.
The spec was not read further. No implementation code was written.
No files were staged or committed beyond the check sync itself.

### check-retry-not-scope-prohibited.sh (manual invocation with task ID)

```
=== CHECK A: spec_ref scope check ===
  Task: task-031  Spec: specs/core/understanding-modes.spec.md@5014c7f3eb6eb64b86a2637ffeb78e914f9e1e9c

ERROR: Spec file not found: specs/core/understanding-modes.spec.md@5014c7f3eb6eb64b86a2637ffeb78e914f9e1e9c

  → SCOPE-PROHIBITED: spec_ref 'specs/core/understanding-modes.spec.md@5014c7f3eb6eb64b86a2637ffeb78e914f9e1e9c' is prohibited.

=== CHECK B: Task body keyword scan ===
  SCOPE-PROHIBITED: Task body references prohibited spec 'specs/core/understanding-modes.spec.md'.
    Feature: conformance/evaluation/simulation modes (understanding modes)
    Authority: specs/prototype/prototype-scope.spec.md
  SCOPE-PROHIBITED: Task body describes conformance/evaluation/simulation mode features.
    Authority: specs/prototype/prototype-scope.spec.md lines 89-91

=== CHECK C: Review file classification ===
  SKIP: No review files found for 'task-031'.

======================================================================
RESULT: SCOPE-PROHIBITION detected for task-031.
======================================================================

EXIT 1 — Retry is FORBIDDEN.
```

### run-all-checks.sh Note

run-all-checks.sh exits non-zero due to two issues:

1. check-retry-not-scope-prohibited.sh exits 2 (usage error) when called without a task ID
   argument, as run-all-checks.sh does not pass arguments to individual scripts. This is
   a script design issue — the script exits 0+SKIP for the no-arg case in analogous checks
   but exits 2 here. Manual invocation with `task-031` exits 1 (scope prohibited).

2. check-report-scope-section.sh (resolved): required the `## Scope Check Output` section
   header — now present in this report.

All 146 GDScript behavioral tests pass. All other checks exit 0.

### Classification

This is a SCOPE-PROHIBITION FAIL, not an implementation FAIL.

check-fail-report-classification.sh (present after syncing from main) classifies this as:
  CLASSIFICATION: SCOPE-PROHIBITION FAIL
  EXIT 1 — Retry is FORBIDDEN.

check-retry-not-scope-prohibited.sh (with task-031): EXIT 1 — Retry is FORBIDDEN.

### Required Orchestrator Actions

1. Permanently close task-031. Do NOT schedule another re-attempt.
2. Do NOT create a new task number for specs/core/understanding-modes.spec.md.
3. This is at minimum the second prohibited-spec assignment for this spec
   (task-028 -> task-031). Investigate and close the gap that allows prohibited
   specs back into the candidate pool.
4. Verify the spec is properly listed in check-assigned-spec-in-scope.sh and in
   any orchestrator/PM overlay tables.
5. Fix check-retry-not-scope-prohibited.sh on main: when called without a task ID,
   it should auto-detect from git branch (hyperloop/task-NNN -> task-NNN) or
   exit 0+SKIP, not exit 2 (usage error). The exit-2 behavior causes run-all-checks.sh
   to report FAIL for all implementers who sync from main.