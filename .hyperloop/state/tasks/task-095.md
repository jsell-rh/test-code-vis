---
id: task-095
title: Schema — purpose-level annotation fields (purpose, beacon, invariant)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema (task-061) to define optional annotation
fields for purpose-level information: human- or LLM-authored purpose annotations,
recognized structural pattern beacons, and business-rule invariants. These fields
bridge the gap between mechanism (what code does) and meaning (what it is for).

Covers `specs/core/visual-primitives.spec.md` — Requirement: Purpose-Level Annotation
("The system MUST support attaching purpose-level annotations to structural elements,
bridging the gap between mechanism (what the code does) and meaning (what the code is
for)"):

**New optional fields on any node entry:**

```
purpose (string | absent, optional)
  A plain-English statement of what this node is FOR — its intent and role in
  the system — rather than what it mechanically does.
  Example: "Payment Safety Gate — ensures all transactions meet compliance
            requirements before processing"

beacon (string | absent, optional)
  A recognised structural pattern found in this node.
  MUST be one of the following fixed vocabulary values:
    "retry_loop"   — contains a retry-on-failure mechanism
    "accumulator"  — gathers values before emitting a single result
    "observer"     — dispatches events to registered listeners
    "pipeline"     — chains transformations in a linear data-flow sequence
    "facade"       — provides a simplified interface over a complex subsystem
    "singleton"    — enforces a single-instance constraint
  No value outside this set is valid; the validator rejects unknown beacons.
  Vocabulary extension follows the same pattern as badge vocabulary (task-077):
  add to both the schema document and the Godot renderer, never at runtime.

invariant (string | absent, optional)
  A business rule enforced by this node, expressed in plain English.
  Example: "Order cannot ship if payment is pending"
  Intended for Aggregate or Container nodes that centralise a business constraint.
```

**Validator updates** (extend the Python validator from task-061):

- `purpose`, if present, MUST be a non-empty string.
- `beacon`, if present, MUST be one of the six vocabulary values listed above.
  The validator MUST raise an error for any unknown beacon value (closed-set enforcement).
- `invariant`, if present, MUST be a non-empty string.
- All three fields are optional; a node with none of them is fully valid.
- The validator MUST NOT require any of these fields on any node type.

**Worked example** — add to the schema document's examples section
(`extractor/schema.md`):

```json
{
  "id": "iam.domain",
  "name": "Domain",
  "type": "module",
  "parent": "iam",
  "position": { "x": 0.0, "y": 0.0, "z": 0.0 },
  "size": 1.8,
  "purpose": "Core business rules for identity and access — ensures every action in the system is authorised before execution",
  "beacon": "facade",
  "invariant": "No resource access is granted without an active, valid session token"
}
```

**Authorship model** — these fields are NOT produced by the Python extractor pipeline.
They are authored by humans or LLMs and injected into the scene graph JSON directly
(e.g. via a separate annotation tool or manual editing). The extractor neither reads
nor writes them. The validator treats them as optional annotations that MAY be present
on any node it receives.

**Non-deliverables** — do NOT implement:
- Any extractor logic to generate `purpose`, `beacon`, or `invariant` values.
- Godot rendering of these annotations (task-096).
- LLM integration or pattern-recognition heuristics.
