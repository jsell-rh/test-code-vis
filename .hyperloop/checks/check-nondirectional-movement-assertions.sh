#!/usr/bin/env bash
# check-nondirectional-movement-assertions.sh
#
# FAIL if any GDScript test function whose name contains a directional keyword
# (direction, drag, pan, inverted, left, right, increases, decreases, toward, away)
# uses a non-directional predicate as its sole assertion:
#   != Vector3.ZERO   — verifies movement occurred, not its direction
#   != Vector2.ZERO   — same
#   != initial_*      — presence check, not a sign check
#
# A sign-inverted implementation passes all three forms identically.
# Direction tests MUST use signed comparisons: > initial_x, < 0.0, etc.
#
# Pattern caught: task-016 FAIL 4
#   test_drag_direction_matches_view_movement returned `cam._pivot != Vector3.ZERO`
#   A completely direction-inverted implementation also passed this test.

set -uo pipefail

GODOT_TESTS="godot/tests"

if [[ ! -d "$GODOT_TESTS" ]]; then
    echo "SKIP: $GODOT_TESTS not found"
    exit 0
fi

DIRECTION_RE="test_(direction|drag|pan|inverted|.*left[_$]|.*right[_$]|increases|decreases|toward|away|movement)"

FAIL=0
FINDINGS=()

while IFS= read -r -d '' file; do
    lineno=0
    current_func=""
    current_func_lineno=0

    while IFS= read -r line; do
        ((lineno++)) || true

        # Detect start of a test_ function
        if [[ "$line" =~ ^func[[:space:]]+(test_[a-zA-Z0-9_]+) ]]; then
            current_func="${BASH_REMATCH[1]}"
            current_func_lineno=$lineno
        fi

        # Inside a directional-named function, look for non-directional predicates
        if [[ -n "$current_func" ]] && echo "$current_func" | grep -qiE "$DIRECTION_RE"; then
            if echo "$line" | grep -qE '!=\s*(Vector3\.ZERO|Vector2\.ZERO|initial_[a-z_]+)'; then
                FINDINGS+=("$file:$lineno (in $current_func): non-directional predicate: $(echo "$line" | xargs)")
                FAIL=1
            fi
        fi

        # Reset on next top-level func (not the same line)
        if [[ "$line" =~ ^func[[:space:]] ]] && [[ "$lineno" -ne "$current_func_lineno" ]]; then
            current_func=""
            current_func_lineno=0
        fi
    done < "$file"
done < <(find "$GODOT_TESTS" -name "test_*.gd" -print0 2>/dev/null)

if [[ $FAIL -ne 0 ]]; then
    echo "FAIL: Non-directional predicates found in directional test functions."
    echo "      These tests pass for both correct AND sign-inverted implementations."
    echo ""
    echo "Offending lines:"
    for f in "${FINDINGS[@]}"; do
        echo "  $f"
    done
    echo ""
    echo "Fix: replace each != Vector3.ZERO / != initial_* with a signed comparison"
    echo "     that encodes the direction the spec requires (e.g., > initial_x, < 0.0)."
    exit 1
fi

echo "OK: All directional test functions use signed comparison predicates"
exit 0
