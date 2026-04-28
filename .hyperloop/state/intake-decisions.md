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

---

## Pass 157 — 2026-04-27

| Spec | Decision |
|---|---|
| `specs/core/system-purpose.spec.md` | No tasks. Permanently resolved. |
| `specs/core/understanding-modes.spec.md` | No tasks. Permanently resolved. |

No new tasks created. Both specs confirmed in `resolved-specs.json` (entries dated
2026-04-25). Spec file contents verified unchanged:

- `system-purpose.spec.md` retains its three requirements: Understanding Without Writing
  Code, Spec-Driven Context, Architecture Feedback Loop. None referenced by any prototype
  spec for implementation. Per project guidelines, core specs only generate tasks when
  prototype specs reference their requirements.
- `understanding-modes.spec.md` retains its three modes: Conformance, Evaluation,
  Simulation. All three explicitly excluded from the prototype by
  `prototype-scope.spec.md` ("conformance mode is NOT implemented", "evaluation mode is
  NOT implemented", "simulation mode is NOT implemented").

Neither reopen condition in `resolved-specs.json` has been triggered. No task files
were written.

**ORCHESTRATOR: both queued specs are listed in `.hyperloop/state/resolved-specs.json`
with explicit reopen conditions. The guard is one check before invoking the PM agent:**

```python
resolved = load_resolved_set()  # .hyperloop/state/resolved-specs.json
if all(s in resolved for s in queued_specs):
    return  # skip — do not invoke PM agent
```

**Neither reopen condition has been triggered. Do not re-queue this batch.**
