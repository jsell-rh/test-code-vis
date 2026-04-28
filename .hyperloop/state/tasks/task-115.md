---
id: task-115
title: Godot — failure-mode overlay: edge blast-radius weight encoding
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-035, task-048, task-094, task-110, task-114]
round: 0
branch: null
pr: null
---

When a failure is injected (task-035), replace edge visual thickness (normally
encoding import count) with blast-radius encoding — thickness proportional to
how many downstream nodes are reachable through each edge — so that the human
can immediately see which dependency paths carry the highest cascade risk.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Overlay/Facet
Composition, Scenario: Switching from dependency view to failure view ("Edge
weights shift to encode blast radius instead of import count AND the underlying
topology does NOT change"):

Task-094 encodes edge thickness from the static `weight` field (import count).
Task-048 computes per-node cascade depth during failure simulation and changes
NODE colours. Neither task changes edge thickness in failure mode. This task
closes the gap: when a failure is active, each edge's thickness shifts from
import count to blast-radius, making the structure of the cascade visible in
the connections, not only in the nodes.

---

**Blast-radius computation** — immediately after task-048 completes its BFS
and assigns depths to nodes:

1. Read the BFS result: `cascade_depths: Dictionary` → `{ node_id: depth }`.

2. For every loaded edge record (all types: `cross_context`, `internal`,
   `direct_call`, `dynamic_call`, `inherits`, `has_a`, `aggregate`):

   - Look up `cascade_depths.get(edge.source, -1)`:
     - If the source node IS in the cascade (depth ≥ 1):
       `blast_radius = cascade_depths[edge.source]`
     - If the source node is NOT in the cascade (depth == -1):
       `blast_radius = 0`

   - Store `blast_radius` on the in-memory edge record as described in task-114.

3. Compute `max_blast = cascade_depths.values().max()`. If the cascade is
   empty (no affected nodes), `max_blast = 0`; skip all thickness updates.

4. For each edge visual (created by task-094 and its LOD extensions):
   ```gdscript
   var ratio: float = 0.0
   if max_blast > 0:
       ratio = float(blast_radius) / float(max_blast)
   var thickness := lerpf(MIN_THICKNESS, MAX_THICKNESS, ratio)
   # Apply to the edge's MeshInstance3D or ImmediateMesh line width:
   edge_visual.set_thickness(thickness)
   ```
   Use the constants from task-114:
   - `MIN_THICKNESS = 0.5`
   - `MAX_THICKNESS = 6.0`

   Edges with `blast_radius = 0` (source not in cascade) receive `MIN_THICKNESS`,
   making them visually recede — the human focuses on high-blast-radius paths.

---

**Animated transition** — the shift from import-count thickness to blast-radius
thickness must not snap. Use `create_tween()` to animate each edge's thickness
from its current value to the new blast-radius value over `0.25 s`.

- Start the tweens immediately after blast_radius values are computed, in the
  same frame that task-048 applies node gradient colours.
- Use `Tween.tween_method()` targeting the edge mesh's line width setter.
- If an edge already has an active thickness tween from a previous simulation
  reset/reinit, kill it before starting the new one.

---

**Restoration** — when the failure simulation is reset (Escape or Reset,
task-035's cleanup):

1. For each edge visual: animate thickness back to the static import-count value
   (`edge_weight_thickness(edge.weight)` from task-094's original algorithm)
   over `0.20 s` using `create_tween()`.
2. After all tweens complete, clear `blast_radius` from all in-memory edge
   records.

Integrate with task-035's existing cleanup sequence: add a call to
`_restore_edge_thickness()` alongside the existing node-colour reset.

---

**Dynamic call edges with null target** — `dynamic_call` edges where target
is null have no visual geometry in some configurations (task-109). If the edge
visual does not exist, skip silently.

**LOD-hidden edges** — edges currently hidden by LOD (not visible) still have
their `blast_radius` set, so that when the human zooms in while a simulation is
active, the edges fade in already showing blast-radius thickness, not a stale
import-count thickness.

**Mode compatibility** — this task operates only when a failure is active in
Simulation Mode. If Conformance Mode or Evaluation Mode is also active, their
visual channels (node fill, border rings) are unaffected. Edge thickness is an
independent perceptual channel (line thickness), distinct from those modes'
channels (hue fill, border width). No conflict.

**Multi-failure** — when multiple nodes are failed simultaneously (task-035's
multi-failure feature), task-048 assigns minimum depth for nodes reachable from
multiple origins. `blast_radius` for each edge = the depth of its source node
from that same minimum-depth assignment. No special multi-failure logic is
needed here beyond reusing task-048's merged depth dictionary.

---

**Distortion Legend update** — task-110 says: "If a future task introduces an
overlay that reassigns edge weight to a different quantity, that task is
responsible for updating `EdgeWeightLabel.text`."

When a failure is active, update the `EdgeWeightLabel` (task-110) text to:
```
Edge thickness: blast radius
```

When the failure is reset, restore to:
```
Edge thickness: import count
```

Connect to task-035's `failure_injected` and `failure_reset` signals (or the
equivalent state-change events) to trigger the label text update.

---

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
