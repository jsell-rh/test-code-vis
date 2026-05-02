---
id: task-002
title: Python extractor — module discovery and containment hierarchy
spec_ref: "specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b"
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): discover modules and emit containment hierarchy"
pr_description: |
  ## What and Why

  Implements the first stage of the Python extractor: walking the kartograph
  codebase (or any Python project) and discovering all packages, modules, and
  their parent-child containment relationships.

  This is the prerequisite for every other extractor task — dependency
  extraction, metrics, and layout all operate on the module tree produced here.

  ## Spec Requirements Satisfied

  From `specs/extraction/code-extraction.spec.md`:
  - **Module Discovery — Discovering kartograph's bounded contexts**: finds all
    top-level packages (iam, graph, management, query, shared_kernel,
    infrastructure) and emits each as a node with `type: "bounded_context"`.
  - **Module Discovery — Discovering nested modules**: discovers internal
    layers (domain, application, infrastructure, presentation) and represents
    containment via the `parent` field on each node.

  ## Key Design Decisions

  - Extractor entry point is `extractor/cli.py` accepting `--target <path>` and
    `--output <file>`.
  - Module walk uses Python's `ast` module (stdlib only — no tree-sitter needed
    at this stage) to find `.py` files and infer package boundaries from
    `__init__.py` presence.
  - Outputs a partial scene graph JSON (nodes array only, edges empty, clusters
    empty) for this task. Later tasks fill in edges and clusters.
  - Node `type` is determined by directory depth: root packages are
    `"bounded_context"`, sub-packages are `"module"`, individual `.py` files
    without their own sub-packages are `"file"`.

  ## Files Affected

  - `extractor/cli.py` — CLI entry point
  - `extractor/discovery.py` — module walk logic
  - `extractor/tests/test_discovery.py` — pytest tests against kartograph fixture

  ## How to Verify

  ```bash
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json
  cat /tmp/kg.json | python -m json.tool | grep '"type"' | sort | uniq -c
  ```
  Expected: entries for bounded_context, module, file types.

  `python -m pytest extractor/tests/test_discovery.py` — all tests pass.

  ## Caveats

  Position coordinates are left as `{"x": 0, "y": 0, "z": 0}` placeholders at
  this stage; task-005 (pre-computed layout) fills them in. Size is set to 1.0
  placeholder; task-004 (complexity metrics) fills it in.
---
