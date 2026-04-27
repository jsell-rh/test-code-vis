#!/usr/bin/env bash
# check-racf-prior-cycle.sh
# Supplementary RACF gate: recovers prior-cycle FAIL reports from git history
# when check-racf-remediation.sh emits SKIP because the orchestrator cleanup
# commit deleted worker-result.yaml content.
#
# Observed pattern (task-001 cycles 5-8, task-007 cycles 1-6):
#   The orchestrator's cleanup commit deletes all content from
#   .hyperloop/worker-result.yaml.  check-racf-remediation.sh reads the
#   most-recently committed version of that file, finds no [EXIT N — FAIL]
#   lines, and emits SKIP.  The implementer sees SKIP and proceeds without
#   applying any of the prescribed fixes — causing the same checks to fail
#   again in the next cycle.
#
# Algorithm:
#   1. Walk THIS BRANCH'S commits (main..HEAD) for .hyperloop/worker-result.yaml.
#   2. Stop at the first commit whose content contains [EXIT N — FAIL] lines.
#   3. If that commit is already the one check-racf-remediation.sh would have
#      processed, skip (no double work).
#   4. FALLBACK (post-reset branches): When main..HEAD has no FAIL reports, also
#      walk main's own git history for the file.  After a branch reset the task
#      branch starts fresh from main, so prior-cycle failures committed to main
#      (e.g. by the verifier via the orchestrator) are not in main..HEAD but ARE
#      in main's history.  This fallback surfaces those failures.
#   5. Extract failing check names and re-run each against the current codebase.
#   6. Exit 1 if any still fail.
#
# Exit 0 = SKIP (nothing to recover) or all recovered failures now pass.
# Exit 1 = Prior-cycle failures still unresolved (RACF).

set -uo pipefail

CHECKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_FILE=".hyperloop/worker-result.yaml"
FAIL=0

# ── Guard: only applies on task branches with prior work ─────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
  echo "SKIP: Not on a task branch."
  exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COMMIT_COUNT" -le 1 ]]; then
  echo "SKIP: Branch has only ${COMMIT_COUNT} commit(s) above main — first attempt, no RACF possible."
  exit 0
fi

# ── What commit does check-racf-remediation.sh already handle? ───────────────
# That check reads the most-recent commit touching the file — if it already found
# FAIL lines, this check adds nothing.  Skip to avoid double-reporting.
RACF_SHA=$(git log --oneline -- "$RESULT_FILE" 2>/dev/null | head -1 | cut -d' ' -f1)
if [[ -n "$RACF_SHA" ]]; then
  RACF_CONTENT=$(git show "${RACF_SHA}:${RESULT_FILE}" 2>/dev/null || true)
  RACF_HAS_FAILS=$(echo "$RACF_CONTENT" | grep -c '\[EXIT [1-9]' 2>/dev/null || true)
  if [[ "$RACF_HAS_FAILS" -gt 0 ]]; then
    echo "SKIP: check-racf-remediation.sh already processes the most recent committed report — no gap to fill."
    exit 0
  fi
fi

# ── Helper: parse FAIL check names from a worker-result file content ─────────
parse_fails() {
  echo "$1" \
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
    ' | sort -u
}

# ── Pass 1: Walk THIS BRANCH's history (main..HEAD) ───────────────────────────
PRIOR_SHA=""
PRIOR_FAILS=""
FROM_MAIN=0

while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue
  content=$(git show "${sha}:${RESULT_FILE}" 2>/dev/null || true)
  [[ -z "$content" ]] && continue
  fails=$(parse_fails "$content")
  if [[ -n "$fails" ]]; then
    PRIOR_SHA="$sha"
    PRIOR_FAILS="$fails"
    break
  fi
done < <(git log main..HEAD --format="%H" -- "$RESULT_FILE" 2>/dev/null)

# ── Pass 2: Fallback — walk main's history (post-reset branches) ─────────────
# After a branch reset the task branch is recreated from main.  The prior-cycle
# verifier's FAIL report was committed to main (by the orchestrator after review),
# so it lives in main's history but NOT in main..HEAD for the new branch.
if [[ -z "$PRIOR_SHA" ]]; then
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    if git merge-base --is-ancestor "$sha" main 2>/dev/null && \
       ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
      : # commit is on main but not on branch — eligible for fallback
    else
      continue
    fi
    content=$(git show "${sha}:${RESULT_FILE}" 2>/dev/null || true)
    [[ -z "$content" ]] && continue
    fails=$(parse_fails "$content")
    if [[ -n "$fails" ]]; then
      PRIOR_SHA="$sha"
      PRIOR_FAILS="$fails"
      FROM_MAIN=1
      break
    fi
  done < <(git log main --format="%H" -- "$RESULT_FILE" 2>/dev/null | head -10)
fi

if [[ -z "$PRIOR_SHA" ]]; then
  echo "SKIP: No prior committed report with FAIL lines found in branch or main history."
  exit 0
fi

PRIOR_SHA_SHORT="${PRIOR_SHA:0:7}"

if [[ $FROM_MAIN -eq 1 ]]; then
  echo "POST-RESET RACF RECOVERY: Prior FAIL report found in main's history (not on branch)."
  echo "This branch was likely reset after a prior failed cycle.  The prior-cycle failures"
  echo "are still active requirements — apply every prescribed fix before adding new code."
  echo "To inspect: git show ${PRIOR_SHA_SHORT}:.hyperloop/worker-result.yaml"
else
  echo "Orchestrator cleanup obscured prior FAIL report — recovered from ${PRIOR_SHA_SHORT}."
  echo "To inspect: git show ${PRIOR_SHA_SHORT}:.hyperloop/worker-result.yaml"
fi

echo ""
echo "Checks that failed in that cycle — must now pass:"
echo ""

SELF="$(basename "${BASH_SOURCE[0]}")"

while IFS= read -r check_name; do
  [[ -z "$check_name" ]] && continue
  check_path="$CHECKS_DIR/$check_name"
  printf "  %-55s " "$check_name"

  # Self-exclusion guard: re-running this script from within itself causes
  # infinite recursion and hangs run-all-checks.sh.
  if [[ "$check_name" == "$SELF" ]]; then
    echo "SKIP (self-reference — cannot recursively verify; current invocation confirms it runs)"
    continue
  fi

  if [[ ! -f "$check_path" ]]; then
    echo "SKIP (script not found — may have been renamed)"
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
  echo "FAIL: One or more prior-cycle failures recovered from ${PRIOR_SHA_SHORT} still fail."
  if [[ $FROM_MAIN -eq 1 ]]; then
    echo "      These failures are from main's history — the branch was reset after a prior"
    echo "      failed cycle, so check-racf-remediation.sh and the branch-history pass above"
    echo "      both emitted SKIP.  The failures are real RACF requirements regardless."
  else
    echo "      This is a Re-Attempt Compliance Failure (RACF) obscured by orchestrator cleanup."
    echo ""
    echo "      The orchestrator's cleanup commit deleted worker-result.yaml content, causing"
    echo "      check-racf-remediation.sh to emit SKIP.  This check filled the gap by walking"
    echo "      full git history to find the actual prior-cycle FAIL report."
  fi
  echo ""
  echo "      Protocol:"
  echo "        1. Read the prior findings: git show ${PRIOR_SHA_SHORT}:.hyperloop/worker-result.yaml"
  echo "        2. Run each failing check: bash .hyperloop/checks/<check>.sh"
  echo "        3. Apply the prescribed fix exactly (not a workaround)."
  echo "        4. Re-run the check and confirm EXIT 0 before adding new code."
  echo "        5. Do NOT add new tests or commits until all RACF checks exit 0."
  exit 1
fi

echo "OK: All prior-cycle failures (recovered from ${PRIOR_SHA_SHORT}) are now resolved."
exit 0
