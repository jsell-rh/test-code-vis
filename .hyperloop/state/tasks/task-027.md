---
id: task-027
title: Implement ubiquitous dependency detection and edge ubiquitous flag
spec_ref: "specs/core/visual-primitives.spec.md@82d048ecde6d3209435ad2561c1384da93ba2cdd"
status: not-started
phase: null
deps: [task-003, task-007]
round: 0
branch: null
pr: null
pr_title: "feat(extractor): detect ubiquitous dependencies and annotate edges with ubiquitous flag"
pr_description: |
  ## What and Why

  This PR implements **Ubiquitous Dependency Detection** as defined in `specs/core/visual-primitives.spec.md`
  (Extraction Layer § Ubiquitous Dependency Detection). When every module imports `logging` or `os`,
  drawing those edges fills the scene graph with noise rather than signal — the visual equivalent
  of showing every wire in a circuit board when you want to understand the logical architecture.
  The power rail principle (borrowed from electronics schematics) suppresses these edges by default
  while acknowledging their existence.

  This extraction task produces the data; the Godot renderer (task-030) consumes it to implement
  the visual power rail notation.

  ## Spec Requirements Satisfied

  - After the module graph is built (task-003), compute the fraction of modules that import each
    dependency.
  - Any dependency imported by more than the configurable threshold (default: 50% of modules) is
    flagged as ubiquitous.
  - All edges TO a ubiquitous module gain `"ubiquitous": true` in the scene graph JSON.
  - The threshold percentage and the list of flagged ubiquitous modules are recorded in the
    extraction `metadata` object so the renderer knows what was suppressed and why.

  ## Schema Changes

  1. Each edge gains an optional boolean field:
     ```json
     { "source": "iam.application", "target": "logging", "type": "internal",
       "weight": 1, "ubiquitous": true }
     ```
     Edges to non-ubiquitous modules omit the field (or carry `"ubiquitous": false`).

  2. The `metadata` object gains a `ubiquitous_deps` section:
     ```json
     "ubiquitous_deps": {
       "threshold_pct": 50,
       "flagged": ["logging", "os", "typing"]
     }
     ```

  ## Files / Areas Affected

  - `extractor/` — post-processing step after module graph extraction; iterates over edges,
    counts target in-degree, computes fraction of total modules, flags threshold crossers.
  - The edge TypedDict / dataclass gains an optional `ubiquitous` boolean field.
  - The metadata TypedDict gains `ubiquitous_deps`.
  - Scene graph JSON output changes: flagged edges carry `"ubiquitous": true`.

  ## How to Verify

  1. Run the extractor against kartograph.
  2. Inspect `scene_graph.json` metadata: `ubiquitous_deps.flagged` should contain `logging`
     (or similar stdlib module) if kartograph uses it widely.
  3. Inspect edges to flagged modules: confirm `"ubiquitous": true` is present.
  4. Add a regression test: synthetic graph where module X is imported by 6 of 10 modules
     → X is flagged ubiquitous (60% > 50% threshold).
  5. Test threshold configurability: pass `--ubiquitous-threshold 70` and confirm 60% no
     longer flags X.
  6. Full extractor test suite must still pass.

  ## Caveats / Follow-up

  - The visual suppression of ubiquitous edges (power rail notation) is a separate Godot task
    (task-030). This task only annotates the JSON; Godot hides them by default.
  - The 50% threshold default is configurable via CLI argument. The threshold used is always
    recorded in metadata so renderers and humans know what rule was applied.
  - Ubiquitous detection runs over ALL edge targets, including cross-context edges, not just
    stdlib. A first-party module imported by more than half of the codebase is also a candidate
    for power rail treatment.
---
