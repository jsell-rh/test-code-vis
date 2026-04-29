---
task_id: task-031
round: 4
role: implementer
verdict: fail
---
INVALID ASSIGNMENT — scope check returned EXIT 1.

check-assigned-spec-in-scope.sh output (verbatim):

  FAIL: INVALID ASSIGNMENT — 'specs/core/understanding-modes.spec.md' is a permanently prohibited spec.
    This spec describes a feature explicitly excluded from the prototype phase.
    Prohibited feature: conformance/evaluation/simulation modes (understanding modes overlay)
    Authority: specs/prototype/prototype-scope.spec.md lines 89-91

    Do NOT read the spec further.  Do NOT write any implementation code.
    Write a FAIL report that quotes this output verbatim and stop.

Per protocol: no spec was read beyond what was already present in the task assignment,
no implementation code was written, and this file is left unstaged.

The assignment is invalid and must be reassigned or deferred by the orchestrator.