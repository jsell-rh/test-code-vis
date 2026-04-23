---
id: task-007
title: "Godot: JSON scene graph loader"
spec_ref: specs/prototype/godot-application.spec.md
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
---

## Goal

Implement the Godot 4 application's scene graph loader: read the JSON file at startup and make its data available to all rendering subsystems.

## Scope

- Set up the Godot 4 project in `godot/` with GDScript as the sole scripting language
- On application start, read a JSON scene graph file from a configurable path (default: sibling `scene_graph.json`)
- Parse the JSON into typed GDScript data structures: a list of node dicts and a list of edge dicts
- Expose the parsed data via an autoload singleton (e.g. `SceneData`) so rendering nodes can access it
- Handle file-not-found and parse errors with a clear on-screen error message rather than a silent crash
- Use a fixture JSON file (hand-crafted or from a dry-run of the extractor) to validate loading before the full extractor is ready

## Out of Scope

- Rendering any geometry — task-008 onward
- Camera setup — task-013
