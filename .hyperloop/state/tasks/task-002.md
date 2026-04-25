---
id: task-002
title: Extractor — module discovery
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

Implement module discovery in the Python extractor: walk a target codebase and produce a
list of nodes (top-level bounded contexts and nested modules) conforming to the schema.

Covers:
- Recursively discover all Python packages under the target path.
- Identify top-level bounded contexts (e.g. iam, graph, management, query, shared_kernel,
  infrastructure in kartograph) and represent each as a node with `type: "bounded_context"`,
  `parent: null`.
- Discover nested layers/modules within each bounded context (e.g. domain, application,
  infrastructure, presentation) and represent each as a node with `type: "module"` and
  `parent` referencing the containing bounded context's id.
- Each node must have a unique `id` (dot-separated path, e.g. "iam.domain"), a human-readable
  `name`, and a `path` in metadata.
- Produce a flat list of node dicts; layout and size fields will be populated by later tasks.
