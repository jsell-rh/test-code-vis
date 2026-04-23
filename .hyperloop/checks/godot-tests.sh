#!/bin/bash
# Verify that GDScript behavioral tests exist and pass for the Godot component.
# A compile-only check (godot --quit) is NOT sufficient — this script runs actual tests.
set -e

GODOT_PROJECT="godot"

if [ ! -d "$GODOT_PROJECT" ]; then
  echo "SKIP: No godot/ directory found. Extractor-only task."
  exit 0
fi

if [ ! -f "$GODOT_PROJECT/project.godot" ]; then
  echo "SKIP: No project.godot found. Godot project not initialized yet."
  exit 0
fi

# Every Godot task requires a tests/ directory with GDScript test files.
if [ ! -d "$GODOT_PROJECT/tests" ]; then
  echo "FAIL: godot/tests/ directory is missing."
  echo "Every Godot spec scenario requires a GDScript behavioral test."
  echo "Create godot/tests/ with test_*.gd files and a headless runner."
  exit 1
fi

TEST_COUNT=$(find "$GODOT_PROJECT/tests" -name "test_*.gd" | wc -l | tr -d ' ')
if [ "$TEST_COUNT" -eq 0 ]; then
  echo "FAIL: No GDScript test files found in godot/tests/ (looking for test_*.gd)."
  echo "Write at least one test_*.gd per Godot spec scenario."
  exit 1
fi

echo "Found $TEST_COUNT GDScript test file(s) in godot/tests/."

# Detect and run the test runner.
if [ -d "$GODOT_PROJECT/addons/gut" ]; then
  echo "Running GUT test suite..."
  godot --headless --path "$GODOT_PROJECT" \
    -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit 2>&1
elif [ -f "$GODOT_PROJECT/tests/run_tests.gd" ]; then
  echo "Running custom headless test runner..."
  godot --headless --path "$GODOT_PROJECT" --script tests/run_tests.gd 2>&1
else
  echo "FAIL: No test runner found in godot/."
  echo "Expected one of:"
  echo "  - GUT addon at godot/addons/gut/  (run via gut_cmdln.gd)"
  echo "  - Custom runner at godot/tests/run_tests.gd  (must exit non-zero on failure)"
  exit 1
fi

echo "GDScript behavioral tests passed."
