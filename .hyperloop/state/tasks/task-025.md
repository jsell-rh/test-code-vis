---
id: task-025
title: Godot — view spec interpreter
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps: [task-024, task-009, task-010, task-013]
round: 0
branch: null
pr: null
---

Implement the Godot subsystem that parses a view spec JSON object and applies its
operations to the live 3D scene, transforming the structural geography in response to a
question-driven view.

Covers `specs/interaction/moldable-views.spec.md` — Requirement: View Specs as
Intermediate Representation and Requirement: Fixed Visual Primitive Set:
- Implement a GDScript class (e.g. `ViewSpecInterpreter`) that accepts a parsed view spec
  Dictionary and applies each operation in `operations` order.
- Implement all six primitives from the view spec schema (task-024):
  - `show` — make the specified node MeshInstance3D nodes visible.
  - `hide` — set specified node MeshInstance3D nodes to invisible.
  - `highlight` — apply a tinted emissive material override to specified nodes using the
    provided hex colour; fall back to a default highlight colour if `color` is absent.
  - `arrange` — reposition specified nodes according to the named layout strategy:
    `"circle"` places them in a horizontal ring; `"column"` stacks them vertically;
    `"default"` resets them to their original positions from the JSON scene graph.
  - `annotate` — attach a Label3D (or a 2D CanvasItem positioned in world space) with the
    given text above the specified node.
  - `connect` — draw a labelled line (MeshInstance3D or ImmediateMesh) between source and
    target nodes with the given label text.
- Maintain a snapshot of the pre-spec scene state so the scene can be fully reset to its
  original appearance when the view spec is dismissed (e.g. on `Escape` or a reset call).
- Validate the view spec before applying it (using the validator from task-024); log a
  warning and skip invalid operations without crashing.
- Expose a public `apply(spec: Dictionary) -> void` and `reset() -> void` API so
  task-026 can drive the interpreter without coupling to its internals.
- Use only GDScript and Godot 4.6 API.
