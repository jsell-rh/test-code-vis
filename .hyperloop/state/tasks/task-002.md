---
id: task-002
title: Module and package discovery with LOC metrics
spec_ref: "specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b"
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): discover Python modules and compute LOC metrics"
pr_description: |
  ## What and Why

  Implements the first stage of the extraction pipeline: walking the target codebase
  directory tree to discover all Python packages and modules, then computing lines-of-code
  (LOC) as the complexity metric. The output is a list of `Node` dicts conforming to the
  schema defined in task-001. This is the foundation that every subsequent extraction task
  builds on — dependency extraction (task-003), layout (task-004), and the JSON writer
  (task-008) all consume the node list produced here.

  ## Spec Requirements Satisfied

  From `specs/extraction/code-extraction.spec.md`:

  - **Module Discovery**: discovers all top-level bounded contexts and nested module layers
  - **Complexity Metrics** (§ Module size): computes total LOC per module; stores in node
    `size` field (raw LOC) and `metrics` sub-object

  ## Key Design Decisions

  - Uses `os.walk` or `pathlib.Path.rglob` — no third-party dependencies (stdlib only,
    matching existing extractor constraints).
  - A "bounded context" is identified as a top-level package (directory with `__init__.py`)
    directly under the codebase root.
  - A "module" is any sub-package (directory with `__init__.py`) inside a bounded context.
    Individual `.py` files are not surfaced as nodes (too granular for the prototype).
  - LOC = total lines across all `.py` files in the package directory (including nested),
    blank and comment lines included (simple, reproducible metric).
  - Node `id` uses dotted-path notation: `"iam"`, `"iam.domain"`, `"iam.application"`, etc.
  - `parent` is `null` for bounded-context nodes, the bounded-context id for module nodes.
  - `position` and `independence_group` are left at zero-vector and `null` respectively at
    this stage; downstream tasks fill them in.

  ## Files Affected

  - `extractor/discovery.py` — new file: `discover_modules(root_path) -> list[Node]`
  - `extractor/tests/test_discovery.py` — tests against fixture codebase and against
    kartograph path (integration)

  ## Verification

  1. `pytest extractor/tests/test_discovery.py` passes.
  2. Running against `~/code/kartograph` produces nodes for `iam`, `graph`, `management`,
     `query`, `shared_kernel`, `infrastructure` plus their sub-packages.
  3. Each node's `size` field is a positive integer (LOC count).

  ## Caveats

  LOC is computed at discovery time, so symlinks or generated files inside the codebase
  tree are counted. If kartograph has generated code, a future task can add an exclusion
  list.
---
