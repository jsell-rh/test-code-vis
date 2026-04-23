---
id: task-011
title: "Godot: size encoding (complexity → volume scale)"
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-008]
round: 0
branch: null
pr: null
---

## Goal

Ensure that volume sizes are proportional to complexity metrics so that larger modules are visually larger in the scene.

## Scope

- Read the `size` field from each node (already computed by the extractor's layout stage)
- Apply a linear (or log-linear) scaling function that maps the `size` value to a Godot mesh scale, with a defined minimum size so no node is invisible and a maximum size so the scene remains navigable
- Verify that relative sizes are visually proportional: a module with 2x the LOC should appear as a visually larger volume than a module with 1x LOC
- The scaling function should be a named constant or configurable parameter, not a magic number

## Acceptance

- Two kartograph modules with significantly different LOC counts render at noticeably different sizes
