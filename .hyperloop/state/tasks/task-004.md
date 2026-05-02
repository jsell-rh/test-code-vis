---
id: task-004
title: Python extractor — complexity metrics and complete JSON output
spec_ref: "specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b"
status: not-started
phase: null
deps: [task-002, task-003]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): compute complexity metrics and write complete scene graph JSON"
pr_description: |
  ## What and Why

  Completes the core extractor pipeline by (a) computing lines-of-code metrics
  for each node and using them to set node `size`, and (b) writing the full
  scene graph JSON to disk in the schema defined by task-001. After this task,
  `extractor/cli.py --target ~/code/kartograph` produces a valid, loadable
  scene graph.

  The `size` field on each node is the signal the Godot renderer uses to scale
  volumes proportionally (task-009). Without it, every box is the same size.

  ## Spec Requirements Satisfied

  From `specs/extraction/code-extraction.spec.md`:
  - **Complexity Metrics — Module size**: counts total source lines (excluding
    blank lines and comments) for each module node; result stored in
    `metadata.loc` on the node and used to compute `size`.
  - **JSON Scene Graph Output — Output format**: writes a conformant JSON file
    with `nodes`, `edges`, `metadata`, and `clusters` (clusters left as `[]`
    at this stage — populated by task-006).

  ## Key Design Decisions

  - `size` is normalized: the largest module in the codebase gets `size: 1.0`;
    all others are scaled proportionally. A module with zero LOC (e.g. an
    `__init__.py` with only imports) gets a minimum `size: 0.1`.
  - `metadata` includes `source_path` (absolute) and `extracted_at` (UTC ISO-8601).
  - Output path is supplied via `--output` flag; defaults to `./scene-graph.json`.
  - The CLI exits non-zero with a clear message if `--target` does not exist or
    contains no Python files.

  ## Files Affected

  - `extractor/metrics.py` — LOC counting logic
  - `extractor/writer.py` — JSON serialization with schema validation
  - `extractor/cli.py` — final wiring: discovery → dependencies → metrics → write
  - `extractor/tests/test_metrics.py` — LOC count tests
  - `extractor/tests/test_writer.py` — round-trip JSON validity test

  ## How to Verify

  ```bash
  python extractor/cli.py --target ~/code/kartograph --output /tmp/kg.json
  python -c "
  import json, sys
  d = json.load(open('/tmp/kg.json'))
  assert 'nodes' in d and 'edges' in d and 'metadata' in d and 'clusters' in d
  sizes = [n['size'] for n in d['nodes']]
  assert max(sizes) == 1.0, f'max size should be 1.0, got {max(sizes)}'
  print('OK:', len(d['nodes']), 'nodes,', len(d['edges']), 'edges')
  "
  ```

  `python -m pytest extractor/tests/`

  ## Caveats

  Positions remain `{x:0, y:0, z:0}` placeholder — task-005 computes layout.
  `clusters` array is empty — task-006 populates it.
  `independence_group` is absent from nodes — task-007 adds it.
---
