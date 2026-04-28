---
id: task-111
title: Extractor — function-to-function call graph (scope-nesting mode)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-113, task-100, task-080]
round: 0
branch: null
pr: null
---

When `--scope-nesting` is active, emit `direct_call` and `dynamic_call` edges
using **function node IDs** as source and target, satisfying the spec's requirement
for function-to-function call graph granularity. Module-level call graph edges
(task-080) continue to serve medium-LOD (tier-1) views; this task's edges serve
tier-2 (near-LOD) rendering in task-109.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Call Graph Extraction,
Scenarios: Direct calls ("an edge is emitted from `handle_request` to
`validate_input`"), Indirect calls ("the call site carries the parameter name and
any type hints"), and Call frequency annotation ("the edge A->B carries a weight of 3"):

task-080 implements call graph extraction at **module** granularity (multiple
function-to-function calls between modules collapse into one module-level edge).
The spec, however, describes function-to-function edges (`handle_request` →
`validate_input`, not `iam.application` → `iam.domain`). task-109 explicitly
expects `direct_call` edges that connect **function nodes** to function nodes
at tier-2 LOD. Without this task those fine-grained edges do not exist in the
scene graph and tier-2 call graph rendering is empty.

---

**Precondition** — this task only runs when `--scope-nesting` is active (i.e.,
after task-100 has emitted class and function nodes into the node list). When
`--scope-nesting` is absent, skip silently; do not error.

**Input** — the flat node list produced by task-100 (contains `class` and
`function` nodes alongside `bounded_context` and `module` nodes), the import map
from task-003, and the per-module AST cache (reuse parsed trees from task-100
wherever possible to avoid re-parsing).

---

**Algorithm** — for each **function node** (type `"function"`) emitted by task-100:

1. Locate the source file for this function from its dot-separated id (e.g.
   `"iam.domain.PaymentProcessor.process"` → module `"iam.domain"` → its `.py`
   files). Retrieve the `ast.FunctionDef` / `ast.AsyncFunctionDef` node that
   matches this function (by name and class context).

2. **Collect parameter type annotations** — build a dict
   `param_annotations: { param_name: annotation_str | None }` from
   `FunctionDef.args` for every argument (including `self`, `cls`). Use
   `ast.unparse(annotation)` when annotation is present; otherwise `None`.

3. **Walk the function body** for `ast.Call` nodes (direct children of statements
   only; do not recurse into nested function defs).

**Direct call resolution** — for each `ast.Call`:

4. Extract callee name:
   - `ast.Name`: bare call, callee is `node.id`.
   - `ast.Attribute`: method call, callee is `node.attr`.

5. Attempt to resolve the callee to a **function node id** in the node list:
   a. Search function nodes within the same bounded context whose `name` matches.
   b. If multiple matches, prefer the one in the same module; then prefer `public`
      visibility; take the first alphabetically as tiebreaker.
   c. If still unresolved, fall back to the module-level match used by task-080
      (resolve to a module node id). Emit the edge with the module node id as
      target — this is valid; the schema does not restrict source/target node types.

6. If resolved to a **function node id**: accumulate a
   `(source_function_id, target_function_id)` count.

7. After all `ast.Call` nodes in this function are processed, emit one
   `direct_call` edge per unique `(source, target)` pair:
   ```json
   {
     "source": "iam.domain.PaymentProcessor.process",
     "target": "iam.domain.validate_input",
     "type": "direct_call",
     "weight": <call_site_count>
   }
   ```

**Dynamic (unresolved) calls** — for each `ast.Call` whose callee cannot be
resolved to ANY known node id:

8. Determine if the callee name matches a parameter name of this function
   (i.e. the caller is dispatching through a received callable):
   - `callee_name in param_annotations` → YES, this is a dynamic dispatch
     through a parameter.

9. Emit ONE `dynamic_call` edge per such **distinct parameter name** used as a
   callee across all call sites in this function:
   ```json
   {
     "source": "iam.application.handle_request",
     "target": null,
     "type": "dynamic_call",
     "weight": <call_site_count_for_this_param>,
     "call_target_hint": {
       "parameter_name": "<param_name>",
       "type_annotation": "<annotation_str_or_null>"
     }
   }
   ```
   `call_target_hint` is populated from `param_annotations[callee_name]`.

10. Calls where the callee is not a parameter and cannot be resolved: emit a bare
    `dynamic_call` edge WITHOUT `call_target_hint` (same as task-080's fallback):
    ```json
    { "source": "...", "target": null, "type": "dynamic_call", "weight": N }
    ```

---

**Deduplication vs. task-080** — task-080 produces module-level call edges.
This task produces function-level call edges. Both coexist in the edge list.
They are NOT duplicates: module-level edges aggregate (e.g.
`"iam.application" → "iam.domain"`, weight 12) while function-level edges are
fine-grained (e.g. `"iam.application.process" → "iam.domain.validate"`, weight 3).
The Godot renderer uses module-level edges at medium LOD (task-067) and
function-level edges at near LOD (task-109). No deduplication between the two sets.

**Self-calls** — a function that calls itself: emit a `direct_call` edge where
source == target (self-loop). Valid per schema.

**Calls into stdlib or third-party code** — if the callee name cannot be resolved
to ANY known node and is not a local parameter name: skip. Do not emit a
`dynamic_call` edge for every unresolvable stdlib call (that would be too noisy).
Only emit `dynamic_call` when the callee is a local parameter (dynamic dispatch).

**Files that fail to parse** — log a warning to stderr; skip the file without
aborting extraction.

**CLI flag** — this task's logic runs automatically when `--scope-nesting` is
active. Add a combined opt-out flag `--no-call-graph` (from task-085) that skips
both task-080 and this task.

---

**Output writer integration** — this task produces a list of function-level edge
dicts (`direct_call` and `dynamic_call` with function node IDs). The output writer
pipeline (task-085) MUST be extended to call this function after task-080 and append
its results to the edge list before serialisation. Add a new pipeline step in
task-085's assembly: "Function-level call graph (task-111) — runs when
`--scope-nesting` is active."

Use only Python standard library (`ast`, `pathlib`). No external dependencies.

**Output**: a list of edge dicts with `type: "direct_call"` or `type: "dynamic_call"`,
using function node IDs as source (and target where resolved), to be merged into
the main edge list by the output writer.
