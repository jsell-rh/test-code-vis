---
id: task-107
title: Godot — near-LOD floating metrics label on module nodes
spec_ref: specs/visualization/spatial-structure.spec.md
status: not-started
phase: null
deps: [task-009, task-067, task-082]
round: 0
branch: null
pr: null
---

Add a persistent floating metrics label to each module node that becomes visible
when the camera is at near LOD distance, so that the near view is semantically
complete — showing LOC, in-degree, and out-degree without requiring a click.

Covers `specs/visualization/spatial-structure.spec.md` — Requirement: Scale Through
Zoom, Scenario: Near — full detail ("all edges, annotations, and metrics for that
module are visible AND the transition from medium to near is continuous — no elements
pop in or snap to visibility"):

---

**Context:**

Task-104 implements aggregate metrics labels (LOC, in-degree, out-degree) on
bounded-context nodes at the FAR LOD tier, making the far view semantically
complete. This task is the parallel implementation for MODULE nodes at the NEAR
LOD tier. The pattern is the same; the node type and LOD tier differ.

---

**Metric computation** — on scene graph load, for each node with `type == "module"`:

1. **LOC**: read `node["metrics"]["loc"]` from the loaded scene graph (integer).
   If absent, treat as 0.

2. **in_degree**: prefer `node["significance"]["in_degree"]` if `significance`
   is present (populated by task-082). Otherwise count edges in the loaded edge
   list where `target == node["id"]` and `type` is not `"aggregate"` (fallback
   for scene graphs produced without `--significance`).

3. **out_degree**: count edges in the loaded edge list where
   `source == node["id"]` and `type` is not `"aggregate"`.

Format the metrics string:
```
LOC: <loc>   In: <in_degree>   Out: <out_degree>
```
Use comma thousands-separators on LOC when LOC ≥ 1,000 (e.g. `LOC: 12,400`).

---

**Label creation** — after module volume meshes are instantiated (task-009),
for each `module` node:

1. Create a `Label3D` node:
   - `text`: the formatted metrics string.
   - `font_size`: 9 (smaller than node name labels, which are typically 12–14;
     smaller than the bounded-context metrics label in task-104, which is 10).
   - `billboard`: `BaseMaterial3D.BILLBOARD_ENABLED`.
   - `modulate`: `Color(0.80, 0.80, 0.80, 1.0)` (light grey, readable against
     the dark module material; less prominent than the node name label).
   - Position: directly below the module name label. Place at
     `node_position + Vector3(0, -(node_size * 0.5 + 0.25), 0)` (below the
     node volume, not above, to avoid overlapping the node name).
   - Name the node `"ModuleMetricsLabel"` for future reference.

2. Add `ModuleMetricsLabel` as a child of the same `Node3D` root that owns the
   module `MeshInstance3D` (sibling to the existing name `Label3D`).

3. **Initial state**: `visible = false`, `modulate.a = 0.0`.

---

**LOD integration** — hook into task-067's LOD update logic:

The near threshold used here is the same `NEAR_THRESHOLD` constant defined in
task-067 (the distance within which a module transitions from medium to near).

- **Near tier active** (camera within `NEAR_THRESHOLD` of this module): if
  `ModuleMetricsLabel.visible == false`:
  - Set `ModuleMetricsLabel.visible = true`.
  - Tween `ModuleMetricsLabel.modulate.a` from `0.0` to `1.0` over `0.30 s`.

- **Near tier NOT active** (camera farther than `NEAR_THRESHOLD` from this
  module): if `ModuleMetricsLabel.visible == true`:
  - Tween `ModuleMetricsLabel.modulate.a` from current value to `0.0` over
    `0.20 s`.
  - On tween completion: `ModuleMetricsLabel.visible = false`.

Transitions must never snap — always use `create_tween()` (Godot 4.6 API).
Set `visible = true` before starting a fade-in tween; set `visible = false` only
in the completion callback of a fade-out tween. This ensures the transition from
medium to near LOD is continuous and animated, not binary.

Because `NEAR_THRESHOLD` is a named constant in task-067, this task reads and
reuses it rather than duplicating the value. If task-067 exposes its LOD distance
check through a signal or callback, hook into that; otherwise replicate the
distance check in `_process()` using the same threshold.

---

**Mode compatibility** — `ModuleMetricsLabel` is structural metadata, not
mode-specific. It is visible regardless of which understanding modes are active
(Conformance, Evaluation, Simulation). Mode-specific overlays (fill colour,
border rings, cascade gradient) apply to the node mesh and do NOT affect Label3D
children.

**Landmark compatibility** — Landmark module nodes (task-086) are a subset of
module nodes. `ModuleMetricsLabel` is visible on Landmark module nodes at near
tier the same as on non-landmark module nodes. No special handling needed.
(Note: `task-086` keeps Landmark nodes visible at all LOD tiers; the metrics
label for Landmark module nodes therefore fades in as the camera approaches
`NEAR_THRESHOLD`, even though the node itself is always visible.)

**Significance data absent** — if `significance` is absent on a node (extractor
ran with `--no-significance`), use the fallback in-degree and out-degree
computation from the edge list (described above). LOC from `metrics.loc` is
always present (required field from task-001). No crash on missing data.

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
