#!/bin/bash
# Verify GDScript behavioral tests pass AND produce no SCRIPT ERRORs.
#
# In Godot 4 headless mode, accessing a non-existent property emits a
# SCRIPT ERROR that aborts the test function before any assert runs.
# The test runner still reports PASS because _test_failed is never set.
# This check catches that silent inertness — exit 0 from the runner is
# NOT sufficient if SCRIPT ERRORs are present in the output.
#
# Root cause pattern: test accesses cam._foo or cam.BAR where _foo / BAR
# do not exist on the GDScript object. Fix: align property/constant names
# in the test to match the implementation exactly (name AND case).

GODOT_PROJECT="godot"

if [ ! -d "$GODOT_PROJECT" ]; then
  echo "SKIP: No godot/ directory found."
  exit 0
fi

if [ ! -f "$GODOT_PROJECT/project.godot" ]; then
  echo "SKIP: No project.godot found."
  exit 0
fi

if [ ! -d "$GODOT_PROJECT/tests" ]; then
  echo "FAIL: godot/tests/ directory missing — every Godot scenario requires behavioral tests."
  exit 1
fi

TEST_COUNT=$(find "$GODOT_PROJECT/tests" -name "test_*.gd" | wc -l | tr -d ' ')
if [ "$TEST_COUNT" -eq 0 ]; then
  echo "FAIL: No GDScript test files found in godot/tests/ (looking for test_*.gd)."
  exit 1
fi

echo "Found $TEST_COUNT GDScript test file(s)."

# Build runner invocation array
if [ -d "$GODOT_PROJECT/addons/gut" ]; then
  echo "Using GUT addon runner."
  RUNNER=(godot --headless --path "$GODOT_PROJECT"
    -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit)
elif [ -f "$GODOT_PROJECT/tests/run_tests.gd" ]; then
  echo "Using custom headless runner (tests/run_tests.gd)."
  RUNNER=(godot --headless --path "$GODOT_PROJECT" --script tests/run_tests.gd)
else
  echo "FAIL: No test runner found."
  echo "Expected GUT addon at godot/addons/gut/ or custom runner at godot/tests/run_tests.gd."
  exit 1
fi

TMPOUT=$(mktemp)
"${RUNNER[@]}" 2>&1 | tee "$TMPOUT"
RUNNER_EXIT="${PIPESTATUS[0]}"

SCRIPT_ERRORS=$(grep "SCRIPT ERROR:" "$TMPOUT" || true)
rm -f "$TMPOUT"

if [ "$RUNNER_EXIT" -ne 0 ]; then
  echo "FAIL: Godot test runner exited $RUNNER_EXIT — one or more tests reported failure."
  exit 1
fi

if [ -n "$SCRIPT_ERRORS" ]; then
  echo ""
  echo "FAIL: Godot test output contains SCRIPT ERROR(s) — affected tests are inert."
  echo ""
  echo "Explanation: SCRIPT ERROR aborts the test function before any assert runs."
  echo "The runner reports PASS because _test_failed is never set — but no assertion"
  echo "was executed. Tests that always PASS regardless of implementation are useless."
  echo ""
  echo "Offending lines:"
  echo "$SCRIPT_ERRORS"
  echo ""
  echo "Fix: align property/constant names in tests to match the implementation exactly"
  echo "(name AND case). Then re-run this check to confirm zero SCRIPT ERRORs."
  exit 1
fi

echo "OK: Godot tests passed — zero test failures, zero SCRIPT ERRORs."
