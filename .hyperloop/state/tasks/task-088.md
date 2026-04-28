---
id: task-088
title: Godot — Port primitive (public symbol interface points on Container membrane)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-078, task-010]
round: 0
branch: null
pr: null
---

Implement the Port primitive in the Godot application: read the `symbols` array from
each module node, render a small Port glyph on the Container's membrane for each
public function symbol, and connect incoming and outgoing edges to these Ports rather
than to the Container body.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Port Primitive
("A small visual element anchored to a Container's membrane, representing an interface
point. Edges connect to Ports, not directly to the Container body"):

**Port identification** — on scene graph load:
1. Extend the scene graph loader autoload (task-008) to read the `symbols` array from
   each module node entry (absent or empty → no ports).
2. A symbol is rendered as a Port if: `kind == "function"` AND `visibility == "public"`.
3. A symbol becomes an INPUT Port if it is the target of a `direct_call` edge from
   another module. An OUTPUT Port is a public function that generates return values
   (all public functions are potential output ports by default).

**Port placement** — for each Container (module node) with public function symbols:
1. Distribute Port positions evenly along the Container's bounding surface.
   - Use the Container's bounding box (from task-010's volume mesh) as the membrane.
   - Place N ports around the XZ perimeter of the container (equidistant arc).
   - Input ports (called from outside) → south face (negative Z edge).
   - Output ports (called by this module's functions into others) → north face.
   - Mixed ports → east face.
   - If the direction cannot be determined, distribute evenly around the perimeter.
2. Each Port is a small `CylinderMesh` with `height = 0.05`, `radius = 0.08` mounted
   flush with the membrane surface, extending slightly outward.
3. Apply a `StandardMaterial3D`: input ports in `Color(0.3, 0.7, 1.0)` (blue);
   output ports in `Color(1.0, 0.6, 0.2)` (orange); ambiguous ports in
   `Color(0.8, 0.8, 0.8)` (grey).

**Port labelling** — at the near LOD tier (task-067 near threshold), add a `Label3D`
to each Port showing the symbol name. At medium and far tiers, the label is hidden.

**Edge connection to Ports** — update the edge rendering (task-013) so that edges
whose source or target module has Port data connect to the Port position rather than
the Container centroid:
1. At near LOD: compute the edge endpoint as the world position of the matching Port
   `CylinderMesh`. If no specific Port matches (e.g. the edge is an import, not a
   direct call), use the Container centroid as before.
2. At medium and far LOD: use the Container centroid (Ports are hidden, edges attach
   to the Container surface).
3. Animate edge endpoint transitions when LOD changes (slide from centroid to Port
   position as the user zooms in) using a `Tween` (0.3 s).

**LOD visibility:**
- Far tier: Port meshes hidden, labels hidden. Edges connect to Container centroid.
- Medium tier: Port meshes visible (no labels). Edges begin transitioning to Port
  endpoints.
- Near tier: Port meshes visible with labels. Edges connect to Port endpoints.

**Maximum ports displayed** — if a module has more than 12 public function symbols,
display only the 12 with the highest call frequency (from `direct_call` edge weights);
indicate the rest with a small `"…+N more"` label on the membrane.

Use only GDScript and Godot 4.6 API. No external libraries.
