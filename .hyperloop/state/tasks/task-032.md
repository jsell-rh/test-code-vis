---
id: task-032
title: Implement Distortion Legend renderer in Godot
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-014, task-019, task-020, task-030]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement Distortion Legend (always-visible panel showing current view distortions)"
pr_description: |
  ## What and Why

  This PR implements the **Distortion Legend** as defined in `specs/core/visual-primitives.spec.md`
  (Composition Principles § Distortion Legend). Every composed view is a deliberate distortion of
  the full codebase — elements are hidden by LOD, edges are suppressed as power rails, Tints encode
  a category. Without a legend, the human cannot tell the difference between "this module has no
  dependencies" and "this module's dependencies are suppressed." The Distortion Legend makes the
  distortion explicit and prevents the human from mistaking a filtered view for a complete picture.

  The spec frames this as a core design principle: *what is hidden is as important as what is shown*.

  ## Spec Requirements Satisfied

  - A persistent legend panel is always visible when the 3D scene is loaded.
  - The legend shows, at minimum:
    - **Tint encoding**: what the active Tint colour channel represents (e.g. "Tint: bounded context
      domain"). If no Tint is active, shows "Tint: none".
    - **Suppressed edges**: count of edges suppressed by power rail notation (e.g. "Power rails:
      3 ubiquitous modules suppressed, 47 edges hidden"). Reads from the metadata written by
      task-027 and the power rail state from task-030.
    - **LOD-hidden elements**: count of nodes/edges not visible at the current zoom tier (e.g.
      "Showing 12 of 147 modules at current zoom").
    - **Active Landmarks**: list of currently highlighted Landmark nodes.
  - The legend updates dynamically as the human changes zoom level (LOD tier) or toggles power
    rails.
  - The legend is rendered as a 2D overlay (CanvasLayer in Godot) rather than a 3D element, so it
    remains readable regardless of camera angle.
  - The Tint legend is ONLY shown when a Tint is active; it is absent (not greyed out) otherwise.

  ## Design Notes

  The Distortion Legend is the one element in the prototype that validates the "principled
  information loss" design principle. Its presence makes the prototype a honest visualization rather
  than one that silently hides information. Even a minimal text-based panel (a Control node with
  labels) satisfies this requirement for the prototype.

  ## Files / Areas Affected

  - `godot/` — new 2D CanvasLayer scene containing the legend Control node.
  - The legend script queries: LOD tier state (task-014), Tint assignments (task-019), active
    Landmarks (task-020), and power rail suppression counts (task-030).
  - The main scene (or scene loader, task-011) adds the legend CanvasLayer as an always-on overlay.

  ## How to Verify

  1. Load the kartograph scene graph in Godot.
  2. Confirm: legend panel is visible in a screen corner.
  3. At far zoom (tier 0): legend shows "Showing N bounded contexts, M hidden at this zoom".
  4. Zoom to medium (tier 1): legend updates to show module-level counts.
  5. With power rails active (task-030): legend shows "Power rails: X modules suppressed, Y edges
     hidden".
  6. Toggle ubiquitous edges on: legend updates suppression count to 0 while visible.
  7. Toggle off: suppression count returns.
  8. If Tint is active (task-019): legend shows what Tint encodes.
  9. Godot test suite passes, no script errors.

  ## Caveats / Follow-up

  - For the prototype, the legend is read-only and informational only. Future iterations may make
    it interactive (click a legend item to toggle the facet).
  - The legend does NOT describe edge weight encoding in this implementation; that is a future
    enhancement consistent with the full Distortion Legend spec.
  - If Tint (task-019) or Landmarks (task-020) are not yet implemented when this task runs,
    the legend can show placeholder text ("Tint: not implemented") without blocking this task.
    The legend should be implemented even in a minimal form so the principle is established.
---
