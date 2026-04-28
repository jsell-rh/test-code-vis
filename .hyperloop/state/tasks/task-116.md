---
id: task-116
title: Godot — failure-mode overlay: resilience Tint encoding
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-035, task-048, task-084, task-089, task-091]
round: 0
branch: null
pr: null
---

When a failure is injected (task-035), switch the Tint channel from its
current categorical dimension (e.g. bounded-context identity) to a resilience
encoding — containers are tinted from high-resilience (strong error handling
coverage) to low-resilience (little or no error handling) — so the human can
immediately see which parts of the cascade are structurally robust and which
are fragile.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Overlay/Facet
Composition, Scenario: Switching from dependency view to failure view ("Tints
shift to encode resilience (presence/absence of error handling) AND the
underlying topology does NOT change"):

Task-089 implements the Tint primitive with a dimension-toggle mechanism.
Task-084 computes the `error_handling` badge for every node and writes it into
the scene graph. Neither task switches the Tint dimension in failure mode. This
task closes the gap: when a failure is active, the Tint channel re-encodes
resilience instead of its previous categorical dimension, giving the human a
failure-aware picture of which containers can absorb the cascade.

---

**Resilience metric computation** — at scene graph load time (after badges are
available from the data loaded by task-085 / task-077), pre-compute for every
`bounded_context` and `module` node:

```
resilience_score(node) =
    (count of descendant nodes with "error_handling" badge) /
    max(1, count of all descendant nodes)
```

"Descendant nodes" = all nodes whose `parent` chain leads back to this node
(i.e. recursive children). For a `module` node this is its class and function
children (when scope-nesting data is present); for a `bounded_context` this
is all modules and their children.

If scope-nesting data is absent (task-100 was not run), fall back to:
```
resilience_score(module_node) =
    1.0 if module_node has "error_handling" badge else 0.0
```

Store `resilience_score` in a Dictionary keyed by node id, built in `_ready()`
alongside the badge data.

---

**Colour mapping** — use a two-colour linear interpolation:

```
low_resilience_colour  = Color(0.85, 0.20, 0.20, 0.45)  # muted red, semi-transparent
high_resilience_colour = Color(0.20, 0.70, 0.35, 0.45)  # muted green, semi-transparent

tint_colour(node) = low_resilience_colour.lerp(high_resilience_colour,
                                                resilience_score(node))
```

These are DESATURATED colours consistent with the Tint primitive's design
principle (task-089: "distinct desaturated fill color"). The alpha `0.45` is
the same transparency used by the categorical Tints from task-089.

---

**Activation — when failure is injected** (connect to task-035's
`failure_injected` signal or equivalent):

1. Record the current Tint dimension label (from task-089's active dimension
   state) so it can be restored on reset.
2. For each container node visual (bounded_context and module volumes):
   - Compute `new_colour = tint_colour(node)`.
   - Tween the container's `modulate` (or its fill material's albedo colour)
     from its current Tint colour to `new_colour` over `0.30 s` using
     `create_tween()`. Never snap.
3. Update the Distortion Legend Tint section (task-091) label to:
   `"Tint: resilience (error handling coverage)"`
   Trigger the legend's existing Tint-dimension-update signal with a new
   dimension name `"resilience"` and the two-colour gradient description.

---

**Restoration — when failure simulation is reset** (connect to task-035's
`failure_reset` signal or equivalent):

1. Retrieve the previously recorded Tint dimension and colours.
2. For each container node visual: tween back to the pre-failure Tint colour
   over `0.20 s` using `create_tween()`.
3. Restore the Distortion Legend Tint label to whatever it was before failure
   was injected.

---

**Interaction with task-089 dimension toggle** — while a failure is active,
the human MAY use the Tint dimension toggle (task-089) to switch between
categorical dimensions. If they do:
- Temporarily override the resilience Tint with their chosen dimension.
- When they toggle back (or when the failure is reset), resilience Tint is
  re-applied.
- Implement by treating "resilience" as a named Tint dimension that task-089's
  dimension picker includes alongside the existing categorical dimensions.

**Interaction with task-089 one-dimension constraint** — only ONE Tint dimension
is active at a time (spec requirement). Activating resilience Tint REPLACES
the previous dimension; it does not layer on top of it.

**Nodes with no badge data** — if a node has no badge fields (extractor ran
without `--badges`), treat it as having zero `error_handling` badges.
`resilience_score = 0.0` → full `low_resilience_colour` tint.

**Multi-failure** — resilience is a property of each container, computed
independently of which node failed. When multiple failures are active, the
resilience tint is unchanged by additional failure selections; the tint encodes
structural resilience, not cascade membership.

**Mode compatibility** — Tint uses the fill colour perceptual channel (hue
fill). Conformance Mode uses border treatment; Evaluation Mode uses intensity
or border rings. These channels do not conflict. All modes may be simultaneously
active while resilience Tint is applied.

---

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
