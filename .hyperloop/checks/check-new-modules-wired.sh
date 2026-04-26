#!/bin/bash
# check-new-modules-wired.sh
#
# Detects new Python source modules (non-test) added on this branch that are
# not imported by any production (non-test) source file.
#
# A new module created to fix or replace logic in an existing module, but
# never imported by that module, is dead code. Its tests pass while the
# consuming file continues to call its own internal version of the same logic.
#
# Example failure mode (task-001 F2):
#   extractor/layout.py was added with a correct compute_layout() function,
#   but extractor/extractor.py was never updated to import it. extractor.py's
#   own broken compute_layout() remained the active code path. Tests for
#   layout.py passed but gave zero assurance about the actual pipeline output.
#
# Fix: either
#   (a) update the consuming file to import the new module and remove (or
#       delegate from) the old internal function, OR
#   (b) fix the logic directly in the consuming file and delete the new module.

set -uo pipefail

FAIL=0

# Find new non-test Python files added by this branch vs main.
NEW_MODULES=$(git diff --name-only main..HEAD 2>/dev/null \
    | grep '\.py$' \
    | grep -v '/test_' \
    | grep -v '__pycache__' \
    | grep -v 'conftest\.py$' \
    | grep -v 'setup\.py$' \
    || true)

if [ -z "$NEW_MODULES" ]; then
    echo "SKIP: No new non-test Python source files added on this branch."
    exit 0
fi

for MODULE_PATH in $NEW_MODULES; do
    BASENAME=$(basename "$MODULE_PATH" .py)

    # Skip infrastructure / entry-point files that are expected to be standalone.
    if [[ "$BASENAME" == "__init__" \
       || "$BASENAME" == "conftest" \
       || "$BASENAME" == "setup" \
       || "$BASENAME" == "__main__" ]]; then
        echo "SKIP: $MODULE_PATH (infrastructure file — import check not applicable)"
        continue
    fi

    # Search for imports of this module in production source files (exclude tests).
    # Matches both absolute imports ("from extractor.layout import ...")
    # and relative imports ("from .layout import ...").
    IMPORT_COUNT=$(grep -rn \
        -e "from[[:space:]]*[a-zA-Z_.]*${BASENAME}[[:space:]]*import" \
        -e "import[[:space:]]*[a-zA-Z_.]*${BASENAME}" \
        extractor/ \
        --include="*.py" \
        2>/dev/null \
        | grep -v '/test_' \
        | grep -v "^${MODULE_PATH}:" \
        | wc -l)

    if [ "$IMPORT_COUNT" -eq 0 ]; then
        echo "FAIL: New module '${MODULE_PATH}' is not imported by any production source file."
        echo "  '${BASENAME}' was added on this branch but no non-test Python file imports it."
        echo "  Tests for '${BASENAME}' pass but provide no assurance about the actual"
        echo "  runtime code path — the consuming file's old internal function remains active."
        echo ""
        echo "  Fix: either"
        echo "    (a) Import it from the consuming file (e.g. 'from extractor.${BASENAME} import <fn>')"
        echo "        and remove or delegate the old internal definition, OR"
        echo "    (b) Fix the logic directly in the consuming file and delete ${MODULE_PATH}."
        FAIL=1
    else
        echo "OK: '${MODULE_PATH}' is imported by production code (${IMPORT_COUNT} import(s) found)."
    fi
done

exit "$FAIL"
