---
id: task-008
title: Godot app — project setup and scene graph loading
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
pr_title: "feat(godot): project scaffold and JSON scene graph loader"
pr_description: |
  ## What and Why

  Establishes the Godot 4.6 project and implements the core loader that reads
  a JSON scene graph file and instantiates 3D node objects for each entry. This
  is the foundation every other Godot task builds on.

  The loader only needs the schema (task-001) to be defined — it can be
  developed and tested against the hand-crafted fixture from task-001 before
  the real extractor output is available.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:
  - **JSON Scene Graph Loading**: reads the JSON file at startup, iterates
    `nodes` and `edges` arrays, instantiates 3D objects, positions them at
    the coordinates in the JSON.
  - **Godot 4.6**: project uses Godot 4.6.x engine; all API calls use the
    4.6 API (e.g. `FileAccess.get_as_text()`, not deprecated methods).

  From `specs/prototype/nfr.spec.md`:
  - Desktop platform (Linux/Fedora), native application, GDScript only.

  ## Key Design Decisions

  - Project lives in `godot/` directory with a `project.godot` file targeting
    Godot 4.6.
  - `Main.gd` is the root autoload script. On `_ready()` it calls
    `SceneGraphLoader.load(path)`.
  - `SceneGraphLoader.gd` uses `FileAccess.open()` / `get_as_text()` to read
    the JSON, then `JSON.parse_string()` to deserialize. For each node entry
    it instantiates a generic `Node3D` (visualization comes in task-009).
  - The scene graph path is configurable via a project setting or a command-line
    `--scene-graph <path>` argument so it can be pointed at different extractions.
  - Uses the fixture from `schema/kartograph-fixture.json` for development
    testing until the extractor produces real output.

  ## Files Affected

  - `godot/project.godot`
  - `godot/scenes/Main.tscn`
  - `godot/scripts/Main.gd`
  - `godot/scripts/SceneGraphLoader.gd`
  - `godot/tests/test_loader.gd` — GUT or gdUnit4 test verifying node count
    after loading the fixture

  ## How to Verify

  ```bash
  godot --headless --path godot/ res://scenes/Main.tscn \
    -- --scene-graph ../../schema/kartograph-fixture.json
  # Should exit 0 and print the count of loaded nodes to stdout.
  ```

  Godot compile check: `bash .hyperloop/checks/godot-compile.sh`

  ## Caveats

  No visual rendering yet — nodes are invisible `Node3D` objects. task-009
  adds the mesh geometry. task-011 adds the camera. The scene will be a black
  window until those tasks are complete.
---
