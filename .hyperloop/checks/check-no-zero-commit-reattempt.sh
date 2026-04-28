#!/usr/bin/env bash
# check-no-zero-commit-reattempt.sh
#
# Detects re-attempt submissions where the implementer made no new implementation
# commits since the prior cycle's FAIL verdict.
#
# The anti-pattern (task-001, cycles 6-9; task-014, cycle 2):
#   The implementer was dispatched to fix F1–F4 in cycles 5, 6, 7, and 8.
#   In each of cycles 6-9, check-racf-prior-cycle.sh detected and re-ran the
#   same four failing checks — all still failed.  No new commits appeared on
#   the branch after cycle 5's implementation commit (5d8aff2f).  The
#   implementer submitted without changing anything.
#
#   task-014 cycle 2: the orchestrator cleanup commit blanked worker-result.yaml,
#   causing the original head-1 logic to read an empty/clean report and emit SKIP.
#   check-racf-prior-cycle.sh still caught it via full-history search (sha 5e92f82).
#   This check now uses the same full-history approach so it produces the correct
#   FAIL output instead of a misleading SKIP.
#
# Algorithm:
#   1. Walk ALL commits on this branch that touched worker-result.yaml (not just head-1).
#   2. Stop at the first commit whose content contains [EXIT N — FAIL] lines.
#      (This skips orchestrator-cleanup commits that blanked the file.)
#   3. If no branch commit has FAILs, fall back to main's history (post-reset branches).
#   4. If a prior FAIL report is found, find implementation commits added AFTER it.
#   5. If no such commit exists, the implementer has submitted without any fixes.
#
# Exit 0 = no prior FAILs found anywhere, or at least one implementation commit added since.
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

# ── Walk ALL branch commits to find the most recent one WITH FAIL lines ───────
# The orchestrator cleanup commit may have blanked the file; using head-1 would
# read the blank version and emit a false SKIP.  Walking all commits finds the
# actual prior FAIL report even when a cleanup commit sits on top of it.
PRIOR_REPORT_SHA=""
PRIOR_FAIL_COUNT=0

while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    content=$(git show "${sha}:${RESULT_FILE}" 2>/dev/null || true)
    [[ -z "$content" ]] && continue
    fail_count=$(echo "$content" | grep -c '\[EXIT [1-9]' 2>/dev/null || true)
    if [[ "$fail_count" -gt 0 ]]; then
        PRIOR_REPORT_SHA="$sha"
        PRIOR_FAIL_COUNT="$fail_count"
        break
    fi
done < <(git log main..HEAD --format="%H" -- "$RESULT_FILE" 2>/dev/null)

# ── Fallback: walk main's history (post-reset branches) ──────────────────────
if [[ -z "$PRIOR_REPORT_SHA" ]]; then
    while IFS= read -r sha; do
        [[ -z "$sha" ]] && continue
        content=$(git show "${sha}:${RESULT_FILE}" 2>/dev/null || true)
        [[ -z "$content" ]] && continue
        fail_count=$(echo "$content" | grep -c '\[EXIT [1-9]' 2>/dev/null || true)
        if [[ "$fail_count" -gt 0 ]]; then
            PRIOR_REPORT_SHA="$sha"
            PRIOR_FAIL_COUNT="$fail_count"
            break
        fi
    done < <(git log main --format="%H" -- "$RESULT_FILE" 2>/dev/null | head -10)
fi

if [[ -z "$PRIOR_REPORT_SHA" ]]; then
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
    echo "  Note: if the most-recently committed report appears clean (e.g., due to"
    echo "  an orchestrator cleanup commit), this check walks full branch history to"
    echo "  find the actual prior FAIL report — consistent with check-racf-prior-cycle.sh."
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

echo "OK: $(echo "$IMPL_COMMITS" | wc -l | tr -d ' ') implementation commit(s) found since prior FAIL report (${PRIOR_SHORT})."
exit 0
