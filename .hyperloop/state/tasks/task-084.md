---
id: task-084
title: Extractor — badge computation from analysis results
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-077, task-078, task-079, task-080, task-082, task-083]
round: 0
branch: null
pr: null
---

Implement badge computation in the Python extractor: combine the results of symbol
table, type topology, call graph, structural significance, and ubiquitous dependency
analysis to produce a `badges` array on each node, conforming to the vocabulary
defined in task-077.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Badge Primitive
("A small glyph docked to a Node indicating an aspect or cross-cutting property.
New Badge types can be added to the vocabulary by extending the extractor"):

**Algorithm** — for each module node, compute which badges apply:

**`io` badge:**
- Apply if the module's `symbols` (task-078) contain any function whose name or body
  (via the call graph from task-080) references known IO modules:
  `{"os", "pathlib", "io", "open", "socket", "http", "urllib", "requests",
    "aiohttp", "httpx", "boto3", "sqlalchemy", "sqlite3", "psycopg2", "subprocess"}`.
- Heuristic: if any `direct_call` edge from this module targets a module whose name
  matches one of the known IO patterns, apply `io`.
- Also apply if any symbol name in the module starts with `open_`, `read_`, `write_`,
  `fetch_`, `download_`, `upload_`, `send_`, `receive_`, or `connect_`.

**`async` badge:**
- Apply if the module's `symbols` (task-078) contain any entry with `kind: "function"`
  and the symbol name contains `async` in it OR if parsing the module reveals
  `ast.AsyncFunctionDef` nodes at top level.
- Implementation: during symbol table extraction (task-078), record `is_async: true`
  on `AsyncFunctionDef` symbols; the badge computation checks for any symbol with
  `is_async: true`. (Update task-078's symbol schema accordingly — add optional
  `is_async: bool` to the symbol entry.)

**`stateful` badge:**
- Apply if the module contains class-level or module-level mutable assignments:
  any `ast.Assign` at module body scope where the target is NOT ALL_CAPS (i.e. not
  a constant) — indicating mutable state.
- Also apply to any class node that has `has_a` edges (task-079) to mutable
  container types (list, dict, set — detected by annotation name).

**`error_handling` badge:**
- Apply if any function in the module contains an `ast.Try` node.
- During symbol table extraction (task-078), record `has_try: bool` on each symbol;
  the badge computation checks for any symbol with `has_try: true`. (Update task-078.)

**`test` badge:**
- Apply if the module node's `id` contains `"test"` (case-insensitive) OR if the
  module's path includes a directory named `tests`, `test`, `spec`, or `__tests__`.

**`entry_point` badge:**
- Apply if the module node's `significance.in_degree == 0` AND
  `significance.peripheral == false` (a node that initiates dependencies but no
  other module in the application depends on it).
- Requires significance data from task-082.

**`deprecated` badge:**
- Apply if any symbol in the module carries a `@deprecated` decorator (detected by
  decorator name matching `"deprecated"` case-insensitively) OR if a `# deprecated`
  or `# DEPRECATED` comment appears at the top of any source file.

**`pure` badge:**
- Apply if NONE of the following badges are set: `io`, `async`, `stateful`,
  `error_handling`. A module is heuristically pure if it has no IO, no async code,
  no mutable state, and no exception handling.
- Only applied to module nodes that have at least one public function symbol.

**Badge ordering** — write badges in vocabulary order (as defined in task-077):
`pure`, `io`, `async`, `stateful`, `error_handling`, `test`, `entry_point`, `deprecated`.
Omit badges that do not apply. An empty `badges: []` is valid.

**Output**: the same node list with `badges` arrays populated on every module node.

Use only Python standard library. No external dependencies.
