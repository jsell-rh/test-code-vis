---
id: task-006
title: Implement node schema fields in extractor output
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-001, task-002, task-005]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement node schema fields in JSON output"
pr_description: |
  ## What and Why

  Serializes the structural data produced by the scope nesting pass (task-002) and
  independence detection pass (task-005) into the node array of the scene graph
  JSON, with all required fields populated. This is the first point at which the
  Godot application can load real node data. Without populated node objects, the
  renderer has nothing to instantiate.

  ## Spec Requirements Satisfied

  `specs/extraction/scene-graph-schema.spec.md` — Requirement: Node Schema

  Each node in the `nodes` array MUST carry:
  - `id` — stable dotted string identifier (e.g. `"iam"`, `"iam.domain"`)
  - `name` — human-readable display name
  - `type` — structural level: `"bounded_context"`, `"module"`, `"class"`,
    `"function"` etc.
  - `position` — `{"x": float, "y": float, "z": float}` (values from layout
    algorithm; placeholder zeros until task-008 runs)
  - `size` — numeric value encoding relative complexity (e.g. LOC count or
    child count)
  - `parent` — parent node `id`, or `null` for top-level nodes
  - `independence_group` — string identifier (e.g. `"iam:0"`) if the node is a
    module; omitted or `null` for non-module nodes

  ## Key Design Decisions

  - `position` fields are initialized to `{"x": 0, "y": 0, "z": 0}` until the
    layout pass (task-008) overwrites them. This allows downstream tasks to depend
    on node schema shape without blocking on layout.
  - `size` is computed as the count of direct children (e.g. number of modules in
    a context, number of classes in a module) normalized to a [1, 10] range.
  - The serialization layer is a pure function: `nodes_to_json(scope_tree,
    independence_groups) -> list[dict]`. No side effects.

  ## Files / Areas Affected

  - `extractor/serialization.py` — new `nodes_to_json()` function
  - `extractor/tests/test_serialization_nodes.py` — unit tests covering:
    - bounded context node has `parent: null`
    - module node has correct `parent` reference
    - `independence_group` present on module nodes, absent on class nodes
    - `position` defaults to `{"x": 0, "y": 0, "z": 0}` before layout
    - `size` proportional to child count

  ## How to Verify

  1. Run `pytest extractor/tests/test_serialization_nodes.py`.
  2. Run the extractor on `~/code/kartograph` and open the JSON.
  3. Pick any module node; confirm all seven fields are present with correct types.
  4. Confirm a top-level bounded context node has `"parent": null`.

  ## Caveats / Follow-up

  Position values are zeros at this stage. task-008 (layout) overwrites them.
  Structural significance annotations (hub/bridge/peripheral from task-004) are
  not yet included in the node schema; they will be added as optional metadata
  fields in task-008 or a subsequent schema extension task.
---
