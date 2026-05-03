#!/bin/bash
# check-banned-task-ids-closed.sh
#
# ORCHESTRATOR GATE — verifies permanently banned task IDs are closed on
# BOTH the working tree (main branch) AND the hyperloop/state branch.
#
# Root cause this script addresses:
#   task-028 and task-031 showed status: closed on main — so
#   check-no-prohibited-tasks-open.sh passed — but remained
#   status: in_progress on the hyperloop/state branch, which is the branch
#   the orchestrator actually reads when selecting and assigning tasks.
#
#   The queue audit ran against main and saw closed tasks; the orchestrator
#   read from hyperloop/state and kept assigning them.  23 total mis-assignments
#   resulted across three prohibited specs before this gap was identified.
#
#   This script explicitly checks BOTH locations so the gap is caught
#   regardless of which branch the orchestrator is reading from.
#
# Usage:
#   bash .hyperloop/checks/check-banned-task-ids-closed.sh --run
#
# Exit codes:
#   0 — All banned task IDs are absent or closed in both locations.
#   1 — At least one banned task ID is open in at least one location.
#
# No-arg path (run-all-checks.sh compatibility):
#   Exits 0 (SKIP) when called without --run.  This is an orchestrator
#   tool — it must not block implementer task branches.

set -uo pipefail

ARG="${1:-}"
if [ -z "$ARG" ]; then
    echo "SKIP: orchestrator gate — run manually at cycle start:"
    echo "  bash .hyperloop/checks/check-banned-task-ids-closed.sh --run"
    exit 0
fi

TASKS_DIR=".hyperloop/state/tasks"
STATE_BRANCH="hyperloop/state"

# ── Permanently banned task IDs (append-only) ────────────────────────────────
declare -a BANNED_IDS=(
    "task-001"
    "task-021"
    "task-024"
    "task-028"
    "task-031"
    "task-078"
)
declare -a BANNED_REASONS=(
    "scene-graph-schema.spec.md (spec fully implemented on main; 2x STOP PROTOCOL; branch-reset defeated check-stop-protocol-repeat.sh — task-001 was not added to BANNED_IDS after Round 1)"
    "data-flow.spec.md (scope-prohibited; 2 mis-assignments)"
    "moldable-views.spec.md (scope-prohibited; 8 mis-assignments)"
    "understanding-modes.spec.md (scope-prohibited; 9 mis-assignments as task-028)"
    "understanding-modes.spec.md (scope-prohibited; 6 mis-assignments as task-031)"
    "Symbol Table Extraction (superseded by task-075; extract_symbols on main at 08dd753f; 5x STOP PROTOCOL — branch resets defeated check-stop-protocol-repeat.sh)"
)

BANNED_FOUND=0

# ── Determine which state branch ref to use ──────────────────────────────────
STATE_REF=""
if git rev-parse --verify "${STATE_BRANCH}" >/dev/null 2>&1; then
    STATE_REF="${STATE_BRANCH}"
elif git rev-parse --verify "origin/${STATE_BRANCH}" >/dev/null 2>&1; then
    STATE_REF="origin/${STATE_BRANCH}"
fi

if [ -n "$STATE_REF" ]; then
    echo "Checking banned task IDs on: working tree + ${STATE_REF}"
else
    echo "Checking banned task IDs on: working tree only (${STATE_BRANCH} branch not found)"
fi
echo ""

# ── Check each banned task ID ─────────────────────────────────────────────────
for i in "${!BANNED_IDS[@]}"; do
    TASK_ID="${BANNED_IDS[$i]}"
    REASON="${BANNED_REASONS[$i]}"
    TASK_PATH="${TASKS_DIR}/${TASK_ID}.md"
    TASK_FOUND_OPEN=0

    # --- Check 1: working tree (main branch) --------------------------------
    if [ -f "$TASK_PATH" ]; then
        WT_STATUS=$(grep -m1 '^status:' "$TASK_PATH" \
            | sed 's/^status:[[:space:]]*//' | tr -d '\r')
        if [ "$WT_STATUS" != "closed" ]; then
            echo "BANNED TASK OPEN [${TASK_ID}] — working tree status='${WT_STATUS}'"
            echo "  Reason: ${REASON}"
            echo "  Fix (on main): set status: closed and spec_ref: null in ${TASK_PATH}"
            echo ""
            TASK_FOUND_OPEN=1
        fi
    fi

    # --- Check 2: hyperloop/state branch (the orchestrator's task store) ----
    if [ -n "$STATE_REF" ]; then
        STATE_CONTENT=$(git show "${STATE_REF}:${TASK_PATH}" 2>/dev/null || true)
        if [ -n "$STATE_CONTENT" ]; then
            STATE_STATUS=$(echo "$STATE_CONTENT" \
                | grep -m1 '^status:' | sed 's/^status:[[:space:]]*//' | tr -d '\r')
            if [ "$STATE_STATUS" != "closed" ]; then
                echo "BANNED TASK OPEN [${TASK_ID}] — ${STATE_REF} branch status='${STATE_STATUS}'"
                echo "  Reason: ${REASON}"
                echo "  *** This is the source of the re-assignment loop. ***"
                echo "  The orchestrator reads task state from ${STATE_BRANCH}, NOT from main."
                echo "  check-no-prohibited-tasks-open.sh passed because it saw the main"
                echo "  branch version (status: closed) — but the orchestrator assigned"
                echo "  from ${STATE_BRANCH} which still shows in_progress."
                echo ""
                echo "  Fix (on ${STATE_BRANCH} branch):"
                echo "    git checkout ${STATE_BRANCH}"
                echo "    sed -i 's/^status:.*/status: closed/' ${TASK_PATH}"
                echo "    sed -i 's/^spec_ref:.*/spec_ref: null/' ${TASK_PATH}"
                echo "    git add ${TASK_PATH}"
                echo "    git commit -m 'chore(tasks): permanently close banned task ${TASK_ID}'"
                echo "    git push origin ${STATE_BRANCH}"
                echo "    git checkout main"
                echo ""
                TASK_FOUND_OPEN=1
            fi
        fi
    fi

    if [ "$TASK_FOUND_OPEN" -eq 1 ]; then
        BANNED_FOUND=1
    fi
done

# ── Result ────────────────────────────────────────────────────────────────────
if [ "$BANNED_FOUND" -eq 0 ]; then
    echo "======================================================================"
    echo "RESULT: All permanently banned task IDs are absent or closed."
    if [ -n "$STATE_REF" ]; then
        echo "  Checked: working tree AND ${STATE_REF}"
    else
        echo "  Checked: working tree only (${STATE_BRANCH} not found)"
    fi
    echo "======================================================================"
    echo "EXIT 0 — Banned task ID check passed."
    exit 0
fi

echo "======================================================================"
echo "RESULT: BANNED TASK IDS ARE OPEN — RE-ASSIGNMENT LOOP RISK DETECTED."
echo "======================================================================"
echo ""
echo "  These task numbers are PERMANENTLY CLOSED and must not be assigned."
echo "  Closing tasks ONLY on main is insufficient when the orchestrator"
echo "  reads task state from a separate '${STATE_BRANCH}' branch."
echo ""
echo "  Required actions before assigning any task this cycle:"
echo "    1. Close every listed task on the ${STATE_BRANCH} branch (see fix commands above)."
echo "    2. Also close on main if not already done."
echo "    3. Re-run this check to confirm exit 0."
echo "    4. Do NOT assign any task until this script exits 0."
echo ""
echo "EXIT 1 — Banned task IDs are open. Resolve before proceeding."
exit 1
