---
id: task-101
title: Godot — tier-2 LOD rendering of class and function scope nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-100, task-067, task-010, task-008]
round: 0
branch: null
pr: null
---

Extend the Godot application to load, render, and show/hide `class` and `function`
nodes from the scene graph at a fourth LOD sub-tier ("very near"), so the human can
see the internal structure of a module when close enough — classes as nested Container
volumes, functions as small nodes within their class.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Scope Nesting
Extraction ("the tree is available for the composition layer to map onto nested
containers at any depth") and Requirement: LOD Shell Primitive, Scenario: Three-tier
LOD ("tier 2 (near): modules expand to show classes, functions, and all Edges"):

---

**Loader extension** — extend the scene graph loader autoload (task-008):

1. After loading `bounded_context` and `module` nodes, read any additional nodes
   with `type == "class"` or `type == "function"` from the `nodes` array.
2. Build two lookup dictionaries:
   - `class_nodes: Dictionary` → `{ node_id: node_dict }`
   - `function_nodes: Dictionary` → `{ node_id: node_dict }`
3. Build a parent-to-children map:
   - `scope_children: Dictionary` → `{ parent_id: Array[node_id] }` covering
     module→classes, class→methods, and module→module-level-functions.
4. If no `class` or `function` nodes are present (extractor ran without
   `--scope-nesting`), all three structures are empty and this task is a no-op.

---

**Class node rendering** — after module volume meshes are created (task-010), for
each loaded class node:

1. Create a `MeshInstance3D` for the class node:
   - Mesh: `BoxMesh` with `size = Vector3(node.size, node.size * 0.35, node.size)`
     (flat box, nested visually within the taller module volume).
   - Position: verbatim from JSON `position` field (absolute world coordinates).
   - Material: `StandardMaterial3D` with
     `albedo_color = Color(0.45, 0.65, 0.85, 0.50)` (cool blue, semi-transparent),
     `transparency = ALPHA`, `cull_mode = CULL_DISABLED`.
2. Add a `Label3D` child above the mesh: class `name` field, `font_size = 12`,
   `billboard = BaseMaterial3D.BILLBOARD_ENABLED`.
3. Parent the `MeshInstance3D` to the same `Node3D` root as the module mesh (sibling,
   not child, to avoid inheriting module transforms).
4. **Initial state**: `visible = false`, `modulate.a = 0.0`.

---

**Function node rendering** — for each loaded function node:

1. Create a `MeshInstance3D`:
   - Mesh: `BoxMesh` with `size = Vector3(node.size, node.size * 0.5, node.size)`.
   - Position: verbatim from JSON.
   - Material: `StandardMaterial3D` with
     `albedo_color = Color(0.78, 0.84, 0.90, 0.90)` (light grey-blue, mostly opaque).
2. Add a `Label3D` child:
   - `text` = function `name`; append `" +" if `visibility == "public"` (absent or
     private: no suffix).
   - `font_size = 10`, `billboard = BaseMaterial3D.BILLBOARD_ENABLED`.
3. If `signature` field is present, add a second, smaller `Label3D` below the name
   label: `font_size = 8`, `modulate.a = 0.65`, text = signature truncated to 36
   chars with `…`.
4. **Initial state**: `visible = false`, `modulate.a = 0.0`.

---

**LOD integration** — add a fourth distance constant below `NEAR_THRESHOLD`:

```
CLASS_THRESHOLD = NEAR_THRESHOLD * 0.45   # tune to fit kartograph extents
```

Named constant; adjust with the project. `CLASS_THRESHOLD < NEAR_THRESHOLD` always.

In `_process()`, after the existing three-tier LOD computation (task-067), for each
module that has class/function children in `scope_children`:

- **Camera farther than `CLASS_THRESHOLD` from the module**: if class/function meshes
  are visible, tween `modulate.a` to 0.0 (0.25 s); set `visible = false` on completion.
- **Camera closer than `CLASS_THRESHOLD` to a module**: if class/function meshes are
  hidden, set `visible = true`, tween `modulate.a` to target alpha
  (class: `0.50`, function: `0.90`) over 0.30 s.

Transitions are always animated — no binary `visible` flips mid-frame. Use
`create_tween()` (Godot 4.6 API). Set `visible = true` before fade-in; set
`visible = false` in the fade-out completion callback only.

---

**Mode compatibility** — class and function node meshes use their own base material
(surface slot 0). Mode-specific overlays (Conformance, Evaluation, Simulation) and
Tint overlays (surface slot 1) are applied only to module and bounded-context nodes
and are NOT applied to class/function nodes.

Badge glyphs (task-087), Port glyphs (task-088), Beacon glyphs (task-097), interior
indicators (task-098), and purpose/invariant labels (task-096) are defined only for
module and bounded-context nodes and are unaffected by this task.

---

**Scope nesting absent** — if the loader finds no `class` or `function` nodes,
`_process()` scope-nesting block is a no-op and no extra geometry is created.

Use only GDScript and Godot 4.6 API. No external libraries.
