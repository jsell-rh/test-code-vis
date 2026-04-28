---
id: task-106
title: Godot — scene graph hot-reload via keyboard shortcut
spec_ref: specs/visualization/orthogonal-independence.spec.md
status: not-started
phase: null
deps: [task-008, task-070]
round: 0
branch: null
pr: null
---

Add a keyboard-triggered scene graph reload that re-reads the JSON file from disk
while the application is running, enabling the smooth node position animation
implemented in task-070 to actually fire when the human re-runs the extractor and
wants to observe structural changes (e.g. a new import that merges two formerly
independent groups).

Covers `specs/visualization/orthogonal-independence.spec.md` — Requirement: Spatial
Separation of Independent Groups, Scenario: Smooth regrouping on data change ("When
a new extraction produces different independence groups, then nodes animate smoothly
to their new positions — the transition preserves spatial continuity — nodes slide
rather than jump"). task-070 implements the animation; this task provides the trigger.

---

**Reload key** — `R` (un-shifted). Document this in the in-scene key legend (same
HUD that shows mode keys C/E/S from task-039).

**`_unhandled_input` handler** — in the main scene script (or a dedicated input
autoload):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R:
            _reload_scene_graph()
```

**`_reload_scene_graph()` function**:

1. Read the scene graph file path from the existing loader autoload (task-008):
   use the same path that was provided at startup (e.g. via command-line argument
   or a stored path in the loader's state).

2. Call the loader autoload's reload method (see below) — do NOT re-instantiate
   the scene; reuse all existing `MeshInstance3D` nodes and animate their positions.

3. Show a brief, non-blocking HUD notification: `"Reloading scene graph…"` in the
   corner for 1.5 s, then fade out. A simple `Label` node in a `CanvasLayer` with
   a `Tween` on `modulate.a` is sufficient.

---

**Loader autoload extension** (task-008):

Add a `reload(new_path: String = "") -> void` method:

1. If `new_path` is provided and non-empty, update the stored scene graph path.
   Otherwise re-read from the same path as the initial load.

2. Parse the new JSON file using the same parsing logic as the initial load.

3. Emit a `scene_graph_reloaded(new_data: Dictionary)` signal carrying the full
   new parsed data (nodes array, edges array, metadata, clusters,
   data_flow_spines — all top-level keys).

4. All systems that need to update on reload — task-070's smooth position animation,
   task-090's power-rail recalculation, task-091's legend count refresh, task-089's
   tint recomputation — connect to `scene_graph_reloaded` and respond independently.
   This keeps the reload mechanism decoupled: the loader emits, subscribers react.

---

**Error handling**:

- If the file cannot be read (path wrong, disk error): display `"Reload failed:
  <error>"` in the HUD notification for 3 s; do NOT crash or alter the currently
  displayed scene.
- If the JSON parses but fails schema validation: display `"Reload failed:
  invalid schema"` and keep the current scene.
- Both error states are recoverable — the human can fix the file and press R again.

---

**task-070 integration** — task-070 already implements `scene_graph_reloaded`
subscriber logic (animate MeshInstance3D nodes from old positions to new JSON
positions over 0.5 s). This task only provides the signal source; task-070's
animation fires automatically when the signal is emitted.

**`scene_graph_reloaded` subscriber checklist** (for implementation reference —
each subscriber is implemented in its respective task):
- task-070: smooth node position animation (independence groups) ✓
- task-067: re-apply LOD visibility state to new node set
- task-086: re-derive landmark list from new significance data
- task-090: re-build power rail glyph set from new ubiquitous edge flags
- task-091: refresh legend counts (module count, suppressed edge count)

These subscribers connect to `scene_graph_reloaded` independently; this task does
not implement them (they are the responsibility of their respective tasks, updated
when those tasks are implemented).

---

**HUD key legend update** — add `"[R] Reload"` to the mode HUD (task-039) key
reference row. The reload key does not toggle a mode; it is a one-shot action.

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
