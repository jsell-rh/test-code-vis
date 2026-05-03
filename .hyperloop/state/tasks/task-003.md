---
id: task-003
title: Import-based dependency extraction
spec_ref: "specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b"
status: not-started
phase: null
deps: [task-002]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): extract import-based dependency edges between modules"
pr_description: |
  ## What and Why

  Parses every Python source file in the target codebase and resolves import statements
  to module nodes discovered in task-002. Emits `Edge` dicts (source, target, type) for
  each module-to-module dependency. This is the data on which layout (task-004),
  independence detection (task-005), aggregate edges (task-006), and cluster suggestions
  (task-007) all depend.

  ## Spec Requirements Satisfied

  From `specs/extraction/code-extraction.spec.md`:

  - **Dependency Extraction** — cross-context edges (`type: "cross_context"`) and internal
    edges (`type: "internal"`) are both produced and are distinguishable by type.

  ## Key Design Decisions

  - Uses `ast.parse` from the Python stdlib — no third-party dependencies.
  - Import resolution strategy: convert `from iam.domain import X` to the module id
    `"iam.domain"` by matching against the discovered node set. Unresolved imports
    (stdlib, third-party) are silently skipped.
  - Edge granularity is at the **module** level (package nodes), not file level. Each
    unique (source_module, target_module) pair produces exactly one `Edge` at this stage.
    Weight counting (number of individual import statements) is deferred to task-006.
  - `type` is `"cross_context"` when source and target belong to different top-level
    bounded contexts; `"internal"` when they share the same bounded context.
  - Edges where source == target (self-imports) are discarded.
  - Edges are deduplicated: multiple files in the same module importing from the same
    target produce one edge, not N.

  ## Files Affected

  - `extractor/dependency.py` — new file:
    `extract_dependencies(nodes: list[Node], root_path) -> list[Edge]`
  - `extractor/tests/test_dependency.py` — unit tests with synthetic fixture packages
    + integration test asserting at least one cross-context edge exists in kartograph

  ## Verification

  1. `pytest extractor/tests/test_dependency.py` passes.
  2. Running against kartograph: `graph → shared_kernel` edge exists with
     `type: "cross_context"`.
  3. Running against kartograph: `iam.application → iam.domain` edge exists with
     `type: "internal"`.

  ## Caveats

  Dynamic imports (`importlib.import_module(...)`) are not detected. This is acceptable
  for the prototype scope. Relative imports (`from . import X`) are resolved relative to
  the file's own package.
---
