---
id: task-031
title: PERMANENTLY CLOSED — banned task ID (understanding-modes mis-assignment history)
spec_ref: null
status: closed
phase: null
deps: [task-007]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement type topology extraction (inheritance and has-a edges)"
pr_description: |
  ## What and Why

  Adds a type topology extraction pass to the Python extractor. This pass analyzes
  class declarations in the AST to produce two categories of type relationships:

  - **Inheritance** (`inherits`): `class Foo(Bar)` → edge `Foo -> Bar`
  - **Composition** (`has_a`): a field or attribute typed as another class
    → edge from owner class to field's type

  These edges are written into the scene graph's `edges` array alongside the
  existing import-based edges produced by task-007. The Edge renderer (task-013)
  already specifies that edge type is encoded by line style ("dotted for
  inheritance"). Without this extraction pass, the renderer has no inheritance
  edges to draw, so the line-style distinction has no effect.

  Type relationships give the viewer structural information that import edges do
  not capture: two modules may not import each other directly, but their classes
  may be linked by a shared type hierarchy that is architecturally significant.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Type Topology Extraction

  - Inheritance edge: `class PaymentProcessor(BaseProcessor)` produces
    `{ source: "PaymentProcessor", target: "BaseProcessor", type: "inherits" }`.
  - Composition edge: `class Order` with a field typed `PaymentInfo` produces
    `{ source: "Order", target: "PaymentInfo", type: "has_a" }`.
  - Extraction requires only AST parsing of class declarations, field types, and
    base classes — no type inference or whole-program flow analysis.

  ## Key Design Decisions

  - **Inheritance** is read directly from `ast.ClassDef.bases`. Each base that
    resolves to a known class in the codebase produces an `inherits` edge.
    Bases that are external (stdlib, third-party) are recorded but marked
    `external: true` and suppressed from default rendering.
  - **Composition** is detected from class-body `ast.AnnAssign` nodes
    (annotated attributes: `foo: Bar`). Unannotated assignments are not analyzed
    (consistent with the spec's "no type inference" constraint).
  - Source and target IDs use the same node IDs as the rest of the scene graph
    (module-qualified class names, e.g. `"iam.domain.Order"`).
  - Type topology edges are a new semantic category in the scene graph; they are
    NOT merged with import edges. The `type` field distinguishes them.
  - If a referenced class is not found in the scene graph (e.g. it is from an
    external library), the edge is emitted with `external: true` and omitted
    from default rendering (consistent with ubiquitous-dependency suppression).

  ## Schema Extension

  Adds new edge objects to the existing `edges` array established by task-007:

  ```json
  { "source": "iam.domain.PaymentProcessor", "target": "iam.domain.BaseProcessor", "type": "inherits" }
  { "source": "iam.domain.Order", "target": "iam.domain.PaymentInfo", "type": "has_a" }
  ```

  No new top-level keys are added to the scene graph. The `type` field values
  `"inherits"` and `"has_a"` are new valid values alongside the existing
  `"internal"`, `"cross_context"`, and `"aggregate"`.

  ## Files / Areas Affected

  - `extractor/passes/type_topology.py` — new extraction pass; walks ASTs for
    class declarations, collects base classes and annotated field types, emits
    edges
  - `extractor/pipeline.py` — adds `type_topology` pass after `module_graph`;
    appends its edges to the scene graph edge list before serialization
  - `tests/test_type_topology.py` — unit tests covering:
    - single-level inheritance produces one `inherits` edge
    - multi-base inheritance produces one edge per base
    - annotated field produces `has_a` edge
    - unannotated field produces no edge
    - external base class produces edge with `external: true`
    - class with no bases and no annotated fields produces no edges

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`.
  2. Open the generated JSON; search for `"type": "inherits"` — confirm edges
     appear for known inheritance relationships in kartograph.
  3. Search for `"type": "has_a"` — confirm composition edges appear for
     annotated fields.
  4. Run `pytest tests/test_type_topology.py` — all tests green.
  5. Load the scene graph in Godot (task-013); inheritance edges should render
     with dotted line style (as specified in the Edge primitive renderer).

  ## Caveats / Follow-up

  - Only annotated class attributes (`foo: Bar`) are analyzed. Properties
    (`@property` with return type hint) are a follow-up.
  - Dynamic attribute assignment (`self.foo = Bar()`) is not captured — consistent
    with the spec's AST-only, no-inference constraint.
  - The Edge renderer (task-013) must map `"inherits"` → dotted line style and
    `"has_a"` → a distinct style. This mapping should be verified during task-013
    implementation.
---
