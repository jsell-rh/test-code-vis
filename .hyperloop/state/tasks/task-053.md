---
id: task-053
title: Godot — animated mode transitions (fade-in/fade-out on toggle)
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-050, task-030, task-031, task-032]
round: 0
branch: null
pr: null
---

Implement smooth animated transitions when any understanding mode is activated or
deactivated — no visual state should snap or pop. Mode visual encodings fade in when
a mode is toggled on and fade out when toggled off, and modes that remain active
animate to use any newly freed visual channels.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Mode Composition, Scenarios:
Activating a second mode ("the second mode's visual encoding fades in smoothly, layering
on top of the first — no visual state snaps or pops — transitions are always animated")
and Deactivating a mode ("that mode's visual encoding fades out smoothly AND the remaining
mode's encoding expands to use the freed visual channels if appropriate AND the transition
is animated and continuous"):

**Trigger:** All mode transitions go through ModeController (task-050), which emits
`mode_changed(active_modes: Array)`. This task adds a transition coordinator that
intercepts that signal and orchestrates the animated handoff.

**Transition coordinator — new autoload or utility class:**
- Add `ModeTransitionCoordinator` (e.g. `godot/autoload/mode_transition_coordinator.gd`)
  that connects to `ModeController.mode_changed`.
- The coordinator holds the previous `active_modes` set (snapshot before the change) and
  the new `active_modes` set.
- It computes three diff lists:
  - `entering`: modes in new set but not in previous set.
  - `leaving`: modes in previous set but not in new set.
  - `staying`: modes in both sets.
- For each mode in `leaving`: call `mode_script.begin_fade_out(duration_ms)`.
- For each mode in `entering`: call `mode_script.begin_fade_in(duration_ms)`.
- For each mode in `staying` that is affected by a channel change (e.g. Evaluation
  switching from primary to secondary fill because Simulation entered): call
  `mode_script.begin_channel_transition(duration_ms)`.
- Default `duration_ms = 250`. Named constant, easy to tune.

**Mode script API additions** (one per mode script):

Each mode script must implement three new methods:

`begin_fade_in(duration_ms: float) -> void`
  - Called when this mode is being activated.
  - Start all node materials at `albedo_color.a = 0` (or modulate `= Color(1,1,1,0)`
    for Label3D nodes) and Tween them to their target colour/alpha over `duration_ms`.
  - Do NOT snap materials to final state — the fade must be visible.

`begin_fade_out(duration_ms: float) -> void`
  - Called when this mode is being deactivated.
  - Tween all mode-specific materials and labels from their current colour/alpha to
    the base structural appearance (task-009 defaults) over `duration_ms`.
  - On Tween completion, call the mode's existing cleanup logic (remove Label3D nodes,
    restore default materials) so the scene is clean for the next activation.

`begin_channel_transition(duration_ms: float) -> void`
  - Called when this mode stays active but must shift visual channels (e.g. Evaluation
    switching from fill-based to border-based rendering after Simulation activates).
  - Tween the outgoing channel's alpha/colour to transparent, then cross-fade to the
    new channel's encoding over `duration_ms`. The transition must be simultaneous
    enough that the human never sees a blank state in between.

**Constraints:**
- If a new `mode_changed` signal fires while a transition is still in progress, cancel
  all active Tweens immediately and start the new transition from the current interpolated
  state. Do not wait for the previous animation to finish.
- The wave animation from task-049 is independent of mode transition animations; both
  may run concurrently without interference.
- The cascade depth gradient is applied post-fade-in (the Simulation mode fades in its
  dimmed entry state, not the cascade colours — cascade animation is task-049's concern).
- All Tweens must use `create_tween()` (Godot 4.6 API); do not use deprecated
  `$AnimationPlayer` patterns.
- Transition animations must not block input: camera controls, mode toggle keys, and
  node clicks must remain responsive during any transition.

**HUD transition:** the mode HUD (task-039) chips switch state instantly (text labels
do not need to fade); only node-level materials and floating label3D nodes animate.

**No schema or extractor changes.** Godot-only task.

- Use only GDScript and Godot 4.6 API. No external libraries.
