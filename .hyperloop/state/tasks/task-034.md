---
id: task-034
title: Implement type topology extraction (inheritance, composition, has-a edges)
spec_ref: specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd
status: in_progress
phase: merge
deps:
- task-006
round: 3
branch: hyperloop/task-034
pr: https://github.com/jsell-rh/test-code-vis/pull/236
pr_title: 'feat(extractor): implement type topology extraction (inheritance, composition,
  has-a)'
pr_description: "## What and Why\n\nAdds a type topology extraction pass to the Python\
  \ extractor. This pass analyzes\nclass declarations in the AST to produce the directed\
  \ graph of type relationships:\n\n- **Inheritance** (`inherits`): class `PaymentProcessor`\
  \ extends `BaseProcessor`\n  → edge `PaymentProcessor -> BaseProcessor` with type\
  \ `inherits`\n- **Composition** (`has_a`): class `Order` has a field of type `PaymentInfo`\n\
  \  → edge `Order -> PaymentInfo` with type `has_a`\n- **Implementation** (`implements`):\
  \ class implements a Protocol or ABC\n  → edge with type `implements`\n\nWithout\
  \ this pass, the scene graph has no record of how types relate to each\nother. The\
  \ Edge renderer (task-013) already handles edge type distinctions by\nline style\
  \ (solid/dashed/dotted), but needs actual type topology edges to draw.\nAt tier-2\
  \ LOD (near zoom), where individual classes are visible, type\nrelationships provide\
  \ essential structural context: inheritance chains reveal\nextension points, composition\
  \ relationships reveal object structure, and\nimplementation relationships reveal\
  \ polymorphic boundaries.\n\nThis is extraction-only work — AST parsing of class\
  \ declarations, base class\nlists, and field type annotations. No cross-file type\
  \ inference or flow analysis\nis required. Extraction cost is proportional to the\
  \ number of class declarations.\n\n## Spec Requirements Satisfied\n\n`specs/core/visual-primitives.spec.md`\
  \ — Requirement: Type Topology Extraction\n\n- `PaymentProcessor(BaseProcessor)`\
  \ → edge\n  `{ source: \"iam.domain.PaymentProcessor\", target: \"iam.domain.BaseProcessor\"\
  , type: \"inherits\" }`\n- Class `Order` with field `payment: PaymentInfo` → edge\n\
  \  `{ source: \"iam.domain.Order\", target: \"iam.domain.PaymentInfo\", type: \"\
  has_a\" }`\n- Only AST parsing of class declarations, field types, and base classes\
  \ — no\n  type inference or flow analysis.\n- Dunder methods and class variables\
  \ without type annotations are not emitted\n  as `has_a` edges (only explicitly\
  \ typed field annotations are used).\n\n## Key Design Decisions\n\n- **Inheritance\
  \ detection**: walk `ast.ClassDef.bases` for each class node.\n  Base class names\
  \ are resolved against the module's import graph to get\n  fully qualified IDs.\
  \ If a base cannot be resolved (external library class),\n  the edge is emitted\
  \ with `external: true` and the unresolved name as the\n  target string.\n- **Composition\
  \ detection**: walk `ast.AnnAssign` nodes at class body scope\n  to find annotated\
  \ field declarations (`field: Type`). The type annotation is\n  parsed to extract\
  \ the type name(s), resolved via the import graph. Generic\n  types (e.g. `list[Order]`)\
  \ extract the inner type (`Order`).\n- **Implementation detection**: Python ABCs\
  \ and Protocols are treated as a\n  subcase of inheritance — any base class that\
  \ is a `Protocol` subclass or\n  `ABC` subclass emits an `implements` edge rather\
  \ than `inherits`. Detection\n  uses the same base-class resolution path with a\
  \ known-ABC/Protocol list\n  seeded from common patterns.\n- **Edge deduplication**:\
  \ if class A inherits from B AND has a field of type B,\n  two edges are emitted\
  \ (one `inherits`, one `has_a`). These are semantically\n  distinct and both are\
  \ valid.\n- This pass runs after scope nesting extraction (task-002) so class node\
  \ IDs\n  are already established, and after module graph extraction (task-003) so\n\
  \  import resolution can use the existing cross-module map.\n\n## Schema Extension\n\
  \nAdds new edge objects to the existing `edges` array (established by task-007).\n\
  New edge type values:\n\n```json\n{ \"source\": \"iam.domain.PaymentProcessor\"\
  ,\n  \"target\": \"iam.domain.BaseProcessor\",\n  \"type\": \"inherits\" }\n\n{\
  \ \"source\": \"iam.domain.Order\",\n  \"target\": \"iam.domain.PaymentInfo\",\n\
  \  \"type\": \"has_a\" }\n\n{ \"source\": \"iam.domain.ConcreteRepo\",\n  \"target\"\
  : \"iam.domain.IRepository\",\n  \"type\": \"implements\" }\n\n{ \"source\": \"\
  iam.domain.SomeClass\",\n  \"target\": \"django.db.models.Model\",\n  \"type\":\
  \ \"inherits\",\n  \"external\": true }\n```\n\nThe `external: true` flag signals\
  \ that the target lives outside the extracted\ncodebase and should not be rendered\
  \ as a node — only the edge is emitted.\n\n## Files / Areas Affected\n\n- `extractor/passes/type_topology.py`\
  \ — new extraction pass; walks class\n  declarations, resolves base classes and\
  \ field type annotations, emits\n  typed edges\n- `extractor/pipeline.py` — adds\
  \ `type_topology` pass after `module_graph`\n  and `scope_nesting`; appends its\
  \ edges to the scene graph edge list before\n  serialization\n- `extractor/schema.py`\
  \ — adds `\"inherits\"`, `\"has_a\"`, `\"implements\"` to the\n  enumerated edge\
  \ `type` values; adds optional `\"external\": bool` field on edges\n- `tests/test_type_topology.py`\
  \ — unit tests covering:\n  - single inheritance produces `inherits` edge\n  - multiple\
  \ inheritance produces multiple `inherits` edges\n  - annotated field of a known\
  \ type produces `has_a` edge\n  - untyped field (`x = None`) does NOT produce `has_a`\
  \ edge\n  - generic field (`items: list[Order]`) produces `has_a` edge to `Order`\n\
  \  - class with no bases and no typed fields produces no edges\n  - external base\
  \ class produces edge with `external: true`\n\n## How to Verify\n\n1. Run the extractor\
  \ on `~/code/kartograph`.\n2. Open the generated JSON; search for `\"type\": \"\
  inherits\"` — confirm inheritance\n   chains appear for known kartograph class hierarchies.\n\
  3. Search for `\"type\": \"has_a\"` — confirm composition edges appear for classes\n\
  \   with typed field annotations.\n4. Run `pytest tests/test_type_topology.py` —\
  \ all tests green.\n5. Confirm that external base classes (e.g. from `pydantic`,\
  \ `sqlalchemy`) have\n   `\"external\": true` in their edge objects.\n\n## Caveats\
  \ / Follow-up\n\n- Resolution is AST-only: aliased imports (`from foo import Bar\
  \ as B`) and\n  dynamic base classes (`class Foo(get_base())`) may not resolve correctly.\n\
  \  Document known limitations.\n- `has_a` detection is limited to explicitly annotated\
  \ class-body fields.\n  Attributes assigned in `__init__` (e.g. `self.payment =\
  \ PaymentInfo()`)\n  are NOT captured — AST annotation pass only.\n- The Edge renderer\
  \ (task-013) renders `inherits` as dotted lines per the\n  visual-primitives spec.\
  \ This task populates the edges; the renderer\n  visualizes them at the appropriate\
  \ LOD tier.\n- Type topology edges are most useful at tier-2 LOD (near zoom) where\n\
  \  individual classes are visible. At tier-0/tier-1, they are suppressed\n  by the\
  \ LOD Shell (task-014)."
---
