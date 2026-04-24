#!/bin/bash
# check-then-test-mapping.sh
#
# Verifies that every test function name listed in the THEN→test mapping in
# worker-result.yaml actually exists in the codebase (extractor/ or godot/).
#
# The protocol requires that implementers grep for each test name before
# submitting. This script enforces that mechanically so fabricated test names
# (names that sound plausible but do not exist in any test file) cannot survive
# to the review stage.
#
# A name listed as ::test_foo (or in a table cell) that produces zero grep
# hits is fabrication — an automatic FAIL regardless of whether a differently-
# named test covers the same behavior.
#
# Handles two mapping formats implementers use:
#   1. Backtick format:  → `file.py::test_function_name`
#   2. Table format:     | clause | test_function_name | PASS |

FAIL=0
RESULT_FILE=".hyperloop/worker-result.yaml"

if [ ! -f "$RESULT_FILE" ]; then
    echo "SKIP: No $RESULT_FILE found — cannot verify THEN→test mapping."
    exit 0
fi

# --- Format 1: `file::test_name` (compact, backtick-wrapped) ---
FORMAT1=$(grep -oE '::[a-zA-Z_][a-zA-Z0-9_]*' "$RESULT_FILE" \
    | sed 's/:://' \
    | grep '^test_' \
    || true)

# --- Format 2: markdown table rows (lines starting with |) that reference test functions.
# Handles verdict values with surrounding spaces: | PASS |, | FAIL |, | PARTIAL |, etc.
# Extract all test_xxx tokens from those rows (handles comma-separated lists too).
FORMAT2=$(grep -E '^\|' "$RESULT_FILE" \
    | grep -iE '\| *(PASS|FAIL|PARTIAL|PASS-WITH-NOTE|MISSING)' \
    | grep -oE '\btest_[a-zA-Z0-9_]+' \
    || true)

# Combine, deduplicate, sort.
TEST_NAMES=$(printf '%s\n%s\n' "$FORMAT1" "$FORMAT2" \
    | grep '^test_' \
    | sort -u)

if [ -z "$TEST_NAMES" ]; then
    echo "SKIP: No test function references found in $RESULT_FILE THEN→test mapping."
    exit 0
fi

CHECKED=0
for test_name in $TEST_NAMES; do
    CHECKED=$((CHECKED + 1))
    if grep -rn --include="*.py" --include="*.gd" "$test_name" extractor/ godot/ > /dev/null 2>&1; then
        echo "OK: '$test_name' found in codebase"
    else
        echo "FAIL: '$test_name' listed in THEN→test mapping but not found in extractor/ or godot/"
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then
    echo "OK: All $CHECKED mapped test function(s) verified in codebase"
fi

exit "$FAIL"
