---
id: task-110
title: Godot — Distortion Legend: edge weight encoding section
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-091, task-094]
round: 0
branch: null
pr: null
---

Extend the Distortion Legend panel (task-091) with a section that explicitly states
what edge line thickness encodes in the current view, fulfilling the spec's requirement
that the legend describes every active visual encoding dimension including edge weight.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Distortion Legend,
Scenario: Legend contents:

> "THEN the legend shows: what Tint encodes, **what Edge weight encodes**, what is
> suppressed (power rails, LOD-hidden elements), and what Landmarks are active"

Task-091 implements Tint encoding (Section 1), suppression summary (Section 2),
scope count (Section 3), and active Landmarks (Section 4), but omits the edge
weight encoding entry. This task closes that gap.

---

**New legend entry — "Edge thickness"**

Insert a `Label` node named `"EdgeWeightLabel"` at the top of the vertical stack
inside the existing `PanelContainer` (task-091), above the Tint encoding section,
so the legend order matches the spec's listed sequence (edge weight → Tint →
suppression → Landmarks):

```
Edge thickness: import count
```

Add an `HSeparator` node immediately below `"EdgeWeightLabel"` to visually separate
it from the Tint encoding section, following the same pattern as existing separators
between legend sections.

---

**Implementation** (inside `_ready()` of the Distortion Legend script):

```gdscript
var edge_weight_label := Label.new()
edge_weight_label.name = "EdgeWeightLabel"
edge_weight_label.text = "Edge thickness: import count"
edge_weight_label.add_theme_font_size_override("font_size", 11)
edge_weight_label.modulate = Color(1, 1, 1, 1)
edge_weight_label.autowrap_mode = TextServer.AUTOWRAP_WORD
panel_vbox.add_child(edge_weight_label)
panel_vbox.move_child(edge_weight_label, 0)  # move to top of stack

var sep := HSeparator.new()
panel_vbox.add_child(sep)
panel_vbox.move_child(sep, 1)
```

`panel_vbox` is the `VBoxContainer` that task-091 already creates to hold Sections
1–4. No other changes to that container's children are required.

---

**Static value** — in the prototype, edge weight always encodes the number of
individual import statements between two modules (set by tasks 063 and 094). This
meaning is invariant across understanding modes (Conformance, Evaluation, Simulation)
and across Tint dimensions. The label is set once in `_ready()` and never needs to
update at runtime.

**No update trigger needed** — unlike the Tint and suppression sections, edge weight
encoding does not change in response to any runtime signal in the current prototype.
If a future task introduces an overlay that reassigns edge weight to a different
quantity (e.g. blast-radius intensity), that task is responsible for updating
`EdgeWeightLabel.text`.

**Interaction with existing sections** — do NOT alter Sections 1–4 defined in
task-091. This task only inserts two new nodes at the top of the `VBoxContainer`;
all existing legend logic, signals, and visual design remain unchanged.

**Visual design** — consistent with task-091:
- Font size: 11
- Text colour: white (`Color(1, 1, 1, 1)`)
- Panel background, maximum height, scroll, and minimum width: unchanged from task-091

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
