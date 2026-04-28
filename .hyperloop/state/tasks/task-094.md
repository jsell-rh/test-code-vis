---
id: task-094
title: Godot — Edge primitive: weighted line thickness and type-based line styles
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-013, task-067, task-076]
round: 0
branch: null
pr: null
---

Extend edge rendering so that every directed connection uses visual thickness
proportional to its `weight` field and a distinct line style keyed to its edge `type`,
making coupling intensity and relationship kind independently readable at a glance.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Edge Primitive, Scenarios:
Weighted edge ("visual thickness is proportional to the weight — a single-import Edge
is visibly thinner than a 12-import Edge") and Edge type distinction ("edge type is
encoded by line style — solid for calls, dashed for imports, dotted for inheritance —
at most 3-4 line styles"):

**Foundation** — this task extends task-013's basic edge rendering.  Task-013 draws
a `CylinderMesh` or `ImmediateMesh` line per edge and distinguishes `cross_context`
from `internal` by colour.  This task adds weight-driven thickness and type-driven
line style on top of that foundation.

---

**Weight → line thickness mapping**

Each edge in the scene graph carries an optional `weight` field (absent → defaults to
1).  Map weight to `CylinderMesh.top_radius` / `bottom_radius` (or equivalent line
width for `ImmediateMesh` edges) using:

```
MIN_RADIUS = 0.02   # single import, thin line
MAX_RADIUS = 0.12   # 12+ imports, thick cable
weight_clamped = clamp(weight, 1, 12)
radius = MIN_RADIUS + (MAX_RADIUS - MIN_RADIUS) * (weight_clamped - 1) / 11.0
```

Named constants `MIN_RADIUS`, `MAX_RADIUS`, and the clamp ceiling (12) allow tuning
without touching the formula.

For `ImmediateMesh` line edges: if Godot's line rendering does not support
sub-pixel widths, use a thin flat `BoxMesh` ribbon scaled along the edge axis instead,
with `scale.y = radius * 2`.

**LOD interaction** — task-067 already overrides aggregate edge thickness proportionally
to weight for the far tier; do NOT duplicate that logic.  This task applies the same
radius formula to ALL individual (non-aggregate) edges at medium and near tiers.

---

**Edge type → line style mapping**

Use the `type` field (extended by task-076) to assign one of four visual styles.
Implement style as a combination of material colour and, where possible, dash/gap
rendering using a scrolling UV texture or alternating segment geometry:

| `type`                              | Style         | Colour hint               |
|-------------------------------------|---------------|---------------------------|
| `direct_call`                       | solid line    | warm white `(0.95,0.9,0.8)` |
| `cross_context`, `internal`         | dashed line   | cyan `(0.4,0.8,1.0)`     |
| `inherits`, `has_a`                 | dotted line   | magenta `(0.8,0.4,0.9)`  |
| `dynamic_call`                      | dashed line   | amber `(0.9,0.7,0.2)` (dimmer) |
| `aggregate`                         | solid line    | (task-067 owns this tier; skip) |

**Dashed line implementation** — render dashes as a sequence of short `CylinderMesh`
segments along the edge vector with gaps between them.  `DASH_LENGTH = 0.25`,
`GAP_LENGTH = 0.15` (named constants).  Gaps are empty space; no geometry there.

**Dotted line implementation** — render dots as small `SphereMesh` primitives
(`radius = base_radius * 1.2`) spaced `DOT_SPACING = 0.30` units apart along the
edge vector.

**Style group limit** — only 3 distinct styles are used (solid, dashed, dotted),
which is within the spec's "at most 3-4" limit.  Type-to-style mapping MUST NOT
grow beyond 4 styles.

---

**Suppressed ubiquitous edges**

Edges with `ubiquitous: true` are hidden by default (task-090 owns this).  This task
MUST NOT draw geometry for ubiquitous edges; check the flag before creating any mesh.

---

**Backward compatibility with task-013**

Task-013's colour-based cross_context / internal distinction remains: the line style
encoding from this task layers on top of the colour distinction, not replacing it.
Both cues (colour AND style) help distinguish edge types.

Task-067's aggregate-edge handling (thickness for far-tier aggregate edges) is not
replaced by this task.  Both can co-exist because they operate at different LOD tiers.

---

**No schema or extractor changes** — all required fields (`weight`, `type`,
`ubiquitous`) are already defined in the schema (tasks 061, 076) and emitted by
the extractor pipeline.

Use only GDScript and Godot 4.6 API.  No external libraries.
