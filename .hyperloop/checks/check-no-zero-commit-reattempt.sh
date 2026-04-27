#!/usr/bin/env bash
# check-no-zero-commit-reattempt.sh
#
# Detects re-attempt submissions where the implementer made no new implementation
# commits since the prior cycle's FAIL verdict.
#
# The anti-pattern (task-001, cycles 6-9):
#   The implementer was dispatched to fix F1–F4 in cycles 5, 6, 7, and 8.
#   In each of cycles 6-9, check-racf-prior-cycle.sh detected and re-ran the
#   same four failing checks — all still failed.  No new commits appeared on
#   the branch after cycle 5's implementation commit (5d8aff2f).  The
#   implementer submitted without changing anything.
#
# This check identifies that pattern: when prior-cycle FAILs exist AND no
# implementation commit has been added since the prior worker-result.yaml was
# written.
#
# Algorithm:
#   1. Find the most recent commit that touched worker-result.yaml ("prior report").
#   2. Check whether that report contains [EXIT N — FAIL] lines.
#   3. If yes (prior FAILs exist), find the commit made AFTER the prior report
#      commit that is NOT itself a worker-result.yaml commit.
#   4. If no such commit exists, the implementer has submitted without any fixes.
#
# Exit 0 = no prior FAILs, or at least one implementation commit added since them.
# Exit 1 = prior FAILs exist but zero new implementation commits were made.

set -uo pipefail

RESULT_FILE=".hyperloop/worker-result.yaml"

# Only meaningful on task branches.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COMMIT_COUNT" -le 1 ]]; then
    echo "SKIP: Branch has only ${COMMIT_COUNT} commit(s) above main — first attempt."
    exit 0
fi

# ── Find the most recent committed worker-result.yaml on this branch ──────────
PRIOR_REPORT_SHA=$(git log main..HEAD --format="%H" -- "$RESULT_FILE" 2>/dev/null | head -1)

if [[ -z "$PRIOR_REPORT_SHA" ]]; then
    # No prior report on branch — check main history (post-reset branches)
    PRIOR_REPORT_SHA=$(git log main --format="%H" -- "$RESULT_FILE" 2>/dev/null | head -1)
    if [[ -z "$PRIOR_REPORT_SHA" ]]; then
        echo "SKIP: No prior committed worker-result.yaml found."
        exit 0
    fi
fi

# ── Does the prior report contain FAIL lines? ─────────────────────────────────
PRIOR_CONTENT=$(git show "${PRIOR_REPORT_SHA}:${RESULT_FILE}" 2>/dev/null || true)
# grep -c exits 1 when count is 0 but still prints "0" to stdout.
# Using "|| echo 0" would produce "0\n0" (two lines), breaking the [[ -eq 0 ]] test.
# "|| true" swallows the non-zero exit without adding extra output.
PRIOR_FAIL_COUNT=$(echo "$PRIOR_CONTENT" | grep -c '\[EXIT [1-9]' 2>/dev/null || true)

if [[ "$PRIOR_FAIL_COUNT" -eq 0 ]]; then
    echo "SKIP: Prior committed report contains no FAIL checks — no zero-commit re-attempt possible."
    exit 0
fi

# ── Find implementation commits added AFTER the prior report commit ───────────
# "Implementation commit" = any commit on this branch after PRIOR_REPORT_SHA
# that does NOT exclusively touch .hyperloop/ files (those are process/report commits).
PRIOR_REPORT_TIME=$(git show -s --format="%ct" "$PRIOR_REPORT_SHA" 2>/dev/null || echo "0")

IMPL_COMMITS=$(git log main..HEAD \
    --format="%H %ct" \
    2>/dev/null \
    | while IFS=' ' read -r sha ts; do
        # Skip commits at or before the prior report
        [[ "$ts" -le "$PRIOR_REPORT_TIME" ]] && continue
        # Skip commits that only touch .hyperloop/ files (report/process commits)
        CHANGED=$(git show --name-only --format="" "$sha" 2>/dev/null | grep -v '^$' || true)
        NON_HYPERLOOP=$(echo "$CHANGED" | grep -v '^\.hyperloop/' | grep -c '.' 2>/dev/null || true)
        if [[ "$NON_HYPERLOOP" -gt 0 ]]; then
            echo "$sha"
        fi
    done | head -5)

PRIOR_SHORT="${PRIOR_REPORT_SHA:0:7}"

if [[ -z "$IMPL_COMMITS" ]]; then
    echo "FAIL: Zero implementation commits since prior FAIL report (${PRIOR_SHORT})."
    echo ""
    echo "  The prior committed worker-result.yaml (${PRIOR_SHORT}) contains"
    echo "  ${PRIOR_FAIL_COUNT} FAIL check(s).  No non-hyperloop commits have been"
    echo "  added to this branch since that report was written."
    echo ""
    echo "  This means the implementer submitted a re-attempt without applying any"
    echo "  fixes.  This is the pattern that causes repeated RACF across many cycles."
    echo ""
    echo "  Protocol:"
    echo "    1. Run each failing check: bash .hyperloop/checks/<check>.sh"
    echo "    2. Apply the prescribed fix from its FAIL output."
    echo "    3. Commit the fix: git commit -m 'fix: <description>'"
    echo "    4. Repeat for each failing check."
    echo "    5. Only then run run-all-checks.sh and write worker-result.yaml."
    exit 1
fi

echo "OK: ${IMPL_COMMITS_COUNT:-$(echo "$IMPL_COMMITS" | wc -l | tr -d ' ')} implementation commit(s) found since prior FAIL report."
exit 0
