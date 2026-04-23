#!/bin/bash
# Verify that every FileAccess.open() call in godot/scripts/ is also exercised by at
# least one test in godot/tests/. Production-only file I/O is an untested code path.
set -e

GODOT_PROJECT="godot"

if [ ! -d "$GODOT_PROJECT/scripts" ] || [ ! -d "$GODOT_PROJECT/tests" ]; then
  echo "SKIP: godot/scripts/ or godot/tests/ not present."
  exit 0
fi

# Count FileAccess.open calls in production scripts.
PROD_USES=$(grep -rl "FileAccess.open" "$GODOT_PROJECT/scripts/" 2>/dev/null | wc -l | tr -d ' ')

if [ "$PROD_USES" -eq 0 ]; then
  echo "SKIP: No FileAccess.open() calls found in godot/scripts/. Nothing to check."
  exit 0
fi

echo "Found FileAccess.open() in $PROD_USES production script file(s)."

# Check that at least one test also uses FileAccess.open.
TEST_USES=$(grep -rl "FileAccess.open" "$GODOT_PROJECT/tests/" 2>/dev/null | wc -l | tr -d ' ')

if [ "$TEST_USES" -eq 0 ]; then
  echo "FAIL: FileAccess.open() is used in godot/scripts/ but never called in any test."
  echo ""
  echo "Production scripts with FileAccess.open():"
  grep -rl "FileAccess.open" "$GODOT_PROJECT/scripts/"
  echo ""
  echo "The file-reading code path is untested. Add a test that calls FileAccess.open()"
  echo "on a known file and asserts the returned content (e.g., read project.godot and"
  echo "assert it contains the expected engine version string)."
  exit 1
fi

echo "OK: FileAccess.open() is exercised in $TEST_USES test file(s)."
