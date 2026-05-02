---
id: task-023
title: Implement symbol table extraction and node symbols schema field
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-002, task-006]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): add symbol table extraction and node symbols schema field"
pr_description: |
  ## What and Why

  This PR implements **Symbol Table Extraction** as defined in `specs/core/visual-primitives.spec.md`
  (Extraction Layer § Symbol Table Extraction). The extractor currently produces module-level nodes
  with names but no information about the functions, types, constants, and variables declared
  inside each module. Without this data, the Godot LOD tier-2 (near zoom) view cannot display
  meaningful function-level labels, and edge renderers cannot show human-readable names for
  call graph endpoints.

  ## Spec Requirements Satisfied

  - Every function, class, type, constant, and variable in each module is extracted as a symbol.
  - Each symbol carries: `name`, `kind` (function | class | constant | variable), `visibility`
    (public | private — derived from Python naming convention: `_` prefix → private), and
    `signature` (parameter names + type hints if present, return type hint if present).
  - The `nodes` array in the scene graph JSON is extended: each module-level node gains an
    optional `symbols` array containing these symbol objects.
  - Extraction uses single-file AST parsing only; no cross-file resolution or type inference.
  - Extraction time is proportional to number of files (linear).

  ## Schema Change

  The node schema (task-006) is extended with a new optional field:
  ```json
  "symbols": [
    {
      "name": "process_order",
      "kind": "function",
      "visibility": "public",
      "signature": "(order_id: int, user: User) -> Result"
    },
    {
      "name": "_validate_input",
      "kind": "function",
      "visibility": "private",
      "signature": "(data: dict) -> bool"
    }
  ]
  ```
  The field is omitted for nodes at bounded-context or package level (only module nodes carry symbols).

  ## Files / Areas Affected

  - `extractor/` — new module or extension of existing extraction pipeline to run AST-based symbol
    analysis on each Python source file.
  - Likely touches the same pipeline entry point that scope nesting extraction (task-002) uses.
  - The extractor's TypedDict / dataclass for nodes must gain a `symbols` optional field.
  - Scene graph JSON output changes shape: module nodes gain `symbols` arrays.

  ## How to Verify

  1. Run the extractor against the kartograph codebase.
  2. Inspect `scene_graph.json`: module nodes should contain a `symbols` array.
  3. Confirm `process_order` appears with `"visibility": "public"` and `_validate_input` appears
     with `"visibility": "private"`.
  4. Confirm signatures include type hints where present and omit them where absent.
  5. Run the extractor test suite — existing tests for scope nesting must still pass.
  6. Check that extraction time has not regressed significantly (still linear in file count).

  ## Caveats / Follow-up

  - This task covers only static visibility (naming convention). It does not perform
    visibility analysis through `__all__` exports; that is a future enhancement.
  - Call graph extraction (task-026) depends on symbol table data for labeling call edges.
  - The Godot renderer is not modified by this PR; the `symbols` field is added to the JSON
    for future use by near-LOD views.
---
