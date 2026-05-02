---
id: task-026
title: Implement call graph extraction (direct_call and dynamic_call edges)
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: not_started
phase: null
deps:
- task-003
- task-023
- task-025
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): add call graph extraction (direct_call and dynamic_call
  edges)'
pr_description: "## What and Why\n\nThis PR implements **Call Graph Extraction** as\
  \ defined in `specs/core/visual-primitives.spec.md`\n(Extraction Layer § Call Graph\
  \ Extraction). The module graph (task-003) tells us which modules\nimport each other.\
  \ The call graph tells us which *functions* call which *functions*, providing\n\
  the data needed for the LOD tier-2 (near zoom) view to show function-level coupling\
  \ and for\nfuture Route primitive rendering to trace execution paths. Without call\
  \ graph data, the\nnear-zoom view is limited to module-level structure.\n\n## Spec\
  \ Requirements Satisfied\n\n- For each function body: every call expression is analysed.\n\
  \  - If the callee is a statically-resolvable name (direct call): a `direct_call`\
  \ edge is\n    emitted from caller to callee. The edge carries a `weight` equal\
  \ to the number of call\n    sites from caller to callee (call frequency annotation).\n\
  \  - If the callee is a dynamic expression (e.g. a parameter, a dictionary lookup,\
  \ a\n    higher-order call): a `dynamic_call` edge is emitted with the source as\
  \ the caller\n    and `target: null`. The call site carries the parameter name and\
  \ any type hints as\n    `dynamic_target_hint`.\n- Extraction is intraprocedural:\
  \ each function body is analysed independently using AST.\n  No whole-program fixed-point\
  \ analysis. No cross-file type resolution.\n\n## Schema Change\n\nThe edge schema\
  \ (task-007, extended by task-025) gains two more `type` values:\n```json\n{ \"\
  source\": \"iam.application.handle_request\", \"target\": \"iam.domain.validate_input\"\
  ,\n  \"type\": \"direct_call\", \"weight\": 3 }\n{ \"source\": \"iam.application.dispatch\"\
  , \"target\": null,\n  \"type\": \"dynamic_call\", \"dynamic_target_hint\": \"handler:\
  \ RequestHandler\" }\n```\nNode IDs for function-level sources use dotted paths\
  \ extending from their module (consistent\nwith the symbol table added in task-023).\n\
  \n## Files / Areas Affected\n\n- `extractor/` — new analysis pass walking function-def\
  \ bodies and collecting Call nodes\n  from the Python AST.\n- Depends on task-023\
  \ (symbol table) to produce consistent function-level node IDs.\n- Depends on task-025\
  \ to ensure the edge TypedDict already accommodates new type values\n  (avoiding\
  \ duplicate field conflicts from concurrent modification).\n- Scene graph JSON gains\
  \ `direct_call` and `dynamic_call` edge entries.\n\n## How to Verify\n\n1. Run the\
  \ extractor against kartograph.\n2. Inspect `scene_graph.json` edges: find at least\
  \ one `\"type\": \"direct_call\"` and confirm\n   its `weight` equals the number\
  \ of call sites from caller to callee in the source.\n3. Find a function with a\
  \ callable parameter and confirm a `\"type\": \"dynamic_call\"` edge\n   appears\
  \ with `\"target\": null` and a non-empty `dynamic_target_hint`.\n4. Add regression\
  \ tests:\n   - A function with `validate_input(data)` called three times → weight\
  \ 3.\n   - A function with `handler(request)` where `handler` is a parameter → dynamic_call.\n\
  5. Confirm the full extractor test suite still passes.\n\n## Caveats / Follow-up\n\
  \n- Dynamic calls are intentionally unresolved. The spec explicitly states that\
  \ resolving all\n  possible targets is the LLM's job in composition, not the extractor's.\n\
  - This task does NOT implement Route Primitive rendering (that is a future vision\
  \ feature,\n  currently out of scope for the prototype).\n- Ubiquitous dependency\
  \ detection (task-027) runs over the module graph, not the call graph,\n  and is\
  \ independent of this task."
---
