---
id: task-078
title: Extractor — symbol table extraction
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-075, task-002]
round: 0
branch: null
pr: null
---

Implement symbol table extraction in the Python extractor: parse each discovered
module's Python source and produce a `symbols` array on the node, listing all
top-level named declarations with their kind, visibility, and signature.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Symbol Table Extraction:

**Algorithm** — for each module node produced by task-002:

1. Locate all `.py` files in the module's directory path.
2. For each file, parse with `ast.parse()`.
3. Walk top-level `ast.FunctionDef`, `ast.AsyncFunctionDef`, `ast.ClassDef`, and
   `ast.Assign` / `ast.AnnAssign` nodes (direct children of the module body):
   - `FunctionDef` / `AsyncFunctionDef` → kind `"function"`.
   - `ClassDef` → kind `"class"`.
   - `Assign` where the target name is ALL_CAPS or the name has no type annotation
     that references a mutable type → kind `"constant"`. Otherwise kind `"variable"`.
4. Determine visibility: name starts with `_` → `"private"`; otherwise `"public"`.
5. Build `signature` for functions:
   - Format: `"(param: Type, ...) -> ReturnType"` using `ast.unparse()` on annotation
     nodes where present; omit annotation where absent (just use the parameter name).
   - If no parameters and no return annotation, use `"()"`.
6. For constants/variables, `signature` is `null`.
7. Collect all symbol entries for the module into a list and set `symbols` on the
   node dict.

**Scenarios from spec:**

- `def process_order()` → kind `"function"`, visibility `"public"`, signature `"()"`
  (or with params/annotations if present).
- `def _validate_input()` → kind `"function"`, visibility `"private"`.
- Class `PaymentProcessor(BaseProcessor)` → kind `"class"`, visibility `"public"`.
- `MAX_RETRY = 3` (ALL_CAPS) → kind `"constant"`, visibility `"public"`.

**Edge cases:**
- Files that fail to parse (syntax errors): log a warning and skip that file; do not
  raise an exception for the whole module.
- Modules with no discoverable symbols: emit `"symbols": []`.
- `__all__` is NOT used to determine visibility — the leading-underscore convention
  is the sole rule.

**Extraction cost constraint** (from spec): symbol table extraction MUST use only
single-file AST parsing. No cross-file resolution. No imports are followed.

Use only Python standard library (`ast`, `pathlib`, etc.). No external dependencies.

**Output**: the node list from task-002, with `symbols` populated on each module node.
