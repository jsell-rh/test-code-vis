---
id: task-091
title: Godot — Distortion Legend panel (current view encoding and suppression summary)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-089, task-090, task-086]
round: 0
branch: null
pr: null
---

Implement the Distortion Legend panel in the Godot application: a permanent, always-
visible HUD panel that makes the current view's distortions explicit — what the Tint
encodes, what is suppressed (power rails, LOD-hidden nodes), and which Landmarks are
active.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Distortion Legend
("Every composed view MUST include a legend that makes the current distortion explicit.
What's hidden is as important as what's shown"):

**Panel structure** — a `CanvasLayer` with a `PanelContainer` anchored to the
bottom-left of the viewport (distinct from the right-anchored detail panels used by
task-040 and task-037). The panel is NOT dismissable.

**Legend sections** (rendered as a vertical stack of `Label` nodes within the panel):

**Section 1 — Tint encoding:**
- Connect to `TintController.dimension_changed` (task-089).
- When `dimension == "none"`: display `"Colour: structural"` (no categorical
  encoding active).
- When `dimension == "context"`: display `"Colour: bounded context"` followed by
  a row of coloured squares (one per context, with the context name label).
- When `dimension == "community"`: display `"Colour: detected community"` followed
  by coloured squares per community.
- The coloured squares are small `ColorRect` nodes (16×16 px) with the tint palette
  colour, labelled with the category name.

**Section 2 — Suppressed elements:**
- Connect to the power-rail toggle state (task-090).
- Display `"Edges suppressed: X power rails"` where X = count of ubiquitous edge
  targets (from `metadata.ubiquitous_deps`). When power rails are shown (`U` toggle
  ON), display `"Power rails: visible (toggle U to hide)"`.
- Display `"Nodes hidden by LOD: Y"` where Y = count of nodes currently not visible
  due to LOD distance (computed in `_process()` by counting nodes with
  `visible == false` due to LOD, not mode-specific hiding).

**Section 3 — Scope summary:**
- Display `"Showing M of N modules"` where:
  - N = total module node count in the scene graph.
  - M = count of module nodes currently `visible == true` (excludes LOD-hidden).
- This updates in `_process()` (or on LOD change signal if the LOD system emits one).

**Section 4 — Active Landmarks:**
- Connect to the landmark list from task-086 (the `LandmarkManager` or equivalent
  autoload — if task-086 creates a landmark list, read from it; otherwise read from
  the scene graph loader directly).
- Display `"Landmarks: <name1>, <name2>, ..."` listing the names of all landmark
  nodes. If more than 5 landmarks exist, show the first 4 and `"… +N more"`.

**Update triggers** — the legend updates when:
- `TintController.dimension_changed` fires (tint section).
- Power rail toggle changes (suppression section).
- A `_process()` tick if the LOD visibility has changed (scope summary + LOD section).
  Rate-limit this check to once per 0.5 s to avoid per-frame string rebuilds.

**Visual design:**
- Panel background: semi-transparent dark (`Color(0.05, 0.05, 0.05, 0.75)`).
- Text: white, font size 11.
- Maximum panel height: 30% of viewport height; scroll if needed.
- Minimum panel width: 240 px.

**Mode compatibility** — the legend panel is always visible and does NOT interact
with the mode HUD (task-039) or mode-specific panels. Both can coexist.

Use only GDScript and Godot 4.6 API. No external libraries.
