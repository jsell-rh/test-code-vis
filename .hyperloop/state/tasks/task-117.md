---
id: task-117
title: Godot — failure-mode overlay: Landmark SPOF highlighting shift
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-035, task-048, task-086, task-091]
round: 0
branch: null
pr: null
---

When a failure is injected (task-035) and the cascade depth gradient has been computed
(task-048), shift the visual treatment of Landmark nodes to communicate single-point-of-failure
(SPOF) status — completing the three-channel failure-mode overlay: edge weights (task-115),
Tint resilience (task-116), and Landmark SPOF emphasis (this task).

Covers `specs/core/visual-primitives.spec.md` — Requirement: Overlay/Facet Composition,
Scenario: Switching from dependency view to failure view ("Landmarks shift to highlight
single points of failure AND the underlying topology does NOT change"):

---

**Baseline** — task-086 gives every Landmark node a persistent gold emissive glow
(`emission = Color(1.0, 0.9, 0.4)`), larger scale (`LANDMARK_SCALE = 1.35`), and a
faint warm `OmniLight3D`. That treatment is the default and this task overrides it
during failure injection.

---

**Failure-active state — connect to task-035's `failure_injected` signal (or equivalent).**
After task-048's cascade BFS has completed for the current failure:

1. **Landmarks reached by the cascade** (node id is in task-048's `reached_nodes` dict):
   - Transition the emissive colour from gold to urgency orange-red:
     `new_emission = Color(1.0, 0.25, 0.0)` over `0.30 s` using `create_tween()` on the
     `emission` property of the emissive surface layer established in task-086.
     Never snap — always animate.
   - Increase scale to `LANDMARK_SCALE * 1.15` (total ~1.55× normal) over the same
     `0.30 s` tween. This scale pulse distinguishes the SPOF warning from the baseline
     Landmark prominence.
   - Add a floating `Label3D` child named `"LandmarkSPOFLabel"`:
     - `text = "⚠ SPOF"`
     - `font_size = 11` (slightly larger than the depth label from task-048).
     - `billboard = BaseMaterial3D.BILLBOARD_ENABLED`.
     - `modulate = Color(1.0, 0.4, 0.1, 1.0)` (orange-red to match the emissive shift).
     - Position: `node_position + Vector3(0, node_size * 0.5 + 0.55, 0)` — above the
       node name label and above the `"⚠ depth N"` label from task-048 (which sits at
       `+0.35`). Adjust if labels overlap on large nodes.
     - Initial state: `visible = false`, `modulate.a = 0.0`. Fade in over `0.25 s`
       starting at the same time as the emissive colour tween.
   - The `OmniLight3D` added by task-086: tween its `light_color` to
     `Color(1.0, 0.3, 0.0)` and `light_energy` to `0.8` over `0.30 s` (intensified,
     warmer-to-red, to cast an urgency halo on surrounding nodes).

2. **Landmarks NOT reached by the cascade** (node id is absent from `reached_nodes`):
   - Retain the default gold emissive glow, scale, and OmniLight from task-086 without
     modification. The gold treatment serves as an explicit SAFE contrast signal —
     "this structural node is not in the blast radius."
   - No label added.

3. **The failed node itself** (node id is the failure origin):
   - Task-035 renders it with a `"✕ FAILED"` label and red failure state. Do NOT
     add the `"⚠ SPOF"` label — the origin is the cause, not a downstream SPOF.
   - Suppress the Landmark gold emissive glow (tween `emission_energy` to `0.0` over
     `0.15 s`) so the task-035 failure state is visually unambiguous.

---

**Distortion Legend update** (task-091) — when failure is active, update the Landmark
section of the legend panel to read:

```
Landmarks: ◆ gold = SAFE  ◆ red = SPOF (cascade-affected)
```

Connect to task-091's legend update API (the same mechanism used by task-115 and
task-116). Restore the legend to its default Landmark description on reset.

---

**Reset — connect to task-035's `failure_reset` signal (or equivalent).**

For each Landmark node that received the SPOF treatment:

1. Tween `emission` back to `Color(1.0, 0.9, 0.4)` over `0.20 s`.
2. Tween `MeshInstance3D` scale back to `LANDMARK_SCALE` over `0.20 s`.
3. Tween `OmniLight3D.light_color` back to `Color(1.0, 0.95, 0.7)` and
   `light_energy` back to `0.4` over `0.20 s`.
4. Fade out `LandmarkSPOFLabel.modulate.a` from current value to `0.0` over `0.15 s`,
   then set `LandmarkSPOFLabel.visible = false` in the tween completion callback.

For the failed-node Landmark (if it was one): restore emissive gold glow.

Restore the Distortion Legend Landmark section to its default text.

No partial animation state should remain after reset.

---

**Multi-failure** — when the human selects additional failed nodes while a previous
wave animation is playing (task-049 multi-failure path): cancel active SPOF tweens,
snap Landmarks to their previous state (gold or red-pulse), then immediately re-evaluate
against the new combined `reached_nodes` set and re-apply the SPOF treatment.

**Mode compatibility** — SPOF emissive override uses the same dedicated emissive surface
slot as task-086's baseline glow. Conformance border rings (task-051), Evaluation
intensity rings (task-052), and Simulation cascade fills (task-048) occupy different
perceptual channels and are unaffected.

**LOD compatibility** — Landmark nodes are visible at all LOD tiers (task-086 LOD
override). The SPOF label (`LandmarkSPOFLabel`) follows the same visibility rule:
`visible = true` at all LOD tiers while a failure is active.

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
