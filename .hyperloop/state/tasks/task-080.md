---
id: task-080
title: Extractor — call graph extraction
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-076, task-003]
round: 0
branch: null
pr: null
---

Implement call graph extraction in the Python extractor: parse function bodies to
find call sites, resolve direct calls to known symbols, emit `direct_call` and
`dynamic_call` edges with call-frequency weights.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Call Graph Extraction
("The extractor MUST produce the directed graph of function-to-function invocations"):

**Algorithm** — for each `.py` file in the codebase:

1. Parse with `ast.parse()`.
2. Walk `ast.FunctionDef` and `ast.AsyncFunctionDef` nodes (the callers).
3. Within each function body, collect all `ast.Call` nodes.

**Direct call resolution:**
4. For each `ast.Call`, extract the callee name:
   - `ast.Name` (bare name call, e.g. `validate_input(data)`) → callee name is
     `node.id`.
   - `ast.Attribute` (method/attribute call, e.g. `self.repo.save(order)`) →
     callee name is the final attribute `node.attr`.
5. Attempt to resolve the callee name to a known module node id:
   - Match against the symbol table of modules in the same bounded context first.
   - Then against modules reachable via imports from the calling module (using the
     import map from task-003).
6. If resolved: accumulate a `(caller_module_id, callee_module_id)` count.
7. After processing all files in a module, emit `direct_call` edges:
   - One edge per unique `(caller, callee)` module pair with `weight` = number of
     distinct call sites between those modules.
   - `{ "source": caller_module_id, "target": callee_module_id,
     "type": "direct_call", "weight": N }`

**Dynamic (unresolved) calls:**
8. For each `ast.Call` whose callee cannot be resolved (e.g. call through a parameter,
   stored function reference, `getattr`), emit:
   - `{ "source": caller_module_id, "target": null, "type": "dynamic_call",
     "weight": 1 }`
   - Accumulate dynamic calls per source module: one `dynamic_call` edge per source
     module, with `weight` = total count of unresolved call sites in that module.

**Aggregation** — this task works at MODULE granularity (same as the existing module
graph). Multiple function-to-function calls within the same source→target module pair
aggregate into one `direct_call` edge with the sum of call counts as weight.

**Deduplication** — the call graph edges are in ADDITION to the import edges from
task-003. A module-pair that has both import-based AND call-based edges will have
both edge types present in the scene graph (they are distinct relationship types).

**Edge cases:**
- Files that fail to parse: log warning, skip.
- Recursive calls (function calls itself): the source and target module are the same;
  emit a self-loop edge (source == target) with `type: "direct_call"`.
- Calls into stdlib or third-party code (not in the known node set): skip direct call;
  count toward dynamic_call only if the name cannot be resolved at all.

Use only Python standard library (`ast`, `pathlib`). No external dependencies.

**Output**: a list of edge dicts with `type: "direct_call"` or `type: "dynamic_call"`,
to be merged into the main edge list by task-085.
