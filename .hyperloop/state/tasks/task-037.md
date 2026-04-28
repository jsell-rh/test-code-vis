---
id: task-037
title: Godot — spec node inspection panel
spec_ref: specs/core/system-purpose.spec.md
status: not-started
phase: null
deps: [task-036, task-030]
round: 0
branch: null
pr: null
---

When the human clicks a spec_item node in Conformance Mode, display a readable panel
showing the full requirement text so the spec's intent is directly inspectable
alongside the realized codebase structure.

Covers `specs/core/system-purpose.spec.md` — Requirement: Spec-Driven Context, Scenario:
Spec and codebase loaded together ("the relationship between them is available for
inspection"):

- This feature is only active while Conformance Mode (task-030) is on; clicking a
  spec_item node outside Conformance Mode has no effect.
- **Panel appearance**: display a CanvasLayer panel (e.g. a PanelContainer with a
  RichTextLabel child) anchored to the right side of the viewport.
  - Header line: the node's `name` field rendered in bold.
  - Body: the node's `spec_body` field rendered as plain text (newlines preserved).
  - Footer: `spec_ref` value in a smaller italic style (the originating file path).
  - If `spec_body` is absent or empty, display "(no body text)" in the body area.
- **Triggering**: clicking a `spec_item` MeshInstance3D node (identified by node
  type metadata set during scene load in task-030) opens the panel with that node's
  data. Clicking the same node again, pressing `Escape`, or clicking elsewhere in
  the scene closes the panel.
- **Simultaneous conformance display**: opening the panel must not suppress the
  conformance colouring or spec_to_code connecting lines rendered by task-030. Both
  the coloured scene and the text panel are visible at the same time.
- **Highlight on open**: when the panel is open for a node, apply a brighter emissive
  outline or pulsing material to the selected spec_item node so the human can see
  which requirement they are reading.
- **Panel dismissal**: closing the panel (Escape or outside-click) removes the
  emissive highlight and returns the node to its normal Conformance Mode appearance.
- The panel must not intercept camera navigation controls (pan, zoom, orbit from
  tasks 015–017); input events consumed by the panel do not propagate to the camera.
- Use only GDScript and Godot 4.6 API.
