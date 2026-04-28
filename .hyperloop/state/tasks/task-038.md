---
id: task-038
title: Godot — mode controller autoload (mutual exclusivity)
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-030, task-031, task-034]
round: 0
branch: null
pr: null
---

Implement a lightweight `ModeController` autoload (GDScript) that is the single
authority for which understanding mode is active. Without this coordinator, the three
mode scripts (task-030, task-031, task-034) each toggle only their own state — entering
Conformance Mode does not deactivate an already-active Evaluation Mode, and vice versa.
This task makes mode transitions correct.

Covers `specs/core/understanding-modes.spec.md` — Purpose: "transitions between them":

- Add an autoload singleton `ModeController` (e.g. `godot/autoload/mode_controller.gd`)
  registered in `project.godot` so every scene can access it.
- Expose a `set_mode(mode: String)` method. Valid values:
  - `"conformance"` — activate Conformance Mode (task-030)
  - `"evaluation"` — activate Evaluation Mode (task-031)
  - `"simulation"` — activate Simulation Mode (task-034)
  - `""` — deactivate all modes
  Passing the currently-active mode name again toggles it off (sets mode to `""`).
- Emit a `mode_changed(new_mode: String)` signal after every state change. All three
  mode scripts connect to this signal and use it to activate or deactivate themselves:
  - If the signal carries their own mode name → activate.
  - If the signal carries a different name or `""` → run their cleanup/deactivation.
- Update the keyboard toggle handlers in task-030 (key `C`), task-031 (key `E`), and
  task-034 (key `S`) to call `ModeController.set_mode(...)` instead of toggling local
  state directly. Do not change any other logic in those scripts.
- Store the current mode in a `current_mode: String` property (default `""`).
- ModeController must not contain any rendering or scene-graph logic — it is a state
  machine only. All visual changes remain in the individual mode scripts.
- Use only GDScript and Godot 4.6 API. No external libraries.
