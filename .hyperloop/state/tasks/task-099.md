---
id: task-099
title: Schema — class and function node types for scope nesting hierarchy
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema (task-061) to define two new node
types — `class` and `function` — that allow the scope nesting hierarchy to extend
below the module level, enabling the composition layer to map class and function
containment onto nested Containers at LOD tier 2.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Scope Nesting
Extraction ("the full containment hierarchy of the codebase: project contains
packages, packages contain modules, modules contain classes, classes contain
methods — every leaf is an atomic declaration — the tree is available for the
composition layer to map onto nested containers at any depth"):

---

**New valid `type` values for node entries** (added to the existing set of
`bounded_context` and `module`):

```
class     — a Python class definition. Parent MUST be a `module` node id.
function  — a Python function or method. Parent is either a `module` id
            (module-level function) or a `class` id (method).
```

**Node shape for `class` and `function` entries** — all existing required fields
apply (id, name, type, parent, position, size, metrics), plus:

| Field        | class nodes                                       | function nodes                               |
|--------------|---------------------------------------------------|----------------------------------------------|
| `id`         | dot-separated path, e.g. `"iam.domain.Processor"` | e.g. `"iam.domain.Processor.process"`        |
| `name`       | class name, e.g. `"Processor"`                    | function/method name, e.g. `"process"`       |
| `type`       | `"class"`                                         | `"function"`                                 |
| `parent`     | module node id (required, non-null)               | module or class node id (required, non-null) |
| `position`   | absolute world coords within parent bounds        | absolute world coords within parent bounds   |
| `size`       | proportional to method count × mean LOC           | proportional to parameter count + body LOC   |
| `metrics`    | `{"loc": <int>}` (total LOC of class body)        | `{"loc": <int>}` (LOC of function body)      |

**Optional fields on `function` nodes:**

```
visibility  (string, optional) — "public" or "private"
signature   (string, optional) — reconstructed function signature string, e.g.
                                  "(order_id: str, amount: float) -> Result"
```

**`class` and `function` nodes are OPTIONAL** — their absence (when the extractor
ran without `--scope-nesting`) must not cause the Godot loader or validator to fail.

---

**Validator updates** (extend the validator from task-061):

1. Accept `class` and `function` as valid `type` values.
2. `class` nodes: `parent` MUST reference an id whose type is `module`.
3. `function` nodes: `parent` MUST reference an id whose type is `module` or `class`.
4. `class` and `function` nodes: `metrics.loc` is required (integer ≥ 0).
5. `visibility` on function nodes, if present, MUST be `"public"` or `"private"`.
6. Neither type is required; a scene graph with no `class` or `function` nodes is
   fully valid.

**Position semantics** — all positions are absolute world coordinates. The extractor
computes positions so that child nodes lie within the parent container's bounding box
`[position ± size/2]` on all axes. The Godot application renders positions verbatim.

---

**Worked example** — add to the schema document's examples section:

```json
{
  "id": "iam.domain.PaymentProcessor",
  "name": "PaymentProcessor",
  "type": "class",
  "parent": "iam.domain",
  "position": { "x": 2.1, "y": 0.0, "z": 1.5 },
  "size": 0.6,
  "metrics": { "loc": 142 }
}

{
  "id": "iam.domain.PaymentProcessor.process",
  "name": "process",
  "type": "function",
  "parent": "iam.domain.PaymentProcessor",
  "position": { "x": 2.1, "y": 0.0, "z": 1.7 },
  "size": 0.2,
  "metrics": { "loc": 38 },
  "visibility": "public",
  "signature": "(order_id: str, amount: float) -> Result"
}
```

**Non-deliverables** — do NOT implement:
- The extractor logic that discovers and emits class/function nodes (task-100).
- Godot rendering of class/function nodes at tier 2 (task-101).
