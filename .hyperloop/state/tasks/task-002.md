---
id: task-002
title: Implement scope nesting extraction
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement scope nesting extraction"
pr_description: |
  ## What and Why

  Implements the containment hierarchy analysis pass of the Python extractor.
  Scope nesting is the cheapest and most fundamental extraction: it tells us that
  packages contain modules, modules contain classes, and classes contain methods.
  This tree is the skeleton onto which every other analysis (dependencies, metrics,
  layout) hangs. Without it, no structural data can be correctly attributed to its
  containing scope.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Scope Nesting Extraction

  - Walk the target codebase and produce a full containment tree:
    project → packages → modules → classes → methods/functions
  - Every entity has a `parent` reference; the tree root is the project itself.
  - Every leaf is an atomic declaration (function, method, constant).
  - Extraction is single-file AST parsing only — no cross-file resolution required.
  - Runtime complexity: O(number of files).

  ## Key Design Decisions

  - Uses Python's built-in `ast` module; no third-party dependencies.
  - Each discovered entity is assigned a stable dotted ID (e.g. `iam.domain.User`)
    derived from its filesystem path and qualified name. This ID is used as the
    node `id` in the scene graph.
  - The extractor returns a flat list of `(id, name, type, parent_id)` tuples —
    tree structure is implicit in the parent references, not in a nested object.
    This keeps serialization to JSON straightforward (task-006 writes the fields).

  ## Files / Areas Affected

  - `extractor/scope_nesting.py` — new module implementing the AST walk
  - `extractor/tests/test_scope_nesting.py` — unit tests covering:
    - nested class inside module
    - method inside class inside module inside package
    - leaf function (no children)
    - tree root is the project entity

  ## How to Verify

  1. Run `pytest extractor/tests/test_scope_nesting.py`.
  2. Run the extractor on `~/code/kartograph`.
  3. Confirm the output JSON `nodes` array contains entries for the top-level
     bounded contexts with `parent: null`, and module nodes with `parent` set to
     their containing context id.

  ## Caveats / Follow-up

  This pass does not compute positions or sizes — those come from the layout pass
  (task-008). The `independence_group` field is populated by task-005 (independence
  detection) and task-006 (node serialization). Symbol visibility (public/private)
  is NOT extracted in this task — that is deferred to a future phase when the symbol
  table requirement enters scope.
---
