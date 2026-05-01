---
id: task-128
title: "[EXCLUDED] spatial-structure.spec.md — first-person navigation not in prototype scope"
spec_ref: "specs/visualization/spatial-structure.spec.md@359dbcb1d7f64009e6dd64084a8bcbb5fa325cb4"
status: closed
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: null
pr_description: null
---

Scope review performed against `specs/prototype/prototype-scope.spec.md` § "Not In Scope".
One requirement from `specs/visualization/spatial-structure.spec.md` is excluded from the
prototype. All remaining requirements are already covered by existing tasks.

## Excluded Requirement

### Requirement: 3D Interactive Navigation (first-person)
> "The system MUST present the software system as a 3D space that the human navigates
> in first person."
> Scenario: "the human can move through it in first person"

`specs/prototype/prototype-scope.spec.md` line 95 explicitly prohibits this:

> "first-person navigation is NOT implemented"

The prototype uses a **top-down camera** (see `prototype-scope.spec.md` line 96:
"navigate with top-down camera"). First-person exploration is a future-phase capability.

**Ruling: excluded — first-person navigation is NOT IN SCOPE for the prototype.**

## Remaining Requirements — Coverage Confirmed

All other requirements in `specs/visualization/spatial-structure.spec.md` are in scope
and fully covered by existing tasks:

| Requirement | Scenario | Covering task(s) |
|---|---|---|
| Structure as Persistent Geography | Structural elements have spatial presence, containment/dependency expressed spatially | task-009 (node volumes), task-010 (nested containers), task-013 (edge lines) |
| Scale Through Zoom | Far — bounded contexts as aggregate volumes with cross-context edges | task-019 (LOD visibility), task-067 (aggregate/individual edge switching) |
| Scale Through Zoom | Medium — modules fade in, inter-module edges appear, aggregate edges dissolve | task-019, task-067 (animated opacity transitions) |
| Scale Through Zoom | Near — full detail edges, annotations, metrics visible | task-067, task-107 (near-LOD metrics label) |
| Scale Through Zoom | Smooth transitions — no pop, aggregate edges morph continuously | task-121 (smooth opacity animation), task-067 |
| Cluster Collapsing | Collapsing a cluster — members converge to supernode, edges re-routed with animation | task-068 |
| Cluster Collapsing | Expanding a supernode — members animate back to original positions | task-068 |
| Cluster Collapsing | Pre-computed cluster suggestions — visual indicator, human-initiated only | task-126 |
| Cluster Collapsing | Nested collapsing — each cluster collapses independently | task-068 |

No new tasks are required from this spec in this cycle.
