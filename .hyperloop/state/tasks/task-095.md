---
id: task-095
title: Schema — purpose annotation, beacon, and invariant fields on nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema (task-061) to define three new optional
fields — `purpose_annotation`, `beacons`, and `invariants` — that bridge the gap
between mechanism (what the code does) and meaning (what the code is for), as required
by the Purpose-Level Annotation primitive.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Purpose-Level Annotation
("The system MUST support attaching purpose-level annotations to structural elements,
bridging the gap between mechanism (what the code does) and meaning (what the code is
for)"):

---

**New field — `purpose_annotation` on `module` and `bounded_context` nodes** (absent if
no annotation has been attached; set by the LLM or a future annotation agent):

```
purpose_annotation (string | null | absent)
  A human-readable sentence or short paragraph describing what this module or context
  is FOR, not what it mechanically does. Authored by the LLM given the structural
  data and any loaded spec.
  null   — annotation key is present but intentionally blank.
  absent — annotation has not been computed for this node.
```

Example (bounded_context node):
```json
{
  "id": "iam",
  "name": "IAM",
  "type": "bounded_context",
  "purpose_annotation": "Identity and Access Management — ensures every request is
    authenticated before reaching business logic, and enforces role-based access
    control across all bounded contexts."
}
```

---

**New field — `beacons` array on any node** (absent if no beacon analysis has run):

```
beacons (array | absent, optional)
  Each entry identifies a well-known programming pattern recognized in this node's
  implementation. Computed by the LLM or a future pattern-recognizer.

  Each beacon object:
    pattern (string) — short canonical name of the recognized pattern,
                       e.g. "retry_loop", "accumulator", "observer_dispatch",
                       "circuit_breaker", "command_pattern", "repository_pattern".
    description (string) — one sentence explaining the specific instance.
```

Example (module node):
```json
{
  "id": "iam.application",
  "beacons": [
    {
      "pattern": "retry_loop",
      "description": "Retries the token validation call up to 3 times with
        exponential backoff on transient failures."
    }
  ]
}
```

**Beacon vocabulary** — unlike Badges (which have a closed fixed vocabulary), beacon
`pattern` values are open strings: the LLM names what it finds. The renderer does NOT
validate beacon pattern names against a fixed list. New patterns are naturally discovered
without a schema change. This is the ONE place where the closed-primitive rule is
intentionally relaxed, because the LLM's value is recognizing patterns the spec author
didn't anticipate.

---

**New field — `invariants` array on `module` and `bounded_context` nodes** (absent if
no invariant analysis has run):

```
invariants (array | absent, optional)
  Each entry is a business rule or structural constraint that the validation logic
  within this node collectively enforces.

  Each invariant object:
    rule (string) — one sentence stating the invariant in domain language.
                    E.g. "Order cannot ship if payment is pending."
    enforced_by (array of string) — node ids of the modules or functions that
                    enforce this invariant. May be empty if enforcement path is unclear.
```

Example (module node):
```json
{
  "id": "iam.domain",
  "invariants": [
    {
      "rule": "A token cannot be issued unless the requesting identity has passed
        all active policy checks.",
      "enforced_by": ["iam.domain", "iam.application"]
    }
  ]
}
```

---

**Validator updates** (extend the validator from task-077):

- `purpose_annotation`, if present, MUST be a string or null. Absent nodes pass.
- `beacons`, if present, MUST be an array (may be empty). Each entry MUST have
  `pattern` (non-empty string) and `description` (string). The `pattern` value is
  NOT validated against a fixed vocabulary.
- `invariants`, if present, MUST be an array (may be empty). Each entry MUST have
  `rule` (non-empty string) and `enforced_by` (array of strings, may be empty).
- None of the three fields is required on any node. Absent means the annotation
  has not been computed; the validator MUST NOT error on absence.

---

**Schema document update** — add a new section "Annotation Fields" to
`extractor/schema.md` documenting all three fields with the worked examples above.
Note that these fields are produced by LLM-based annotation agents, not by the
deterministic extractor pipeline. The extractor's own analysis steps (tasks 078–084)
do NOT populate these fields; they remain absent in purely extractor-produced outputs.

**Non-deliverables** — do NOT implement:
- Any LLM or annotation agent that populates these fields (future work).
- Any Godot rendering (task-096 for purpose_annotation/invariants, task-097 for beacons).
