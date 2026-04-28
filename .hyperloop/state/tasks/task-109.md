---
id: task-109
title: Godot — tier-2 LOD edge visibility for call graph and type topology edges
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-076, task-094, task-101]
round: 0
branch: null
pr: null
---

Make call graph edges (`direct_call`, `dynamic_call`) and type topology edges
(`inherits`, `has_a`) visible only when the camera crosses the `CLASS_THRESHOLD`
established by task-101, so that the tier-2 view satisfies the "all Edges" condition
in the LOD Shell primitive requirement.

Covers `specs/core/visual-primitives.spec.md` — Requirement: LOD Shell Primitive,
Scenario: Three-tier LOD ("tier 2 (near): modules expand to show classes, functions,
and **all Edges**"):

task-067 manages LOD visibility for module-level import/aggregate edges (`cross_context`,
`internal`) between bounded-context and module nodes. task-101 manages LOD visibility
for class and function **nodes** at `CLASS_THRESHOLD`. Neither task addresses call
graph or type topology **edges**, which connect function nodes to function nodes and
class nodes to class nodes. Without this task those edges are either always visible
(cluttering the far and medium views) or always hidden.

---

**Affected edge types** — from the edge list loaded by task-008 (schema: task-076):

| type           | connects                                              |
|----------------|-------------------------------------------------------|
| `direct_call`  | function node → function node                         |
| `dynamic_call` | function node → function node (target may be null)    |
| `inherits`     | class node → class node                               |
| `has_a`        | class node → class node                               |

---

**Initial state at scene load** — after task-094 creates visual geometry for these
edge types, immediately set:

```gdscript
for edge_visual in fine_grained_edge_visuals:
    edge_visual.visible = false
    edge_visual.modulate.a = 0.0
```

These edges must not appear at far or medium LOD.

---

**Data structures** — build at load time after task-094 finishes creating edge visuals:

1. `fine_grained_edge_visuals: Array[Node3D]` — all edge visual nodes whose source
   JSON edge has `type` in `["direct_call", "dynamic_call", "inherits", "has_a"]`.

2. `module_to_fine_edges: Dictionary` → `{ module_id (String): Array[Node3D] }` —
   groups each fine-grained edge visual by the module that owns its source node.
   Ownership: walk the `parent` field chain up from the source node's id until a node
   with `type == "module"` is reached; that module id is the key.

---

**LOD integration** — in `_process()`, immediately after the CLASS_THRESHOLD check
from task-101 (reuse the same `CLASS_THRESHOLD` constant without redefining it):

For each module `M` that has class/function children (`scope_children` from task-101):

- **Camera within `CLASS_THRESHOLD` of M** — for each edge visual in
  `module_to_fine_edges[M.id]` that is currently not visible:
  - Set `visible = true`.
  - Tween `modulate.a` from `0.0` to `0.9` over `0.30 s` using `create_tween()`.

- **Camera farther than `CLASS_THRESHOLD` from M** — for each edge visual in
  `module_to_fine_edges[M.id]` that is currently visible:
  - Tween `modulate.a` from current value to `0.0` over `0.20 s`.
  - In the tween completion callback: set `visible = false`.

Always use `create_tween()` (Godot 4.6 API). Set `visible = true` before starting a
fade-in tween; set `visible = false` only inside a tween completion callback. Never
snap `modulate.a` mid-frame. If a new tween fires for a node that already has an
active tween, kill the old tween before starting the new one to prevent alpha
oscillation.

---

**Dynamic call edges with null target** — `dynamic_call` edges where `target` is null
have no endpoint node. If task-094 did not create a visual for them (no valid line to
draw), they will not appear in `fine_grained_edge_visuals`. Skip silently; do not
crash on a missing lookup.

**Cross-module edges** — a `direct_call` edge from function A (in module X) to
function B (in module Y) is keyed to module X in `module_to_fine_edges`. It becomes
visible when module X crosses `CLASS_THRESHOLD`, regardless of module Y's distance.
This is consistent with how task-101 scopes node visibility to the owning module.

**Extractor ran without `--scope-nesting` or `--call-graph`** — if no class/function
nodes exist (`scope_children` is empty from task-101) or no fine-grained edges are
present, `fine_grained_edge_visuals` is empty and `_process()` is a no-op. No crash.

**Mode compatibility** — fine-grained edge visibility is structural, not mode-specific.
These edges appear at `CLASS_THRESHOLD` regardless of which understanding modes
(Conformance, Evaluation, Simulation) are active.

**No schema or extractor changes.** Godot-only task.

Use only GDScript and Godot 4.6 API. No external libraries.
