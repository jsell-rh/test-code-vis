#!/bin/bash
# pre-submit.sh — Run as your LAST action before writing a verdict.
#
# Verifies that your worker-result.yaml satisfies the mandatory format
# requirements that the independent reviewer checks mechanically.
#
# If this script exits non-zero, your submission is invalid.
# Fix every failure, re-run this script, then write your verdict.
#
# Usage:
#   bash .hyperloop/checks/pre-submit.sh

set -euo pipefail

PASS=0
FAIL=0

run_check() {
  local label="$1"
  local script="$2"
  printf "--- %-45s " "${label} ---"
  if output=$(bash "$script" 2>&1); then
    echo "[EXIT 0  OK]"
    PASS=$((PASS + 1))
  else
    echo "[EXIT 1  FAIL]"
    echo "$output" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

echo "=== pre-submit.sh: final submission gate ==="
echo ""

run_check "check-report-scope-section.sh" ".hyperloop/checks/check-report-scope-section.sh"
run_check "check-scope-report-not-falsified.sh" ".hyperloop/checks/check-scope-report-not-falsified.sh"
run_check "check-branch-has-commits.sh" ".hyperloop/checks/check-branch-has-commits.sh"

echo ""
echo "--- Summary ---"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL pre-submit check(s) failed."
  echo "      Fix all failures, then re-run this script before writing your verdict."
  exit 1
fi

echo "OK: All pre-submit checks passed. You may now write your verdict."
exit 0
