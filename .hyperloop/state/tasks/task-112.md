---
id: task-112
title: Extractor — class-level type topology (scope-nesting mode)
spec_ref: specs/core/visual-primitives.spec.md
status: not-started
phase: null
deps: [task-079, task-100]
round: 0
branch: null
pr: null
---

When `--scope-nesting` is active, emit `inherits` and `has_a` edges using
**class node IDs** as source and target, satisfying the spec's requirement for
class-to-class type topology granularity. Module-level topology (task-079)
continues to serve medium-LOD (tier-1) views; this task's edges serve tier-2
(near-LOD) rendering in task-109.

Covers `specs/core/visual-primitives.spec.md` — Requirement: Type Topology
Extraction, Scenarios: Inheritance chain ("GIVEN class `PaymentProcessor` extends
`BaseProcessor` THEN an inheritance edge is emitted from `PaymentProcessor` to
`BaseProcessor`") and Composition relationship ("GIVEN class `Order` has a field
of type `PaymentInfo` THEN a composition edge is emitted from `Order` to
`PaymentInfo`"):

task-079 implements type topology at **module** granularity, explicitly noting
"at this prototype stage, class-level edges use the MODULE node id as both source
and target — Full class-level node granularity is deferred." task-100 has now
emitted class nodes with dot-separated IDs into the scene graph (e.g.
`"iam.domain.PaymentProcessor"`, `"iam.domain.BaseProcessor"`). task-109 explicitly
expects `inherits` and `has_a` edges that connect **class nodes** to class nodes
at tier-2 LOD. Without this task, tier-2 type topology rendering is empty.

---

**Precondition** — this task only runs when `--scope-nesting` is active (i.e.,
after task-100 has emitted class nodes). When `--scope-nesting` is absent, skip
silently; do not error.

**Input** — the flat node list produced by task-100 (contains `class` nodes
alongside `module` and `bounded_context` nodes), and the import map from task-003
for cross-module name resolution.

---

**Algorithm** — for each **class node** (type `"class"`) emitted by task-100:

1. Locate the source file for this class from its id (e.g.
   `"iam.domain.PaymentProcessor"` → module `"iam.domain"` → its `.py` files).
   Retrieve the `ast.ClassDef` node matching this class name (reuse parsed ASTs
   from task-100 where cached).

**Inheritance edges (`inherits`):**

2. Inspect `ClassDef.bases` (the list of base class expressions):
   - For each base, extract the name using `ast.unparse()`.
   - Attempt to resolve the base name to a **class node id** in the node list:
     a. Search class nodes in the same bounded context whose `name` matches.
     b. If not found, try class nodes across the full node list (cross-context
        inheritance is possible).
     c. Use the import map (task-003) as a resolution hint for imported base names.
   - If resolved to a class node id: emit:
     ```json
     {
       "source": "iam.domain.PaymentProcessor",
       "target": "iam.domain.BaseProcessor",
       "type": "inherits"
     }
     ```
   - If unresolved (base is in stdlib — `object`, `Exception`, `BaseException`,
     `abc.ABC`, `abc.ABCMeta`, `enum.Enum`, `enum.IntEnum` — or is a third-party
     class): skip. Do NOT emit an edge with a null target for `inherits` (the
     schema forbids null targets on non-dynamic_call edges).

**Composition edges (`has_a`):**

3. Inspect annotated field assignments within the class body
   (`ast.AnnAssign` nodes that are direct children of `ClassDef.body`):
   - For assignments like `self.field: SomeType = ...` or bare class-level
     `field: SomeType`, extract the annotation type name using `ast.unparse()`.
   - Attempt to resolve the annotation type to a **class node id** in the node
     list using the same resolution strategy as step 2.
   - If resolved: emit:
     ```json
     {
       "source": "iam.domain.Order",
       "target": "iam.domain.PaymentInfo",
       "type": "has_a"
     }
     ```
   - If unresolved: skip.

4. Also inspect `__init__` method parameters with type annotations as an
   additional source of composition relationships (many Python classes receive
   their composed objects via `__init__` rather than class-body annotations):
   - Walk `ast.FunctionDef` named `__init__` within the class body.
   - For each parameter (excluding `self`) that has a type annotation, attempt
     to resolve the annotation to a class node id as above.
   - If resolved: emit a `has_a` edge with the same format as step 3.

**Deduplication** — if multiple bases, fields, or `__init__` parameters resolve
to the same target class, emit only ONE edge of each type (`inherits` or `has_a`)
between the same source/target pair.

---

**Deduplication vs. task-079** — task-079 produces module-level topology edges
(e.g. `"iam.domain" → "iam.domain"` — self-loop — or `"iam.domain" → "shared_kernel"`).
This task produces class-level edges (e.g. `"iam.domain.PaymentProcessor" →
`"iam.domain.BaseProcessor"`). Both coexist in the edge list; they are NOT
duplicates. Module-level edges are consumed at medium LOD; class-level edges are
consumed at near LOD (task-109). No deduplication between the two sets.

**Generic types** — for annotations like `List[Order]` or `Optional[PaymentInfo]`,
extract only the innermost concrete type name (`Order`, `PaymentInfo`) and resolve
that. Use simple string parsing (`annotation_str.split("[")[0].strip()` after
`ast.unparse()`), not full type inference.

**Files that fail to parse** — log a warning to stderr; skip without aborting.

---

**CLI flag** — this task's logic runs automatically when `--scope-nesting` is
active. Add a combined opt-out flag `--no-type-topology` (extending the flag
defined in task-085) that skips both task-079 and this task.

**Output writer integration** — this task produces a list of class-level edge
dicts (`inherits` and `has_a` with class node IDs). The output writer pipeline
(task-085) MUST be extended to call this function after task-079 and append its
results to the edge list before serialisation. Add a new pipeline step:
"Class-level type topology (task-112) — runs when `--scope-nesting` is active."

Use only Python standard library (`ast`, `pathlib`). No external dependencies.

**Output**: a list of edge dicts with `type: "inherits"` or `type: "has_a"`,
using class node IDs as source and target, to be merged into the main edge list
by the output writer.
