---
id: task-122
title: Schema — owner field on module and bounded-context nodes
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-061]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema (task-061) to define the optional
`owner` field on module and bounded-context nodes, providing the team-ownership
data that the ownership tint facet (task-124) requires.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Overlay/Facet
Composition, Scenario: Switching from structure view to ownership view ("Tints
encode team ownership AND the structural geography provides continuity — the
human recognizes the same space with different coloring"):

The TintController (task-089) supports categorical dimensions driven by
scene graph data ("context", "community"). An ownership facet requires an
`owner` field on nodes so Godot can assign tint colours by team without
consulting any external data source at render time. This task is the schema
contract between the extractor (task-123) and Godot (task-124).

---

**New field — `owner` on `module` and `bounded_context` nodes** (absent if
ownership annotation has not run):

```
owner (string | null | absent, optional)
  The team or individual identifier that owns this node, as declared in the
  repository's CODEOWNERS file (or equivalent ownership manifest).

  string  — a non-empty owner identifier taken verbatim from CODEOWNERS.
            Common formats: "@org/team-name", "@username", "payments-team".
  null    — no ownership rule matched this path.
  absent  — ownership annotation has not run (extractor invoked without --owners).
```

The field is NOT valid on `class` or `function` nodes — ownership is expressed
at module and bounded-context granularity only.

---

**Validator updates** (extend the validator from task-061):

- `owner`, if present, MUST be a string or JSON null. Empty string is invalid.
- `owner` is valid only on nodes of type `"module"` or `"bounded_context"`.
  Presence on `"class"` or `"function"` nodes is a validation warning (not
  a hard error, to allow forward-compatible data).
- `owner` is NOT required on any node — its absence means ownership was not
  annotated for this run.

---

**Worked examples** — add to the schema document's examples section:

```json
{
  "id": "iam",
  "name": "IAM",
  "type": "bounded_context",
  "parent": null,
  "position": { "x": 0.0, "y": 0.0, "z": 0.0 },
  "size": 3.2,
  "metrics": { "loc": 3200 },
  "owner": "@org/identity-team"
}

{
  "id": "iam.application",
  "name": "Application",
  "type": "module",
  "parent": "iam",
  "position": { "x": 10.0, "y": 0.0, "z": 5.0 },
  "size": 1.4,
  "metrics": { "loc": 480 },
  "owner": "@org/identity-team"
}

{
  "id": "shared_kernel.logging",
  "name": "Logging",
  "type": "module",
  "parent": "shared_kernel",
  "position": { "x": -5.0, "y": 0.0, "z": 0.0 },
  "size": 0.8,
  "metrics": { "loc": 120 },
  "owner": null
}
```

The third example — `owner: null` — indicates this module exists but no
CODEOWNERS rule matched its path. The field is present and explicitly null,
so Godot can distinguish "no owner assigned" from "ownership not extracted."

---

**Non-deliverables** — do NOT implement:
- The CODEOWNERS parsing logic (task-123).
- Any Godot rendering of this field (task-124).
