---
id: task-076
title: Schema — new edge types and ubiquitous flag
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema (task-061) to define the new edge types
introduced by the call graph and type topology extraction requirements, and to define
the `ubiquitous` flag for power-rail suppression.

Covers `specs/core/visual-primitives.spec.md` — Requirements: Call Graph Extraction,
Type Topology Extraction, and Ubiquitous Dependency Detection:

**New valid `type` values for edge entries** (added to the existing set of
`cross_context`, `internal`, `aggregate`):

```
direct_call    — a statically-resolved function-to-function invocation;
                 `source` and `target` are node ids of the caller and callee.
dynamic_call   — a call site where the target cannot be statically resolved
                 (e.g. a call through a parameter, attribute, or variable);
                 `source` is the caller id; `target` is null or omitted.
inherits       — a type topology edge: `source` class extends `target` class.
has_a          — a type topology edge: `source` class has a field of `target` type
                 (composition relationship).
```

**Existing `weight` field semantics by type:**
- `direct_call` edges: `weight` = number of distinct call sites from source to target.
- `inherits` and `has_a` edges: `weight` omitted (defaults to 1).
- `dynamic_call` edges: `weight` = number of dynamic call sites at the given source.

**New field — `ubiquitous` flag on edge entries:**

```
ubiquitous (bool | absent, optional, default false)
  true  — this dependency is imported by more than the ubiquitous threshold fraction
          of all modules; the Godot renderer defaults to suppressing it (power rail).
  false or absent — normal rendering.
```

**New field — `target` may be null for `dynamic_call` edges:**

Update the validator to allow `target: null` specifically for edges with
`type: "dynamic_call"`. All other edge types MUST have a non-null `target`.

**Validator updates** (extend validator from task-061):
- Accept `direct_call`, `dynamic_call`, `inherits`, `has_a` as valid `type` values
  in addition to existing types.
- `ubiquitous`, if present, MUST be a boolean.
- `target` may be null only when `type == "dynamic_call"`.
- `weight` on `direct_call` and `dynamic_call` edges MUST be a positive integer
  when present; it is optional (defaults to 1).

**Worked examples** — add to the schema document's examples section:

```json
{ "source": "iam.application", "target": "iam.domain",
  "type": "direct_call", "weight": 3 }

{ "source": "iam.application", "target": null,
  "type": "dynamic_call", "weight": 1 }

{ "source": "iam.domain.PaymentProcessor",
  "target": "iam.domain.BaseProcessor",
  "type": "inherits" }

{ "source": "iam.domain.Order",
  "target": "iam.domain.PaymentInfo",
  "type": "has_a" }

{ "source": "iam.application", "target": "shared_kernel.logging",
  "type": "cross_context", "ubiquitous": true, "weight": 1 }
```

**Non-deliverables** — do NOT implement:
- Call graph or type topology extraction (tasks 079, 080).
- Ubiquitous detection logic (task-083).
- Power rail rendering (task-090).
