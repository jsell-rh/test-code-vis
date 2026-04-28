---
id: task-089
title: Godot — Tint primitive (categorical background colour on containers with dimension toggle)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-009, task-010]
round: 0
branch: null
pr: null
---

Implement the Tint primitive in the Godot application: apply a categorical background
colour to Container (module and bounded-context) nodes encoding one structural
dimension at a time, with a toggle to cycle between available dimensions and a
legend indicator showing the current encoding.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Tint Primitive ("A
background color on a Container encoding one categorical dimension. Limited to 4-6
categorical colors. ONE tint dimension at a time. Tint is the only primitive that
requires a legend"):

**Tint palette** — six desaturated categorical hues (≈20% saturation, 70% value):

```
TINT_PALETTE = [
  Color(0.75, 0.87, 0.75),  # soft green
  Color(0.75, 0.83, 0.95),  # soft blue
  Color(0.95, 0.85, 0.70),  # soft amber
  Color(0.90, 0.75, 0.90),  # soft purple
  Color(0.95, 0.80, 0.75),  # soft rose
  Color(0.75, 0.92, 0.92),  # soft teal
]
```

**Available tint dimensions** — the system supports three initial dimensions:

1. **Community** (`dimension: "community"`) — encode `significance.community_id` on
   each module node. Assign palette colours round-robin in community-id order within
   each bounded context.
2. **Bounded context** (`dimension: "context"`) — each `bounded_context` node gets a
   unique palette colour; all child module nodes inherit their parent context's tint.
3. **None** (`dimension: "none"`) — no tint applied; all Containers use their base
   material.

**TintController autoload** (`godot/autoload/tint_controller.gd`):
- Holds `current_dimension: String` (default `"none"`).
- Exposes `cycle_dimension() -> void`: cycles through `["none", "context",
  "community"]`.
- Emits `dimension_changed(dimension: String)` signal when the dimension changes.
- Exposes `get_tint_for_node(node_id: String) -> Color` — returns the assigned
  colour for the given node id under the current dimension, or `Color.TRANSPARENT`
  if no tint applies.

**Tint application** — connect to `TintController.dimension_changed`:
1. For `"none"`: restore all Container meshes to their base `albedo_color` (remove
   any tint override).
2. For any other dimension: iterate all module and bounded-context `MeshInstance3D`
   nodes. For each, call `get_tint_for_node()` and blend the returned colour into
   the node's albedo as a transparent overlay:
   - Create a new `StandardMaterial3D` with `albedo_color = tint_colour`,
     `transparency = ALPHA`, `albedo_color.a = 0.3`.
   - Apply as a material overlay (surface slot 1) so it composes with any existing
     mode-specific material on slot 0.
3. **Transition**: tween the overlay material's `albedo_color.a` from 0 to 0.3 when
   activating a new tint, and from 0.3 to 0 when deactivating (duration 0.25 s).

**Keyboard shortcut** — press `T` to call `TintController.cycle_dimension()`.

**One dimension at a time** — when `cycle_dimension()` is called, the previous tint
is fully removed before the new one is applied. TWO overlapping tint dimensions
MUST NOT be simultaneously active.

**Interaction with other mode colours** — Tint uses material surface slot 1. All
mode-specific colours (Conformance, Evaluation, Simulation) use surface slot 0.
Badge glyphs are child meshes and unaffected. Tint MUST NOT overwrite any mode
colour already on slot 0.

**Scene graph independence** — if `significance.community_id` is absent (extractor
ran without `--significance`), the `"community"` dimension silently produces no tint
(falls through to `"none"` behaviour for that node). No crash.

Use only GDScript and Godot 4.6 API. No external libraries.
