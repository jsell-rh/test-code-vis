---
id: task-092
title: Godot — Route primitive (named directed paths with direction animation)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-022, task-013, task-009]
round: 0
branch: null
pr: null
---

Enhance the flow path rendering (task-022) with the full Route primitive semantics:
named, directed paths with animated flow direction, distinct visual treatment per
route, entry/terminus landmark styling, de-emphasis of non-route elements, and
support for up to 4 simultaneous active routes.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Route Primitive ("A
named, highlighted path through the graph representing a unit of work. Route has a
name. Direction of flow is apparent. At most 4 simultaneous Routes before visual
overload"):

**Foundation** — this task extends task-022's flow path system. Task-022 provides
basic highlight/de-emphasis for a single active flow path. This task adds:

**Route colour palette** — four visually distinct route colours:
```
ROUTE_COLOURS = [
  Color(0.2, 0.8, 0.3),   # route 0: bright green
  Color(0.3, 0.6, 1.0),   # route 1: bright blue
  Color(1.0, 0.6, 0.1),   # route 2: bright orange
  Color(0.9, 0.3, 0.9),   # route 3: bright magenta
]
```

**Simultaneous routes** — extend task-022's single-route model to track up to 4
active routes:
- `active_routes: Array` (max length 4), each entry: `{ "path_index": int,
  "colour": Color }`.
- Keyboard shortcut `1`–`4`: toggle route at that slot. Press again to deactivate.
- A fifth route key press replaces slot 1 (oldest), cycling round-robin.

**Directed flow animation** — for each active route:
1. Along each edge segment in the route's `steps` array, render a series of small
   `SphereMesh` particles (`radius = 0.04`, colour = route colour) that travel from
   source to target at a constant speed.
2. Implementation: spawn 3 particles per edge segment, staggered evenly along the
   edge. Move them using `_process(delta)`, advancing by `PARTICLE_SPEED * delta`
   (default 2.0 units/s) along the edge vector. When a particle reaches the end of
   a segment, teleport it back to the start of that segment (loop within each segment).
3. The particles visually convey direction (they move from source node toward target
   node) without requiring Godot particle systems.
4. Particle nodes are freed when the route is deactivated.

**Entry and terminus styling** — the first and last node in the route's `steps` array:
1. Apply an additional emissive ring using a slightly enlarged wireframe sphere
   `MeshInstance3D` around the node (scale 1.2× the node's bounding sphere).
2. Ring colour: white for the entry point, route colour for the terminus.
3. Add a `Label3D`: `"▶ <route_name>"` above the entry node, `"◼ <route_name>"`
   above the terminus node.

**Route name label** — display the route's `name` field as a floating `Label3D`
anchored to the midpoint of the route path (the node at position `len(steps) // 2`
in the steps array). Route colour is used for the label.

**Edge line treatment** — route edges use the route colour and a thicker line width
(if the edge renderer supports line width; otherwise increase emissive intensity on
that edge segment).

**De-emphasis** — non-route nodes and edges have their `modulate.a` reduced to 0.25
when any route is active (extending task-022's de-emphasis). When MULTIPLE routes are
active, a node is NOT de-emphasised if it appears in ANY active route's steps.

**Deactivation** — pressing the route's key again:
1. Fades out particles (`modulate.a` to 0, 0.2 s), then frees them.
2. Restores entry/terminus rings and labels.
3. Fades the route's edge highlights back to base appearance.
4. If no routes remain active, restores all nodes to full opacity (0.25 → 1.0, 0.3 s).

**Compatibility with task-022** — this task REPLACES task-022's keyboard shortcut
and highlight logic. Task-022's `flow_paths` loading (from the scene graph JSON) is
reused as the Route data source. Task-022's `Escape` reset is replaced by the
per-slot toggle above; `Escape` now deactivates ALL active routes.

Use only GDScript and Godot 4.6 API. No external libraries.
