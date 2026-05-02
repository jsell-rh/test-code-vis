---
id: task-008
title: Godot app — project setup and scene graph loading
spec_ref: specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed
status: not_started
phase: null
deps:
- task-001
round: 0
branch: null
pr: null
pr_title: 'feat(godot): project scaffold and JSON scene graph loader'
pr_description: "## What and Why\n\nEstablishes the Godot 4.6 project and implements\
  \ the core loader that reads\na JSON scene graph file and instantiates 3D node objects\
  \ for each entry. This\nis the foundation every other Godot task builds on.\n\n\
  The loader only needs the schema (task-001) to be defined — it can be\ndeveloped\
  \ and tested against the hand-crafted fixture from task-001 before\nthe real extractor\
  \ output is available.\n\n## Spec Requirements Satisfied\n\nFrom `specs/prototype/godot-application.spec.md`:\n\
  - **JSON Scene Graph Loading**: reads the JSON file at startup, iterates\n  `nodes`\
  \ and `edges` arrays, instantiates 3D objects, positions them at\n  the coordinates\
  \ in the JSON.\n- **Godot 4.6**: project uses Godot 4.6.x engine; all API calls\
  \ use the\n  4.6 API (e.g. `FileAccess.get_as_text()`, not deprecated methods).\n\
  \nFrom `specs/prototype/nfr.spec.md`:\n- Desktop platform (Linux/Fedora), native\
  \ application, GDScript only.\n\n## Key Design Decisions\n\n- Project lives in `godot/`\
  \ directory with a `project.godot` file targeting\n  Godot 4.6.\n- `Main.gd` is\
  \ the root autoload script. On `_ready()` it calls\n  `SceneGraphLoader.load(path)`.\n\
  - `SceneGraphLoader.gd` uses `FileAccess.open()` / `get_as_text()` to read\n  the\
  \ JSON, then `JSON.parse_string()` to deserialize. For each node entry\n  it instantiates\
  \ a generic `Node3D` (visualization comes in task-009).\n- The scene graph path\
  \ is configurable via a project setting or a command-line\n  `--scene-graph <path>`\
  \ argument so it can be pointed at different extractions.\n- Uses the fixture from\
  \ `schema/kartograph-fixture.json` for development\n  testing until the extractor\
  \ produces real output.\n\n## Files Affected\n\n- `godot/project.godot`\n- `godot/scenes/Main.tscn`\n\
  - `godot/scripts/Main.gd`\n- `godot/scripts/SceneGraphLoader.gd`\n- `godot/tests/test_loader.gd`\
  \ — GUT or gdUnit4 test verifying node count\n  after loading the fixture\n\n##\
  \ How to Verify\n\n```bash\ngodot --headless --path godot/ res://scenes/Main.tscn\
  \ \\\n  -- --scene-graph ../../schema/kartograph-fixture.json\n# Should exit 0 and\
  \ print the count of loaded nodes to stdout.\n```\n\nGodot compile check: `bash\
  \ .hyperloop/checks/godot-compile.sh`\n\n## Caveats\n\nNo visual rendering yet —\
  \ nodes are invisible `Node3D` objects. task-009\nadds the mesh geometry. task-011\
  \ adds the camera. The scene will be a black\nwindow until those tasks are complete."
---
