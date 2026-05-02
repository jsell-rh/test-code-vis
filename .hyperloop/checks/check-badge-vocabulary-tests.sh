#!/usr/bin/env bash
# check-badge-vocabulary-tests.sh
#
# Verifies that all 8 required badge vocabulary types have dedicated
# test functions in godot/tests/test_visual_primitives.gd.
#
# The spec (visual-primitives.spec.md) mandates support for exactly
# these badge types: pure, io, async, stateful, error_handling, test,
# entry_point, deprecated.
#
# Each MUST have a dedicated test function named:
#   func test_badge_vocabulary_<type>():
# that asserts the specific "Badge_<type>" child name — not just a
# count or a begins_with("Badge_") check.
#
# Observed gap (task-076): error_handling and entry_point appeared only
# as incidental fixtures in other tests (count assertion, begins_with
# assertion). No dedicated test_badge_vocabulary_error_handling() or
# test_badge_vocabulary_entry_point() function existed. The verifier
# classified both as PARTIAL.
#
# Exit 0 — all 8 vocabulary types have dedicated test functions
# Exit 1 — one or more vocabulary types lack a dedicated test function
# Exit 0 (SKIP) — test_visual_primitives.gd not found (not applicable)

set -euo pipefail

TEST_FILE="godot/tests/test_visual_primitives.gd"

if [ ! -f "$TEST_FILE" ]; then
    echo "SKIP: $TEST_FILE not found — badge vocabulary tests not yet applicable."
    exit 0
fi

REQUIRED_BADGES=(pure io async stateful error_handling test entry_point deprecated)
MISSING=()

for badge in "${REQUIRED_BADGES[@]}"; do
    if ! grep -q "func test_badge_vocabulary_${badge}()" "$TEST_FILE"; then
        MISSING+=("$badge")
    fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "OK: All 8 required badge vocabulary types have dedicated test functions."
    echo "  Verified in: $TEST_FILE"
    exit 0
fi

echo "FAIL: Missing dedicated test_badge_vocabulary_<type>() for: ${MISSING[*]}"
echo ""
echo "The spec mandates support for 8 badge types:"
echo "  pure, io, async, stateful, error_handling, test, entry_point, deprecated"
echo ""
echo "Each requires a dedicated function in $TEST_FILE:"
for badge in "${MISSING[@]}"; do
    echo "  func test_badge_vocabulary_${badge}():"
    echo "      # Must assert the specific child name 'Badge_${badge}'"
    echo "      # Pattern: attach_primitives(node, [\"${badge}\"])"
    echo "      #          assert child.name == \"Badge_${badge}\""
    echo ""
done
echo "A test that uses ${MISSING[0]} as one of multiple badges in a count assertion"
echo "does NOT satisfy this requirement — the specific Badge_<type> name must"
echo "be asserted directly."
exit 1
