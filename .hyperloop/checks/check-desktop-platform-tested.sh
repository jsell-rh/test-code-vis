#!/bin/bash
# check-desktop-platform-tested.sh
#
# Verifies that when a spec declares a desktop/native-platform requirement
# (THEN-clause: runs natively, not in browser/container/VM), at least one
# GDScript test in godot/tests/ exercises it via OS.has_feature().
#
# Pattern from task-023: implementers correctly configured the Godot project
# as a desktop app but did not write a behavioral test for the platform
# THEN-clause. Structural enforcement is not a substitute for a test.
#
# Logic:
#   1. Scan specs/ for desktop/native-platform language in THEN-clauses.
#   2. If found, verify godot/tests/ contains at least one test_*.gd that
#      calls OS.has_feature (asserting the system is not web/mobile).
#   3. FAIL if the spec names the constraint but no test covers it.
#   4. SKIP if no Godot component exists or spec has no platform constraint.

FAIL=0

# --- Guard: Godot component must exist ---
if [ ! -d "godot/tests" ]; then
    echo "SKIP: No godot/tests/ directory found — Godot component not present."
    exit 0
fi

# --- Step 1: Check if any spec file declares a desktop/native-platform constraint ---
PLATFORM_SPEC=$(grep -rl \
    -e "desktop" \
    -e "native" \
    -e "without browser" \
    -e "without.*container" \
    -e "without.*VM" \
    -e "not.*browser" \
    -e "not.*container" \
    specs/ 2>/dev/null || true)

if [ -z "$PLATFORM_SPEC" ]; then
    echo "SKIP: No desktop/native-platform constraint found in specs/ — check not applicable."
    exit 0
fi

echo "INFO: Desktop/native-platform constraint detected in spec(s):"
echo "$PLATFORM_SPEC" | sed 's/^/  /'

# --- Step 2: Verify godot/tests/ has at least one test using OS.has_feature ---
OS_FEATURE_TEST=$(grep -rl "OS.has_feature" godot/tests/ 2>/dev/null || true)

if [ -z "$OS_FEATURE_TEST" ]; then
    echo "FAIL: Spec declares a desktop/native-platform constraint but no GDScript test"
    echo "      in godot/tests/ calls OS.has_feature() to assert it."
    echo "      Add a test file (e.g. test_desktop_platform.gd) with:"
    echo "        _check(not OS.has_feature(\"web\"), \"must run as desktop, not web\")"
    echo "      and register it in run_tests.gd."
    FAIL=1
else
    echo "OK: OS.has_feature() test(s) found covering desktop-platform constraint:"
    echo "$OS_FEATURE_TEST" | sed 's/^/  /'
fi

exit "$FAIL"
