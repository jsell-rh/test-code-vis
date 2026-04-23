---
id: task-005
title: "Extractor: pre-computed layout algorithm"
spec_ref: specs/extraction/scene-graph-schema.spec.md
status: not-started
phase: null
deps: [task-002, task-003, task-004]
round: 0
branch: null
pr: null
---

## Goal

Implement the layout algorithm that assigns x/y/z coordinates to every node before the JSON is written. The Godot application must render nodes at these coordinates without recomputing layout.

## Scope

- Take the node list (task-002 + task-004 metrics) and edge list (task-003) as input
- Run a layout algorithm (e.g. force-directed / spring model) that positions nodes so that tightly coupled nodes are closer together
- Top-level bounded context nodes are positioned in the global coordinate space
- Child module nodes are positioned relative to their parent's position and within the parent's spatial bounds
- Assign the resulting `x`, `y`, `z` values to each node's `position` field
- Assign a `size` value to each node derived from its LOC metric (with a defined min/max range to keep the scene navigable)

## Constraints (from NFR)

- Must complete in a reasonable time for kartograph's scale (~50 modules, ~100 files)
- Stdlib only; no heavy graph libraries required (a simple iterative spring model is acceptable)

## Out of Scope

- JSON file writing — task-006
