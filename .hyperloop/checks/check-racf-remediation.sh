#!/usr/bin/env bash
# check-racf-remediation.sh
# Re-Attempt Compliance Failure (RACF) gate.
#
# When an implementer submits a re-attempt, every check that exited non-zero
# in the most-recently committed worker-result.yaml MUST now exit 0.  If any
# prior-failing check still fails, the submission is blocked with a clear
# RACF diagnostic.
#
# How it works:
#   1. Find the most recent git commit that touched .hyperloop/worker-result.yaml.
#   2. Parse that committed report for check names paired with [EXIT N — FAIL].
#   3. Re-run each such check against the current codebase.
#   4. Exit 1 if any still fail.
#
# This check addresses the observed pattern of implementers adding new tests
# without first resolving previously-identified failures (task-001, cycles 5-8).
#
# Exit 0 = no prior committed failures, or all prior failures now pass.
# Exit 1 = one or more prior-cycle failures still fail (RACF).

set -uo pipefail

CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE=".hyperloop/worker-result.yaml"
FAIL=0

# ── Locate the most recently committed worker-result.yaml ──────────────────
# Implementers run checks BEFORE writing/committing their own worker-result.yaml,
# so the most recent commit for this file is the prior cycle's verifier report.
PRIOR_SHA=$(git log --oneline -- "$RESULT_FILE" 2>/dev/null | head -1 | cut -d' ' -f1)

if [[ -z "$PRIOR_SHA" ]]; then
  echo "SKIP: No prior committed worker-result.yaml found — first attempt, no RACF possible."
  exit 0
fi

# ── Extract check names that exited non-zero in the prior report ─────────────
# run-all-checks.sh produces blocks like:
#   --- check-some-name.sh ---
#   ...output lines...
#   [EXIT 1 — FAIL]
#
# The awk below tracks the most recent --- check-*.sh --- header and prints
# its name whenever a [EXIT N ... FAIL] line follows.
PRIOR_FAILS=$(git show "${PRIOR_SHA}:${RESULT_FILE}" 2>/dev/null \
  | awk '
    /^--- check-[a-z0-9_-]+\.sh ---/ {
      name = $0
      sub(/^--- /, "", name)
      sub(/ ---$/, "", name)
      current = name
    }
    /\[EXIT [0-9]+ / && /FAIL\]/ {
      if (current != "") print current
    }
  ' \
  | sort -u \
  || true)

if [[ -z "$PRIOR_FAILS" ]]; then
  echo "SKIP: Prior committed report contains no FAIL checks — no RACF to verify."
  exit 0
fi

PRIOR_SHA_SHORT="${PRIOR_SHA:0:7}"
echo "Prior committed report: ${PRIOR_SHA_SHORT} (${RESULT_FILE})"
echo "Checks that failed in that cycle — must now pass:"
echo ""

while IFS= read -r check_name; do
  [[ -z "$check_name" ]] && continue
  # Skip self: if check-racf-remediation.sh appears in PRIOR_FAILS (because it
  # failed in the prior cycle), re-running it here causes infinite self-recursion.
  # The OS eventually kills the deepest processes, but not before exhausting the
  # 90-second timeout and preventing run-all-checks.sh from producing a RESULT line.
  [[ "$check_name" == "check-racf-remediation.sh" ]] && {
    echo "  $(printf '%-55s' "$check_name") SKIP (self — cannot re-run RACF check from within RACF check)"
    continue
  }
  check_path="$CHECKS_DIR/$check_name"
  printf "  %-55s " "$check_name"
  if [[ ! -f "$check_path" ]]; then
    echo "SKIP (script not found — may have been removed or renamed)"
    continue
  fi
  if bash "$check_path" > /dev/null 2>&1; then
    echo "OK (resolved)"
  else
    echo "FAIL (still failing — RACF)"
    FAIL=1
  fi
done <<< "$PRIOR_FAILS"

echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "FAIL: One or more checks that failed in the prior committed cycle still fail."
  echo "      This is a Re-Attempt Compliance Failure (RACF)."
  echo ""
  echo "      Protocol:"
  echo "        1. Run each failing check individually: bash .hyperloop/checks/<check>.sh"
  echo "        2. Read its FAIL output carefully — it contains the prescribed fix."
  echo "        3. Apply the prescribed fix exactly (not a workaround)."
  echo "        4. Re-run the check and confirm EXIT 0 before moving on."
  echo "        5. Do NOT add new tests or commits until all RACF checks exit 0."
  exit 1
fi

echo "OK: All prior-cycle failures resolved — no RACF."
exit 0
