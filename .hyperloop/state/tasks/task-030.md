---
id: task-030
title: Godot — Conformance Mode
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-028, task-009, task-010, task-013, task-029]
round: 0
branch: null
pr: null
---

Implement Conformance Mode in the Godot application: a toggleable view that overlays
the spec structure on the realized codebase structure so the human can see alignment and
divergence at a glance.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Conformance Mode:

- Add a keyboard shortcut (e.g. `C`) that toggles Conformance Mode on and off.
- When Conformance Mode is off, the scene looks and behaves as in the base structural view.
- When Conformance Mode is on:
  - Render `spec_item` nodes as distinct translucent volumes (e.g. flat diamond or disc
    shape, coloured differently from codebase volumes) positioned on their spec plane.
  - For each `spec_to_code` edge, draw a faint connecting line from the spec volume to
    the corresponding codebase node, indicating the spec item is realized.
  - Codebase nodes that are targeted by at least one `spec_to_code` edge are highlighted
    in a "conformant" colour (e.g. green tint).
  - Spec nodes that have no `spec_to_code` edge are highlighted in a "divergence" colour
    (e.g. red/amber tint) to indicate unimplemented requirements.
  - Codebase nodes that are not targeted by any spec edge are highlighted in a neutral
    "undocumented" colour (e.g. grey tint) — they exist in the build but have no spec
    counterpart.
- Add a HUD label in the corner indicating "CONFORMANCE MODE" while active.
- If the loaded scene graph contains no `spec_item` nodes (e.g. extractor was run without
  `--specs`), toggling Conformance Mode shows a brief warning ("No spec data loaded")
  instead of changing the scene.
- Toggling off Conformance Mode resets all materials to their base structural appearance.
- Use only GDScript and Godot 4.6 API.
