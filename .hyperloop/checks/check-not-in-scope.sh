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
for src in extractor/extractor.py extractor/__main__.py; do
  if [ -f "$src" ]; then
    if grep -q "extract_spec_nodes\|_layout_spec_nodes\|include_specs\|--specs\b" "$src"; then
      echo "FAIL: Prohibited spec-extraction code found in $src"
      FAIL=1
    fi
  fi
done

if grep -rq "TestSpecExtraction\|test_spec_extraction\|src_with_specs" extractor/tests/ 2>/dev/null; then
  echo "FAIL: Prohibited spec-extraction tests found in extractor/tests/"
  FAIL=1
fi

# ── 3. Other prohibited modes (belt-and-suspenders) ──────────────────────────
if grep -rq "conformance.mode\|evaluation.mode\|simulation.mode" godot/scripts/ extractor/ 2>/dev/null; then
  echo "FAIL: Prohibited mode (conformance/evaluation/simulation) detected"
  FAIL=1
fi

if grep -rq "data.flow\|dataflow" godot/scripts/ extractor/ 2>/dev/null; then
  echo "FAIL: Prohibited data-flow visualization code detected"
  FAIL=1
fi

# First-person navigation: WASD or fly-cam bindings
if grep -qi "KEY_W\|KEY_A\|KEY_S\|KEY_D\|fly.cam\|first.person" godot/scripts/camera_controller.gd 2>/dev/null; then
  echo "FAIL: Prohibited first-person navigation code detected in camera_controller.gd"
  FAIL=1
fi

# ── Result ────────────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
  echo "OK: No prohibited (not-in-scope) features detected."
fi

exit "$FAIL"
