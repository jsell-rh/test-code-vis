---
id: task-036
title: Implement badge property detection and emission in extractor (Badge extraction pass)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-023]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): add badge property detection pass (pure, io, async, stateful, error_handling, test, entry_point, deprecated)"
pr_description: |
  ## What and Why

  Adds a badge-property detection pass to the Python extractor. The Badge primitive
  (defined in `specs/core/visual-primitives.spec.md`) requires the extractor to annotate
  each symbol (function, method, class) with its applicable cross-cutting properties.
  These annotations are consumed by the Godot Badge renderer (task-037), which docks small
  glyph icons onto Node primitives to make structural aspects readable at a glance.

  Without badge annotations in the scene graph, the Godot renderer has no data to drive
  badge display. This task produces that data.

  ## Spec Requirements Satisfied

  `specs/core/visual-primitives.spec.md` — Requirement: Badge Primitive (extraction layer)

  - **Badge vocabulary**: `pure`, `io`, `async`, `stateful`, `error_handling`, `test`,
    `entry_point`, `deprecated`
  - Badges attach to symbols (functions and methods in the symbol table)
  - New badge types are added by extending the extractor, not invented at runtime

  ## Key Design Decisions

  The pass runs after symbol table extraction (task-023) so all symbols with their
  signatures are available. It augments each symbol entry with a `badges` array:

  ```json
  {
    "name": "validate_order",
    "visibility": "public",
    "signature": { "params": [...], "return_type": "bool" },
    "badges": ["pure", "error_handling"]
  }
  ```

  ### Detection heuristics (AST-only, no type inference):

  - **`pure`**: function body contains no `global`/`nonlocal` statements, no `ast.Attribute`
    writes (`self.x = ...`), and no calls to known I/O builtins or stdlib modules
    (`open`, `print`, `os.*`, `sys.*`, `socket.*`, `subprocess.*`, `logging.*`).
    Conservative: a function is only `pure` if NONE of these patterns appear.
  - **`io`**: function body or any nested call contains `open(...)`, `print(...)`, or
    imports/calls into `os`, `sys`, `socket`, `subprocess`, `pathlib`, `shutil`, `urllib`,
    `http`, `requests`, or `aiohttp`. Direct AST name resolution; no cross-function tracing.
  - **`async`**: function is an `ast.AsyncFunctionDef` node.
  - **`stateful`**: class-level detection — class has `__init__` that assigns `self.*`
    attributes; or function-level: body assigns `nonlocal` or `global` variable.
  - **`error_handling`**: function body contains at least one `ast.Try` node (try/except block).
  - **`test`**: function name begins with `test_`, or class name begins with `Test`, or
    function is decorated with `@pytest.mark.*`.
  - **`entry_point`**: function is named `main`, or decorated with `@click.command`,
    `@app.route`, `@router.get/post/put/delete/patch`, `@app.get/post/...` (FastAPI/Flask).
  - **`deprecated`**: function or class decorated with `@deprecated`, or docstring contains
    the token `deprecated` (case-insensitive) in the first two lines.

  ### Schema impact

  The `badges` field is an array of strings from the fixed vocabulary. It is added to
  each symbol entry inside the `symbols` array on each node. Empty array (`[]`) when no
  badge applies. The array is ordered by vocabulary position for deterministic output.

  This is an extension to the existing symbol schema introduced by task-023. No changes
  to the top-level node/edge structure.

  ### Pass ordering

  This pass runs after `symbol_table` (task-023) in the pipeline. It operates in-place,
  mutating each symbol dict to add the `badges` key before serialization.

  ## Files / Areas Affected

  - `extractor/passes/badge_detection.py` — new pass; walks each node's function
    and class AST bodies to apply badge heuristics; mutates symbol entries in-place
  - `extractor/pipeline.py` — registers `badge_detection` pass after `symbol_table`
  - `extractor/schema.py` — adds `badges: list[str]` to the symbol TypedDict; defines
    the `BADGE_VOCABULARY` constant listing the 8 supported badge types
  - `extractor/tests/test_badge_detection.py` — unit tests covering:
    - `async def` function gets `async` badge
    - function with `try/except` gets `error_handling` badge
    - function with `open()` call gets `io` badge
    - function named `test_foo` gets `test` badge
    - function with no side effects, no I/O, no nonlocal gets `pure` badge
    - class with `self.*` assignments in `__init__` gets `stateful` badge
    - function with `@deprecated` decorator gets `deprecated` badge
    - function with `@app.route(...)` gets `entry_point` badge
    - function with multiple applicable badges gets all of them
    - function with no applicable badges gets empty `badges: []`
    - badge vocabulary is a closed set (no unknown strings in output)

  ## How to Verify

  1. Run the extractor on `~/code/kartograph`.
  2. Inspect the generated JSON; find symbols in the `symbols` array and confirm
     `badges` fields are present (including `[]` for symbols with no badge).
  3. Check that `async` functions in kartograph carry the `async` badge.
  4. Check that functions containing `try/except` carry `error_handling`.
  5. Run `pytest extractor/tests/test_badge_detection.py` — all tests green.

  ## Caveats / Follow-up

  - Badge detection is heuristic and conservative. False negatives (missed badges) are
    preferred over false positives (incorrect badges). Document the known limitations.
  - Cross-function I/O detection is NOT performed (only intra-body AST scan). A function
    that calls another function that does I/O will NOT get the `io` badge unless the call
    is to a known I/O name.
  - `pure` detection may produce false positives for functions that call non-I/O stdlib
    functions with side effects not covered by the heuristic list. This is acceptable for
    the prototype.
  - task-037 (Badge renderer in Godot) depends on this task.
---
