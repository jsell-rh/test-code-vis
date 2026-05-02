---
id: task-030
title: Implement Power Rail Notation renderer in Godot
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-013, task-027]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Power Rail Notation (suppress ubiquitous dependency edges)"
pr_description: |
  ## What and Why

  This PR implements **Power Rail Notation** as defined in `specs/core/visual-primitives.spec.md`
  (Composition Layer § Power Rail Notation). When `logging`, `os`, `typing`, and similar
  stdlib/utility modules are imported by 60–90% of the codebase, drawing their dependency edges
  makes the scene unreadable — every Node has lines radiating out to the same few ubiquitous
  modules. Electronics schematics solve this with the "power rail" convention: connect to a named
  rail symbol instead of drawing every wire.

  This task applies the same principle: edges flagged `ubiquitous: true` by the extractor
  (task-027) are NOT rendered as Edge primitives. Instead, each Node that has a ubiquitous
  dependency shows a small, consistent indicator (a "rail glyph") at its base, and the ubiquitous
  module itself is not placed in the structural scene. A toggle allows the human to reveal all
  suppressed edges when they want to see the full dependency picture.

  ## Spec Requirements Satisfied

  - On scene load, edges with `"ubiquitous": true` are NOT rendered as visible Edge primitives.
  - Each Node whose outgoing edges include at least one ubiquitous edge displays a small
    power rail indicator glyph (e.g. a tiny rail icon or consistent shape at the node base).
  - Multiple ubiquitous targets each get their own indicator on the Node; at most 5–7 are shown
    (above that, the indicators themselves become noise — spec § Power Rail Notation).
  - The ubiquitous module node itself is NOT placed in the structural scene (it is a background
    dependency, not a first-class structural element).
  - A toggle (keyboard shortcut or UI button) fades in all suppressed ubiquitous edges. The
    toggle is reversible. When revealed, the visual immediately demonstrates WHY they were
    suppressed: the scene becomes cluttered.
  - The power rail glyph is visually consistent: same shape, same position (base of Node or
    bottom edge of Container) across all affected Nodes.

  ## Files / Areas Affected

  - `godot/` — modification to the scene graph loader (task-011) to skip rendering `ubiquitous: true`
    edges during initial load.
  - New or modified script to attach rail glyph indicator to Nodes/Containers with ubiquitous
    dependencies.
  - UI element or keyboard shortcut handler for the ubiquitous edge toggle.
  - Edge renderer (task-013) gains a visibility flag that the toggle controls.

  ## How to Verify

  1. Run the extractor with ubiquitous detection (task-027) to produce `scene_graph.json` with
     `"ubiquitous": true` edges (e.g. edges to `logging`).
  2. Load the scene in Godot. Confirm: no edges rendered to flagged ubiquitous modules.
  3. Confirm: Nodes that imported `logging` show a small rail glyph indicator.
  4. Activate the toggle (via keyboard or button). Confirm: suppressed edges fade in.
  5. Toggle off. Confirm: edges fade out again (reversible).
  6. Confirm: `logging` itself has no visible Node volume in the scene (not rendered as a
     structural element).
  7. Godot test suite passes, no script errors.

  ## Caveats / Follow-up

  - The toggle state is session-only (not persisted). This is sufficient for the prototype.
  - If more than 5–7 ubiquitous modules are detected, the indicator system should show the
    first 5 and a "+N more" indicator. This keeps the visual clean even with many ubiquitous
    deps.
  - The Distortion Legend (task-032) will display a "suppressed: N edges to M ubiquitous
    modules" count; that cross-cutting concern is handled there, not here.
---
