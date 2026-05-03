---
id: task-009
title: Godot JSON scene graph loader
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: "feat(godot): load JSON scene graph file and parse into scene data structures"
pr_description: |
  ## What and Why

  The Godot application's first responsibility is reading the JSON scene graph produced by
  the extractor and making its data available to subsequent rendering nodes. This task
  establishes the loader and the shared data model (GDScript Dictionaries/Arrays) that all
  other Godot tasks consume. It is the Godot-side entry point and must be done before any
  rendering work can begin.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:

  - **JSON Scene Graph Loading**: reads JSON file, generates 3D volumes and connections
    (this task covers the "reads the JSON file" portion; volume and connection generation
    are in subsequent tasks)
  - **Godot 4.6**: uses `FileAccess.get_as_text()` (Godot 4.6 API, not deprecated
    `read_as_text()`)

  ## Key Design Decisions

  - Loader is a GDScript autoload singleton (`SceneGraphLoader`) that exposes:
    - `load_from_file(path: String) -> Dictionary` — returns parsed scene graph dict
    - `nodes() -> Array[Dictionary]`
    - `edges() -> Array[Dictionary]`
    - `clusters() -> Array[Dictionary]`
    - `metadata() -> Dictionary`
  - JSON is parsed with `JSON.parse_string()` (Godot 4.6).
  - On parse error, prints an error message and returns an empty graph (graceful degradation).
  - Scene graph file path is configurable via a Godot Project Setting or an `@export`
    variable on the main scene root — not hardcoded.
  - No rendering logic in this file; it is a pure data loader.

  ## Files Affected

  - `godot/autoload/SceneGraphLoader.gd` — new file: loader singleton
  - `godot/tests/test_scene_graph_loader.gd` — GUT tests: valid JSON loads correctly;
    malformed JSON does not crash; missing file returns empty graph

  ## Verification

  1. GUT tests pass (`check-godot-no-script-errors.sh`).
  2. Application starts without script errors when given the kartograph `scene_graph.json`.
  3. `SceneGraphLoader.nodes()` returns a non-empty Array after loading.

  ## Caveats

  This task does not validate the JSON against the schema at runtime — it trusts the
  extractor produced valid output. Schema validation can be added in a later hardening task.
---
