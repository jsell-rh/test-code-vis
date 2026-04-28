#!/usr/bin/env bash
# check-circular-position-y-axis.sh
#
# Detects non-zero y-axis values in _circular_positions() calls.
#
# Observed pattern (task-001, cycles 11-12):
#   extractor/extractor.py:222:
#     _circular_positions(children_bc, bc_radius, center=(...), y=1.0)
#
#   The y=1.0 argument adds a 1-unit vertical component to every child
#   position.  When the test computes the 3D distance between the parent's
#   world position and the child's local offset, that vertical component
#   inflates the result by 1.0 — pushing it over the proximity threshold
#   even when the orbit radius is correctly bounded with min().
#
#   The check-layout-radius-bound.sh check catches the missing min() cap;
#   this check catches the separate y-inflation source.
#
# Fix: use y=0.0 in every _circular_positions call for module-level positions:
#   _circular_positions(children, radius, center=(...), y=0.0)
#
# Exit 0 = no non-zero y detected in _circular_positions calls (or no calls found).
# Exit 1 = non-zero y value detected.

set -uo pipefail

SEARCH_ROOT="extractor"

if [[ ! -d "$SEARCH_ROOT" ]]; then
    echo "SKIP: No extractor/ directory found."
    exit 0
fi

# Find all _circular_positions calls in non-test Python files that include a y= argument.
ALL_CALLS=$(grep -rn --include='*.py' \
    '_circular_positions' \
    "$SEARCH_ROOT" \
    | grep -v '/test_' \
    | grep 'y=' \
    || true)

if [[ -z "$ALL_CALLS" ]]; then
    echo "OK: No _circular_positions calls with a y= argument found."
    exit 0
fi

# From those, filter out lines where y=0 or y=0.0 (the correct value).
# A y= with any non-zero numeric literal is a FAIL.
OFFENDING=$(echo "$ALL_CALLS" \
    | grep -vE 'y=0(\.0)?[[:space:]]*[,)]' \
    || true)

if [[ -z "$OFFENDING" ]]; then
    echo "OK: All _circular_positions calls use y=0.0 (no non-zero y detected)."
    exit 0
fi

echo "FAIL: Non-zero y-axis value in _circular_positions call inflates 3D distance."
echo "  A non-zero y argument (e.g. y=1.0) adds a vertical component to every child"
echo "  position.  The proximity test computes a 3D distance, so this inflation causes"
echo "  test_child_nodes_are_near_parent_position to fail even when the orbit radius is"
echo "  correctly bounded.  This is a separate contributor from the unbounded max() issue."
echo ""
echo "  Offending lines:"
while IFS= read -r line; do
    echo "  $line"
done <<< "$OFFENDING"
echo ""
echo "  Fix: use y=0.0 in every _circular_positions call for module-level positions:"
echo "    _circular_positions(children, radius, center=(...), y=0.0)"
exit 1
