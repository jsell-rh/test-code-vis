---
id: task-086
title: Godot — Landmark primitive (hub/bridge/entry-point nodes at all zoom levels)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-082, task-009, task-067]
round: 0
branch: null
pr: null
---

Implement the Landmark primitive in the Godot application: nodes flagged as
`landmark: true` in the scene graph receive a distinctive visual treatment and
remain visible at every LOD tier, overriding the normal distance-based visibility
rules from task-067.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Landmark Primitive
("A structurally significant Node that persists across all zoom levels and serves as
an orientation anchor"):

**Landmark identification** — on scene graph load:
1. Extend the scene graph loader autoload (task-008) to read the `landmark` boolean
   from each node entry (absent or false → not a landmark).
2. Maintain a `landmark_nodes: Array[String]` in the loader (node ids of all
   landmarks).
3. Also derive landmarks from `significance.hub == true`,
   `significance.bridge == true`, and nodes with `significance.in_degree == 0` AND
   at least one outgoing edge (entry points) — even if the `landmark` field is absent
   (forward-compatibility for scene graphs produced before task-074/082 run).

**Visual treatment** — after the base node mesh is created (task-009):
1. Scale Landmark `MeshInstance3D` nodes up by `LANDMARK_SCALE = 1.35` (named
   constant). This makes them visibly larger than peers.
2. Apply a distinct emissive material property: `emission_enabled = true`,
   `emission = Color(1.0, 0.9, 0.4)` (warm gold), `emission_energy = 0.6`.
   The emissive glow does NOT interfere with mode-specific fill colour — use a
   separate `surface_material_override` layer rather than replacing the base
   material.
3. Add a faint `OmniLight3D` child node at the landmark's position with
   `light_color = Color(1.0, 0.95, 0.7)`, `light_energy = 0.4`, `omni_range = 8.0`
   to illuminate surrounding nodes slightly.

**LOD override** — integrate with the LOD system (task-067):
1. In task-067's visibility update loop, after computing camera distance and setting
   `modulate.a` on non-landmark nodes, iterate `landmark_nodes` and set
   `modulate.a = 1.0` on every landmark node unconditionally — regardless of distance
   or tier.
2. Set `visible = true` on landmark nodes before the LOD loop runs; do not allow the
   LOD loop to set `visible = false` on them.
3. Landmark LOD override is additive: the emissive treatment and scaling persist even
   when surrounding non-landmark nodes are hidden (far tier).

**Mode compatibility** — Landmark emissive treatment must compose with mode
colour overlays:
- Conformance, Evaluation, Simulation fills are applied to the base material. The
  emissive layer is a separate surface slot and is NOT overwritten by mode scripts.
- If a Landmark node is flagged in Evaluation Mode (e.g. `CRITICAL` label), the
  label is rendered above the landmark mesh as normal — no conflict.

**Landmark label** — add a persistent `Label3D` above each landmark node:
- Text: the node's `name` field.
- Font size slightly larger than non-landmark labels.
- Visible at all zoom levels (same LOD-override logic as the mesh).
- Fades to 50% opacity at far zoom (so it does not dominate the far-view text).

**Human-designated landmarks** — if a node has `landmark: true` but no
`significance` data (manually designated), it still receives the full visual
treatment above.

Use only GDScript and Godot 4.6 API. No external libraries.
