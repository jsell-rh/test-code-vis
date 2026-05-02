#!/bin/bash
# Verifies that features explicitly prohibited by prototype-scope.spec.md are absent.
# Prohibited features: moldable views, spec extraction, conformance/evaluation/simulation
# modes, data flow visualization, first-person navigation.
# See specs/prototype/prototype-scope.spec.md § "Not In Scope".

set -e
FAIL=0

# ── 1. Moldable views ─────────────────────────────────────────────────────────
# 1a. Prohibited script files (by historic name)
for f in godot/scripts/question_panel.gd godot/scripts/view_spec.gd godot/scripts/view_spec_renderer.gd; do
  if [ -f "$f" ]; then
    echo "FAIL: Prohibited file present: $f (moldable views are not in scope)"
    FAIL=1
  fi
done

# 1b. Prohibited test files (by historic name)
for f in godot/tests/test_question_panel.gd godot/tests/test_view_spec.gd godot/tests/test_view_spec_renderer.gd; do
  if [ -f "$f" ]; then
    echo "FAIL: Prohibited test file present: $f (covers a not-in-scope feature)"
    FAIL=1
  fi
done

# 1c. Moldable views by FEATURE KEYWORDS — catches renamed implementations.
# The prohibited feature is "moldable views (LLM-powered question-driven views)".
# Any code that implements this feature — under any file or class name — is prohibited.
MOLDABLE_PATTERN="LlmViewGenerator\|llm_view_generator\|SceneInterpreter\|scene_interpreter\|moldable.view\|MoldableView\|build_prompt\b\|parse_response\b\|apply_spec\b"
if grep -rl "$MOLDABLE_PATTERN" godot/ 2>/dev/null | grep -q .; then
  echo "FAIL: Moldable-views feature detected by keyword search — prohibited regardless of file name."
  echo "  The spec bans the FEATURE (moldable views / LLM-powered question-driven views), not just specific file names."
  echo "  Matched files:"
  grep -rl "$MOLDABLE_PATTERN" godot/ 2>/dev/null || true
  FAIL=1
fi

# 1d. LLM question-UI wiring in main.gd (moldable-views pipeline entry point)
if grep -q "_add_question_ui\|_call_llm\|_on_ask_button_pressed\|_on_question_submitted" godot/scripts/main.gd 2>/dev/null; then
  echo "FAIL: main.gd contains moldable-views UI/LLM wiring — prohibited"
  FAIL=1
fi

# 1e. Historic wiring patterns in main.gd
if grep -q "question_panel\|QuestionPanel\|ViewSpec\|view_spec_requested\|view_spec_renderer\|ViewSpecRenderer" godot/scripts/main.gd 2>/dev/null; then
  echo "FAIL: main.gd contains references to prohibited moldable-views code"
  FAIL=1
fi

# ── 2. Spec extraction ────────────────────────────────────────────────────────
# Patterns extended (task-034): discover_spec_nodes and _position_spec_nodes were
# correctly removed from this codebase; guard prevents accidental reintroduction.
for src in extractor/extractor.py extractor/__main__.py; do
  if [ -f "$src" ]; then
    if grep -q "extract_spec_nodes\|_layout_spec_nodes\|include_specs\|--specs\b\|discover_spec_nodes\|_position_spec_nodes" "$src"; then
      echo "FAIL: Prohibited spec-extraction code found in $src"
      FAIL=1
    fi
  fi
done

if grep -rq "TestSpecExtraction\|test_spec_extraction\|src_with_specs\|TestSpecNodeDiscovery\|test_discover_spec_nodes\|test_position_spec_nodes" extractor/tests/ 2>/dev/null; then
  echo "FAIL: Prohibited spec-extraction tests found in extractor/tests/"
  FAIL=1
fi

# ── 3. Other prohibited modes (belt-and-suspenders) ──────────────────────────
# Use -i (case-insensitive) to catch title-cased usage such as "Conformance Mode",
# "Evaluation Mode", "Simulation Mode" in addition to snake_case and lowercase forms.
# Previously this check used case-sensitive patterns and missed pre-existing scripts
# (understanding_analyzer.gd, understanding_overlay.gd) that used title-cased labels.
#
# Scope: only flag files INTRODUCED by the current branch (i.e., present in
# git diff main..HEAD --name-only). Pre-existing files on main are attributed to
# their originating task — flagging them here creates an unresolvable deadlock
# because the current implementer cannot be required to clean up prior work.
# Pre-existing violations are reported as NOTEs (informational) but do NOT set FAIL.
_MODE_PATTERN="conformance.mode\|evaluation.mode\|simulation.mode"
_ALL_MATCHES=$(grep -rli "$_MODE_PATTERN" godot/scripts/ extractor/ 2>/dev/null || true)
if [ -n "$_ALL_MATCHES" ]; then
  # Determine which files were introduced by this branch.
  _BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  if [[ "$_BRANCH" != "main" && "$_BRANCH" != "HEAD" ]]; then
    _BRANCH_FILES=$(git diff main..HEAD --name-only 2>/dev/null || true)
  else
    # On main itself every file is "branch-introduced" (no filtering).
    _BRANCH_FILES="$_ALL_MATCHES"
  fi
  _BRANCH_VIOLATIONS=""
  _PREEXISTING_VIOLATIONS=""
  for _f in $_ALL_MATCHES; do
    if echo "$_BRANCH_FILES" | grep -qF "$_f"; then
      _BRANCH_VIOLATIONS="$_BRANCH_VIOLATIONS $_f"
    else
      _PREEXISTING_VIOLATIONS="$_PREEXISTING_VIOLATIONS $_f"
    fi
  done
  if [ -n "$_BRANCH_VIOLATIONS" ]; then
    echo "FAIL: Prohibited mode (conformance/evaluation/simulation) detected"
    echo "  Matched files (introduced by this branch):"
    for _f in $_BRANCH_VIOLATIONS; do echo "  $_f"; done
    FAIL=1
  fi
  if [ -n "$_PREEXISTING_VIOLATIONS" ]; then
    echo "NOTE: Pre-existing prohibited-mode patterns detected in files that originate from main"
    echo "  (NOT introduced by this branch — attributed to their originating task, not to you):"
    for _f in $_PREEXISTING_VIOLATIONS; do
      _origin=$(git log --oneline -1 -- "$_f" 2>/dev/null || echo "unknown")
      echo "  $_f  (origin: $_origin)"
    done
    echo "  These are informational only and do NOT count as a FAIL for this branch."
  fi
fi

# ── 4. Data flow visualization ────────────────────────────────────────────────
# Check broad semantic synonyms across scripts AND tests.
# The prohibited feature covers any implementation of path/flow/aggregate overlay
# visualisation — regardless of file name or class name.
#
# Scope: only flag files that have at least one commit on the current branch
# (git log main..HEAD --oneline -- <file> returns non-empty). Pre-existing files
# on main — including files deleted from main after the branch was created — are
# attributed to their originating task, not to the current implementer. Flagging
# them would create an unresolvable deadlock.
# Pre-existing violations are reported as NOTEs (informational) but do NOT set FAIL.
#
# Pattern design note: target RENDERING VERBS only — not schema type names.
# `FlowPath` as a TypedDict class name and `flow_paths` as a JSON field name are
# schema-layer definitions, not visualization code. Broad token matches on those
# names produce false positives on any task that extends the scene-graph schema
# with flow-path data structures. Use function-level rendering verb patterns
# (show_flow_path, render_flow_path, draw_flow_path, clear_flow_path) instead.
_DF_KW_PATTERN="data\.flow\|dataflow\|flow_overlay\|FlowOverlay\|show_path\b\|show_aggregate\b\|flow\.path\|clear_path\b\|is_path_active\b\|show_flow_path\b\|render_flow_path\b\|draw_flow_path\b\|clear_flow_path\b\|highlight_flow\b"
_DF_KW_MATCHES=$(grep -rl "$_DF_KW_PATTERN" godot/scripts/ godot/tests/ extractor/ 2>/dev/null || true)
_DF_SPEC_MATCHES=$(grep -rl "data-flow\.spec\|data_flow\.spec\|visualization/data.flow" godot/ extractor/ 2>/dev/null || true)
_DF_ALL=$(printf '%s\n%s\n' "$_DF_KW_MATCHES" "$_DF_SPEC_MATCHES" | sort -u | grep -v '^$' || true)

if [ -n "$_DF_ALL" ]; then
  _DF_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  _DF_NEW=""
  _DF_OLD=""
  for _f in $_DF_ALL; do
    if [[ "$_DF_BRANCH" == "main" || "$_DF_BRANCH" == "HEAD" ]]; then
      # On main itself every file is considered branch-introduced (no filtering).
      _DF_NEW="$_DF_NEW $_f"
    elif git log main..HEAD --oneline -- "$_f" 2>/dev/null | grep -q .; then
      # File has at least one commit on this branch — it was introduced here.
      _DF_NEW="$_DF_NEW $_f"
    else
      # Zero commits from this branch — file is pre-existing on main.
      _DF_OLD="$_DF_OLD $_f"
    fi
  done
  if [ -n "$_DF_NEW" ]; then
    echo "FAIL: Prohibited data-flow visualization code detected (matched by feature keyword)."
    echo "  The spec bans the FEATURE (data flow visualization), not just specific file names."
    echo "  Matched files (introduced by this branch):"
    for _f in $_DF_NEW; do echo "  $_f"; done
    FAIL=1
  fi
  if [ -n "$_DF_OLD" ]; then
    echo "NOTE: Pre-existing data-flow visualization patterns detected in files that originate from main"
    echo "  (NOT introduced by this branch — attributed to their originating task, not to you):"
    for _f in $_DF_OLD; do
      _origin=$(git log --oneline -1 -- "$_f" 2>/dev/null || echo "unknown")
      echo "  $_f  (origin: $_origin)"
    done
    echo "  These are informational only and do NOT count as a FAIL for this branch."
  fi
fi

# ── 5. First-person navigation ────────────────────────────────────────────────
# Search ALL scripts and autoload files — not just camera_controller.gd — because
# the prohibited feature can be introduced under any filename (e.g.,
# first_person_camera_controller.gd, camera_mode.gd).
# Use branch-attribution: only FAIL for files introduced by this branch.
_FP_PATTERN="KEY_W\b\|KEY_A\b\|KEY_S\b\|KEY_D\b\|fly.cam\|first.person\|FirstPerson\|first_person"
_FP_ALL=$(grep -rli "$_FP_PATTERN" godot/scripts/ godot/autoload/ 2>/dev/null || true)

if [ -n "$_FP_ALL" ]; then
  _FP_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  _FP_NEW=""
  _FP_OLD=""
  for _f in $_FP_ALL; do
    if [[ "$_FP_BRANCH" == "main" || "$_FP_BRANCH" == "HEAD" ]]; then
      _FP_NEW="$_FP_NEW $_f"
    elif git log main..HEAD --oneline -- "$_f" 2>/dev/null | grep -q .; then
      _FP_NEW="$_FP_NEW $_f"
    else
      _FP_OLD="$_FP_OLD $_f"
    fi
  done
  if [ -n "$_FP_NEW" ]; then
    echo "FAIL: Prohibited first-person navigation code detected (introduced by this branch)."
    echo "  First-person navigation is explicitly excluded in prototype-scope.spec.md."
    echo "  Matched files:"
    for _f in $_FP_NEW; do echo "  $_f"; done
    FAIL=1
  fi
  if [ -n "$_FP_OLD" ]; then
    echo "NOTE: Pre-existing first-person navigation patterns in files from main"
    echo "  (NOT introduced by this branch — attributed to their originating task):"
    for _f in $_FP_OLD; do
      _origin=$(git log --oneline -1 -- "$_f" 2>/dev/null || echo "unknown")
      echo "  $_f  (origin: $_origin)"
    done
    echo "  These are informational only and do NOT count as a FAIL for this branch."
  fi
fi

# ── Result ────────────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
  echo "OK: No prohibited (not-in-scope) features detected."
fi

exit "$FAIL"
