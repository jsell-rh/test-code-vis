---
id: task-002
title: Python extractor — module discovery and containment hierarchy
spec_ref: specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b
status: not_started
phase: null
deps:
- task-001
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): discover modules and emit containment hierarchy'
pr_description: "## What and Why\n\nImplements the first stage of the Python extractor:\
  \ walking the kartograph\ncodebase (or any Python project) and discovering all packages,\
  \ modules, and\ntheir parent-child containment relationships.\n\nThis is the prerequisite\
  \ for every other extractor task — dependency\nextraction, metrics, and layout all\
  \ operate on the module tree produced here.\n\n## Spec Requirements Satisfied\n\n\
  From `specs/extraction/code-extraction.spec.md`:\n- **Module Discovery — Discovering\
  \ kartograph's bounded contexts**: finds all\n  top-level packages (iam, graph,\
  \ management, query, shared_kernel,\n  infrastructure) and emits each as a node\
  \ with `type: \"bounded_context\"`.\n- **Module Discovery — Discovering nested modules**:\
  \ discovers internal\n  layers (domain, application, infrastructure, presentation)\
  \ and represents\n  containment via the `parent` field on each node.\n\n## Key Design\
  \ Decisions\n\n- Extractor entry point is `extractor/cli.py` accepting `--target\
  \ <path>` and\n  `--output <file>`.\n- Module walk uses Python's `ast` module (stdlib\
  \ only — no tree-sitter needed\n  at this stage) to find `.py` files and infer package\
  \ boundaries from\n  `__init__.py` presence.\n- Outputs a partial scene graph JSON\
  \ (nodes array only, edges empty, clusters\n  empty) for this task. Later tasks\
  \ fill in edges and clusters.\n- Node `type` is determined by directory depth: root\
  \ packages are\n  `\"bounded_context\"`, sub-packages are `\"module\"`, individual\
  \ `.py` files\n  without their own sub-packages are `\"file\"`.\n\n## Files Affected\n\
  \n- `extractor/cli.py` — CLI entry point\n- `extractor/discovery.py` — module walk\
  \ logic\n- `extractor/tests/test_discovery.py` — pytest tests against kartograph\
  \ fixture\n\n## How to Verify\n\n```bash\npython extractor/cli.py --target ~/code/kartograph\
  \ --output /tmp/kg.json\ncat /tmp/kg.json | python -m json.tool | grep '\"type\"\
  ' | sort | uniq -c\n```\nExpected: entries for bounded_context, module, file types.\n\
  \n`python -m pytest extractor/tests/test_discovery.py` — all tests pass.\n\n## Caveats\n\
  \nPosition coordinates are left as `{\"x\": 0, \"y\": 0, \"z\": 0}` placeholders\
  \ at\nthis stage; task-005 (pre-computed layout) fills them in. Size is set to 1.0\n\
  placeholder; task-004 (complexity metrics) fills it in."
---
