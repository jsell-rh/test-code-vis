---
id: task-004
title: "Extractor: LOC complexity metrics per module"
spec_ref: specs/extraction/code-extraction.spec.md
status: not-started
phase: null
deps: [task-002]
round: 0
branch: null
pr: null
---

## Goal

Implement the complexity metrics stage: compute lines of code (LOC) for each discovered module and attach the metric to its node data.

## Scope

- For each node produced by task-002, sum the non-blank, non-comment lines across all `.py` files within that module's directory (recursively)
- Store the result as a `loc` field in the node's `metrics` object (or directly as `size` if that maps 1:1 per schema)
- The metric must be available for task-005 (layout) to use when computing node sizes and coupling distances

## Out of Scope

- Other metrics (cyclomatic complexity, etc.) — not required by the spec
- Layout — task-005
- JSON output — task-006
