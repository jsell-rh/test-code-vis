#!/usr/bin/env bash
# Verifies that if the spec declares an "all scripts use GDScript" constraint,
# at least one test in godot/tests/ exercises it via DirAccess directory iteration
# (not a config-string search, which checks a different predicate).
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -euo pipefail

SPEC_FILES=()
while IFS= read -r -d '' f; do
    SPEC_FILES+=("$f")
done < <(find specs/ -name "*.spec.md" -print0 2>/dev/null)

if [[ ${#SPEC_FILES[@]} -eq 0 ]]; then
    echo "SKIP: No spec file found — check not applicable"
    exit 0
fi

# Detect a "GDScript only" or "all scripts … GDScript" constraint in ANY spec file.
MATCHED_SPEC=""
for f in "${SPEC_FILES[@]}"; do
    if grep -qiE "(all scripts (use|are) GDScript|GDScript only|scripts must be GDScript)" "$f"; then
        MATCHED_SPEC="$f"
        break
    fi
done

if [[ -z "$MATCHED_SPEC" ]]; then
    echo "SKIP: No 'all scripts use GDScript' constraint found in spec"
    exit 0
fi

# Confirm a test exists that actually iterates the scripts directory via DirAccess.
if grep -rqE "DirAccess\.(open|new)\s*\(" godot/tests/ 2>/dev/null; then
    echo "OK: DirAccess iteration test found — 'all scripts use GDScript' constraint is exercised"
    exit 0
else
    echo "FAIL: Spec requires 'all scripts use GDScript' but no DirAccess-based iteration test exists in godot/tests/"
    echo "  A test that reads project.godot for a version string does NOT cover this predicate."
    echo "  Add a test using DirAccess.open(\"res://scripts\") that iterates every file and"
    echo "  asserts each filename ends in '.gd' (see test_scripts_dir_contains_only_gdscript)."
    exit 1
fi
