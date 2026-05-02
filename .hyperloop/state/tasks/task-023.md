---
id: task-023
title: Implement symbol table extraction and node symbols schema field
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: in_progress
phase: mark-ready
deps:
- task-002
- task-006
round: 1
branch: hyperloop/task-023
pr: https://github.com/jsell-rh/test-code-vis/pull/234
pr_title: 'feat(extractor): add symbol table extraction and node symbols schema field'
pr_description: "## What and Why\n\nThis PR implements **Symbol Table Extraction**\
  \ as defined in `specs/core/visual-primitives.spec.md`\n(Extraction Layer § Symbol\
  \ Table Extraction). The extractor currently produces module-level nodes\nwith names\
  \ but no information about the functions, types, constants, and variables declared\n\
  inside each module. Without this data, the Godot LOD tier-2 (near zoom) view cannot\
  \ display\nmeaningful function-level labels, and edge renderers cannot show human-readable\
  \ names for\ncall graph endpoints.\n\n## Spec Requirements Satisfied\n\n- Every\
  \ function, class, type, constant, and variable in each module is extracted as a\
  \ symbol.\n- Each symbol carries: `name`, `kind` (function | class | constant |\
  \ variable), `visibility`\n  (public | private — derived from Python naming convention:\
  \ `_` prefix → private), and\n  `signature` (parameter names + type hints if present,\
  \ return type hint if present).\n- The `nodes` array in the scene graph JSON is\
  \ extended: each module-level node gains an\n  optional `symbols` array containing\
  \ these symbol objects.\n- Extraction uses single-file AST parsing only; no cross-file\
  \ resolution or type inference.\n- Extraction time is proportional to number of\
  \ files (linear).\n\n## Schema Change\n\nThe node schema (task-006) is extended\
  \ with a new optional field:\n```json\n\"symbols\": [\n  {\n    \"name\": \"process_order\"\
  ,\n    \"kind\": \"function\",\n    \"visibility\": \"public\",\n    \"signature\"\
  : \"(order_id: int, user: User) -> Result\"\n  },\n  {\n    \"name\": \"_validate_input\"\
  ,\n    \"kind\": \"function\",\n    \"visibility\": \"private\",\n    \"signature\"\
  : \"(data: dict) -> bool\"\n  }\n]\n```\nThe field is omitted for nodes at bounded-context\
  \ or package level (only module nodes carry symbols).\n\n## Files / Areas Affected\n\
  \n- `extractor/` — new module or extension of existing extraction pipeline to run\
  \ AST-based symbol\n  analysis on each Python source file.\n- Likely touches the\
  \ same pipeline entry point that scope nesting extraction (task-002) uses.\n- The\
  \ extractor's TypedDict / dataclass for nodes must gain a `symbols` optional field.\n\
  - Scene graph JSON output changes shape: module nodes gain `symbols` arrays.\n\n\
  ## How to Verify\n\n1. Run the extractor against the kartograph codebase.\n2. Inspect\
  \ `scene_graph.json`: module nodes should contain a `symbols` array.\n3. Confirm\
  \ `process_order` appears with `\"visibility\": \"public\"` and `_validate_input`\
  \ appears\n   with `\"visibility\": \"private\"`.\n4. Confirm signatures include\
  \ type hints where present and omit them where absent.\n5. Run the extractor test\
  \ suite — existing tests for scope nesting must still pass.\n6. Check that extraction\
  \ time has not regressed significantly (still linear in file count).\n\n## Caveats\
  \ / Follow-up\n\n- This task covers only static visibility (naming convention).\
  \ It does not perform\n  visibility analysis through `__all__` exports; that is\
  \ a future enhancement.\n- Call graph extraction (task-026) depends on symbol table\
  \ data for labeling call edges.\n- The Godot renderer is not modified by this PR;\
  \ the `symbols` field is added to the JSON\n  for future use by near-LOD views."
---
