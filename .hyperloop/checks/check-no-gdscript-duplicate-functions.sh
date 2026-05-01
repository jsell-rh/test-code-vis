#!/usr/bin/env bash
# check-no-gdscript-duplicate-functions.sh
#
# Detects when the same function name is defined more than once inside any
# single GDScript file (.gd) on the current branch.
#
# GDScript does NOT support function overloading.  A second `func` definition
# with the same name causes a parse error that prevents the script from loading.
# Because GDScript test files preload main.gd (or any shared script), a compile
# error in one file silently inerts EVERY test that preloads it — the test runner
# reports the suite as skipped or empty, not as a failure.
#
# Observed failure (task-062):
#   A fix commit added `_build_aggregate_edges(edges: Array, nodes: Array) -> Array`
#   at line 490 of godot/scripts/main.gd.  The file already contained a function
#   of the same name at line 544:
#     func _build_aggregate_edges(edges: Array) -> void
#   GDScript rejected the second definition with:
#     SCRIPT ERROR: Parse Error: Function "_build_aggregate_edges" has the same name
#       as a previously declared function.
#   This blocked ALL 164 Godot tests.  check-no-duplicate-toplevel-functions.sh
#   did not catch it because it only scans Python files in extractor/.
#
# Fix: Remove the unused duplicate.  Identify which definition is actually called
# (grep for call sites) and keep only that one.

set -uo pipefail

RESULT_FILE=".hyperloop/worker-result.yaml"

# Only meaningful on task branches.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

# Find .gd files added or modified on this branch (working tree state).
CHANGED_GD_FILES=$(git diff --name-only main..HEAD -- '*.gd' 2>/dev/null | grep -v '^$' || true)

if [[ -z "$CHANGED_GD_FILES" ]]; then
    echo "SKIP: No GDScript files changed on this branch."
    exit 0
fi

FAIL=0

while IFS= read -r gd_file; do
    [[ -z "$gd_file" ]] && continue
    [[ ! -f "$gd_file" ]] && continue

    # Extract function names from top-level `func name(` patterns.
    # Match lines that start with "func " (no leading whitespace) to avoid
    # inner/lambda functions.  Capture only the function name before "(".
    FUNC_NAMES=$(grep -n '^func ' "$gd_file" \
        | sed 's/^[0-9]*:func \([a-zA-Z_][a-zA-Z0-9_]*\)(.*/\1/' \
        2>/dev/null || true)

    if [[ -z "$FUNC_NAMES" ]]; then
        continue
    fi

    # Find names that appear more than once.
    DUPLICATES=$(echo "$FUNC_NAMES" | sort | uniq -d)

    if [[ -n "$DUPLICATES" ]]; then
        echo "FAIL: Duplicate function name(s) in $gd_file:"
        while IFS= read -r func_name; do
            [[ -z "$func_name" ]] && continue
            echo "  '$func_name' defined at:"
            grep -n "^func ${func_name}(" "$gd_file" \
                | sed 's/^/    line /' || true
        done <<< "$DUPLICATES"
        FAIL=1
    fi
done <<< "$CHANGED_GD_FILES"

if [[ "$FAIL" -ne 0 ]]; then
    echo ""
    echo "  GDScript does not support function overloading.  The second definition"
    echo "  causes a parse error that silently inerts every test file that preloads"
    echo "  the affected script — even though godot-compile.sh may have passed before"
    echo "  the duplicate was introduced."
    echo ""
    echo "  Fix:"
    echo "    1. Identify which definition is actually called:"
    echo "         grep -n '<func_name>' <gd_file>"
    echo "    2. Remove the unused definition."
    echo "    3. Re-run: bash .hyperloop/checks/godot-compile.sh"
    echo "    4. Re-run: bash .hyperloop/checks/godot-tests.sh"
    echo ""
    echo "[EXIT 1 — FAIL]"
    exit 1
fi

echo "OK: No duplicate top-level function names in changed GDScript files."
exit 0
