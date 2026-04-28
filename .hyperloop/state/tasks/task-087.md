---
id: task-087
title: Godot — Badge primitive (vocabulary glyphs docked to nodes)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-084, task-009]
round: 0
branch: null
pr: null
---

Implement the Badge primitive in the Godot application: read the `badges` array from
each node in the scene graph and render small glyph indicators docked to the
top-right corner of each node's `MeshInstance3D`, one per badge type.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Badge Primitive
("A small glyph docked to a Node indicating an aspect or cross-cutting property.
Multiple badges are visible, arranged in a consistent order. Badge vocabulary is
fixed at runtime"):

**Badge loading** — on scene graph load:
1. Extend the scene graph loader autoload (task-008) to read the `badges` array from
   each node entry (absent or empty → no badges).

**Badge rendering** — after the base node mesh is created (task-009), for each node
with at least one badge:
1. For each badge in the `badges` array (in vocabulary order):
   - Create a `MeshInstance3D` child of the node's root `Node3D`.
   - Use a small `BoxMesh` with `size = Vector3(0.18, 0.18, 0.18)` as the badge shape.
   - Apply a `StandardMaterial3D` with the badge's colour (see palette below).
   - Position the badge at a consistent offset from the parent node's top-right corner:
     - First badge: `offset = Vector3(node_size * 0.5 + 0.12, node_size * 0.5 + 0.12, 0)`.
     - Additional badges: stack along the X axis with `0.22` unit spacing.
2. Add a `Label3D` child above the badge with the badge type abbreviation (2 chars):

| Badge type      | Colour              | Abbreviation |
|-----------------|---------------------|--------------|
| `pure`          | `Color(0.4,0.9,0.4)` (green)   | `Pu` |
| `io`            | `Color(0.9,0.5,0.2)` (orange)  | `IO` |
| `async`         | `Color(0.4,0.6,1.0)` (blue)    | `As` |
| `stateful`      | `Color(0.9,0.8,0.2)` (yellow)  | `St` |
| `error_handling`| `Color(0.8,0.2,0.2)` (red)     | `Eh` |
| `test`          | `Color(0.7,0.3,0.9)` (purple)  | `Ts` |
| `entry_point`   | `Color(1.0,1.0,1.0)` (white)   | `EP` |
| `deprecated`    | `Color(0.5,0.5,0.5)` (grey)    | `Dp` |

**LOD behaviour** — badges follow the visibility of their parent node:
- When the parent node is hidden by the LOD system (task-067), hide all badge
  `MeshInstance3D` and `Label3D` children simultaneously (set `visible = false`).
- When the parent node fades in, badges fade in with it (copy the parent's
  `modulate.a` tween to the badge nodes using `Tween.tween_property`).
- At the far LOD tier (parent barely visible), suppress badge label visibility
  (`Label3D.visible = false`); only the coloured box glyph remains.

**Mode compatibility** — badge glyphs occupy the glyph perceptual channel (shape),
which is distinct from the fill colour channel (Tint/Conformance/Evaluation/
Simulation). Badges MUST NOT be removed or hidden when any mode is active.

**Maximum badges** — up to 8 badges can be active simultaneously per node (one per
vocabulary type). If all 8 are set, they form a row of 8 small cubes. The row MUST
fit within the parent node's bounding box or extend slightly beyond — no wrapping.

**Hover tooltip** — when the mouse hovers over a badge mesh, display a small HUD
label (CanvasLayer Label) with the full badge type name (e.g. "io — performs I/O
operations"). Use the same tooltip mechanism established by other hover interactions
in the project; implement from scratch if none exists.

Use only GDScript and Godot 4.6 API. No external libraries.
