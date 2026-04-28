---
id: task-030
title: Godot — conformance view (spec-vs-realisation overlay)
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-028, task-029, task-008, task-027]
round: 0
branch: null
pr: null
---

Implement a conformance view mode in the Godot application. When active, the scene
overlays spec-intended structure on the as-built structure, making alignment and
divergence immediately visible. This implements the Conformance Mode requirement from
`specs/core/understanding-modes.spec.md`.

Covers:
- Add a toggleable conformance mode (e.g., keyboard shortcut `C` or a UI button) that
  activates/deactivates the overlay without reloading the scene.
- When conformance mode is active:
  - Nodes that carry one or more `spec_refs` are visually highlighted as "spec-covered"
    (e.g., a green tint or border on the volume).
  - Nodes that have no `spec_refs` are visually marked as "unspecced" (e.g., an amber
    tint), indicating the agent built something not described in the spec.
  - If the spec names a component as a separate entity but the realisation has merged
    it into another node (i.e., no separate node exists for the spec component), display
    a labelled indicator or annotation in the scene at the parent node's position, clearly
    showing the divergence (e.g., a floating label "payment [spec: separate service]").
- Conformance mode must not hide any node — it annotates on top of the existing scene.
- When conformance mode is inactive, the scene returns to its default appearance.
- Use GDScript and Godot 4.6 API only. No external libraries.

Scenario coverage:
- Spec-aligned: a spec-named auth service maps to a realised auth bounded context →
  the auth volume shows the "spec-covered" indicator.
- Spec-divergent: spec names payment as separate but it is inlined in order service →
  the order service node shows the divergence annotation.
