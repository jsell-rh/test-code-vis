---
id: task-075
title: Schema — symbol table data on nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema (task-061) to define the `symbols` array
on module nodes, providing the structured symbol table data that feeds Port rendering
(task-088) and badge computation (task-084).

Covers `specs/core/visual-primitives.spec.md` — Requirement: Symbol Table Extraction
("The extractor MUST produce the named entities in each scope — functions, types,
constants, variables — with their signatures and visibility"):

**New field — `symbols` array on `module` and `bounded_context` nodes** (absent if
symbol table extraction has not run):

```
symbols (array | absent, optional)
  Each entry in the array describes one named declaration:

  name        (string)            — identifier as written in source
  kind        (string)            — one of: "function", "class", "constant", "variable"
  visibility  (string)            — "public" or "private"
  signature   (string | null)     — for functions/methods: "(param: Type, ...) -> Return"
                                    as a single string; null for constants/variables or
                                    when no type annotations are present
```

**Visibility convention** — Python-specific:
- Names starting with `_` (single or double underscore) → `"private"`.
- All other names → `"public"`.

**Port derivation** — public `function` symbols in a module's `symbols` array are the
canonical source for Port rendering. The Godot Port primitive (task-088) reads the
`symbols` array directly; no separate `ports` field is needed.

**Validator updates** (extend validator from task-061):
- `symbols`, if present, MUST be an array (may be empty).
- Each symbol entry MUST have `name` (non-empty string), `kind` (one of the four
  valid values), `visibility` (one of the two valid values), and `signature`
  (string or null).
- `symbols` is NOT required — absent means symbol table extraction has not run for
  this node. The validator MUST NOT error on its absence.

**Worked example** — add to the schema document's examples section:

```json
{
  "id": "iam.domain",
  "name": "Domain",
  "type": "module",
  "parent": "iam",
  "position": { "x": 0.0, "y": 0.0, "z": 0.0 },
  "size": 1.8,
  "symbols": [
    {
      "name": "process_order",
      "kind": "function",
      "visibility": "public",
      "signature": "(order: Order, context: Context) -> Result"
    },
    {
      "name": "_validate_input",
      "kind": "function",
      "visibility": "private",
      "signature": "(data: dict) -> bool"
    },
    {
      "name": "MAX_RETRY",
      "kind": "constant",
      "visibility": "public",
      "signature": null
    }
  ]
}
```

**Non-deliverables** — do NOT implement:
- The extraction logic that populates `symbols` (task-078).
- Any Godot rendering (task-088).
