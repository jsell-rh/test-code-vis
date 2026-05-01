---
id: task-131
title: "[DEFERRED] understanding-modes — permanently prohibited spec, no implementation tasks"
spec_ref: null
status: closed
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: null
pr_description: null
---

Scope review performed against `specs/prototype/prototype-scope.spec.md` § "Not In
Scope". `check-assigned-spec-in-scope.sh` returned EXIT 1 for the understanding-modes
specification. No implementation tasks may be created from it under any circumstances.

## Prohibition Authority

All requirements in the understanding-modes spec describe three architectural overlay
modes (comparison, quality-assessment, and impact-simulation) that are explicitly
excluded from the prototype at `specs/prototype/prototype-scope.spec.md` lines 89–91.
The cascade-depth and mode-layering requirements are extensions of those same modes.

## Mis-Assignment History

This spec has been mis-assigned 14 times across prior cycles. It is listed in the
permanently-prohibited spec table in the project guidelines. The in-scope check script
exits non-zero for this spec path; do not override that result.

## Resolution

Do not re-open or reassign. Remove from any candidate pool. Revisit only when
`specs/prototype/prototype-scope.spec.md` is revised to lift the restrictions at
lines 89–91.

## Coverage Audit — Other Specs This Cycle

All five remaining modified specs submitted in this intake cycle are either already
deferred or fully covered by prior intake tasks. No new implementation work is needed.

| Spec | Disposition | Coverage |
|---|---|---|
| system-purpose | Deferred (task-130, closed) — all requirements outside prototype scope | task-130 |
| visual-primitives | Fully covered by prior intake | task-074 – task-101, task-109 – task-125 |
| scene-graph-schema | Fully covered by prior intake | task-001, task-005, task-061, task-063, task-064, task-066, task-126 |
| orthogonal-independence | Fully covered by prior intake | task-062, task-065, task-070, task-071, task-106, task-127 |
| spatial-structure | Fully covered by prior intake (top-down-only nav correctly has no task) | task-019, task-067, task-068, task-107, task-121, task-126 |

Note: `spatial-structure.spec.md` requirement "3D Interactive Navigation" specifies a
top-down camera navigation mode for the prototype and an immersive exploration mode
for the vision. The immersive exploration mode is excluded per
`specs/prototype/prototype-scope.spec.md` line 95 and has no task (correctly).
