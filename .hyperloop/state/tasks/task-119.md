---
id: task-119
title: Schema — define `metrics` object (raw `loc` integer) on node entries
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Extend the canonical JSON scene graph schema to formally define a `metrics` object
on node entries, carrying the raw line-of-code count (`loc`) as an integer. This is
distinct from the `size` field (a normalised visual scale value) and is required by
the LOD Shell tier-0 display (task-104) to render the human-readable
"LOC: 12,400" label on bounded context volumes.

Covers `specs/core/visual-primitives.spec.md` — Requirement: LOD Shell Primitive,
Scenario: Three-tier LOD ("tier 0 (far): the context is a single Container with
aggregate metrics (total LOC, total in-degree, total out-degree)").

---

**Schema document update** — edit `extractor/schema.md`:

1. In the "Node fields" section, add:

   ```
   metrics (object | absent, optional)
     loc  (int)  — raw source line count for this node.
                   For bounded_context nodes: sum of all descendant module loc values.
                   For module nodes: direct line count of the module file(s).
                   For class/function nodes: line count of the declaration block.
                   Absent on nodes where line counting has not run.
   ```

2. Clarify the existing `size` field description to make the distinction explicit:

   ```
   size (number) — normalised visual scale factor derived from `metrics.loc`.
                   Computed as: max(0.5, min(10.0, loc / LOC_SCALE_DIVISOR)).
                   Dimensionless; used by Godot to set the MeshInstance3D scale.
                   Do NOT use `size` for display of raw line counts.
   ```

3. Add a worked example showing both fields on the same node:

   ```json
   {
     "id": "iam",
     "name": "IAM",
     "type": "bounded_context",
     "position": { "x": -12.5, "y": 0.0, "z": 4.0 },
     "size": 3.2,
     "parent": null,
     "metrics": { "loc": 3200 }
   }
   ```

---

**Validator update** — extend the Python validator (from task-001, or later from
task-061 if the validator was split):

- `metrics`, if present, MUST be an object.
- `metrics.loc`, if present, MUST be a non-negative integer.
- `metrics` is optional on all node types; absent means "not yet computed".
- The validator update is additive — no existing validation rules are removed.

---

**No extractor logic changes.** Schema documentation and validator only.
The emission of `metrics.loc` values is task-120's responsibility.

**Dependency note** — task-104 (LOD tier-0 aggregate metrics label) reads
`node["metrics"]["loc"]` at render time. This schema task formally documents the
contract that task-120 (extractor) fulfils and task-104 (Godot) consumes.
