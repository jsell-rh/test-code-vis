---
id: task-025
title: Implement type topology extraction (inheritance and has-a edges)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-003, task-007]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): add type topology extraction (inherits and has_a edges)"
pr_description: |
  ## What and Why

  This PR implements **Type Topology Extraction** as defined in `specs/core/visual-primitives.spec.md`
  (Extraction Layer § Type Topology Extraction). The module graph (task-003) captures import-based
  dependencies between modules. Type topology captures a finer-grained layer: the structural
  relationships *between types* — inheritance chains and composition (has-a) relationships. This
  data enriches the dependency graph used by the Godot renderer, enabling future views to show
  "which types extend which" and "which types are composed into which" at near-zoom LOD.

  ## Spec Requirements Satisfied

  - For each class in the codebase: if it inherits from another class, an `inherits` edge is
    emitted from the subclass to the base class.
  - For each class with a field typed as another class: a `has_a` edge is emitted from the
    containing class to the field type.
  - Extraction is AST-only: class declarations, base class lists, and field type annotations
    are parsed from source. No type inference or flow analysis is performed.
  - The `edges` array in the scene graph JSON gains new entries with `"type": "inherits"` and
    `"type": "has_a"`.

  ## Schema Change

  The edge schema (task-007) is extended with two new `type` values:
  ```json
  { "source": "iam.domain.PaymentProcessor", "target": "iam.domain.BaseProcessor", "type": "inherits" }
  { "source": "iam.domain.Order", "target": "iam.domain.PaymentInfo", "type": "has_a" }
  ```
  Node IDs for class-level sources/targets use dotted paths extending from their containing module.

  ## Files / Areas Affected

  - `extractor/` — new analysis pass that walks class definitions and their base lists and
    annotated field types to emit `inherits` and `has_a` edges.
  - The extractor TypedDict / dataclass for edges may need to accommodate class-level node IDs
    that are sub-entities of modules (if the schema registers class nodes, those come from
    scope nesting — task-002).
  - Scene graph JSON output gains new edge entries.

  ## How to Verify

  1. Run the extractor against kartograph.
  2. Inspect `scene_graph.json` edges: find at least one `"type": "inherits"` and one
     `"type": "has_a"` entry if kartograph has inheritance or composition.
  3. Confirm the extractor test suite still passes (module graph edges still present).
  4. Add a regression test: given a synthetic Python file with `class B(A): pass` and
     `class C: x: A = None`, confirm edges `B->A (inherits)` and `C->A (has_a)` are emitted.

  ## Caveats / Follow-up

  - Only explicit annotations are analysed (e.g. `x: Foo`). Implicit types (e.g. `x = Foo()`)
    are not extracted; this is consistent with the spec's "no type inference" constraint.
  - Call graph extraction (task-026) is a peer task that also adds new edge types. These tasks
    should be sequenced (026 depends on 025) to avoid concurrent TypedDict modifications.
  - The Godot renderer does not yet render `inherits` or `has_a` edges distinctively; that is
    a future rendering enhancement. These edges are present in the JSON for future use.
---
