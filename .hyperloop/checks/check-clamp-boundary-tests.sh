#!/bin/bash
# check-clamp-boundary-tests.sh
# For every clamp() call in production GDScript, verify a test exists that
# asserts a boundary value (>= or <=) on the clamped variable.
#
# Motivation: implementers sometimes write a boundary test for one clamped
# variable and miss another in the same file (e.g. _distance covered,
# _theta missed). This script enumerates ALL clamp() assignments so none
# are silently skipped.

set -uo pipefail

GODOT_SRC="godot"
FAIL=0
CHECKED=0

if [ ! -d "$GODOT_SRC" ]; then
    echo "SKIP: No godot/ directory found"
    exit 0
fi

if [ ! -d "$GODOT_SRC/tests" ]; then
    echo "SKIP: No godot/tests/ directory found"
    exit 0
fi

# Collect production GDScript files (exclude tests/ and addons/)
mapfile -t prod_files < <(find "$GODOT_SRC" -name "*.gd" \
    ! -path "*/tests/*" \
    ! -path "*/addons/*" \
    2>/dev/null | sort)

if [ ${#prod_files[@]} -eq 0 ]; then
    echo "SKIP: No production GDScript files found"
    exit 0
fi

# Collect test GDScript files
mapfile -t test_files < <(find "$GODOT_SRC/tests" -name "test_*.gd" 2>/dev/null | sort)

if [ ${#test_files[@]} -eq 0 ]; then
    echo "SKIP: No test_*.gd files found in godot/tests/"
    exit 0
fi

for prod_file in "${prod_files[@]}"; do
    [ -f "$prod_file" ] || continue

    # Find lines with: <word> = clamp(
    # Captures the variable name being assigned the clamped result.
    while IFS= read -r matched_line; do
        # Extract variable name: everything before the first '='
        var=$(echo "$matched_line" | grep -oP '^\s*\K\w+(?=\s*=\s*clamp\()')
        [ -z "$var" ] && continue

        CHECKED=$((CHECKED + 1))
        found=0

        for test_file in "${test_files[@]}"; do
            [ -f "$test_file" ] || continue
            # Test file must reference the variable AND contain a boundary comparison
            # (>= or <=) on a line that also references the variable.
            if grep -q "\b${var}\b" "$test_file" 2>/dev/null; then
                if grep -qP "\b${var}\b\s*(>=|<=)" "$test_file" 2>/dev/null; then
                    found=1
                    echo "OK: '${var}' clamped in $(basename "$prod_file") — boundary assertion found in $(basename "$test_file")"
                    break
                fi
            fi
        done

        if [ $found -eq 0 ]; then
            echo "FAIL: '${var}' is assigned via clamp() in $prod_file"
            echo "      but no test file asserts a boundary value (>= or <=) on '${var}'."
            echo "      Add a test that sets '${var}' near the limit, applies an extreme"
            echo "      input, and asserts '${var} >= lower_bound' or '${var} <= upper_bound'."
            FAIL=1
        fi
    done < <(grep -P '\b\w+\s*=\s*clamp\(' "$prod_file" 2>/dev/null || true)
done

if [ $CHECKED -eq 0 ]; then
    echo "OK: No clamp() assignments found in production GDScript — nothing to check"
    exit 0
fi

if [ $FAIL -eq 1 ]; then
    exit 1
fi

echo "OK: All $CHECKED clamped variable(s) have boundary-asserting tests"
