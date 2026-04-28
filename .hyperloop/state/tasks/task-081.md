---
id: task-081
title: Extractor — data flow spine extraction
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-080]
round: 0
branch: null
pr: null
---

Implement intraprocedural data flow spine extraction in the Python extractor: trace
how values flow from function parameters through internal operations to return values,
plus one-call-deep interprocedural flow, and store the spines as metadata on the
relevant module nodes.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Data Flow Spine Extraction
("The extractor MUST produce intraprocedural data flow chains showing how values produced
in one place are consumed in another, scoped to function parameters and return values"):

**Scope constraint** (critical — strictly enforce):
- Intraprocedural: trace within a single function body.
- Interprocedural: at most ONE call level (follow a call into the callee and track
  argument → parameter → return flow back to the caller). No recursive expansion.
- Do NOT perform whole-program fixed-point analysis.

**Algorithm** — for each `ast.FunctionDef` / `ast.AsyncFunctionDef` in each file:

**Intraprocedural spine:**
1. Identify all function parameters as data sources.
2. Walk the function body with a light use-def tracker:
   - `ast.Assign` / `ast.AnnAssign`: the right-hand value may be a parameter name or
     the result of a function call; record the chain step.
   - `ast.Return`: if the return expression references a tracked name, close the chain.
3. Produce a spine: an ordered list of `{ "source": name_or_call, "step": description }`.
4. If the parameter reaches the return value (even through intermediates), emit the
   complete spine.

**One-call-deep interprocedural step:**
5. For call sites within the function (from task-080's call list) where the callee
   module and function are resolved:
   - Record the mapping: caller_arg → callee_param → callee_return → caller_assignment.
   - Add this as a cross-function step in the spine.

**Storage** — store spines as a `data_flow_spines` top-level array in the scene graph
JSON (alongside `nodes`, `edges`, `metadata`, `clusters`). Each entry:

```json
{
  "function_id": "<module_id>::<function_name>",
  "parameter": "<param_name>",
  "steps": [
    { "step": 0, "description": "parameter <param_name>" },
    { "step": 1, "description": "passed to <callee_name>" },
    { "step": 2, "description": "assigned to <local_var>" },
    { "step": 3, "description": "returned" }
  ]
}
```

**Validator update** (extend from task-076):
- Add `data_flow_spines` as an optional top-level key (array, default `[]`).
- Each spine entry MUST have `function_id` (non-empty string), `parameter` (string),
  and `steps` (non-empty array of step objects with integer `step` and string
  `description`).

**Extraction cost boundary** (from spec):
- Process each function body independently. Functions are not combined.
- Interprocedural depth is strictly capped at 1. If a callee calls another function,
  that deeper call is NOT expanded.
- For codebases with 10,000+ functions, this MUST remain tractable: O(n) in function
  count.

**Edge cases:**
- Functions with no parameters: no spines emitted for that function.
- Functions where the parameter does not reach any return value: no spine emitted.
- Generators, async generators: treat `yield` expressions as "return" endpoints.

Use only Python standard library. No external dependencies.

**Output**: a list of spine dicts, stored as `data_flow_spines` in the final JSON.
The scene graph schema document MUST be updated to document this new top-level key.
