---
id: task-039
title: Godot — persistent mode-status HUD
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-038]
round: 0
branch: null
pr: null
---

Add a small always-visible status bar that shows which of the three understanding
modes is currently active and what keyboard shortcuts activate each one. Without this,
the architecture feedback loop (system-purpose Requirement: Support the Architecture
Feedback Loop) requires the human to remember three separate key bindings with no
on-screen confirmation of the current state.

Covers `specs/core/understanding-modes.spec.md` — Purpose: "transitions between them";
`specs/core/system-purpose.spec.md` — Requirement: Support the Architecture Feedback Loop:

- Add a CanvasLayer scene (e.g. `godot/ui/mode_hud.tscn`) that is always present in the
  main scene tree regardless of which mode is active.
- Render a compact horizontal strip (e.g. bottom-left corner, semi-transparent background)
  containing three chip labels:
  - `[C] Conformance`
  - `[E] Evaluate`
  - `[S] Simulate`
- Active mode chip: render in a bright, high-contrast colour (e.g. white text on a
  coloured background matching the mode's theme colour — green for conformance, yellow
  for evaluation, orange for simulation).
- Inactive mode chips: render in a dim, low-contrast style (e.g. grey text, no
  background fill) so the active mode is immediately obvious.
- When no mode is active, all three chips appear dim and a faint hint reads
  `"C / E / S — activate a mode"`.
- The HUD connects to `ModeController.mode_changed` (task-038) and updates the chip
  states whenever the active mode changes.
- The HUD is display-only: it does not handle input or emit mode changes itself.
- The strip must not overlap the mode-specific HUD elements added by task-030
  ("CONFORMANCE MODE" label), task-031 (evaluation legend), or task-032/task-034
  (simulation banners). Position it so all HUD elements are simultaneously visible.
- Use only GDScript and Godot 4.6 API. No external libraries.
