# Intake Decisions

Records cases where specs were reviewed but no tasks were created, with rationale.

---

## 2026-05-02 — Full batch of 5 modified specs (reviewed nine times, same day)

All five specs present in `resolved-specs.json` with blob SHAs unchanged since
2026-05-01 baseline. No reopen conditions triggered. **No tasks created.**

Ninth review (HEAD: `20461a84`): all blob SHAs identical, all in-scope requirements
confirmed covered. Task-025 failure is a rebase-only issue; fix is `git rebase origin/main`.
No decomposition change needed.

| Spec | Blob SHA | Decision |
|---|---|---|
| `specs/core/system-purpose.spec.md` | `f1f52d80` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/core/visual-primitives.spec.md` | `82d048ec` (unchanged) | **No tasks. All in-scope requirements covered.** |
| `specs/extraction/scene-graph-schema.spec.md` | `4ea7e337` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/visualization/orthogonal-independence.spec.md` | `ca0ad7af` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/visualization/spatial-structure.spec.md` | `359dbcb1` (unchanged) | **No tasks. Permanently resolved.** |

HEAD at ninth review: `20461a84`

---

## 2026-05-02 — Full batch of 5 modified specs (reviewed seven times, same day)

All five specs present in `resolved-specs.json` with blob SHAs unchanged. No reopen
conditions triggered. **No tasks created.**

Seventh review: after task-025/034 duplicate resolution (b10f564e), Badge task creation
(c51b954e), and process fix (6fa72ad2). All blob SHAs identical to the 2026-05-01
baseline. Task-025 already configured for retry (status: not-started, retry note in
pr_description). No decomposition change needed.

| Spec | Blob SHA | Decision |
|---|---|---|
| `specs/core/system-purpose.spec.md` | `f1f52d80` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/core/visual-primitives.spec.md` | `82d048ec` (unchanged) | **No tasks. All in-scope requirements covered.** |
| `specs/extraction/scene-graph-schema.spec.md` | `4ea7e337` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/visualization/orthogonal-independence.spec.md` | `ca0ad7af` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/visualization/spatial-structure.spec.md` | `359dbcb1` (unchanged) | **No tasks. Permanently resolved.** |

HEAD at seventh review: `6fa72ad2`

---

## 2026-05-02 — Full batch of 5 modified specs (reviewed five times, same day)

All five specs present in `resolved-specs.json` with blob SHAs unchanged. No reopen
conditions triggered. **No tasks created.**

Fifth review confirmed each resolved entry, including the Badge and Port Primitive
coverage under tasks 074–125 for `visual-primitives.spec.md`.

| Spec | Blob SHA | Decision |
|---|---|---|
| `specs/core/system-purpose.spec.md` | `f1f52d80` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/core/visual-primitives.spec.md` | `82d048ec` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/extraction/scene-graph-schema.spec.md` | `4ea7e337` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/visualization/orthogonal-independence.spec.md` | `ca0ad7af` (unchanged) | **No tasks. Permanently resolved.** |
| `specs/visualization/spatial-structure.spec.md` | `359dbcb1` (unchanged) | **No tasks. Permanently resolved.** |

HEAD at fifth review: `9811fd86`

---

## 2026-05-02 — Full batch of 5 modified specs (reviewed four times, same day)

All five specs were already present in `resolved-specs.json` with blob SHAs unchanged
since the 2026-05-01 review. No reopen conditions triggered. **No tasks created.**
Reviewed four times (first pass HEAD `cf00f6d4`, second pass HEAD `d567556c`, third
pass HEAD `50e9a92b`, fourth pass HEAD `82e9d5c3`) — same conclusion all four times.

| Spec | Blob SHA | Decision |
|---|---|---|
| `specs/core/system-purpose.spec.md` | `f1f52d80` (unchanged) | **No tasks. Permanently resolved.** Vision-only document; all concrete features either serve the overarching hypothesis (already covered by prototype tasks) or are prohibited (spec extraction, conformance mode). |
| `specs/core/visual-primitives.spec.md` | `82d048ec` (unchanged) | **No tasks. Permanently resolved.** All Extraction Layer and in-scope Composition Layer requirements covered. Out-of-scope items (Data Flow Spine, Badge, Port, Route, Overlay/Facet, Purpose-Level Annotation) deferred. |
| `specs/extraction/scene-graph-schema.spec.md` | `4ea7e337` (unchanged) | **No tasks. Permanently resolved.** All 7 requirements covered; Cascade Depth (simulation mode) remains prohibited. |
| `specs/visualization/orthogonal-independence.spec.md` | `ca0ad7af` (unchanged) | **No tasks. Permanently resolved.** All 3 requirements covered by existing tasks. |
| `specs/visualization/spatial-structure.spec.md` | `359dbcb1` (unchanged) | **No tasks. Permanently resolved.** All in-scope requirements covered; first-person navigation remains out of scope. |

HEAD at first review: `cf00f6d4`
HEAD at second review: `d567556c`
HEAD at third review: `50e9a92b`
HEAD at fourth review: `82e9d5c3`

---

## 2026-04-30 — Full batch of 6 modified specs

| Spec | Decision | Rationale |
|---|---|---|
| `specs/core/system-purpose.spec.md` | **No tasks. Permanently resolved.** | Vision-only document. Three requirements (Understanding Without Writing Code, Spec-Driven Context, Architecture Feedback Loop) describe long-term outcomes, not prototype implementation work. Per guidelines, core specs only generate tasks when prototype specs reference their requirements for implementation. None do. |
| `specs/core/understanding-modes.spec.md` | **No tasks. Permanently resolved. Prohibited.** | Defines Conformance Mode, Evaluation Mode, Simulation Mode (all explicitly excluded from prototype by `prototype-scope.spec.md` lines 89–91). Permanently prohibited per check-assigned-spec-in-scope.sh. |
| `specs/core/visual-primitives.spec.md` | **task-125 created.** | All Extraction Layer and Composition Layer requirements covered by tasks 074–124 except the Landmark Primitive. Task-086 (former Landmark task) is permanently closed; no open task replaced it. The Landmark primitive is a MUST requirement not listed in the prototype NOT IN SCOPE list. Task-125 implements Godot Landmark rendering derived from task-082's structural significance output. |
| `specs/extraction/scene-graph-schema.spec.md` | **task-126 created.** | Six of seven requirements covered by existing tasks. Cluster Schema requires a Godot loader extension so task-068 (collapse mechanic) can access cluster data — task-068 explicitly references "task-069's loader extension", but task-069 is permanently closed. Task-126 provides the loader extension, suggestion ring indicator, and UI trigger. |
| `specs/visualization/orthogonal-independence.spec.md` | **No tasks. Permanently resolved.** | All 3 requirements fully covered: Independence Detection → task-062; Spatial Separation → task-065, task-070, task-106; Queryable Property → task-071. Spec contents unchanged since last review. |
| `specs/visualization/spatial-structure.spec.md` | **No tasks (task-126 covers cluster suggestion).** | Structure as Persistent Geography, Scale Through Zoom, and smooth transitions covered by tasks 008, 009, 019, 067, 107, 121. Cluster Collapsing (collapse/expand/nested) covered by task-068. Pre-computed cluster suggestions indicator now covered by task-126 (same task serves both this spec and scene-graph-schema). First-person navigation excluded from prototype per prototype-scope.spec.md line 95. |

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
