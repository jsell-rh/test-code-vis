#!/usr/bin/env bash
# check-pytest-passes.sh
#
# Runs the extractor test suite and fails if any tests fail.
#
# pytest failures are blocking: a FAILED test means the implementation is
# incorrect.  The canonical failure mode (task-001 F4, recurring cycles 5-8):
#   - extractor.py's compute_layout() assigned mod_radius = max(1.5, len(children)*0.9)
#     without an upper bound, so children with many siblings exceeded the parent's
#     scene radius.  The 3D Euclidean distance also included a y-component from
#     _circular_positions(..., y=1.0), inflating the distance further.
#   - test_child_nodes_are_near_parent_position asserted the child was within
#     scene radius — a correct semantic test that caught the bug.
#   - Because run-all-checks.sh did not invoke pytest, the failing test was
#     invisible to the submission gate.  This check closes that gap.
#
# This check is intentionally simple: run pytest, forward its exit code.
# Do NOT use subprocess tricks to suppress the failure — the full output is
# useful for diagnosing which test failed and why.

set -uo pipefail

TESTS_DIR="extractor/tests"

if [ ! -d "$TESTS_DIR" ]; then
    echo "SKIP: No extractor/tests/ directory found — pytest check not applicable."
    exit 0
fi

if ! command -v pytest &>/dev/null; then
    echo "SKIP: pytest not found in PATH — install it and re-run."
    exit 0
fi

echo "Running: pytest extractor/tests/ -v --tb=short"
echo ""

if pytest extractor/tests/ -v --tb=short; then
    echo ""
    echo "OK: All pytest tests passed."
    exit 0
else
    echo ""
    echo "FAIL: One or more pytest tests failed."
    echo "  Fix every failing test before submitting."
    echo "  A FAILED test means the implementation does not satisfy the spec."
    echo ""
    echo "  Common causes (from task-001 recurring failures):"
    echo "    - mod_radius grows unbounded for contexts with many children:"
    echo "        Fix: cap it, e.g. mod_radius = min(max(1.5, n*0.9), parent_size*0.4)"
    echo "    - y-component in _circular_positions inflates 3D distance:"
    echo "        Fix: use y=0.0 for module-level positions."
    echo "    - Test compares child world distance from parent — but child position"
    echo "      is stored as a local offset.  Both must use the same coordinate frame."
    exit 1
fi
