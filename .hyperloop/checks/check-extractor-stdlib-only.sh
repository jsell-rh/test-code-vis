#!/bin/bash
# Verifies that a test exists which checks the extractor uses only stdlib imports.
#
# Pattern caught: specs that say "requires no dependencies beyond stdlib" are
# satisfied architecturally but never mechanically verified by an automated test.
# Required: a test that inspects all imports in the extractor package and asserts
# every import resolves to a stdlib module.

set -e
FAIL=0

MAIN_FILE="extractor/__main__.py"
TESTS_DIR="extractor/tests"

# Only run when __main__.py exists (extractor is in scope)
if [ ! -f "$MAIN_FILE" ]; then
  echo "SKIP: No extractor/__main__.py found."
  exit 0
fi

if [ ! -d "$TESTS_DIR" ]; then
  echo "SKIP: No extractor/tests/ directory found."
  exit 0
fi

# Look for a test that checks stdlib-only constraint.
# Must use sys.stdlib_module_names (the canonical Python mechanism) or explicitly
# assert no third-party imports. Matching "requirements" in a docstring is NOT
# sufficient — the check requires a real assertion on import provenance.
if grep -rl "stdlib_module_names" "$TESTS_DIR" 2>/dev/null | grep -q .; then
  echo "OK: A test using sys.stdlib_module_names to verify stdlib-only imports found."
else
  echo "FAIL: No test verifies the 'stdlib-only' constraint for the extractor."
  echo "  Required: a pytest test that inspects extractor imports and asserts all"
  echo "  are from the standard library, e.g.:"
  echo "    import sys, ast, pathlib"
  echo "    import extractor  # triggers all imports"
  echo "    # parse all .py files in extractor/ with ast, collect Import/ImportFrom names"
  echo "    # assert each name in sys.stdlib_module_names or is the extractor package itself"
  echo "  A THEN-clause 'requires no dependencies beyond stdlib' is PARTIAL until this test exists."
  FAIL=1
fi

exit "$FAIL"
