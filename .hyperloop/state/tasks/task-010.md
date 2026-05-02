---
id: task-010
title: Implement extraction metadata
spec_ref: "specs/extraction/scene-graph-schema.spec.md@4ea7e33731b8eb0cd47c19012a9f7b5774420e21"
status: not-started
phase: null
deps: [task-001]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): implement extraction metadata in scene graph"
pr_description: |
  ## What and Why

  Writes the `metadata` object to the scene graph JSON, recording the provenance
  of the extraction: which codebase was analyzed and when. This allows the Godot
  application to display extraction information to the user and enables debugging
  when the scene graph is stale or from an unexpected source.

  ## Spec Requirements Satisfied

  `specs/extraction/scene-graph-schema.spec.md` — Requirement: Metadata

  The `metadata` object MUST contain:
  - `source` — absolute or relative path to the analyzed codebase
  - `extracted_at` — ISO 8601 timestamp of when extraction was run

  ## Key Design Decisions

  - `extracted_at` uses `datetime.utcnow().isoformat() + "Z"` for a
    deterministic, timezone-unambiguous format.
  - `source` is the path passed to the extractor CLI, normalized to an absolute
    path via `os.path.abspath()`.
  - The metadata object is intentionally minimal — additional fields (extractor
    version, kartograph commit hash) are deferred to future phases.

  ## Files / Areas Affected

  - `extractor/serialization.py` — new `build_metadata(source_path) -> dict`
    function (alongside `nodes_to_json()` and `edges_to_json()`)
  - `extractor/tests/test_serialization_metadata.py` — unit tests covering:
    - `source` is an absolute path
    - `extracted_at` is a valid ISO 8601 string ending in `Z`
    - metadata has exactly two keys (`source`, `extracted_at`)

  ## How to Verify

  1. Run `pytest extractor/tests/test_serialization_metadata.py`.
  2. Run the extractor on `~/code/kartograph` and inspect the `metadata` field
     in the output JSON; confirm both fields are present and correctly typed.

  ## Caveats / Follow-up

  The Godot loader (task-011) reads `metadata` but does not currently display it
  in the UI. Future tasks may surface it in a HUD overlay.
---
