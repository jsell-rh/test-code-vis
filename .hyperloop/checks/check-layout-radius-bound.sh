#!/usr/bin/env bash
# check-layout-radius-bound.sh
#
# Detects an unbounded child-orbit radius in spatial layout code.
#
# The bug (task-001, cycles 5-10):
#   compute_layout uses:
#       mod_radius = max(1.5, len(children) * 0.9)
#   With no upper bound, large groups of children are placed far outside
#   the parent's scene radius, causing TestLayout::test_child_nodes_are_near_parent_position
#   to fail with "Child at distance X from parent, exceeding scene radius Y."
#
# The fix:
#   mod_radius = min(max(1.5, len(children) * 0.9), parent_size * FRACTION)
#   where FRACTION keeps children inside the parent's spatial boundary.
#   Alternatively, compare local position magnitude against parent size
#   in the test rather than world-distance from parent world position.
#
# This check scans for the unbounded max(…) pattern without a wrapping min(…).
#
# Exit 0 = no unbounded radius pattern found (or no layout source present).
# Exit 1 = unbounded radius pattern detected.

set -uo pipefail

SEARCH_ROOT="extractor"

if [[ ! -d "$SEARCH_ROOT" ]]; then
    echo "SKIP: No extractor/ directory found."
    exit 0
fi

# Look for lines that assign a radius/size using max() without a surrounding min().
# Pattern: variable = max(... without a min( wrapping the whole expression on that line.
# We target the common form: `xxx = max(literal, expr)` with no `min(` on the same line.
OFFENDING=$(grep -rn --include='*.py' \
    -E '^\s*\w+\s*=\s*max\([^)]+\)' \
    "$SEARCH_ROOT" \
    | grep -v '/test_' \
    | grep -v 'min(' \
    | grep -iE '(radius|offset_r|mod_radius|orbit)' \
    || true)

if [[ -z "$OFFENDING" ]]; then
    echo "OK: No unbounded spatial-layout radius pattern found."
    exit 0
fi

echo "FAIL: Unbounded child-orbit radius detected in layout source."
echo "  A bare max(lower, expr) without a wrapping min(…, parent_size * fraction)"
echo "  allows child nodes to be placed outside the parent's scene bounds."
echo ""
echo "  Offending lines:"
while IFS= read -r line; do
    echo "  $line"
done <<< "$OFFENDING"
echo ""
echo "  Fix: wrap the max() in a min() to cap the radius:"
echo "    mod_radius = min(max(1.5, len(children) * 0.9), parent_size * 0.4)"
echo "  Or, if no parent_size is available, derive a safe cap from a sibling"
echo "  attribute (e.g., scene_radius) and clamp to it."
echo ""
echo "  Alternatively, fix the test's coordinate-frame assumption: compare"
echo "  the child LOCAL position magnitude against parent size rather than"
echo "  world-distance from parent world position."
exit 1
