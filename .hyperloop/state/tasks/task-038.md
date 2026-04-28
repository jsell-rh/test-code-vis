---
id: task-038
title: Godot — Mode Manager: mutual exclusivity and transitions
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-030, task-031, task-032]
round: 0
branch: null
pr: null
---

Implement a Mode Manager autoload singleton in Godot that coordinates Conformance Mode
(task-030), Evaluation Mode (task-031), and Simulation Mode (task-032), enforcing that
only one mode can be active at a time and that transitions between modes are clean.

Covers `specs/core/understanding-modes.spec.md` — Purpose: "the transitions between
them"; and `specs/core/system-purpose.spec.md` — Requirement: Support the Architecture
Feedback Loop (the iterative evaluate → refine loop requires moving fluidly between all
three modes without leftover visual state from a prior mode).

**Mode Manager singleton (`ModeManager.gd` registered as an autoload):**
- Tracks the currently active mode as an enum: `NONE`, `CONFORMANCE`, `EVALUATION`,
  `SIMULATION`.
- Exposes a `set_mode(new_mode)` method that:
  1. If `new_mode` equals the current mode, deactivates it (toggle off) and sets mode
     to `NONE`.
  2. Otherwise, calls the active mode's cleanup/reset function first (so no stale
     visual state leaks into the next mode), then activates the requested mode.
- Emits a `mode_changed(old_mode, new_mode)` signal after every transition so the HUD
  and individual mode controllers can react without polling.

**Keyboard routing:**
- Remove direct toggle handling from each mode's own script for the activation keys
  (`C`, `E`, `S`). Instead, `ModeManager` handles `_unhandled_input` for these three
  keys and calls `set_mode()`.
- Each mode controller retains its internal rendering logic and its own cleanup/reset
  function (called by the Mode Manager on deactivation); it no longer handles its own
  activation keypress.

**HUD integration:**
- Replace the per-mode HUD labels ("CONFORMANCE MODE", "EVALUATION MODE",
  "SIMULATION MODE") with a single shared HUD element driven by the `mode_changed`
  signal: show the active mode name in the corner, or nothing when `NONE`.
- The existing per-mode HUD content (legends, warning banners, simulation HUD buttons)
  is unchanged; only the top-level mode-name label is unified.

**Cleanup contract for each mode:**
- Conformance Mode cleanup: reset all node/edge materials to base structural appearance,
  hide spec-item volumes and connecting lines, clear the HUD.
- Evaluation Mode cleanup: reset all node/edge materials and remove CRITICAL Label3D
  nodes, clear the HUD.
- Simulation Mode cleanup: call the existing Escape-exit path from task-032 (remove
  failure/affected markers, restore base appearance), clear the HUD.

**Invariants:**
- At most one mode is active at any time; no combination of two or three modes is
  ever simultaneously active.
- Calling `set_mode(NONE)` is always safe and always results in the base structural
  appearance being restored regardless of which mode was previously active.
- The Mode Manager does not reparse or reload the scene graph; it operates only on
  already-loaded Godot node state.

**Escape handling:**
- `Escape` remains the exit key for Simulation Mode (task-032) but is now also wired
  through the Mode Manager so it calls `set_mode(NONE)`, ensuring a clean state reset
  consistent with all other mode exits.

Use only GDScript and Godot 4.6 API.
