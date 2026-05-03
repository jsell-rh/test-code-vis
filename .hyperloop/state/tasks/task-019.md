---
id: task-019
title: Godot 4.6 project configuration and API compliance
spec_ref: "specs/prototype/godot-application.spec.md@abc16ac365e3e44b8c942e9623dc64cd1cba7aed"
status: not-started
phase: null
deps: []
round: 0
branch: null
pr: null
pr_title: "chore(godot): configure project for Godot 4.6.x and audit GDScript API usage"
pr_description: |
  ## What and Why

  The godot-application spec now explicitly mandates Godot 4.6.x as the engine version
  and requires that every GDScript API call be valid for the Godot 4.6 API (e.g.
  `FileAccess.get_as_text()` rather than the deprecated `read_as_text()`). Without a
  locked engine version and a clean API audit, later implementers may unknowingly write
  code for the wrong API, causing runtime errors that are invisible until the app is
  launched in the correct Godot build.

  This task establishes the project configuration baseline and produces an API compliance
  report so all subsequent Godot tasks can target a known, tested version.

  ## Spec Requirements Satisfied

  From `specs/prototype/godot-application.spec.md`:

  - **Godot 4.6**: project MUST be built using Godot 4.6.x with GDScript; all API calls
    MUST be compatible with the Godot 4.6 API.

  ## Key Design Decisions

  - Ensure `godot/project.godot` sets `config/features` to include "4.6" and
    `config_version = 5`.
  - Audit all existing `.gd` files in `godot/` for deprecated pre-4.6 API patterns:
    - `read_as_text()` → `get_as_text()`
    - `File.new()` → `FileAccess.open()`
    - Any `_ready`/signal patterns that changed between 4.x minor versions
  - Fix any identified violations in-place.
  - Add a CI check (`checks/godot-fileaccess-tested.sh` already exists) to catch
    regressions; if the check does not cover all known deprecated patterns, extend it.
  - Document the minimum Godot binary version required in `godot/README.md` (or a top-
    level comment in `project.godot`) so contributors know which binary to download.

  ## Files Affected

  - `godot/project.godot` — version config locked to 4.6.x
  - `godot/**/*.gd` — any files where deprecated API calls are found and corrected
  - `godot/tests/test_api_compat.gd` (new) — GUT test that verifies at least one
    `FileAccess.get_as_text()` call pattern compiles and runs, confirming the engine
    is 4.6-compatible at test time

  ## Verification

  1. `godot/project.godot` inspection shows Godot 4.6.x feature tag.
  2. `grep -r "read_as_text\|File.new()" godot/` returns no results.
  3. GUT tests pass under Godot 4.6.x binary.
  4. `checks/godot-fileaccess-tested.sh` exits 0.

  ## Caveats

  This task does not change any gameplay logic or scene structure — it is purely a
  configuration and compliance audit. If a future spec change requires moving to 4.7+,
  a new task should be opened; do not amend this one.
---
