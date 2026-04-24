#!/usr/bin/env bash
# check-pan-grab-model-comments.sh
#
# Pan/drag directional tests must reason all the way to the USER-VISIBLE screen
# outcome, not stop at the internal pivot state. This is necessary because the
# two competing pan models — map-grab (spec-required) and camera-pan (inverted) —
# produce OPPOSITE pivot signs for the same drag input, yet both produce a
# plausible-looking "pivot.x increases" or "pivot.x decreases" comment.
#
# A derivation comment that ends at pivot state (e.g., "→ pivot.x increases") is
# ambiguous: it passes check-direction-test-derivations.sh but cannot distinguish
# the correct model from the inverted one. Only a comment that names what the USER
# SEES on screen (e.g., "→ content from the right enters view ✓") proves map-grab
# reasoning was actually applied.
#
# This check finds pan/drag directional test functions and verifies that each body
# contains at least one comment line with user-visible-outcome language.
#
# Matched function names (case-insensitive):
#   test_*pan_drag*, test_*drag_direction*, test_*drag_right*, test_*drag_left*,
#   test_*drag_up*, test_*drag_down*, test_*pan_dir*
#
# Required tokens in a comment line (any one of):
#   reveals, enters view, scene moves, scene shifts, content from, on screen,
#   drifts, user sees, scroll
#
# Exit 0 = all matched tests have user-visible-outcome language (or no matches).
# Exit 1 = at least one pan/drag direction test lacks user-visible-outcome language.

set -euo pipefail

TESTS_DIR="godot/tests"

# Keywords that identify a test as a pan/drag directional test.
PAN_DRAG_PATTERN="pan_drag|drag_direction|drag_right|drag_left|drag_up|drag_down|pan_dir"

# Tokens (in comment lines) that demonstrate user-visible-outcome reasoning.
# At least one must appear somewhere in the function body's comment lines.
USER_VISIBLE_PATTERN="reveals|enters.view|scene.moves|scene.shifts|content.from|on.screen|drifts|user.sees|scroll"

if [[ ! -d "$TESTS_DIR" ]]; then
  echo "SKIP: $TESTS_DIR not found — no Godot tests to check."
  exit 0
fi

mapfile -t TEST_FILES < <(find "$TESTS_DIR" -name "test_*.gd" 2>/dev/null || true)

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "SKIP: No test_*.gd files found in $TESTS_DIR."
  exit 0
fi

FAIL=0
CHECKED=0

for file in "${TEST_FILES[@]}"; do
  while IFS= read -r func_line; do
    [[ -z "$func_line" ]] && continue

    func_lineno=$(grep -n "$func_line" "$file" | head -1 | cut -d: -f1)
    func_name=$(echo "$func_line" | grep -oP 'func\s+\K\w+')

    # Extract function body: lines after the declaration up to the next func/class.
    body=$(awk -v start="$func_lineno" '
      NR < start { next }
      NR == start { printing=1; next }
      printing && /^func |^class / { exit }
      printing { print }
    ' "$file" | head -60)

    CHECKED=$((CHECKED + 1))

    # Check only comment lines for user-visible-outcome tokens.
    comment_lines=$(echo "$body" | grep -P '^\s*#' || true)

    if echo "$comment_lines" | grep -qiP "$USER_VISIBLE_PATTERN"; then
      echo "OK: $file :: $func_name — user-visible-outcome language found in derivation."
    else
      echo "FAIL: $file :: $func_name — pan/drag direction test derivation comment does"
      echo "      not trace to a user-visible screen outcome."
      echo ""
      echo "      Map-grab (correct) and camera-pan (inverted) produce opposite pivot"
      echo "      signs — a comment that only states pivot state cannot distinguish them."
      echo "      The derivation MUST end with what the user sees on screen, e.g.:"
      echo "        # drag left → delta.x < 0 → negated → pivot.x increases"
      echo "        # → camera looks right → scene shifts right"
      echo "        # → content from the left drifts off; right-side content enters view ✓"
      echo ""
      echo "      Accepted tokens (any one): reveals, enters view, scene moves,"
      echo "      scene shifts, content from, on screen, drifts, user sees, scroll."
      FAIL=$((FAIL + 1))
    fi

  done < <(grep -iP "func\s+test_\w*($PAN_DRAG_PATTERN)\w*\s*\(" "$file" 2>/dev/null || true)
done

if [[ $CHECKED -eq 0 ]]; then
  echo "SKIP: No pan/drag directional test functions found."
  exit 0
fi

echo ""
if [[ $FAIL -gt 0 ]]; then
  echo "FAIL: $FAIL pan/drag direction test(s) lack user-visible-outcome language."
  echo "      Derivations that stop at pivot state (e.g., 'pivot.x increases') are"
  echo "      ambiguous between map-grab and camera-pan — the exact pair that caused"
  echo "      the task-027 pan-inversion regression. Extend every derivation comment"
  echo "      to name what the user sees on screen as the final arrow step."
  exit 1
fi

echo "OK: All $CHECKED pan/drag direction test(s) contain user-visible-outcome derivation language."
exit 0
