---
id: task-003
title: Python extractor — import-based dependency extraction
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

  Adds the dependency-extraction stage to the Python extractor. After module
  discovery (task-002) produces the node list, this task parses each file's
  import statements and emits directed edges between modules.

  Dependency edges are the primary structural signal for the 3D visualization:
  they drive the coupling-aware layout in task-005, cluster detection in
  task-006, and independence grouping in task-007. Without them, the rendered
  scene is just a flat list of boxes.

  ## Spec Requirements Satisfied

  From `specs/extraction/code-extraction.spec.md`:
  - **Dependency Extraction — Cross-context dependency**: identifies that (e.g.)
    the `graph` context imports from `shared_kernel` and emits a directed edge
    `graph → shared_kernel`.
  - **Dependency Extraction — Internal dependency**: identifies
    `iam.application.services → iam.domain` and emits an internal edge with
    `type: "internal"`.

  ## Key Design Decisions

  - Uses Python `ast.parse` to extract `import X` and `from X import Y`
    statements from each `.py` file without executing them.
  - Resolves import targets against the discovered module tree; unresolved
    (third-party or stdlib) imports are recorded but not emitted as edges.
  - Each unique (source, target) module pair becomes one edge entry with
    `weight` equal to the count of individual import statements referencing
    that target. This weight feeds the aggregate-edge computation in task-006.
  - Edge `type` is `"cross_context"` if source and target are in different
    top-level packages, `"internal"` otherwise.

  ## Files Affected

  - `extractor/dependencies.py` — import-parsing and edge-emission logic
  - `extractor/cli.py` — wired to call dependency extraction after discovery
  - `extractor/tests/test_dependencies.py` — tests covering cross-context,
    internal, and zero-dependency module cases

  ## How to Verify

  ```bash
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json
  python -c "
  import json
  d = json.load(open('/tmp/kg.json'))
  print(f'{len(d[\"edges\"])} edges found')
  print([e for e in d['edges'] if e['type'] == 'cross_context'][:3])
  "
  ```

  `python -m pytest extractor/tests/test_dependencies.py`

  ## Caveats

  Dynamic imports (`importlib.import_module(...)`) are not resolved — they
  require execution and are outside the static-analysis scope of the prototype.
  Star imports (`from X import *`) are recorded as a single edge with weight 1.
---
