---
id: task-077
title: Schema — badge vocabulary on nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-074, task-075, task-076]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema to define the `badges` array on node
entries, establishing the closed vocabulary of aspect badges that the extractor
computes and the Godot renderer displays.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Badge Primitive
("A Badge primitive: a small glyph docked to a Node indicating an aspect or
cross-cutting property. New Badge types can be added to the vocabulary by extending
the extractor, not by LLM invention at runtime"):

**New field — `badges` array on any node entry** (absent if badge computation has
not run):

```
badges (array | absent, optional)
  Each entry in the array is a badge object:

  type  (string) — one of the fixed badge vocabulary values listed below
```

**Badge vocabulary** — the closed set of valid `type` values:

| Badge type        | Meaning                                                              |
|-------------------|----------------------------------------------------------------------|
| `pure`            | No IO, no side effects, no mutable state access (heuristic)          |
| `io`              | Performs IO operations (file, network, database, subprocess)         |
| `async`           | Contains `async def` declarations or `await` expressions             |
| `stateful`        | Holds or mutates module-level or class-level mutable state           |
| `error_handling`  | Contains try/except blocks or error-recovery decorators              |
| `test`            | Name begins with `test_` or resides under a `tests/` directory       |
| `entry_point`     | Has no incoming edges from application code (top-level initiator)    |
| `deprecated`      | Carries a `@deprecated` decorator or `# deprecated` comment          |

**Ordering** — badges in the `badges` array MUST be listed in the vocabulary order
above (the order mirrors the display order in the Godot renderer).

**Constraint: closed set** — the validator MUST reject any badge `type` value not
in the vocabulary above. The vocabulary may be extended in future intake rounds by
modifying both this schema task and the badge computation extractor task; new types
are never invented at render time.

**Validator updates** (extend validator from task-076):
- `badges`, if present, MUST be an array (may be empty).
- Each badge entry MUST have a `type` field whose value is one of the eight valid
  vocabulary values.
- `badges` is NOT required — absent means badge computation has not run.

**Worked example** — add to the schema document's examples section:

```json
{
  "id": "iam.application",
  "name": "Application",
  "type": "module",
  "parent": "iam",
  "position": { "x": 10.0, "y": 0.0, "z": 5.0 },
  "size": 1.4,
  "badges": [
    { "type": "io" },
    { "type": "async" },
    { "type": "error_handling" }
  ]
}
```

**Non-deliverables** — do NOT implement:
- The badge computation logic (task-084).
- Any Godot rendering (task-087).
