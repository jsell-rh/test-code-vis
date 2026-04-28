---
id: task-114
title: Schema — blast-radius weight field on edges in failure-overlay output
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-001, task-072, task-102]
round: 0
branch: null
pr: null
---

Document the `blast_radius` weight field that the Godot failure-overlay BFS
engine (task-115) annotates on each edge during a failure simulation, so the
data contract between the cascade engine and the edge renderer is defined in
one place.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Overlay/Facet
Composition, Scenario: Switching from dependency view to failure view ("Edge
weights shift to encode blast radius instead of import count AND the underlying
topology does NOT change"):

In the default dependency view, edge visual thickness is proportional to import
count (task-094). The failure-mode overlay must reassign edge thickness to encode
blast radius — how many downstream nodes are reachable through each edge. That
runtime quantity needs a named, documented field so task-115 (Godot rendering)
and any future components can reference a stable contract rather than inventing
conventions independently. This task provides that contract documentation.

---

**Deliverable — new subsection in `extractor/schema.md`**

Add a subsection `### Edge blast-radius (failure-overlay runtime field)` inside
the existing `## Simulation Output (Runtime Format)` section added by task-102.
This subsection documents the field that task-115 writes at runtime on edge
records held in memory; it is NOT serialised to the static scene graph JSON file
and does NOT require a validator change.

---

**Field definition** — for each edge record that the failure-overlay engine
processes, add:

```
blast_radius (integer ≥ 0)
  Set at runtime by the failure-overlay edge encoder (task-115).
  Absent in the static scene graph JSON; present only in the in-memory edge
  representation during an active failure simulation.

  Definition: the number of graph nodes reachable from the edge's source node
  (edge.source) in the reverse dependency direction, computed during the same
  BFS that assigns cascade depth to nodes (task-048). In other words,
  blast_radius of edge A → B equals the cascade depth-count of node A: how
  many nodes in the system are affected if A were to fail.

  Equivalence to cascade depth: blast_radius of edge A → B == depth of node A
  as assigned by task-048's BFS when the failure origin is the node that A
  directly depends on.

  Edges whose source node was NOT reached by the cascade BFS (i.e. the source
  node is not in the affected set) carry blast_radius = 0.

  Minimum value: 0.
```

---

**Normalisation contract** — reproduce in the schema document:

```
max_blast  = maximum blast_radius across all edges for the current origin(s)
ratio      = blast_radius / max_blast         (float in [0.0, 1.0])
             If max_blast == 0, ratio = 0 for all edges (no affected edges).

thickness  = lerp(MIN_THICKNESS, MAX_THICKNESS, ratio)

MIN_THICKNESS = 0.5   # hairline; same as a weight-1 import-count edge
MAX_THICKNESS = 6.0   # maximum thickness; same as the heaviest import-count edge
```

These constants are reproduced in the schema document so that task-115 reads
them from one authoritative location.

---

**Worked example** — add to the schema document:

```
# Edge A.application → A.domain with blast_radius = 8
# (8 nodes are reachable through the cascade via A.application)
{
  "source": "a.application",
  "target": "a.domain",
  "type": "internal",
  "weight": 3,          # static import count from the scene graph JSON
  "blast_radius": 8     # runtime, set during failure simulation
}
```

---

**Restoration contract** — also document:

When the failure simulation is reset (Escape / Reset button, task-035), all
in-memory `blast_radius` values are cleared from edge records and thickness is
restored from the static `weight` field.

---

**No JSON schema changes** — `blast_radius` is a runtime-only field. The
static scene graph JSON file is unchanged. No validator updates are required.

**No extractor changes** — the Python extractor does not compute blast_radius.

**No Godot implementation changes** — task-115 implements the engine described
here. This task only adds the formal documentation.
