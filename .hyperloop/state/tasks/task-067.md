---
id: task-067
title: Godot — semantic LOD (aggregate/individual edges with animated opacity transitions)
spec_ref: specs/visualization/spatial-structure.spec.md
status: not-started
phase: null
deps: [task-061, task-019, task-013]
round: 0
branch: null
pr: null
---

Extend the LOD visibility system (task-019) so that each zoom level presents a
semantically complete story — switching between aggregate and individual edges with
animated opacity, never an instant snap.

Covers `specs/visualization/spatial-structure.spec.md` — Requirement: Scale Through
Zoom, Scenarios: Far, Medium, Near, and Smooth transitions:

**Loader extension** — extend the scene graph loader autoload (task-008) to expose
each edge's `weight` field and distinguish `type: "aggregate"` edges from individual
module-level edges.

**Three semantic tiers** (distances are tunable constants against kartograph's extents):

- **Far** (camera farther than `FAR_THRESHOLD` from any bounded context):
  - Bounded context volumes visible (unchanged from task-019).
  - Only aggregate edges (`type: "aggregate"`) are visible; render their line thickness
    proportional to `weight` so total import volume is visible at a glance.
  - All module nodes and individual (non-aggregate) edges have `modulate.a` tweened
    toward 0.0.  `visible` is set to false only after `modulate.a` reaches 0.
  - This view alone answers "what are the major parts and how do they relate?"

- **Medium** (within `FAR_THRESHOLD` of a context, farther than `NEAR_THRESHOLD`):
  - Module nodes inside the nearest context fade in (`modulate.a` tweened to 1.0).
  - Individual module-level edges fade in with animated opacity.
  - Aggregate edges targeting the nearest context fade out: their `modulate.a` tweens
    to 0.0 as constituent individual edges tween to full opacity (cross-fade, not
    geometric morphing).
  - This view answers "how is this context organised internally?"

- **Near** (within `NEAR_THRESHOLD` of a specific module):
  - All edges for that module and its context are at full opacity.
  - Annotations and metrics (if any) become visible.

**Animation** — use `Tween` (`create_tween()`, Godot 4.6 API) to animate `modulate.a`
on all `MeshInstance3D` and edge line nodes.  Duration: 0.25–0.4 s.  Set
`visible = true` before starting a fade-in tween; set `visible = false` only in the
tween completion callback of a fade-out tween.  No binary `visible` flips mid-frame.

**LOD recomputation** — run in `_process()`, computing camera distance to each bounded
context world position (reusing task-019's approach).  Reuse task-019's distance
constants as starting values; tune so semantic content matches the visual intent.

Use only GDScript and Godot 4.6 API.  No external libraries.
