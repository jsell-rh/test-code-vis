---
id: task-085
title: Extractor — output writer extension for visual-primitives fields
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-066, task-078, task-079, task-080, task-081, task-082, task-083, task-084]
round: 0
branch: null
pr: null
---

Extend the extractor CLI output writer (task-066) to integrate the new analysis steps
introduced by the visual-primitives spec — symbol table, type topology, call graph,
data flow spines, structural significance, ubiquitous detection, and badge computation
— into the pipeline and emit their results in the final JSON.

Covers `specs/core/visual-primitives.spec.md` — Extraction Layer (all requirements):
this task is the assembly step that wires all new extraction tasks into a single run.

**Pipeline extension** — after the existing steps in task-066's pipeline, call the new
analysis functions in this order (respecting data dependencies):

1. **Symbol table extraction** (task-078):
   - Call for all module nodes; populate `symbols` on each node.

2. **Type topology extraction** (task-079):
   - Produce `inherits` and `has_a` edges; append to the edge list.

3. **Call graph extraction** (task-080):
   - Produce `direct_call` and `dynamic_call` edges; append to the edge list.

4. **Data flow spine extraction** (task-081):
   - Depends on call graph (task-080). Produce `data_flow_spines` list.

5. **Structural significance** (task-082):
   - Depends on weighted edges from task-063 (already in the pipeline). Annotate
     module nodes with `significance` objects and `landmark` flags.

6. **Ubiquitous dependency detection** (task-083):
   - Depends on weighted edges from task-063. Mark edges with `ubiquitous: true`;
     extend `metadata` with `ubiquitous_threshold` and `ubiquitous_deps`.

7. **Badge computation** (task-084):
   - Depends on symbol table, call graph, structural significance, and ubiquitous
     detection. Populate `badges` on each node.

**JSON serialisation** — build the output dict with exactly FIVE top-level keys
(extending the four from task-066):
`nodes`, `edges`, `metadata`, `clusters`, `data_flow_spines`.

All other top-level keys are forbidden. The validator MUST be updated to accept
`data_flow_spines` as the fifth required top-level key (array, MAY be empty).

**Validation** — run the updated validator (from task-081 and task-076) before
writing. The validator now checks:
- All five top-level keys are present.
- `significance`, `landmark`, `badges`, `symbols` on nodes (optional, validated
  when present).
- `ubiquitous`, new edge `type` values on edges (validated when present).
- `data_flow_spines` structure.

**CLI flags for selective analysis** — add opt-out flags to keep fast extraction
runs tractable on large codebases:
- `--no-symbol-table`: skip task-078 (implies --no-badges, --no-ports).
- `--no-call-graph`: skip task-080 (implies --no-data-flow).
- `--no-data-flow`: skip task-081.
- `--no-significance`: skip task-082 (implies --no-landmarks, --no-badges).
- `--no-ubiquitous`: skip task-083.
- `--no-badges`: skip task-084.
When a step is skipped, its fields are simply absent from the output (not null).

**Backward compatibility** — the four top-level keys from task-066 (`nodes`, `edges`,
`metadata`, `clusters`) remain present and valid at all times. The fifth key
(`data_flow_spines`) is always present but may be `[]` if data flow analysis is
skipped. Godot loads from task-008 MUST gracefully handle absent per-node optional
fields (`significance`, `badges`, `symbols`) without crashing.
