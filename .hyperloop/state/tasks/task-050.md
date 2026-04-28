---
id: task-050
title: Godot — ModeController: simultaneous mode support
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-038]
round: 0
branch: null
pr: null
---

Refactor the `ModeController` autoload (task-038) to track a **set** of active modes
rather than a single active mode, enabling Conformance, Evaluation, and Simulation to
be active simultaneously as orthogonal understanding lenses.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Mode Composition ("modes
are orthogonal, not mutually exclusive. Multiple modes MAY be active simultaneously"):

**Current behaviour (task-038):** `ModeController` holds a single `current_mode: String`.
`set_mode(mode)` activates one mode and deactivates any previously active mode by emitting
a `mode_changed(new_mode: String)` signal. Each mode script activates on its own name and
deactivates on any other name or `""`.

**New behaviour:**

**State change:**
- Replace `current_mode: String` with `active_modes: Array[String]` (default `[]`).
- Add `is_mode_active(mode: String) -> bool` convenience method:
  returns `mode in active_modes`.

**API change:**
- Rename `set_mode(mode)` to `toggle_mode(mode: String)`:
  - If `mode` is in `active_modes`, remove it (deactivate that mode).
  - If `mode` is not in `active_modes`, add it (activate that mode without deactivating
    any currently active mode).
  - Emit `mode_changed(active_modes.duplicate())` after every state change.
- Keep a compatibility shim `set_mode(mode: String)` that clears `active_modes` and then
  calls `toggle_mode(mode)`, so existing callers that expect mutual exclusivity continue
  to work during the transition period. Mark the shim with a comment `# DEPRECATED — use
  toggle_mode`.

**Signal change:**
- Change the `mode_changed` signal parameter from `new_mode: String` to
  `active_modes: Array` (the full current set).
- Update all three mode scripts (task-030 Conformance, task-031 Evaluation, task-034
  Simulation) to connect to the updated signal:
  - Each script activates itself when its mode name **is present** in the received array.
  - Each script deactivates itself when its mode name **is absent** from the received array.
  - This is a mechanical change to the signal handler only; no rendering logic changes.
- Update the mode HUD (task-039) to connect to the updated signal and render all chips
  whose mode name is in the active set as "active", rather than just one.

**Keyboard toggle update:**
- Update key `C` (Conformance), `E` (Evaluation), `S` (Simulation) handlers to call
  `ModeController.toggle_mode(...)` instead of `set_mode(...)`.

**No rendering changes in this task:** ModeController remains a pure state machine.
All visual changes (layering, colour priority, animated transitions) are handled by
subsequent tasks (task-051, task-052, task-053).

- Use only GDScript and Godot 4.6 API. No external libraries.
