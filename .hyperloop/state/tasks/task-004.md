---
id: task-004
title: Python extractor — complexity metrics and complete JSON output
spec_ref: specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b
status: not_started
phase: null
deps:
- task-002
- task-003
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): compute complexity metrics and write complete scene graph
  JSON'
pr_description: "## What and Why\n\nCompletes the core extractor pipeline by (a) computing\
  \ lines-of-code metrics\nfor each node and using them to set node `size`, and (b)\
  \ writing the full\nscene graph JSON to disk in the schema defined by task-001.\
  \ After this task,\n`extractor/cli.py --target ~/code/kartograph` produces a valid,\
  \ loadable\nscene graph.\n\nThe `size` field on each node is the signal the Godot\
  \ renderer uses to scale\nvolumes proportionally (task-009). Without it, every box\
  \ is the same size.\n\n## Spec Requirements Satisfied\n\nFrom `specs/extraction/code-extraction.spec.md`:\n\
  - **Complexity Metrics — Module size**: counts total source lines (excluding\n \
  \ blank lines and comments) for each module node; result stored in\n  `metadata.loc`\
  \ on the node and used to compute `size`.\n- **JSON Scene Graph Output — Output\
  \ format**: writes a conformant JSON file\n  with `nodes`, `edges`, `metadata`,\
  \ and `clusters` (clusters left as `[]`\n  at this stage — populated by task-006).\n\
  \n## Key Design Decisions\n\n- `size` is normalized: the largest module in the codebase\
  \ gets `size: 1.0`;\n  all others are scaled proportionally. A module with zero\
  \ LOC (e.g. an\n  `__init__.py` with only imports) gets a minimum `size: 0.1`.\n\
  - `metadata` includes `source_path` (absolute) and `extracted_at` (UTC ISO-8601).\n\
  - Output path is supplied via `--output` flag; defaults to `./scene-graph.json`.\n\
  - The CLI exits non-zero with a clear message if `--target` does not exist or\n\
  \  contains no Python files.\n\n## Files Affected\n\n- `extractor/metrics.py` —\
  \ LOC counting logic\n- `extractor/writer.py` — JSON serialization with schema validation\n\
  - `extractor/cli.py` — final wiring: discovery → dependencies → metrics → write\n\
  - `extractor/tests/test_metrics.py` — LOC count tests\n- `extractor/tests/test_writer.py`\
  \ — round-trip JSON validity test\n\n## How to Verify\n\n```bash\npython extractor/cli.py\
  \ --target ~/code/kartograph --output /tmp/kg.json\npython -c \"\nimport json, sys\n\
  d = json.load(open('/tmp/kg.json'))\nassert 'nodes' in d and 'edges' in d and 'metadata'\
  \ in d and 'clusters' in d\nsizes = [n['size'] for n in d['nodes']]\nassert max(sizes)\
  \ == 1.0, f'max size should be 1.0, got {max(sizes)}'\nprint('OK:', len(d['nodes']),\
  \ 'nodes,', len(d['edges']), 'edges')\n\"\n```\n\n`python -m pytest extractor/tests/`\n\
  \n## Caveats\n\nPositions remain `{x:0, y:0, z:0}` placeholder — task-005 computes\
  \ layout.\n`clusters` array is empty — task-006 populates it.\n`independence_group`\
  \ is absent from nodes — task-007 adds it."
---
