---
id: task-004
title: Extractor — complexity metrics (lines of code)
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-002]
round: 0
branch: null
pr: null
---

Compute a basic complexity metric (total lines of code) for each discovered node and attach
it to the node's metadata.

Covers:
- For each node, sum the lines of code across all `.py` files directly within that node's
  directory (non-recursive for modules; recursive for bounded contexts that have no sub-nodes
  of their own).
- Store the metric as `metrics.loc` (integer) on each node dict.
- This value will be used by task-005 to derive the `size` field for the schema.
- Metric computation must not require any external dependencies beyond the Python standard
  library.
