---
id: task-025
title: Implement type topology extraction (inheritance, composition, and implements edges)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-002, task-003, task-006, task-007]
round: 1
branch: null
pr: null
pr_title: "feat(extractor): implement type topology extraction (inherits, has_a, implements)"
pr_description: |
  ## ⚠ Retry Prescription (Round 1 — Rebase Only)

  The prior attempt (`hyperloop/task-025`) completed a correct implementation that passed
  234 pytest tests and 230 Godot behavioral tests, and satisfied all checks **except one**:
  `check-rebased-onto-main.sh` exited 1 because the branch forked before commit `61c9117a`,
  which deleted 3 test functions from `extractor/tests/test_extractor.py`.

  **Do NOT start from scratch.** The implementation is complete. The only required action is:

  ```bash
  git fetch origin
  git checkout hyperloop/task-025        # the completed implementation branch
  git rebase origin/main
  # Conflict will occur in extractor/tests/test_extractor.py.
  # KEEP MAIN'S VERSION: accept the deletion of these three functions:
  #   test_bounded_context_nodes_have_metrics_with_loc
  #   test_cross_context_edge_direction_encodes_importer_to_imported
  #   test_internal_edge_distinguishable_from_cross_context
  # Apply the task-025 additions on top. Do NOT use 'ours' strategy.
  git add extractor/tests/test_extractor.py
  git rebase --continue
  bash .hyperloop/checks/check-run-tests-suite-count.sh   # must stay >= 19
  bash .hyperloop/checks/run-all-checks.sh                # all checks must be EXIT 0
  ```

  After the rebase, open a PR from the rebased `hyperloop/task-025` branch. No other
  changes are required.

  ---

  ## What and Why

  Adds a type topology extraction pass to the Python extractor. This pass analyzes class
  declarations in the AST to produce the directed graph of type relationships:

  - **Inheritance** (`inherits`): class `PaymentProcessor(BaseProcessor)` →
    edge `PaymentProcessor -> BaseProcessor` with type `inherits`
  - **Composition** (`has_a`): class `Order` has an annotated field `payment: PaymentInfo` →
    edge `Order -> PaymentInfo` with type `has_a`
  - **Implementation** (`implements`): class implements a Protocol or ABC →
    edge with type `implements`

  The module graph (task-003) captures import-based dependencies between modules. Type topology
  captures a finer-grained layer: the structural relationships *between types* — inheritance
  chains, composition, and interface implementation. This data enriches the dependency graph
  used by the Godot renderer, enabling views to show "which types extend which" and "which types
  are composed into which" at near-zoom LOD (tier 2). Without this pass, the scene graph has no
  record of how types relate to each other.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Type Topology Extraction

  - `PaymentProcessor(BaseProcessor)` → edge
    `{ source: "iam.domain.PaymentProcessor", target: "iam.domain.BaseProcessor", type: "inherits" }`
  - Class `Order` with field `payment: PaymentInfo` → edge
    `{ source: "iam.domain.Order", target: "iam.domain.PaymentInfo", type: "has_a" }`
  - Only AST parsing of class declarations, field type annotations, and base class lists —
    no type inference or flow analysis required.
  - Dunder methods and class variables without type annotations are not emitted as `has_a`
    edges (only explicitly typed field annotations are used).

  ## Key Design Decisions

  - **Inheritance detection**: walk `ast.ClassDef.bases` for each class node. Base class
    names are resolved against the module's import graph to get fully qualified IDs. If a
    base cannot be resolved (external library class), the edge is emitted with
    `external: true` and the unresolved name as the target string.
  - **Composition detection**: walk `ast.AnnAssign` nodes at class body scope to find
    annotated field declarations (`field: Type`). The type annotation is parsed to extract
    the type name(s) via the import graph. Generic types (e.g. `list[Order]`) extract the
    inner type (`Order`).
  - **Implementation detection**: Python ABCs and Protocols are treated as a subcase of
    inheritance — any base class that is a `Protocol` subclass or `ABC` subclass emits an
    `implements` edge rather than `inherits`. Detection uses the same base-class resolution
    path with a known-ABC/Protocol seed list.
  - **Edge deduplication**: if class A inherits from B AND has a field of type B, two edges
    are emitted (one `inherits`, one `has_a`). These are semantically distinct and both valid.
  - This pass runs after scope nesting (task-002) so class node IDs are established, and
    after module graph extraction (task-003) so import resolution can use the cross-module map.

  ## Schema Extension

  Adds new edge objects to the existing `edges` array (task-007). New edge `type` values:

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

  The `external: true` flag signals that the target lives outside the extracted codebase and
  should not be rendered as a node — only the edge is emitted.

  ## Files / Areas Affected

  - `extractor/passes/type_topology.py` — new extraction pass; walks class declarations,
    resolves base classes and field type annotations, emits typed edges
  - `extractor/pipeline.py` — adds `type_topology` pass after `module_graph` and
    `scope_nesting`; appends its edges to the scene graph edge list before serialization
  - `extractor/schema.py` — adds `"inherits"`, `"has_a"`, `"implements"` to the enumerated
    edge `type` values; adds optional `"external": bool` field on edges
  - `extractor/tests/test_type_topology.py` — unit tests covering:
    - single inheritance produces `inherits` edge
    - multiple inheritance produces multiple `inherits` edges
    - annotated field of a known type produces `has_a` edge
    - untyped field (`x = None`) does NOT produce `has_a` edge
    - generic field (`items: list[Order]`) produces `has_a` edge to `Order`
    - class with no bases and no typed fields produces no edges
    - external base class produces edge with `external: true`
    - ABC/Protocol base class produces `implements` edge rather than `inherits`

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`.
  2. Open the generated JSON; search for `"type": "inherits"` — confirm inheritance chains
     appear for known kartograph class hierarchies.
  3. Search for `"type": "has_a"` — confirm composition edges appear for classes with typed
     field annotations.
  4. Run `pytest extractor/tests/test_type_topology.py` — all tests green.
  5. Confirm that external base classes (e.g. from `pydantic`, `sqlalchemy`) carry
     `"external": true` in their edge objects.

  ## Caveats / Follow-up

  - Resolution is AST-only: aliased imports (`from foo import Bar as B`) and dynamic base
    classes (`class Foo(get_base())`) may not resolve correctly. Document known limitations.
  - `has_a` detection is limited to explicitly annotated class-body fields. Attributes
    assigned in `__init__` (e.g. `self.payment = PaymentInfo()`) are NOT captured.
  - Call graph extraction (task-026) is a peer task adding new edge types. task-026 depends
    on this task to avoid concurrent schema modifications.
  - **Retry note**: A prior attempt on branch `hyperloop/task-025` passed all checks except
    `check-rebased-onto-main.sh` (branch forked before commit 61c9117a which deleted 3 test
    functions from `extractor/tests/test_extractor.py`). The implementation was correct. The
    fix is: `git rebase origin/main`, keeping main's version of `test_extractor.py` (which
    drops the 3 deleted tests), then apply the task-025 changes on top. The branch
    `hyperloop/task-025` on origin contains the completed implementation and may be reused
    after rebasing.
---
