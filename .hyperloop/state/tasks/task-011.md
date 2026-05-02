---
id: task-011
title: Implement Godot scene graph JSON loader
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-006, task-007]
round: 0
branch: null
pr: null
pr_title: "feat(godot): implement scene graph JSON loader"
pr_description: |
  ## What and Why

  The Godot application's entry point for all structural data. Reads the JSON scene
  graph file written by the extractor and instantiates in-memory data structures
  (GDScript Dictionaries and Arrays) that all rendering scripts consume. Nothing
  in the Godot side works until this loader exists and produces correct output.

  ## Spec Requirements Satisfied

  `specs/extraction/scene-graph-schema.spec.md` — all requirements on the consumer
  side: the loader must correctly read `nodes`, `edges`, `metadata`, and `clusters`
  with all their required fields.

  ## Key Design Decisions

  - Implemented as a GDScript autoload singleton (`SceneGraphLoader`) so that all
    rendering nodes can access the parsed data without passing it through the scene
    tree manually.
  - The loader reads the JSON file at a configurable path (default:
    `res://scene_graph.json` or a user-provided path via the project settings).
  - Validates that the four top-level keys are present; logs an error and returns
    early if any are missing.
  - Does NOT validate every field of every node/edge — full schema validation is
    deferred. The loader trusts the extractor output.
  - Exposes typed accessors: `get_nodes() -> Array`, `get_edges() -> Array`,
    `get_clusters() -> Array`, `get_metadata() -> Dictionary`.

  ## Files / Areas Affected

  - `godot/autoload/scene_graph_loader.gd` — new singleton loader script
  - `godot/project.godot` — register the autoload
  - `godot/tests/test_scene_graph_loader.gd` — GDScript unit tests (using the
    project's test framework) covering:
    - valid JSON with all four keys loads successfully
    - missing top-level key triggers error and returns empty state
    - `get_nodes()` returns correct count and field values
    - `get_clusters()` returns empty array when `clusters` is `[]`

  ## How to Verify

  1. Run the extractor on `~/code/kartograph` to produce `scene_graph.json`.
  2. Open the Godot project; confirm no script errors on launch.
  3. From a debug console or test scene, call
     `SceneGraphLoader.get_nodes().size()` and verify it equals the number of
     nodes in the JSON.
  4. Run `godot --headless --script tests/test_scene_graph_loader.gd` and
     confirm all tests pass.

  ## Caveats / Follow-up

  The loader does not yet trigger rendering — it only populates data structures.
  The Container renderer (task-012) and Edge renderer (task-013) are the first
  consumers of the loaded data.
---
