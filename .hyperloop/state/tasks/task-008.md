---
id: task-008
title: JSON output writer and extractor CLI entry point
spec_ref: "specs/extraction/code-extraction.spec.md@045851f001a15374395b876d4cf9ccfc1a8fad2b"
status: not-started
phase: null
deps: [task-002, task-003, task-004, task-005, task-006, task-007]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): wire pipeline stages into CLI and write JSON scene graph"
pr_description: |
  ## What and Why

  Wires together all extractor pipeline stages (discovery, dependency, layout, independence,
  aggregate edges, clusters) into a single CLI entry point that accepts a codebase path,
  runs all stages in sequence, and writes the complete JSON scene graph file. This is the
  deliverable the Godot application loads.

  ## Spec Requirements Satisfied

  From `specs/extraction/code-extraction.spec.md`:

  - **JSON Scene Graph Output**: writes JSON with `nodes`, `edges`, `metadata`, `clusters`
  - Output is consumable by Godot without transformation
  - Spec Extraction is **not** implemented (excluded per prototype-scope.spec.md § Not In Scope)

  From `specs/extraction/scene-graph-schema.spec.md`:

  - **Metadata**: `source_path` and `extracted_at` timestamp in metadata object

  ## Key Design Decisions

  - Entry point: `python -m extractor <codebase_path> [--output <path>]`
    Default output: `scene_graph.json` in the current directory.
  - Pipeline sequence:
    1. `discovery.discover_modules(root)` → nodes with LOC
    2. `dependency.extract_dependencies(nodes, root)` → edges
    3. `independence.assign_independence_groups(nodes, edges)` → annotated nodes
    4. `aggregate.compute_aggregate_edges(nodes, edges)` → full edge list
    5. `clusters.compute_clusters(nodes, edges)` → clusters list
    6. `layout.compute_layout(nodes, edges)` → nodes with positions
    7. Assemble `SceneGraph` dict and write JSON with `json.dump(indent=2)`.
  - `metadata.extracted_at` is an ISO-8601 UTC timestamp string.
  - The output JSON is pretty-printed (indent=2) for human readability during debugging.
  - Exit code 0 on success, 1 on any unhandled exception (with error message to stderr).

  ## Files Affected

  - `extractor/__main__.py` — new file: CLI argument parsing and pipeline orchestration
  - `extractor/tests/test_cli.py` — integration test: run against kartograph path, assert
    output JSON is valid, contains expected top-level keys, and all node ids are non-empty
  - `extractor/tests/test_pipeline_wiring.py` — ensures all pipeline stages are called
    (import-time check that no stage is accidentally omitted)

  ## Verification

  1. `python -m extractor ~/code/kartograph --output /tmp/scene_graph.json` exits 0.
  2. Output JSON has top-level keys: `nodes`, `edges`, `metadata`, `clusters`.
  3. `nodes` contains entries for `iam`, `graph`, `management`, `query`, `shared_kernel`,
     `infrastructure`.
  4. All nodes have non-null `position` with numeric `x`, `y`, `z`.
  5. `metadata.source_path` equals the resolved input path.

  ## Caveats

  This task completes the extraction pipeline. Godot tasks (task-009 onward) can now
  be developed against a real `scene_graph.json`. The check script
  `check-pipeline-wiring.sh` should be run as part of CI for this task.
---
