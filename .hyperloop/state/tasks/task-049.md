---
id: task-049
title: Godot — Simulation: cascade wave animation
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-048]
round: 0
branch: null
pr: null
---

Animate the failure-injection cascade so that each depth ring lights up in sequence after
a brief staggered delay, letting the human perceive the propagation sequence — not just
the final affected state — and see where the cascade attenuates as it moves further from
the origin.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Cascade Depth, Scenario:
Cascade wave animation ("each depth level animates in sequence with a brief staggered delay
AND the animation is smooth and continuous, not stepped AND the human can see where the
cascade attenuates (few or no nodes at deeper levels)"):

**Context:** task-048 computes the per-hop depth gradient and applies it instantaneously
when the human clicks a failed node. This task replaces that instantaneous reveal with a
wave-propagation animation.

**Animation design:**

- When the human clicks a failed node to trigger failure injection, all reached nodes are
  initially rendered in their dimmed Simulation Mode entry state (as per task-032). The
  failed node's `"✕ FAILED"` marker appears immediately.
- Group reached nodes by depth level: all distance-1 nodes form wave 1, all distance-2
  nodes form wave 2, and so on up to the max depth from task-048.
- Animate each wave in sequence:
  - Wave 1 begins immediately (delay 0 ms).
  - Wave N begins after `(N - 1) * wave_delay_ms` milliseconds, where `wave_delay_ms`
    is a constant (default 300 ms; make it a named constant so it is easy to tune).
  - Within each wave, all nodes at that depth transition from dimmed to their task-048
    gradient colour simultaneously.
  - The transition for each individual node is a smooth interpolation over `fade_ms`
    milliseconds (default 200 ms; also a named constant). Use a `Tween` (Godot 4.6
    `create_tween()`) on the node material's `albedo_color` property.
  - The `"⚠ depth N"` label (from task-048) fades in with the same Tween as the colour
    transition (animate the label's `modulate.a` from 0 to 1).
- The animation is non-blocking: the human may continue to interact with the scene
  (pan/zoom/orbit) while the cascade plays. All input handling remains active during
  the animation.
- **Cascade attenuation feedback:** when a depth ring contains zero nodes (the cascade
  terminates before reaching that depth), emit no animation for that ring. This produces
  a natural "fade-out" effect: the waves stop arriving when there are no further
  dependents. No explicit attenuation label is needed; the absence of further waves is
  itself the signal.
- **Multi-failure:** when the human selects an additional failed node while a previous
  wave animation is still playing, cancel the previous `Tween` nodes and immediately
  snap all previously-animated nodes to their final depth-gradient colour, then begin
  the new animation from depth 1.
- **Reset / Escape:** cancels all active `Tween` nodes and restores the full dimmed
  Simulation Mode state (as per task-032's Reset logic). No partial animation state
  should remain after a reset.

- Use only GDScript and Godot 4.6 API (`create_tween`, `Tween.tween_property`). No
  external libraries.
