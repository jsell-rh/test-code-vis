---
id: task-100
title: Extractor — scope nesting: class and function node discovery
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-099, task-002, task-005]
round: 0
branch: null
pr: null
---

Implement scope nesting analysis in the Python extractor: for each module discovered
by task-002, parse its source files via AST to discover class definitions and
function/method definitions, emit them as `class` and `function` nodes (schema
defined in task-099), compute positions within parent spatial bounds, and append
them to the node list before JSON serialisation.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Scope Nesting
Extraction ("the full containment hierarchy: modules contain classes, classes contain
methods — every leaf is an atomic declaration — it requires only single-file AST
parsing — completes in time proportional to number of files"):

---

**Algorithm** — for each module node (type `"module"`) in the node list:

1. Locate all `.py` files belonging to this module (same discovery logic as
   task-002/task-004).

2. For each `.py` file, parse with `ast.parse()`. Walk the AST:

   **Class nodes** — for each `ast.ClassDef` at the module body level:
   - Emit a `class` node with:
     - `id`: `"{module_id}.{class_name}"` (e.g. `"iam.domain.PaymentProcessor"`).
     - `name`: the `ClassDef.name` attribute.
     - `type`: `"class"`.
     - `parent`: the module node id.
     - `metrics.loc`: `ClassDef.end_lineno - ClassDef.lineno + 1`.

   **Method nodes within a class** — for each `ast.FunctionDef` or
   `ast.AsyncFunctionDef` that is a direct child of a `ClassDef` body:
   - Emit a `function` node with:
     - `id`: `"{class_id}.{method_name}"`.
     - `name`: the method name.
     - `type`: `"function"`.
     - `parent`: the enclosing class node id.
     - `visibility`: `"private"` if name starts with `_`, else `"public"`.
     - `signature`: reconstructed from `FunctionDef.args` (parameter names and
       annotations as strings, `", "`-joined) and `FunctionDef.returns` (return
       annotation string if present). Format: `"(<params>) -> <return>"` or
       `"(<params>)"` if no return annotation.
     - `metrics.loc`: `FunctionDef.end_lineno - FunctionDef.lineno + 1`.

   **Module-level function nodes** — for each `ast.FunctionDef` or
   `ast.AsyncFunctionDef` at the module body level (not inside a class):
   - Emit a `function` node with:
     - `id`: `"{module_id}.{function_name}"`.
     - `parent`: the module node id.
     - Same `visibility`, `signature`, and `metrics.loc` rules as method nodes above.

3. **Nested classes** (class inside a class) — skip; only top-level classes within
   modules and their direct method children are emitted. Deeper nesting is not supported.

4. **Duplicate ids** — if a module spans multiple `.py` files and a class or function
   name appears in more than one, disambiguate by appending the file stem:
   `"{module_id}.{filename_stem}.{name}"`. If only one file per module, no
   disambiguation is needed.

---

**Position computation** — assign positions so that child nodes lie within their
parent container's bounding box (requirement from task-099's schema):

**Class nodes within a module:**
1. Get the module's `position` (x, y, z) and `size` (from task-005 output).
2. Arrange class nodes in a uniform grid within the module's footprint:
   - `N = number of class nodes + number of module-level functions`.
   - `cols = ceil(sqrt(N))`.
   - `cell_size = (module_size * 0.85) / cols` (leaves gap at module edge).
   - Assign each node a grid slot; offset from module centre.
   - `node.size = cell_size * 0.8` (leaves gap between cells).

**Function nodes within a class:**
1. Get the class node's `position` and `size`.
2. Arrange in a single row along the class's x-axis:
   - `cell_width = class_size / max(N_methods, 1)`.
   - `node.size = min(cell_width * 0.8, 0.18)` (capped to keep legible).

**Module-level functions** share the same grid as class nodes (treated as peers in
the grid layout).

---

**Extraction cost** — single-file AST parsing only. No cross-file resolution, no
type inference, no whole-program analysis. Each `.py` file is parsed once; runtime
is O(file count × mean file size).

---

**CLI flag** — expose as opt-in:
- `--scope-nesting`: enable class and function node discovery. Off by default.
- When omitted, only `bounded_context` and `module` nodes are emitted (unchanged
  from task-002).
- When enabled, class and function nodes are appended to the flat `nodes` array
  in the JSON output alongside the existing module nodes. The output writer
  (task-085) serialises the combined list without modification.

**Edge cases:**
- Module with no classes and no module-level functions: no child nodes emitted.
- Class with no methods (only class variables): class node emitted, no children.
- Syntax errors in a `.py` file: skip that file with a `stderr` warning; do not
  abort the extraction.
- Module with more than 64 classes: emit all (no cap); Godot tier-2 rendering
  handles display limits independently.

Use only Python standard library (`ast`, `pathlib`). No external dependencies.

**Output**: the existing flat `nodes` array (bounded_context + module) with `class`
and `function` nodes appended, all conforming to the schema defined in task-099.
