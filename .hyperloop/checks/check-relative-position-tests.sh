#!/bin/bash
# check-relative-position-tests.sh
#
# Detects the absolute-coordinate accumulation anti-pattern in child node
# position computation.
#
# The spec requires module node `position` fields to be relative to the
# parent node (local offset only). The known failure modes are:
#
#   Form A (extracted variables):
#     child["position"] = {"x": px + pos[0], "y": py + pos[1], "z": pz + pos[2]}
#
#   Form B (array indexing on a parent_pos tuple/list):
#     child["position"] = {"x": parent_pos[0] + math.cos(angle) * r, ...}
#
# Both forms store an absolute world position instead of a local offset, causing
# Godot to double-offset the child (since main.gd adds the parent's world
# position again at render time).
#
# Form B is the typical failure mode when a new module is created as a fix but
# the absolute-coordinate pattern is reproduced under different variable names.
# This check scans ALL Python files in the extractor package, including newly
# created modules, so the bug is caught regardless of file or variable name.
#
# Additionally, verifies that at least one test explicitly checks the relative
# (local offset) value rather than only checking proximity to the parent.

set -uo pipefail

EXTRACTOR_DIR="extractor"
TESTS_DIR="extractor/tests"
FAIL=0

if [ ! -d "$EXTRACTOR_DIR" ]; then
    echo "SKIP: No extractor/ directory found."
    exit 0
fi

# ── Check 1: Detect absolute position accumulation in extractor source ──────

# Pattern: parent world coord added to child position assignment.
# Matches patterns like `px + pos[`, `py + pos[`, `pz + pos[`
# or `parent_x + `, `parent_pos["x"] + ` etc.
if grep -rn \
    -e 'px + pos\[' \
    -e 'py + pos\[' \
    -e 'pz + pos\[' \
    -e 'parent_x + \|parent_y + \|parent_z + ' \
    -e 'parent_pos\[0\] +' \
    -e 'parent_pos\[1\] +' \
    -e 'parent_pos\[2\] +' \
    -e 'parent_pos\["x"\] +\|parent_pos\["y"\] +\|parent_pos\["z"\] +' \
    "$EXTRACTOR_DIR" \
    --include="*.py" \
    2>/dev/null | grep -v "test_" | grep -q .; then

    echo "FAIL: Extractor source accumulates parent world coordinates into child position."
    echo "  Found absolute-coordinate accumulation pattern (form A: px/py/pz + pos[],"
    echo "  or form B: parent_pos[N] + ...) in a non-test Python file."
    echo "  The spec requires child positions to be relative (local offset only)."
    echo "  Godot's main.gd adds the parent's world position at render time —"
    echo "  storing absolute coordinates here causes double-offset rendering."
    echo "  This check scans ALL Python files in extractor/ — the bug is caught"
    echo "  regardless of which file or variable names are used."
    echo ""
    echo "  Offending lines:"
    grep -rn \
        -e 'px + pos\[' \
        -e 'py + pos\[' \
        -e 'pz + pos\[' \
        -e 'parent_pos\[0\] +' \
        -e 'parent_pos\[1\] +' \
        -e 'parent_pos\[2\] +' \
        "$EXTRACTOR_DIR" \
        --include="*.py" \
        2>/dev/null | grep -v "test_" || true
    echo ""
    echo "  Fix: store only the local offset in every file:"
    echo "    child[\"position\"] = {\"x\": pos[0], \"y\": pos[1], \"z\": pos[2]}"
    echo "  If a new module was created as the fix, verify it does not reproduce"
    echo "  the pattern under different variable names (e.g., parent_pos[0] + ...)."
    FAIL=1
else
    echo "OK: No absolute parent-coordinate accumulation detected in extractor source."
fi

# ── Check 2: Verify a relative-offset test exists (not just a proximity test) ──

if [ ! -d "$TESTS_DIR" ]; then
    # No test dir at all — let other checks handle that; skip this specific check
    echo "SKIP: No extractor/tests/ directory — skipping relative-position test verification."
    exit "$FAIL"
fi

# A valid relative-position test must:
#   a) Reference a non-zero parent position (parent not at origin)
#   b) Assert child position equals a local offset directly
#
# We look for any test file that asserts a child position value directly
# (not purely through an abs()-proximity comparison).
#
# Heuristic: look for assertions on ["position"]["x"] or .position.x that are
# equality checks (== or assertEqual), which indicate a direct-value assertion
# rather than a proximity check.

HAS_DIRECT_ASSERT=$(grep -rn \
    -e '"\(position\)"\]\["\(x\|y\|z\)"\].*==' \
    -e "'\(position\)'\]\['\(x\|y\|z\)'\].*==" \
    -e 'assert.*\["position"\].*==\s*[0-9]' \
    -e 'assert.*\["position"\].*==\s*pos\[' \
    "$TESTS_DIR" \
    --include="*.py" \
    2>/dev/null | wc -l)

HAS_ONLY_PROXIMITY=$(grep -rn \
    -e 'near_parent\|child.*near.*parent\|abs.*child.*parent\|abs.*parent.*child' \
    "$TESTS_DIR" \
    --include="*.py" \
    2>/dev/null | wc -l)

if [ "$HAS_ONLY_PROXIMITY" -gt 0 ] && [ "$HAS_DIRECT_ASSERT" -eq 0 ]; then
    echo "FAIL: Only proximity-based child position tests found — no direct relative-offset assertion."
    echo "  A test like 'test_child_nodes_are_near_parent_position' that only checks"
    echo "  abs(child_pos - parent_pos) < threshold passes for BOTH absolute and relative"
    echo "  coordinate storage when the offset is small. It does NOT cover the spec"
    echo "  requirement that positions are stored as relative (local) offsets."
    echo ""
    echo "  Required: a test that:"
    echo "    1. Places the parent at a non-zero world position (e.g., x=10.0)"
    echo "    2. Asserts child['position']['x'] == local_offset_x  (not proximity)"
    echo "    3. Optionally asserts child['position']['x'] != parent_x + local_offset_x"
    FAIL=1
elif [ "$HAS_DIRECT_ASSERT" -gt 0 ]; then
    echo "OK: Direct relative-offset assertion test(s) found in test suite."
else
    echo "SKIP: No child-position tests detected — no proximity or direct-assert patterns found."
fi

exit "$FAIL"
