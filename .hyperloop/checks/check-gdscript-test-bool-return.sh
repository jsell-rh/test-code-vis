#!/usr/bin/env bash
# check-gdscript-test-bool-return.sh
#
# Detects GDScript test functions that return `bool` inside a Pattern-1 test suite.
#
# Background:
#   run_tests.gd detects a Pattern-1 suite when the test class declares
#   `var _test_failed: bool`. Under Pattern 1 the runner:
#     1. Resets _test_failed = false
#     2. Calls the test method and IGNORES its return value
#     3. Checks whether _test_failed became true (via _check())
#   A test method that `return`s a bool without calling `_check()` is
#   therefore silently inert — it always reports PASS regardless of the
#   assertion result.
#
# This script fails if any test_*.gd file that is a Pattern-1 suite
# (i.e., contains `var _test_failed`) also contains a `func test_`
# whose signature includes `-> bool`.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

TESTS_DIR="godot/tests"

if [[ ! -d "$TESTS_DIR" ]]; then
    echo "SKIP: $TESTS_DIR not found — check not applicable"
    exit 0
fi

FAILED=0
CHECKED=0

while IFS= read -r -d '' file; do
    # Only Pattern-1 suites (those that declare _test_failed)
    if ! grep -q 'var _test_failed' "$file"; then
        continue
    fi

    CHECKED=$((CHECKED + 1))

    # Find test functions whose signature declares `-> bool`
    while IFS= read -r match; do
        lineno=$(echo "$match" | cut -d: -f1)
        funcline=$(echo "$match" | cut -d: -f2-)
        func_name=$(echo "$funcline" | grep -oP 'func \K[a-zA-Z_][a-zA-Z0-9_]*')
        echo "FAIL: ${file}:${lineno}: ${func_name}() -> bool is inert in a Pattern-1 suite"
        echo "      Under Pattern 1 the runner ignores return values — use _check() instead:"
        echo "      Change signature to '-> void' and replace 'return <expr>' with '_check(<expr>, \"message\")'"
        FAILED=1
    done < <(grep -n 'func test_[a-zA-Z0-9_]*[^:]*-> bool' "$file" || true)

done < <(find "$TESTS_DIR" -name 'test_*.gd' -print0 2>/dev/null)

if [[ $CHECKED -eq 0 ]]; then
    echo "SKIP: No Pattern-1 test suites found (no test_*.gd file declares 'var _test_failed')"
    exit 0
fi

if [[ $FAILED -eq 0 ]]; then
    echo "OK: No inert bool-returning test functions found in Pattern-1 suites (${CHECKED} suite(s) checked)"
    exit 0
else
    exit 1
fi
