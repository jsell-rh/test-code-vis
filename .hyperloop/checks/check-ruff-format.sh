#!/usr/bin/env bash
# check-ruff-format.sh
#
# Verifies that all Python files in extractor/ (including tests) are
# formatted according to ruff's style rules.
#
# Failure mode observed in task-001 cycle 8 (F5):
#   The implementer ran `ruff check` but not `ruff format --check`.
#   New test files (test_extractor.py, test_layout.py) had assert-statement
#   parenthesisation that ruff's formatter would rewrite.  The cycle-7
#   reviewer reported PASS on a slightly different ruff version, so the
#   violation was invisible until cycle 8 ran a newer ruff.
#
# Fix: run `ruff format extractor/` (NOT --check) to auto-fix all violations,
# then re-run `ruff format --check extractor/` to confirm a clean state.
# Do this before every commit — not just before final submission.

set -uo pipefail

EXTRACTOR_DIR="extractor"

if [ ! -d "$EXTRACTOR_DIR" ]; then
    echo "SKIP: No extractor/ directory found."
    exit 0
fi

if ! command -v ruff &>/dev/null; then
    echo "SKIP: ruff not found in PATH — install with: pip install ruff"
    exit 0
fi

# Run ruff format --check (exits 1 if any file would be reformatted)
OUTPUT=$(ruff format --check "$EXTRACTOR_DIR" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "FAIL: ruff format --check found formatting violations in extractor/."
    echo "  This includes test files (test_extractor.py, test_layout.py, etc.)."
    echo ""
    echo "  ruff output:"
    echo "$OUTPUT" | sed 's/^/  /'
    echo ""
    echo "  Fix: run 'ruff format extractor/' to auto-fix all violations,"
    echo "  then re-run 'ruff format --check extractor/' to confirm clean."
    echo "  Do this before every commit, not only at final submission."
    exit 1
fi

echo "OK: ruff format --check passed — all extractor/ files are correctly formatted."
exit 0
