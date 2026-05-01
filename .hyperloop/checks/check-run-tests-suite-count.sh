#!/usr/bin/env bash
# check-run-tests-suite-count.sh
#
# Verifies the number of _run_suite() registrations in godot/tests/run_tests.gd
# on the current branch is NOT less than the count on origin/main.
#
# Observed pattern (task-108, round 8):
#   Branch had 17 _run_suite() calls; origin/main had 18.
#   The missing entry was for test_visual_primitives.gd (task-074 work).
#   The test runner reported 161 passed, 0 failed — because the unregistered
#   suite simply never executed. No other check detected the regression.
#
#   Root cause: branch was not rebased onto main; conflict resolution in
#   run_tests.gd chose the branch version, dropping the main-side registration.
#
# This check fills the gap: a count drop relative to main is always a FAIL.
# Adding new suites (count increase) is fine; removing them is not.
#
# Exit 0 = branch count >= origin/main count (no suites removed).
# Exit 1 = branch count < origin/main count (regression — suites removed).
# Exit 0 (SKIP) = file not found, or origin/main has 0 registrations.

set -uo pipefail

RUN_TESTS_FILE="godot/tests/run_tests.gd"

if [[ ! -f "$RUN_TESTS_FILE" ]]; then
    echo "SKIP: $RUN_TESTS_FILE not found in working tree."
    exit 0
fi

# Fetch to ensure origin/main is current before comparison.
git fetch origin main:main --quiet 2>/dev/null || true

MAIN_COUNT=$(git show origin/main:"$RUN_TESTS_FILE" 2>/dev/null \
    | grep -c '_run_suite(' || true)
BRANCH_COUNT=$(grep -c '_run_suite(' "$RUN_TESTS_FILE" 2>/dev/null || true)

# Normalize: grep -c returns empty string on no-match in some environments.
MAIN_COUNT="${MAIN_COUNT:-0}"
BRANCH_COUNT="${BRANCH_COUNT:-0}"

if [[ "$MAIN_COUNT" -eq 0 ]]; then
    echo "SKIP: origin/main has 0 _run_suite() calls in $RUN_TESTS_FILE — nothing to compare."
    exit 0
fi

if [[ "$BRANCH_COUNT" -ge "$MAIN_COUNT" ]]; then
    echo "OK: _run_suite() count on branch ($BRANCH_COUNT) >= origin/main ($MAIN_COUNT)."
    exit 0
fi

MISSING=$(( MAIN_COUNT - BRANCH_COUNT ))
echo "FAIL: Branch has fewer _run_suite() registrations than origin/main."
echo ""
echo "  origin/main: $MAIN_COUNT _run_suite() call(s)"
echo "  This branch: $BRANCH_COUNT _run_suite() call(s)"
echo "  Missing:     $MISSING suite(s)"
echo ""
echo "  Tests for the missing suite(s) NEVER RAN. The reported pass count is"
echo "  artificially clean — the unregistered test file(s) were never executed."
echo ""
echo "  Diagnostic — identify which registrations are missing:"
echo "    diff <(git show origin/main:$RUN_TESTS_FILE | grep '_run_suite') \\"
echo "         <(grep '_run_suite' $RUN_TESTS_FILE)"
echo ""
echo "  Fix: restore the missing _run_suite() line(s) from origin/main."
echo "  If this branch adds a NEW suite, add its _run_suite() line too."
echo "  The count must be >= the count on origin/main after your changes."
exit 1
