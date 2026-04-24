#!/usr/bin/env bash
# check-direction-test-derivations.sh
#
# Finds GDScript test functions whose names signal a directional / sign-convention
# assertion (keywords: direction, inverted, pan, drag, orbit, zoom_toward) and
# verifies that each such function body contains a sign-chain derivation comment.
#
# A derivation comment must include at least one arrow sequence (→ or ->) that
# shows how the spec's behavioral reference maps to the expected sign/direction.
# Example:
#   # drag left → delta.x < 0 → × right_vec × minus sign → pivot.x increases ✓
#
# Without this comment the test cannot be distinguished from one that was written
# by observing the implementation's output rather than reasoning from the spec —
# exactly the failure mode that produced the task-024 pan-inversion bug.
#
# Exit 0 = all direction tests have derivation comments (or none exist).
# Exit 1 = at least one direction test is missing a derivation comment.

set -euo pipefail

TESTS_DIR="godot/tests"

# Keywords that mark a test function as direction/sign-sensitive.
DIRECTION_KEYWORDS="direction|inverted|non_inverted|pan_dir|drag|orbit_dir|zoom_toward"

# Pattern for a derivation comment: must contain an arrow (→ or ->) somewhere
# in a comment line within the test function body.
ARROW_PATTERN='(→|->)'

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "SKIP: $TESTS_DIR not found — no Godot tests to check."
  exit 0
fi

# Collect all test_*.gd files.
mapfile -t TEST_FILES < <(find "$TESTS_DIR" -name "test_*.gd" 2>/dev/null || true)

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "SKIP: No test_*.gd files found in $TESTS_DIR."
  exit 0
fi

FAIL=0
CHECKED=0

for file in "${TEST_FILES[@]}"; do
  # Extract function names matching direction keywords (case-insensitive).
  # We look for lines like: func test_pan_direction_not_inverted(...):
  while IFS= read -r func_line; do
    [[ -z "$func_line" ]] && continue

    # Get the line number of the func declaration.
    func_lineno=$(grep -n "$func_line" "$file" | head -1 | cut -d: -f1)
    func_name=$(echo "$func_line" | grep -oP 'func\s+\K\w+')

    # Extract the function body: lines from func_lineno to the next blank-line-
    # terminated block (GDScript uses indentation; grab up to 60 lines as a
    # reasonable upper bound for a test body, stopping at the next func/class).
    body=$(awk -v start="$func_lineno" '
      NR < start { next }
      NR == start { printing=1; next }
      printing && /^func |^class / { exit }
      printing { print }
    ' "$file" | head -60)

    CHECKED=$((CHECKED + 1))

    if echo "$body" | grep -qP "$ARROW_PATTERN"; then
      echo "OK: $file :: $func_name — derivation comment found."
    else
      echo "FAIL: $file :: $func_name — direction/sign-convention test is missing a"
      echo "      sign-chain derivation comment (must contain '→' or '->' showing"
      echo "      how the spec's behavioral reference maps to the expected predicate)."
      echo "      Add a comment like:"
      echo "        # drag left → delta.x < 0 → × right_vec × minus sign → pivot.x increases ✓"
      FAIL=$((FAIL + 1))
    fi

  done < <(grep -iP "func\s+test_\w*($DIRECTION_KEYWORDS)\w*\s*\(" "$file" 2>/dev/null || true)
done

if [[ $CHECKED -eq 0 ]]; then
  echo "SKIP: No direction/sign-convention test functions found."
  exit 0
fi

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "FAIL: $FAIL direction test(s) lack a sign-chain derivation comment."
  echo "      Tests that assert directional behavior without a derivation comment"
  echo "      cannot be distinguished from tests written by observing a (possibly"
  echo "      wrong) implementation rather than reasoning from the spec."
  exit 1
fi

echo ""
echo "OK: All $CHECKED direction/sign-convention test(s) contain derivation comments."
exit 0
