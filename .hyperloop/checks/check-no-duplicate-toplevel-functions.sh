#!/bin/bash
# check-no-duplicate-toplevel-functions.sh
#
# Detects when the same top-level function name is defined in two or more
# non-test Python source files in extractor/.
#
# The "shadow replacement" anti-pattern (task-001 recurring failure):
#   - extractor/layout.py::compute_layout() was created as a "replacement"
#     for extractor/extractor.py::compute_layout().
#   - The consuming file (extractor.py) was never updated to import from
#     layout.py, so extractor.py's own broken compute_layout() remained active.
#   - layout.py's tests passed, giving false confidence.
#   - check-new-modules-wired.sh catches the import gap after the fact;
#     this check catches the root-cause name collision at the moment the
#     duplicate is introduced, before any tests are written.
#
# Fix: either
#   (a) fix the function in-place in the original file and delete the new module, OR
#   (b) import from the new module in the original file and remove the old definition.

set -uo pipefail

EXTRACTOR_DIR="extractor"

if [ ! -d "$EXTRACTOR_DIR" ]; then
    echo "SKIP: No extractor/ directory found."
    exit 0
fi

# Use Python's AST to find top-level function definitions (avoids false
# positives from methods or nested functions with the same name).
RESULT=$(python3 - "$EXTRACTOR_DIR" <<'PYEOF'
import ast
import os
import sys
from collections import defaultdict

extractor_dir = sys.argv[1]
func_files = defaultdict(list)

for root, dirs, files in os.walk(extractor_dir):
    dirs[:] = [d for d in dirs if d != '__pycache__']
    for f in sorted(files):
        if not f.endswith('.py'):
            continue
        # Skip test files and infrastructure files
        if f.startswith('test_') or f in ('conftest.py', 'setup.py'):
            continue
        path = os.path.join(root, f)
        try:
            src = open(path).read()
            tree = ast.parse(src, filename=path)
        except (SyntaxError, OSError):
            continue
        # Only top-level definitions (direct children of the module node)
        for node in ast.iter_child_nodes(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                func_files[node.name].append(path)

duplicates = {n: ps for n, ps in func_files.items() if len(ps) >= 2}

if duplicates:
    for name, paths in sorted(duplicates.items()):
        print(f"DUPLICATE: '{name}' defined in {len(paths)} files:")
        for p in sorted(paths):
            print(f"  {p}")
    sys.exit(1)
sys.exit(0)
PYEOF
)

EXIT_CODE=$?
echo "$RESULT"

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "FAIL: Duplicate top-level function name(s) found across extractor/ source files."
    echo "  Each function should be defined in exactly one non-test source file."
    echo "  A duplicate means the consuming file still calls the original (possibly broken)"
    echo "  definition while the new file's tests pass — giving false confidence."
    echo ""
    echo "  Fix:"
    echo "    (a) Fix the function in-place in the ORIGINAL file and delete the new file, OR"
    echo "    (b) Remove the definition from the original file and import from the new one."
    echo ""
    echo "  Run check-new-modules-wired.sh after fix (b) to confirm the import is wired."
    exit 1
fi

echo "OK: No duplicate top-level function names across extractor/ source files."
exit 0
