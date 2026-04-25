---
id: task-013
title: Godot — dependency line rendering (directed edges)
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-009]
round: 0
branch: null
pr: null
---

Render each edge in the JSON as a visible line connecting the source and target node volumes,
with direction indicated.

Covers:
- For each edge dict, draw a line (using `ImmediateMesh` or a thin `CylinderMesh`) between
  the centre positions of the source and target nodes.
- Indicate edge direction visually (e.g. an arrowhead mesh at the target end, or a colour
  gradient from source to target).
- Distinguish `cross_context` edges from `internal` edges visually (e.g. different colour
  or thickness).
- Lines must not obscure node volumes; render with appropriate depth offset or transparency.
