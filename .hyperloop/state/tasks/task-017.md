---
id: task-017
title: 'Godot: aggregate flow pattern overlay (hot paths and bottlenecks)'
spec_ref: specs/visualization/data-flow.spec.md
status: not-started
phase: null
deps:
- task-015
round: 0
branch: null
pr: null
---

## What

Visualize aggregate flow patterns — high-traffic paths and bottleneck nodes — as a weight-encoded overlay on the structural geography. This is a SHOULD requirement; implement after task-016 is stable.

## Acceptance criteria

- The JSON scene graph may optionally carry per-edge and per-node traffic weight values (integers or floats). If absent, this feature is gracefully skipped.
- When aggregate flow data is present and the user activates aggregate mode, edge thickness or color saturation scales with traffic weight.
- Bottleneck nodes (high in-degree + high out-degree under load) are visually prominent (e.g. pulsing glow or distinct color).
- High-traffic paths stand out against low-traffic paths.
- The aggregate overlay is a separate mode from the single-path flow mode (task-015/016); both cannot be active simultaneously.

## Notes

- SHOULD priority — can be deferred if other tasks are higher value.
- Aggregate weight data is optional in the schema; the extractor does not need to be modified to unblock this task if data is supplied manually or via a test fixture.
