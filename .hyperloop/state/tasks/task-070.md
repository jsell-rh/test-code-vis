---
id: task-070
title: Godot — independence group: spatial rendering and group tinting
spec_ref: specs/visualization/orthogonal-independence.spec.md
status: not-started
phase: null
deps: [task-061, task-009]
round: 0
branch: null
pr: null
---

Read the `independence_group` field from loaded module nodes, apply a per-group
visual tint, and animate node positions smoothly when a new scene graph is loaded
with different independence groupings.

Covers `specs/visualization/orthogonal-independence.spec.md` — Requirement: Spatial
Separation of Independent Groups, Scenarios: Visual gap between independent groups,
Smooth regrouping on data change:

**Tinting** — after node volumes are rendered (task-009), iterate all module nodes
that carry an `independence_group` field:
1. Within each bounded context, collect the set of distinct `independence_group` values.
2. Assign each value a hue from a fixed 6-colour soft palette, index determined by
   the sorted position of the group identifier within the context.
3. Apply the hue as a subtle albedo tint (≈20% saturation, full brightness) to the
   module's `MeshInstance3D`.  The tint MUST compose with cluster suggestion tints
   (task-069) and mode colouring — use a secondary material layer or additive blend
   rather than overwriting.
4. `bounded_context` nodes are not tinted.

**Gap visualisation** — the spatial gap between groups is baked into node `position`
values by the extractor (task-065).  Godot renders nodes at JSON positions verbatim;
no additional geometry is needed.

**Smooth regrouping on scene reload** — when a new scene graph is loaded while the
application is running:
1. Before applying new positions, record the current world position of each
   `MeshInstance3D` indexed by node id.
2. For each node id present in both old and new data: animate the `MeshInstance3D`
   from its current position to the new JSON position using a `Tween` (0.5 s) rather
   than snapping.
3. New nodes (only in new data): appear at target position immediately, fading in via
   `modulate.a` tween.
4. Removed nodes (only in old data): fade out (`modulate.a` to 0), then freed.

Use only GDScript and Godot 4.6 API.  No external libraries.
