#!/usr/bin/env bash
# check-docstring-arrow-placement.sh
# Detects the exact mis-placement pattern observed in task-007 (F1, cycles 1–3):
# a sign-chain derivation arrow (→ or ->) placed ONLY in a GDScript ## docstring
# ABOVE a direction test function, but NOT inside the function body.
#
# check-direction-test-derivations.sh already exits 1 when no arrow is found
# inside the body.  This companion script provides a more specific diagnostic
# that distinguishes the "arrow absent entirely" case from the "arrow present
# in docstring only" case — which is harder to notice because the code looks
# annotated but the annotation is invisible to the check.
#
# Root cause of task-007 F1:
#   ## Sign-chain derivation:
#   ## call set_pivot(target, dist) → _pivot = target → distance changes to dist
#   func test_zoom_toward_point_moves_pivot_toward_target() -> bool:
#       var cam = CameraScript.new()   # ← no arrow here; check scans from here
#
# Fix: add a # comment with → inside the function body (after the func line):
#   func test_zoom_toward_point_moves_pivot_toward_target() -> bool:
#       # spec: "camera moves closer" → set_pivot(target, dist) → _distance = dist ✓
#       var cam = CameraScript.new()
#
# Exit 0 = pattern absent (all arrows correctly inside bodies, or none exist).
# Exit 1 = at least one function has arrows in docstring but not in body.

set -euo pipefail

TESTS_DIR="godot/tests"
DIRECTION_KEYWORDS="direction|inverted|non_inverted|pan_dir|drag|orbit_dir|zoom_toward"
ARROW_PATTERN='(→|->)'

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

    # Lines ABOVE the func declaration — capture any ## docstring block.
    above=$(awk -v lineno="$func_lineno" '
      NR < lineno && /^[[:space:]]*##/ { print }
      NR >= lineno { exit }
    ' "$file" | tail -20)

    # Lines INSIDE the function body (after the func declaration line).
    body=$(awk -v start="$func_lineno" '
      NR < start { next }
      NR == start { printing=1; next }
      printing && /^func |^class / { exit }
      printing { print }
    ' "$file" | head -60)

    CHECKED=$((CHECKED + 1))

    has_arrow_above=0
    has_arrow_body=0
    echo "$above" | grep -qP "$ARROW_PATTERN" 2>/dev/null && has_arrow_above=1 || true
    echo "$body"  | grep -qP "$ARROW_PATTERN" 2>/dev/null && has_arrow_body=1  || true

    if [[ $has_arrow_above -eq 1 && $has_arrow_body -eq 0 ]]; then
      echo "FAIL: $file :: $func_name"
      echo "      Sign-chain arrow (→ or ->) found in ## docstring ABOVE the func"
      echo "      declaration, but NOT inside the function body."
      echo "      check-direction-test-derivations.sh scans only lines AFTER the"
      echo "      'func' declaration line — the ## docstring is never reached."
      echo ""
      echo "      Fix: duplicate the key arrow as a # comment inside the body:"
      echo "        func ${func_name}():"
      echo "            # spec: <clause> → <step> → <outcome> ✓"
      echo "            ..."
      echo ""
      FAIL=$((FAIL + 1))
    fi

  done < <(grep -iP "func\s+test_\w*($DIRECTION_KEYWORDS)\w*\s*\(" "$file" 2>/dev/null || true)
done

if [[ $CHECKED -eq 0 ]]; then
  echo "SKIP: No direction/sign-convention test functions found."
  exit 0
fi

if [[ $FAIL -gt 0 ]]; then
  echo "FAIL: $FAIL function(s) have derivation arrows in ## docstrings only."
  echo "      Add a # inline comment with → inside each function body before the"
  echo "      first assertion.  The docstring may remain — just add a body duplicate."
  exit 1
fi

echo "OK: No docstring-only arrow placements detected in $CHECKED direction test(s)."
exit 0
