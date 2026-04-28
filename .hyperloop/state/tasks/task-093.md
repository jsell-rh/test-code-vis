---
id: task-093
title: Godot — Container membrane permeability visual encoding
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-010, task-078, task-088]
round: 0
branch: null
pr: null
---

Extend the Container (module-level bounded volume) rendering so that the boundary
material's visual density reflects the module's encapsulation strength: few public
symbols relative to total → thick/opaque membrane; many public symbols → thin/porous
membrane. Permeability is a continuous visual property, not a binary toggle.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Container Primitive,
Scenario: Container membrane permeability ("the membrane appears thick/opaque when few
openings relative to interior AND a module with 25 public symbols and 5 private symbols
has a thin/porous membrane AND permeability is a continuous visual property, not a
binary toggle"):

**Permeability computation** — on scene graph load, for each module node that carries
a `symbols` array (task-078):

```
total   = len(symbols)
public  = len([s for s in symbols if s["visibility"] == "public"])
ratio   = public / total  if total > 0  else  0.0
```

If `symbols` is absent or empty: treat `ratio = 0.0` (fully encapsulated; membrane
appears opaque). Store `ratio` in a `_permeability` Dictionary keyed by node id on
the scene graph loader autoload (task-008).

**Visual encoding** — after the containment volume is created (task-010):

1. The Container boundary is the **translucent parent mesh** that task-010 renders for
   module nodes. Adjust two material properties on this mesh based on `ratio`:

   | `ratio` | `albedo_color.a` | `rim` / edge emission |
   |---------|------------------|-----------------------|
   | 0.0     | 0.75 (opaque)    | no rim; solid boundary |
   | 0.5     | 0.45 (semi)      | faint rim, `rim_enabled = true`, `rim = 0.3` |
   | 1.0     | 0.15 (porous)    | bright rim, `rim = 0.9` |

   Interpolate linearly between these anchor points.  Use `StandardMaterial3D` with
   `transparency = ALPHA` and `rim_enabled = true` (Godot 4.6 API).

2. Additionally scale the **effective boundary thickness** by adjusting the container
   mesh's wall inset (if using a hollow `BoxMesh` shell technique) or the `albedo_color`
   brightness relative to children.  A fully encapsulated module (ratio ≈ 0) should look
   clearly bounded; a porous one (ratio ≈ 1) should look barely contained.

3. If a module has no `symbols` data (task-078 did not run), fall back to task-010's
   default translucent appearance — no crash, no permeability encoding.

**LOD interaction** — permeability encoding applies at medium and near LOD tiers
(task-067).  At the far tier, module boundaries are hidden by distance; no change
needed.  Do not force module boundaries visible at far tier.

**Mode compatibility** — mode-specific fill colours (Conformance, Evaluation,
Simulation) are applied on surface slot 0 of the CHILD node meshes, not the parent
Container boundary.  Permeability affects only the parent Container boundary mesh
(surface slot 0 of the parent); no interference.

**Port composability** — Port glyphs (task-088) sit on the membrane surface.  Their
positioning and visibility are unaffected by this task; they remain docked to the
membrane regardless of permeability.

**No schema or extractor changes required** — `symbols` data is already emitted by
task-078.  All logic is Godot-side, reading from the loaded scene graph.

Use only GDScript and Godot 4.6 API.  No external libraries.
