---
id: task-024
title: Define view spec format (moldable views intermediate representation)
spec_ref: specs/interaction/moldable-views.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Define the structured view spec format that acts as the intermediate representation
between the LLM and the Godot 3D renderer. This is a shared contract: the LLM generates
view specs; the Godot interpreter (task-025) executes them.

Covers `specs/interaction/moldable-views.spec.md` — Requirement: View Specs as
Intermediate Representation and Requirement: Fixed Visual Primitive Set:
- Document the view spec format in a schema file (e.g. `extractor/view-spec-schema.md`
  or `godot/docs/view-spec-schema.md`).
- A view spec is a JSON object with:
  - `question` (string) — the original natural language question that triggered this spec.
  - `description` (string) — human-readable summary of what this view shows.
  - `operations` (array of operation objects) — ordered list of primitive operations.
- Operation object shape (discriminated by `op` field):
  - `{ "op": "show",      "nodes": [<node id>, ...] }` — make these nodes visible.
  - `{ "op": "hide",      "nodes": [<node id>, ...] }` — hide these nodes.
  - `{ "op": "highlight", "nodes": [<node id>, ...], "color": "<hex>" }` — tint nodes.
  - `{ "op": "arrange",   "nodes": [<node id>, ...], "layout": "<layout-name>" }` —
    reposition nodes using a named layout strategy (e.g. `"circle"`, `"column"`, `"default"`).
  - `{ "op": "annotate",  "node": "<node id>", "label": "<text>" }` — attach a text label.
  - `{ "op": "connect",   "source": "<node id>", "target": "<node id>", "label": "<text>" }` —
    draw an explicit labelled connection line between two nodes.
- The set of `op` values is fixed and finite. No other values are valid. The LLM MUST
  compose answers from these primitives only.
- Include 2–3 worked examples in the schema document showing how a question maps to a
  view spec (e.g. "how does authentication work?" → ops to show auth nodes, hide others,
  annotate entry points).
- Include a lightweight Python or GDScript validator that checks a view spec object for
  required fields and valid `op` values; used by task-025 before applying operations.
