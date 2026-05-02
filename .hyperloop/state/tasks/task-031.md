---
id: task-031
title: Implement type topology extraction
spec_ref: null
status: closed
phase: null
deps:
- task-007
round: 0
branch: null
pr: null
pr_title: 'feat(extractor): implement type topology extraction (inheritance and has-a
  edges)'
pr_description: "## What and Why\n\nAdds a type topology extraction pass to the Python\
  \ extractor. This pass analyzes\nclass declarations in the AST to produce two categories\
  \ of type relationships:\n\n- **Inheritance** (`inherits`): `class Foo(Bar)` → edge\
  \ `Foo -> Bar`\n- **Composition** (`has_a`): a field or attribute typed as another\
  \ class\n  → edge from owner class to field's type\n\nThese edges are written into\
  \ the scene graph's `edges` array alongside the\nexisting import-based edges produced\
  \ by task-007. The Edge renderer (task-013)\nalready specifies that edge type is\
  \ encoded by line style (\"dotted for\ninheritance\"). Without this extraction pass,\
  \ the renderer has no inheritance\nedges to draw, so the line-style distinction\
  \ has no effect.\n\nType relationships give the viewer structural information that\
  \ import edges do\nnot capture: two modules may not import each other directly,\
  \ but their classes\nmay be linked by a shared type hierarchy that is architecturally\
  \ significant.\n\n## Spec Requirements Satisfied\n\n`specs/core/visual-primitives.spec.md`\
  \ — Requirement: Type Topology Extraction\n\n- Inheritance edge: `class PaymentProcessor(BaseProcessor)`\
  \ produces\n  `{ source: \"PaymentProcessor\", target: \"BaseProcessor\", type:\
  \ \"inherits\" }`.\n- Composition edge: `class Order` with a field typed `PaymentInfo`\
  \ produces\n  `{ source: \"Order\", target: \"PaymentInfo\", type: \"has_a\" }`.\n\
  - Extraction requires only AST parsing of class declarations, field types, and\n\
  \  base classes — no type inference or whole-program flow analysis.\n\n## Key Design\
  \ Decisions\n\n- **Inheritance** is read directly from `ast.ClassDef.bases`. Each\
  \ base that\n  resolves to a known class in the codebase produces an `inherits`\
  \ edge.\n  Bases that are external (stdlib, third-party) are recorded but marked\n\
  \  `external: true` and suppressed from default rendering.\n- **Composition** is\
  \ detected from class-body `ast.AnnAssign` nodes\n  (annotated attributes: `foo:\
  \ Bar`). Unannotated assignments are not analyzed\n  (consistent with the spec's\
  \ \"no type inference\" constraint).\n- Source and target IDs use the same node\
  \ IDs as the rest of the scene graph\n  (module-qualified class names, e.g. `\"\
  iam.domain.Order\"`).\n- Type topology edges are a new semantic category in the\
  \ scene graph; they are\n  NOT merged with import edges. The `type` field distinguishes\
  \ them.\n- If a referenced class is not found in the scene graph (e.g. it is from\
  \ an\n  external library), the edge is emitted with `external: true` and omitted\n\
  \  from default rendering (consistent with ubiquitous-dependency suppression).\n\
  \n## Schema Extension\n\nAdds new edge objects to the existing `edges` array established\
  \ by task-007:\n\n```json\n{ \"source\": \"iam.domain.PaymentProcessor\", \"target\"\
  : \"iam.domain.BaseProcessor\", \"type\": \"inherits\" }\n{ \"source\": \"iam.domain.Order\"\
  , \"target\": \"iam.domain.PaymentInfo\", \"type\": \"has_a\" }\n```\n\nNo new top-level\
  \ keys are added to the scene graph. The `type` field values\n`\"inherits\"` and\
  \ `\"has_a\"` are new valid values alongside the existing\n`\"internal\"`, `\"cross_context\"\
  `, and `\"aggregate\"`.\n\n## Files / Areas Affected\n\n- `extractor/passes/type_topology.py`\
  \ — new extraction pass; walks ASTs for\n  class declarations, collects base classes\
  \ and annotated field types, emits\n  edges\n- `extractor/pipeline.py` — adds `type_topology`\
  \ pass after `module_graph`;\n  appends its edges to the scene graph edge list before\
  \ serialization\n- `tests/test_type_topology.py` — unit tests covering:\n  - single-level\
  \ inheritance produces one `inherits` edge\n  - multi-base inheritance produces\
  \ one edge per base\n  - annotated field produces `has_a` edge\n  - unannotated\
  \ field produces no edge\n  - external base class produces edge with `external:\
  \ true`\n  - class with no bases and no annotated fields produces no edges\n\n##\
  \ How to Verify\n\n1. Run the extractor on `~/code/kartograph`.\n2. Open the generated\
  \ JSON; search for `\"type\": \"inherits\"` — confirm edges\n   appear for known\
  \ inheritance relationships in kartograph.\n3. Search for `\"type\": \"has_a\"`\
  \ — confirm composition edges appear for\n   annotated fields.\n4. Run `pytest tests/test_type_topology.py`\
  \ — all tests green.\n5. Load the scene graph in Godot (task-013); inheritance edges\
  \ should render\n   with dotted line style (as specified in the Edge primitive renderer).\n\
  \n## Caveats / Follow-up\n\n- Only annotated class attributes (`foo: Bar`) are analyzed.\
  \ Properties\n  (`@property` with return type hint) are a follow-up.\n- Dynamic\
  \ attribute assignment (`self.foo = Bar()`) is not captured — consistent\n  with\
  \ the spec's AST-only, no-inference constraint.\n- The Edge renderer (task-013)\
  \ must map `\"inherits\"` → dotted line style and\n  `\"has_a\"` → a distinct style.\
  \ This mapping should be verified during task-013\n  implementation."
---
