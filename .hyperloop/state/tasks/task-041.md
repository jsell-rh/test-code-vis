---
id: task-041
title: Schema — add divergence_type to spec_item nodes
spec_ref: specs/core/understanding-modes.spec.md
status: not-started
phase: null
deps: [task-028]
round: 0
branch: null
pr: null
---

Extend the JSON scene graph schema so that spec_item nodes carry a `divergence_type`
field distinguishing three conformance states: `"realized"`, `"merged"`, and `"absent"`.
Without this field, Conformance Mode can only show whether a `spec_to_code` edge exists
or not — it cannot communicate that a spec requirement was absorbed into a broader
component rather than implemented as its own dedicated component.

Covers `specs/core/understanding-modes.spec.md` — Requirement: Conformance Mode,
Scenario: Spec-divergent implementation ("the specific nature of the divergence is
clear (merged vs. separate)"):

- Add an optional `divergence_type` field to `spec_item` node objects in the schema.
  Valid string values:
  - `"realized"`: the spec item is implemented as its own dedicated code component
    (a separate service, module, or bounded context whose primary purpose matches the
    spec item's scope).
  - `"merged"`: the spec item's functionality exists in the codebase but is absorbed
    into a code component that serves a broader scope — the concern is not isolated as
    its own component (e.g. payment logic inside the order service).
  - `"absent"`: no code evidence of the spec item's functionality was found anywhere
    in the codebase.
- If `divergence_type` is omitted, behaviour is equivalent to `"absent"` (safe default
  for backwards compatibility with scene graphs produced without task-042).
- Update the schema document (`extractor/schema.md` or `extractor/schema.json`) to
  document the new field and its three permitted values, with an example for each.
- Update the Python validator from task-001/task-028 to:
  - Accept `divergence_type` as an optional field on `spec_item` nodes.
  - Not reject nodes that omit it.
  - Reject nodes that include it with a value outside the three permitted strings.
- The field is set by the extractor (task-042) and read by the Godot Conformance Mode
  implementation (task-043). No other tasks need to be changed.
