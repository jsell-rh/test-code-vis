---
id: task-113
title: Schema — call_target_hint field on dynamic_call edges
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-076, task-099]
round: 0
branch: null
pr: null
---

Extend the JSON schema to define the optional `call_target_hint` object on
`dynamic_call` edges, carrying the name of the dynamically dispatched parameter
and its type annotation string from the enclosing function's signature.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Call Graph Extraction,
Scenario: Indirect calls ("the call site is emitted as a `dynamic_call` with no
resolved target AND the call site carries the parameter name and any type hints"):

The current schema (task-076) defines `dynamic_call` edges as
`{ "source": ..., "target": null, "type": "dynamic_call", "weight": N }`.
No field exists for the parameter name or its type annotation. Without this field
the LLM cannot reason about likely targets (e.g. inferring that `handler: Callable`
is likely called with a specific protocol), which is the whole point of recording
dynamic calls at all.

---

**New field — `call_target_hint` object on `dynamic_call` edges** (optional;
absent when the dynamic call site carries no useful type information):

```
call_target_hint (object | absent, optional)
  Only present on edges with type == "dynamic_call".
  MUST NOT be present on any other edge type.

  parameter_name  (string)        — the name of the local variable or parameter
                                    being called, as it appears in the source code.
                                    e.g. "handler", "callback", "dispatch_fn"

  type_annotation (string | null) — the type annotation string from the enclosing
                                    function's signature, as written in the source.
                                    e.g. "Callable", "Handler", "Callable[[Request], Response]"
                                    null when no annotation is present for this parameter.
```

**Validator updates** (extend the validator from task-076):

1. `call_target_hint`, if present, MUST only appear on edges whose `type` is
   `"dynamic_call"`. Presence on any other edge type is a validation error.
2. When present, `call_target_hint` MUST be an object containing:
   - `parameter_name`: a non-empty string.
   - `type_annotation`: a string or JSON null.
3. When absent on a `dynamic_call` edge: valid. The hint is best-effort; not
   every dynamic call site can be meaningfully annotated.

**Worked example** — add to the schema document's examples section:

```json
// Dynamic call WITH type hint:
{
  "source": "iam.application.handle_request",
  "target": null,
  "type": "dynamic_call",
  "weight": 2,
  "call_target_hint": {
    "parameter_name": "handler",
    "type_annotation": "Callable[[Request], Response]"
  }
}

// Dynamic call WITHOUT type hint (parameter has no annotation):
{
  "source": "iam.application.dispatch",
  "target": null,
  "type": "dynamic_call",
  "weight": 1
}
```

**Function-level edge IDs** — for edges emitted by the function-level call graph
(task-111), source values are function node IDs (dot-separated path from task-099,
e.g. `"iam.application.handle_request"`). For edges emitted by the module-level
call graph (task-080), source values are module node IDs. Both are valid; the
validator does not restrict which node types source/target may reference.

**Non-deliverables** — do NOT implement:
- The extractor logic that discovers and emits `call_target_hint` (task-111).
- Any Godot rendering of this field (it is metadata for the LLM, not a visual primitive).
