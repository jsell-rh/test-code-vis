---
id: task-071
title: Godot — independence queryable property (orthogonal complement highlight)
spec_ref: specs/visualization/orthogonal-independence.spec.md
status: not-started
phase: null
deps: [task-070]
round: 0
branch: null
pr: null
---

Implement the interactive independence query: clicking a module reveals its orthogonal
complement (everything that can change without affecting it) and its co-dependents,
with animated transitions.

Covers `specs/visualization/orthogonal-independence.spec.md` — Requirement:
Independence as Queryable Property, Scenarios: Selecting a module shows its independent
peers, Cross-context independence:

**Trigger** — in any mode, when the human clicks a module node (type: "module"),
enter independence-query display.

**Within-context highlight**:
1. Read the clicked module's `independence_group`.
2. Within the same bounded context:
   - Modules in OTHER independence groups → highlight "INDEPENDENT" (e.g. bright cyan
     tint + `Label3D` reading "INDEPENDENT").
   - Modules in the SAME independence group → highlight "CO-DEPENDENT" (e.g. amber
     tint + `Label3D` reading "CO-DEPENDENT").
3. The selected module itself gets a brighter emissive ring.
4. Fade all highlights in over 0.3 s via `Tween`.

**Cross-context highlight**:
1. Identify the bounded context containing the selected module.
2. For every OTHER bounded context: traverse `cross_context` edges to determine whether
   that context has any transitive dependency path to the selected module's context
   (using a BFS/DFS with a visited set on the edge list).
3. Contexts with NO transitive dependency path → highlight as "FULLY INDEPENDENT"
   (e.g. bright green tint on the context volume).
4. Animate with a 0.1 s stagger after the within-context highlight begins.

**Exiting** — clicking elsewhere, pressing `Escape`, or clicking the same node again
fades all highlights out (0.3 s) and restores base appearance.

**Mode compatibility** — independence highlights overlay any active mode encoding.
Modes are not deactivated; an additional highlight layer is added and removed.

Use only GDScript and Godot 4.6 API.  No external libraries.
