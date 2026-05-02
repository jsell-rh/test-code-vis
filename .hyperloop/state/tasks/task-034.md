---
id: task-034
title: Implement type topology extraction (inheritance, composition, has-a edges)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-006]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement type topology extraction (inheritance, composition, has-a)"
pr_description: |
  ## What and Why

  Adds a type topology extraction pass to the Python extractor. This pass analyzes
  class declarations in the AST to produce the directed graph of type relationships:

  - **Inheritance** (`inherits`): class `PaymentProcessor` extends `BaseProcessor`
    → edge `PaymentProcessor -> BaseProcessor` with type `inherits`
  - **Composition** (`has_a`): class `Order` has a field of type `PaymentInfo`
    → edge `Order -> PaymentInfo` with type `has_a`
  - **Implementation** (`implements`): class implements a Protocol or ABC
    → edge with type `implements`

  Without this pass, the scene graph has no record of how types relate to each
  other. The Edge renderer (task-013) already handles edge type distinctions by
  line style (solid/dashed/dotted), but needs actual type topology edges to draw.
  At tier-2 LOD (near zoom), where individual classes are visible, type
  relationships provide essential structural context: inheritance chains reveal
  extension points, composition relationships reveal object structure, and
  implementation relationships reveal polymorphic boundaries.

  This is extraction-only work — AST parsing of class declarations, base class
  lists, and field type annotations. No cross-file type inference or flow analysis
  is required. Extraction cost is proportional to the number of class declarations.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Type Topology Extraction

  - `PaymentProcessor(BaseProcessor)` → edge
    `{ source: "iam.domain.PaymentProcessor", target: "iam.domain.BaseProcessor", type: "inherits" }`
  - Class `Order` with field `payment: PaymentInfo` → edge
    `{ source: "iam.domain.Order", target: "iam.domain.PaymentInfo", type: "has_a" }`
  - Only AST parsing of class declarations, field types, and base classes — no
    type inference or flow analysis.
  - Dunder methods and class variables without type annotations are not emitted
    as `has_a` edges (only explicitly typed field annotations are used).

  ## Key Design Decisions

  - **Inheritance detection**: walk `ast.ClassDef.bases` for each class node.
    Base class names are resolved against the module's import graph to get
    fully qualified IDs. If a base cannot be resolved (external library class),
    the edge is emitted with `external: true` and the unresolved name as the
    target string.
  - **Composition detection**: walk `ast.AnnAssign` nodes at class body scope
    to find annotated field declarations (`field: Type`). The type annotation is
    parsed to extract the type name(s), resolved via the import graph. Generic
    types (e.g. `list[Order]`) extract the inner type (`Order`).
  - **Implementation detection**: Python ABCs and Protocols are treated as a
    subcase of inheritance — any base class that is a `Protocol` subclass or
    `ABC` subclass emits an `implements` edge rather than `inherits`. Detection
    uses the same base-class resolution path with a known-ABC/Protocol list
    seeded from common patterns.
  - **Edge deduplication**: if class A inherits from B AND has a field of type B,
    two edges are emitted (one `inherits`, one `has_a`). These are semantically
    distinct and both are valid.
  - This pass runs after scope nesting extraction (task-002) so class node IDs
    are already established, and after module graph extraction (task-003) so
    import resolution can use the existing cross-module map.

  ## Schema Extension

  Adds new edge objects to the existing `edges` array (established by task-007).
  New edge type values:

  ```json
  { "source": "iam.domain.PaymentProcessor",
    "target": "iam.domain.BaseProcessor",
    "type": "inherits" }

  { "source": "iam.domain.Order",
    "target": "iam.domain.PaymentInfo",
    "type": "has_a" }

  { "source": "iam.domain.ConcreteRepo",
    "target": "iam.domain.IRepository",
    "type": "implements" }

  { "source": "iam.domain.SomeClass",
    "target": "django.db.models.Model",
    "type": "inherits",
    "external": true }
  ```

  The `external: true` flag signals that the target lives outside the extracted
  codebase and should not be rendered as a node — only the edge is emitted.

  ## Files / Areas Affected

  - `extractor/passes/type_topology.py` — new extraction pass; walks class
    declarations, resolves base classes and field type annotations, emits
    typed edges
  - `extractor/pipeline.py` — adds `type_topology` pass after `module_graph`
    and `scope_nesting`; appends its edges to the scene graph edge list before
    serialization
  - `extractor/schema.py` — adds `"inherits"`, `"has_a"`, `"implements"` to the
    enumerated edge `type` values; adds optional `"external": bool` field on edges
  - `tests/test_type_topology.py` — unit tests covering:
    - single inheritance produces `inherits` edge
    - multiple inheritance produces multiple `inherits` edges
    - annotated field of a known type produces `has_a` edge
    - untyped field (`x = None`) does NOT produce `has_a` edge
    - generic field (`items: list[Order]`) produces `has_a` edge to `Order`
    - class with no bases and no typed fields produces no edges
    - external base class produces edge with `external: true`

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`.
  2. Open the generated JSON; search for `"type": "inherits"` — confirm inheritance
     chains appear for known kartograph class hierarchies.
  3. Search for `"type": "has_a"` — confirm composition edges appear for classes
     with typed field annotations.
  4. Run `pytest tests/test_type_topology.py` — all tests green.
  5. Confirm that external base classes (e.g. from `pydantic`, `sqlalchemy`) have
     `"external": true` in their edge objects.

  ## Caveats / Follow-up

  - Resolution is AST-only: aliased imports (`from foo import Bar as B`) and
    dynamic base classes (`class Foo(get_base())`) may not resolve correctly.
    Document known limitations.
  - `has_a` detection is limited to explicitly annotated class-body fields.
    Attributes assigned in `__init__` (e.g. `self.payment = PaymentInfo()`)
    are NOT captured — AST annotation pass only.
  - The Edge renderer (task-013) renders `inherits` as dotted lines per the
    visual-primitives spec. This task populates the edges; the renderer
    visualizes them at the appropriate LOD tier.
  - Type topology edges are most useful at tier-2 LOD (near zoom) where
    individual classes are visible. At tier-0/tier-1, they are suppressed
    by the LOD Shell (task-014).
---
