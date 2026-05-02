---
id: task-026
title: Implement call graph extraction (direct_call and dynamic_call edges)
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-003, task-023, task-025]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): add call graph extraction (direct_call and dynamic_call edges)"
pr_description: |
  ## What and Why

  This PR implements **Call Graph Extraction** as defined in `specs/core/visual-primitives.spec.md`
  (Extraction Layer § Call Graph Extraction). The module graph (task-003) tells us which modules
  import each other. The call graph tells us which *functions* call which *functions*, providing
  the data needed for the LOD tier-2 (near zoom) view to show function-level coupling and for
  future Route primitive rendering to trace execution paths. Without call graph data, the
  near-zoom view is limited to module-level structure.

  ## Spec Requirements Satisfied

  - For each function body: every call expression is analysed.
    - If the callee is a statically-resolvable name (direct call): a `direct_call` edge is
      emitted from caller to callee. The edge carries a `weight` equal to the number of call
      sites from caller to callee (call frequency annotation).
    - If the callee is a dynamic expression (e.g. a parameter, a dictionary lookup, a
      higher-order call): a `dynamic_call` edge is emitted with the source as the caller
      and `target: null`. The call site carries the parameter name and any type hints as
      `dynamic_target_hint`.
  - Extraction is intraprocedural: each function body is analysed independently using AST.
    No whole-program fixed-point analysis. No cross-file type resolution.

  ## Schema Change

  The edge schema (task-007, extended by task-025) gains two more `type` values:
  ```json
  { "source": "iam.application.handle_request", "target": "iam.domain.validate_input",
    "type": "direct_call", "weight": 3 }
  { "source": "iam.application.dispatch", "target": null,
    "type": "dynamic_call", "dynamic_target_hint": "handler: RequestHandler" }
  ```
  Node IDs for function-level sources use dotted paths extending from their module (consistent
  with the symbol table added in task-023).

  ## Files / Areas Affected

  - `extractor/` — new analysis pass walking function-def bodies and collecting Call nodes
    from the Python AST.
  - Depends on task-023 (symbol table) to produce consistent function-level node IDs.
  - Depends on task-025 to ensure the edge TypedDict already accommodates new type values
    (avoiding duplicate field conflicts from concurrent modification).
  - Scene graph JSON gains `direct_call` and `dynamic_call` edge entries.

  ## How to Verify

  1. Run the extractor against kartograph.
  2. Inspect `scene_graph.json` edges: find at least one `"type": "direct_call"` and confirm
     its `weight` equals the number of call sites from caller to callee in the source.
  3. Find a function with a callable parameter and confirm a `"type": "dynamic_call"` edge
     appears with `"target": null` and a non-empty `dynamic_target_hint`.
  4. Add regression tests:
     - A function with `validate_input(data)` called three times → weight 3.
     - A function with `handler(request)` where `handler` is a parameter → dynamic_call.
  5. Confirm the full extractor test suite still passes.

  ## Caveats / Follow-up

  - Dynamic calls are intentionally unresolved. The spec explicitly states that resolving all
    possible targets is the LLM's job in composition, not the extractor's.
  - This task does NOT implement Route Primitive rendering (that is a future vision feature,
    currently out of scope for the prototype).
  - Ubiquitous dependency detection (task-027) runs over the module graph, not the call graph,
    and is independent of this task.
---
