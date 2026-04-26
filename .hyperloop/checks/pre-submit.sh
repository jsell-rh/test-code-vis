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
  printf -- "--- %-45s " "${label} ---"
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

# ── Gate: worker-result.yaml must not contain a run-all-checks FAIL result ──
#
# When an implementer pastes run-all-checks.sh output that says
# "RESULT: FAIL — one or more checks exited non-zero" into their
# worker-result.yaml and then submits, this check catches it.
#
# During fix cycles: if worker-result.yaml has placeholder text (no RESULT:
# line), this check is skipped — placeholder state is OK while work is in
# progress. Clear your results section between fix rounds to avoid a false
# block from stale FAIL content.

RESULT_FILE=".hyperloop/worker-result.yaml"
if [ -f "$RESULT_FILE" ]; then
  if grep -qF "RESULT: FAIL — one or more checks exited non-zero" "$RESULT_FILE"; then
    echo ""
    echo "FAIL: worker-result.yaml contains a failing run-all-checks.sh result."
    echo "      Your pasted check output shows 'RESULT: FAIL'. You may NOT submit"
    echo "      while run-all-checks.sh exits non-zero."
    echo "      Fix every failing check, clear the '## Check Script Results' section"
    echo "      of worker-result.yaml, re-run run-all-checks.sh, paste the passing"
    echo "      output, then re-run this script."
    FAIL=$((FAIL + 1))
  elif grep -qF "RESULT: ALL PASS" "$RESULT_FILE"; then
    echo "OK: worker-result.yaml confirms run-all-checks.sh exited 0."
  else
    echo ""
    echo "FAIL: worker-result.yaml contains no run-all-checks.sh result line."
    echo "      Neither 'RESULT: ALL PASS' nor 'RESULT: FAIL' was found."
    echo "      You must run 'bash .hyperloop/checks/run-all-checks.sh' and paste"
    echo "      its COMPLETE output (including the 'RESULT:' summary line) into"
    echo "      the '## Check Script Results' section of worker-result.yaml before"
    echo "      running pre-submit.sh."
    echo "      A report without a run-all-checks.sh result cannot be accepted."
    FAIL=$((FAIL + 1))
  fi
fi

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
