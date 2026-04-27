# Intake Decisions

Records cases where specs were reviewed but no tasks were created, with rationale.

---

## 2026-04-27 — specs/core/system-purpose.spec.md & specs/core/understanding-modes.spec.md

**Decision:** No tasks created.

**Rationale:**

Per project guidelines, tasks are only created from `specs/core/` when prototype specs
reference them. `specs/prototype/prototype-scope.spec.md` explicitly excludes every
concrete feature described in these two specs:

| Feature | Core spec | Prototype verdict |
|---|---|---|
| Conformance Mode | understanding-modes.spec.md | NOT implemented |
| Evaluation Mode | understanding-modes.spec.md | NOT implemented |
| Simulation Mode | understanding-modes.spec.md | NOT implemented |
| Spec-Driven Context (spec extraction) | system-purpose.spec.md | NOT implemented |
| Architecture Feedback Loop | system-purpose.spec.md | Process vision; not buildable |
| Understanding Without Writing Code | system-purpose.spec.md | Overarching hypothesis; already drives existing 27 tasks |

These specs define the long-term product vision. They become actionable inputs in a
future phase when conformance, evaluation, and simulation modes enter prototype scope.
At that point they should be re-processed as new task inputs.
