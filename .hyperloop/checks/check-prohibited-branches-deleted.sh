#!/bin/bash
# check-prohibited-branches-deleted.sh
#
# ORCHESTRATOR BRANCH AUDIT — confirms that remote branches for permanently
# prohibited tasks have been deleted.
#
# Observed pattern (task-028, task-031): scope-prohibited task branches were
# never deleted after permanent closure.  On subsequent re-assignments the new
# branch inherited rebase conflicts from the stale prohibited branch diverging
# against main.  Implementers correctly refused to resolve these conflicts
# ("doing so would constitute implementation work on a prohibited task").
# Only the orchestrator can clean this up by deleting the branch.
#
# Usage:
#   bash .hyperloop/checks/check-prohibited-branches-deleted.sh --run
#
# Exit codes:
#   0  — No prohibited task branches exist remotely (or could not connect).
#   1  — At least one prohibited branch still exists remotely.  See output.
#
# No-arg path (run-all-checks.sh compatibility):
#   Script exits 0 (SKIP) when called without --run.  This is an orchestrator
#   tool, not an implementer check — it must not block task branches.
#
# Required action when exit 1:
#   Delete each listed branch:
#     git push origin --delete hyperloop/<task-id>
#   Do NOT merge or cherry-pick — prohibited branches contain only scope-
#   prohibition FAIL reports.  There is no implementation work to preserve.

set -uo pipefail

ARG="${1:-}"
if [ -z "$ARG" ]; then
    echo "SKIP: orchestrator branch audit — run manually after closing prohibited tasks:"
    echo "  bash .hyperloop/checks/check-prohibited-branches-deleted.sh --run"
    exit 0
fi

# ── Permanently prohibited task IDs (append-only, mirrors orchestrator-overlay table) ──
declare -a PROHIBITED_TASK_IDS=(
    "task-024"
    "task-028"
    "task-031"
)
declare -a PROHIBITED_SPEC_FEATURES=(
    "moldable views (LLM-powered question-driven views)"
    "conformance/evaluation/simulation modes (understanding modes)"
    "conformance/evaluation/simulation modes (understanding modes)"
)

# Branch naming convention: hyperloop/<task-id>
BRANCH_PREFIX="hyperloop"

STALE_FOUND=0

# Fetch remote branch list (non-fatal if remote unreachable)
if ! REMOTE_BRANCHES=$(git ls-remote --heads origin 2>/dev/null); then
    echo "SKIP: Could not reach remote 'origin' — skipping branch audit."
    exit 0
fi

echo "Checking remote branches for permanently prohibited task IDs..."
echo ""

for i in "${!PROHIBITED_TASK_IDS[@]}"; do
    TASK_ID="${PROHIBITED_TASK_IDS[$i]}"
    FEATURE="${PROHIBITED_SPEC_FEATURES[$i]}"
    BRANCH_NAME="${BRANCH_PREFIX}/${TASK_ID}"

    if echo "$REMOTE_BRANCHES" | grep -q "refs/heads/${BRANCH_NAME}$"; then
        echo "STALE BRANCH [${TASK_ID}] remote branch exists: ${BRANCH_NAME}"
        echo "  Feature: ${FEATURE}"
        echo "  Task permanently closed — branch contains only a scope-prohibition"
        echo "  FAIL report.  No implementation work to preserve."
        echo "  Delete with:"
        echo "    git push origin --delete ${BRANCH_NAME}"
        echo ""
        STALE_FOUND=1
    fi
done

if [ "$STALE_FOUND" -eq 0 ]; then
    echo "======================================================================"
    echo "RESULT: No stale prohibited-task branches found on remote."
    echo "======================================================================"
    echo "EXIT 0 — Branch audit passed."
    exit 0
fi

echo "======================================================================"
echo "RESULT: STALE PROHIBITED-TASK BRANCHES DETECTED."
echo "======================================================================"
echo ""
echo "  Required actions:"
echo "    1. Delete each listed branch (git push origin --delete <branch>)."
echo "    2. Do NOT merge or cherry-pick content — there is nothing to preserve."
echo "    3. Re-run this script to confirm exit 0 before assigning any task."
echo ""
echo "EXIT 1 — Stale prohibited branches exist. Delete before re-assigning tasks."
exit 1
