---
id: task-009
title: "Godot: containment rendering (nested volumes)"
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-008]
round: 0
branch: null
pr: null
---

## Goal

Render parent-child containment relationships so that child nodes appear visually inside their parent volume.

## Scope

- For nodes where `parent` is non-null, attach the child's 3D node as a child of the parent's 3D node in the Godot scene tree (or ensure child positions are offset correctly relative to parent)
- Parent (bounded context) volumes must be large enough to visually contain all their children
- Parent volumes must use a translucent material so children are visible through them
- The boundary of the parent must be visually distinct from the children (e.g. wireframe outline, different color, or semi-transparent surface)
- Child nodes are fully opaque and rendered inside the parent's bounds

## Acceptance

- Loading the kartograph scene graph shows bounded contexts as large translucent boxes with module volumes visible inside them
