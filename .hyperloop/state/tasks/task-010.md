---
id: task-010
title: Godot — containment rendering (nested translucent volumes)
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-009]
round: 0
branch: null
pr: null
---

Render parent–child containment relationships so that child modules visually appear inside
their parent bounded context volume.

Covers:
- Identify nodes with a non-null `parent` field; render their parent nodes as larger
  translucent volumes and the children as smaller opaque volumes inside them.
- Apply a semi-transparent material (alpha < 1) to bounded-context (parent) nodes so
  children are visible through the boundary.
- Apply an opaque material to module (child) nodes.
- Visually distinguish the parent boundary from its children (e.g. different colour tint,
  wireframe outline, or transparency level).
- Ensure the translucency is implemented correctly in Godot 4.6 (StandardMaterial3D with
  transparency enabled and correct render priority).
