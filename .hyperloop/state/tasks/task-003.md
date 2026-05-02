---
id: task-003
title: Python extractor — import-based dependency extraction
spec_ref: specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b
status: not_started
phase: null
deps:
- task-002
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): extract import-based dependency edges between modules'
pr_description: "## What and Why\n\nAdds the dependency-extraction stage to the Python\
  \ extractor. After module\ndiscovery (task-002) produces the node list, this task\
  \ parses each file's\nimport statements and emits directed edges between modules.\n\
  \nDependency edges are the primary structural signal for the 3D visualization:\n\
  they drive the coupling-aware layout in task-005, cluster detection in\ntask-006,\
  \ and independence grouping in task-007. Without them, the rendered\nscene is just\
  \ a flat list of boxes.\n\n## Spec Requirements Satisfied\n\nFrom `specs/extraction/code-extraction.spec.md`:\n\
  - **Dependency Extraction — Cross-context dependency**: identifies that (e.g.)\n\
  \  the `graph` context imports from `shared_kernel` and emits a directed edge\n\
  \  `graph → shared_kernel`.\n- **Dependency Extraction — Internal dependency**:\
  \ identifies\n  `iam.application.services → iam.domain` and emits an internal edge\
  \ with\n  `type: \"internal\"`.\n\n## Key Design Decisions\n\n- Uses Python `ast.parse`\
  \ to extract `import X` and `from X import Y`\n  statements from each `.py` file\
  \ without executing them.\n- Resolves import targets against the discovered module\
  \ tree; unresolved\n  (third-party or stdlib) imports are recorded but not emitted\
  \ as edges.\n- Each unique (source, target) module pair becomes one edge entry with\n\
  \  `weight` equal to the count of individual import statements referencing\n  that\
  \ target. This weight feeds the aggregate-edge computation in task-006.\n- Edge\
  \ `type` is `\"cross_context\"` if source and target are in different\n  top-level\
  \ packages, `\"internal\"` otherwise.\n\n## Files Affected\n\n- `extractor/dependencies.py`\
  \ — import-parsing and edge-emission logic\n- `extractor/cli.py` — wired to call\
  \ dependency extraction after discovery\n- `extractor/tests/test_dependencies.py`\
  \ — tests covering cross-context,\n  internal, and zero-dependency module cases\n\
  \n## How to Verify\n\n```bash\npython extractor/cli.py --target ~/code/kartograph\
  \ --output /tmp/kg.json\npython -c \"\nimport json\nd = json.load(open('/tmp/kg.json'))\n\
  print(f'{len(d[\\\"edges\\\"])} edges found')\nprint([e for e in d['edges'] if e['type']\
  \ == 'cross_context'][:3])\n\"\n```\n\n`python -m pytest extractor/tests/test_dependencies.py`\n\
  \n## Caveats\n\nDynamic imports (`importlib.import_module(...)`) are not resolved\
  \ — they\nrequire execution and are outside the static-analysis scope of the prototype.\n\
  Star imports (`from X import *`) are recorded as a single edge with weight 1."
---
