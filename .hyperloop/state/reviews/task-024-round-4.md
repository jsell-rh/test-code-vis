---
task_id: task-024
round: 4
role: implementer
verdict: fail
---
## INVALID ASSIGNMENT — Permanently Prohibited Spec

### check-assigned-spec-in-scope.sh output (verbatim)

```
FAIL: INVALID ASSIGNMENT — 'specs/interaction/moldable-views.spec.md' is a permanently prohibited spec.
  This spec describes a feature explicitly excluded from the prototype phase.
  Prohibited feature: moldable views (LLM-powered question-driven views)
  Authority: specs/prototype/prototype-scope.spec.md line 93

  Do NOT read the spec further.  Do NOT write any implementation code.
  Write a FAIL report that quotes this output verbatim and stop.
```

Exit code: 1

### Reason for FAIL

The assigned spec `specs/interaction/moldable-views.spec.md` is permanently prohibited
by `specs/prototype/prototype-scope.spec.md` (line 93). `check-assigned-spec-in-scope.sh`
exits 1 unconditionally for this spec.

No implementation code was written. This is the correct behavior per the SCOPE COMPLIANCE
protocol — the implementer cannot resolve scope conflicts, only the orchestrator can.

### Checks Performed

- Sync Point 1: `git checkout main -- .hyperloop/checks/` completed successfully
- `check-checks-in-sync.sh`: EXIT 0 (45 check scripts present and content-identical)
- `check-assigned-spec-in-scope.sh specs/interaction/moldable-views.spec.md`: EXIT 1 (PROHIBITED)

### Prior Finding Confirmation

This is the second consecutive FAIL for task-024 with the same spec. The prior review
(in Findings) reached the same conclusion. The prohibition is unconditional.

### Recommended Orchestrator Action

1. **Permanently retire task-024** — the spec is prohibited by prototype-scope authority
   and cannot be implemented in the current prototype phase.
2. **Do not re-assign** `specs/interaction/moldable-views.spec.md` to any implementer
   until `specs/prototype/prototype-scope.spec.md` is explicitly revised to permit it.
3. No code changes were made on this branch; no cleanup is required.