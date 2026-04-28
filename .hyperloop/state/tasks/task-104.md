---
id: task-104
title: Godot — LOD tier-0 aggregate metrics label on bounded context nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-009, task-067, task-082]
round: 0
branch: null
pr: null
---

Add aggregate metric labels (LOC, in-degree, out-degree) to bounded context node
meshes, visible only at the far LOD tier (tier 0), so that the tier-0 view is
semantically complete without requiring the human to navigate inside a context to
understand its scale and connectivity.

Covers `specs/core/visual-primitives.spec.md` — Requirement: LOD Shell Primitive,
Scenario: Three-tier LOD ("tier 0 (far): the context is a single Container with
aggregate metrics (total LOC, total in-degree, total out-degree) and its Landmarks"):

---

**Metric label creation** — after bounded context node meshes are instantiated
(task-009), for each node with `type == "bounded_context"`:

1. Compute the three metrics:
   - **LOC**: read `node["metrics"]["loc"]` from the loaded scene graph (integer).
   - **in_degree**: read `node["significance"]["in_degree"]` if present; otherwise
     count edges in the loaded edge list where `target == node["id"]` and
     `type != "aggregate"` (fallback for scene graphs produced before task-082).
   - **out_degree**: count edges in the loaded edge list where `source == node["id"]`
     and `type == "aggregate"`. Aggregate edges are the bounded-context level
     dependency count; each represents one outgoing context dependency. If no
     aggregate edges exist (extractor ran without task-063), fall back to counting
     all non-aggregate outgoing edges.

2. Format the metrics string:
   ```
   LOC: <loc>   In: <in_degree>   Out: <out_degree>
   ```
   Use commas for thousands separators on LOC if LOC ≥ 1000 (e.g. `LOC: 12,400`).

3. Create a `Label3D` node:
   - `text`: the formatted metrics string.
   - `font_size`: 10 (smaller than the node name label, which is typically 14–16).
   - `billboard`: `BaseMaterial3D.BILLBOARD_ENABLED`.
   - `modulate`: `Color(0.85, 0.85, 0.85, 1.0)` (light grey, readable against dark
     node material).
   - Position: directly below the node name label. If the node name label is at
     `position + Vector3(0, node_half_height + 0.3, 0)`, place this label at
     `position + Vector3(0, node_half_height + 0.05, 0)`.
   - Name the node `"MetricsLabel"` for future reference.

4. Add `MetricsLabel` as a child of the same `Node3D` root that owns the bounded
   context `MeshInstance3D` (sibling to the existing name `Label3D`).

5. **Initial visibility**: `visible = false`, `modulate.a = 0.0`.

---

**LOD integration** — hook into task-067's LOD update logic:

- **Far tier active** (camera farther than `FAR_THRESHOLD` from all bounded contexts):
  For each bounded context node, if `MetricsLabel.visible == false`:
  - Set `MetricsLabel.visible = true`.
  - Tween `MetricsLabel.modulate.a` from `0.0` to `1.0` over `0.3 s`.

- **Far tier NOT active** (camera closer than `FAR_THRESHOLD` to any bounded context):
  For each bounded context node, if `MetricsLabel.visible == true`:
  - Tween `MetricsLabel.modulate.a` from current value to `0.0` over `0.2 s`.
  - On tween completion: `MetricsLabel.visible = false`.

Transitions must never snap — always use `create_tween()` (Godot 4.6 API).
Set `visible = true` before starting a fade-in tween; set `visible = false` only
in the completion callback of a fade-out tween.

---

**Landmark compatibility** — Landmark nodes (task-086) are a subset of bounded
context nodes. MetricsLabel is visible on Landmark context nodes at far tier the
same as on non-landmark context nodes. No special handling needed.

**Mode compatibility** — MetricsLabel is structural metadata, not mode-specific.
It is visible regardless of which modes are active. Mode-specific visual overlays
(fill colour, border rings, cascade gradient) apply to the node mesh, not to labels.

**Missing significance data** — if `significance` is absent on a node (extractor
ran without `--no-significance` flag — note inverted: `--no-significance` suppresses
it), use the fallback in-degree and out-degree computation from the edge list.
LOC from `metrics.loc` is always present (required field from task-001).

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
