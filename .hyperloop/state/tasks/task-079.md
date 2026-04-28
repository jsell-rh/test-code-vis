---
id: task-079
title: Extractor — type topology extraction
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-076, task-003]
round: 0
branch: null
pr: null
---

Implement type topology extraction in the Python extractor: parse class definitions
to discover inheritance and composition relationships and emit them as edges with the
new `inherits` and `has_a` types defined in task-076.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Type Topology Extraction
("The extractor MUST produce the graph of type relationships: inheritance, implementation,
and composition (has-a). It does NOT require type inference or flow analysis"):

**Algorithm** — for each `.py` file in the codebase:

1. Parse with `ast.parse()`.
2. Walk `ast.ClassDef` nodes.

**Inheritance edges** (`inherits`):
3. For each `ClassDef`, inspect `bases` (the list of base class expressions):
   - For each base expression, extract the name(s) using `ast.unparse()`.
   - Attempt to resolve the base name to a known node id (using the module's import
     map from task-003 as a resolution hint).
   - If resolved: emit `{ "source": <class_node_id>, "target": <base_node_id>,
     "type": "inherits" }`.
   - If unresolved (base is in stdlib, third-party, or cannot be matched): skip
     (do not emit an edge with a null target for `inherits`).

**Composition edges** (`has_a`):
4. Within each `ClassDef`, inspect `ast.AnnAssign` nodes in the class body (annotated
   assignments like `self.field: SomeType = ...`):
   - Extract the annotation type name using `ast.unparse()`.
   - Attempt to resolve to a known node id as above.
   - If resolved: emit `{ "source": <class_node_id>, "target": <type_node_id>,
     "type": "has_a" }`.
   - If unresolved: skip.

**Node id for class-level entities** — at this prototype stage, class-level edges use
the MODULE node id as both source and target (i.e. `PaymentProcessor` in
`iam.domain` contributes an `inherits` edge from `iam.domain` to the target module
node id). Full class-level node granularity is deferred; the module-level aggregation
is sufficient for prototype rendering.

**Deduplication** — if multiple classes in the same module inherit from the same
target module, emit only ONE `inherits` edge between those modules. If multiple
classes in the same module have `has_a` references to the same target, emit only
ONE `has_a` edge.

**Edge cases:**
- Files that fail to parse: log warning, skip.
- Classes with no base classes: no `inherits` edge emitted.
- `object` as base class: skip (do not emit edges to the built-in `object`).

Use only Python standard library (`ast`, `pathlib`). No external dependencies.

**Output**: a list of edge dicts with `type: "inherits"` or `type: "has_a"`,
to be merged into the main edge list by task-085.
