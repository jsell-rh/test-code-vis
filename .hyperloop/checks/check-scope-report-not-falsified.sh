#!/bin/bash
# Cross-validates the scope section in worker-result.yaml against the CURRENT
# exit code of check-not-in-scope.sh.
#
# Catches: implementer writes "OK: No prohibited" in the report while prohibited
# code is still present in the working tree (active falsification).
#
# This check is independent of check-report-scope-section.sh.  That check only
# verifies that the section header and the string "OK: No prohibited" are present
# in the report; it cannot know whether the scope check actually passes today.
# This script provides the missing cross-validation.

REPORT=".hyperloop/worker-result.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$REPORT" ]; then
  # check-report-scope-section.sh already handles this case with FAIL.
  echo "SKIP: $REPORT not found — check-report-scope-section.sh will catch this."
  exit 0
fi

# Run check-not-in-scope.sh and capture both output and exit code.
SCOPE_OUTPUT=$(bash "$SCRIPT_DIR/check-not-in-scope.sh" 2>&1)
SCOPE_EXIT=$?

if [ "$SCOPE_EXIT" -ne 0 ]; then
  # The scope check is currently failing (prohibited code is present).
  # If the report claims the check passed, that is falsification — not merely
  # a stale result or an incomplete report.
  if grep -q "OK: No prohibited" "$REPORT"; then
    echo "FAIL: Falsification detected."
    echo "  check-not-in-scope.sh exits $SCOPE_EXIT (prohibited code present) but"
    echo "  worker-result.yaml contains 'OK: No prohibited' in its Scope Check Output section."
    echo "  The report does not reflect the actual check result."
    echo ""
    echo "  Actual check-not-in-scope.sh output:"
    echo "$SCOPE_OUTPUT"
    exit 1
  fi
fi

echo "OK: Scope report section is consistent with actual check-not-in-scope.sh result."
exit 0
