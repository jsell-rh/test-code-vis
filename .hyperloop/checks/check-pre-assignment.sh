#!/usr/bin/env bash
# check-pre-assignment.sh
#
# ORCHESTRATOR PRE-ASSIGNMENT GATE — mandatory before assigning ANY task,
# whether the task came from findings OR from the hyperloop/state queue.
#
# Root cause this script addresses:
#   Round 8 of task-001: the orchestrator's cycle-update commit re-created
#   task-001.md on hyperloop/state.  The cycle-start gate (check-cycle-gate.sh)
#   had already passed before the cycle update ran, and the per-task checks
#   (Steps 2/2c) only fire for task IDs passed as arguments — task IDs picked
#   from the queue AFTER a cycle update bypass the per-task gates entirely.
#
#   Result: task-001 was assigned an 8th time despite being in BANNED_IDS,
#   despite check-state-branch-post-commit.sh being documented in the overlay,
#   and despite check-stop-protocol-repeat.sh correctly exiting 1 for task-001.
#
# Gap: there was no check run AT THE MOMENT OF ASSIGNMENT for queue-sourced
# tasks.  This script is that check.
#
# Usage:
#   bash .hyperloop/checks/check-pre-assignment.sh <task-id>
#
#   Example:
#     bash .hyperloop/checks/check-pre-assignment.sh task-001
#     bash .hyperloop/checks/check-pre-assignment.sh task-108
#
# Exit codes:
#   0 — Task is clear to assign. All banned-ID, scope, and STOP PROTOCOL
#       checks passed.
#   1 — Task MUST NOT be assigned. Detailed fix commands printed.
#   2 — Usage error (missing task ID or required subscripts).
#
# Checks performed (in order):
#   A — BANNED_IDS: task ID is in the permanent ban list → immediate exit 1.
#   B — Orphan file: task file present on hyperloop/state but absent from main
#       → indicates a task deleted from main that cycle update re-created.
#   C — Scope prohibition: check-retry-not-scope-prohibited.sh exit 0 required.
#   D — STOP PROTOCOL repeat: check-stop-protocol-repeat.sh exit 0 required.
#
# When to run:
#   EVERY TIME the orchestrator is about to assign a specific task.
#   This includes tasks selected from the hyperloop/state queue, not just
#   tasks from the current cycle's findings.

set -uo pipefail

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
    echo "ERROR: Usage: bash check-pre-assignment.sh <task-id>"
    echo "  Example: bash check-pre-assignment.sh task-001"
    exit 2
fi

TASKS_DIR=".hyperloop/state/tasks"
STATE_BRANCH="hyperloop/state"
SCOPE_RETRY=".hyperloop/checks/check-retry-not-scope-prohibited.sh"
STOP_REPEAT=".hyperloop/checks/check-stop-protocol-repeat.sh"

# ── Permanently banned task IDs (keep in sync with check-banned-task-ids-closed.sh) ──
BANNED_IDS=(
    "task-001"  # 9x STOP PROTOCOL
    "task-021"
    "task-024"
    "task-028"
    "task-031"
    "task-078"
)

echo "========================================================================"
echo "PRE-ASSIGNMENT GATE — ${TASK_ID}"
echo "========================================================================"
echo ""
echo "  Run before assigning any task, whether from findings or from the queue."
echo "  All four checks must pass (exit 0) before assignment is permitted."
echo ""

GATE_FAILED=0

# ── Check A: BANNED_IDS ───────────────────────────────────────────────────────
echo "--- Check A: Banned task ID ---"
IS_BANNED=0
for BAN_ID in "${BANNED_IDS[@]}"; do
    if [ "$TASK_ID" = "$BAN_ID" ]; then
        IS_BANNED=1
        break
    fi
done

if [ "$IS_BANNED" -eq 1 ]; then
    echo "  BANNED: ${TASK_ID} is in the permanently banned task list."
    echo "  This task MUST NOT be assigned under any circumstances."
    echo ""
    echo "  Required action:"
    echo "    1. Do NOT assign this task."
    echo "    2. If it exists on hyperloop/state, delete it:"
    echo "         git checkout ${STATE_BRANCH}"
    echo "         rm ${TASKS_DIR}/${TASK_ID}.md"
    echo "         git add ${TASKS_DIR}/${TASK_ID}.md"
    echo "         git commit -m 'chore(tasks): delete banned ${TASK_ID} (re-introduced by cycle update)'"
    echo "         git push origin ${STATE_BRANCH}"
    echo "         git checkout main"
    echo ""
    echo "  EXIT 1 — Task is permanently banned."
    exit 1
fi
echo "  PASS: ${TASK_ID} is not in BANNED_IDS."
echo ""

# ── Check B: Orphan file detection ────────────────────────────────────────────
echo "--- Check B: Orphan file (on state branch, absent from main) ---"

# Fetch state branch to get current content
git fetch origin "${STATE_BRANCH}:${STATE_BRANCH}" 2>/dev/null || true

TASK_FILE="${TASKS_DIR}/${TASK_ID}.md"
ON_MAIN=0
ON_STATE=0

if git show "main:${TASK_FILE}" >/dev/null 2>&1; then
    ON_MAIN=1
fi

if git show "${STATE_BRANCH}:${TASK_FILE}" >/dev/null 2>&1; then
    ON_STATE=1
fi

if [ "$ON_STATE" -eq 1 ] && [ "$ON_MAIN" -eq 0 ]; then
    STATE_STATUS=$(git show "${STATE_BRANCH}:${TASK_FILE}" 2>/dev/null \
        | grep '^status:' | head -1 | awk '{print $2}' || echo "unknown")
    echo "  ORPHAN: ${TASK_ID} (status: ${STATE_STATUS}) is on ${STATE_BRANCH} but ABSENT from main."
    echo "  This file was deleted from main without being deleted from ${STATE_BRANCH}."
    echo "  The cycle-update process re-created it — it must be deleted from ${STATE_BRANCH}."
    echo ""
    echo "  Required action:"
    echo "    git checkout ${STATE_BRANCH}"
    echo "    rm ${TASK_FILE}"
    echo "    git add ${TASK_FILE}"
    echo "    git commit -m 'chore(tasks): delete orphaned ${TASK_ID} from state branch'"
    echo "    git push origin ${STATE_BRANCH}"
    echo "    git checkout main"
    echo ""
    GATE_FAILED=1
else
    echo "  PASS: ${TASK_ID} is not an orphan file."
fi
echo ""

# ── Check C: Scope prohibition ────────────────────────────────────────────────
echo "--- Check C: Scope prohibition (check-retry-not-scope-prohibited.sh) ---"

if [ -f "$SCOPE_RETRY" ]; then
    # If the task file doesn't exist in the working tree (e.g. it only lives on
    # hyperloop/state as an orphan), Check B above already reported the problem.
    # Skip Check C in that case to avoid a misleading "scope-prohibited" error.
    if [ ! -f "${TASK_FILE}" ]; then
        echo "  SKIP: Task file not in working tree (orphan case caught by Check B above)."
    elif ! bash "$SCOPE_RETRY" "$TASK_ID" 2>&1; then
        echo ""
        echo "  SCOPE-PROHIBITED: ${TASK_ID} — do NOT assign."
        GATE_FAILED=1
    else
        echo "  PASS: ${TASK_ID} is not scope-prohibited."
    fi
else
    echo "  SKIP: check-retry-not-scope-prohibited.sh not found — sync checks from main:"
    echo "    git fetch origin main:main && git checkout main -- .hyperloop/checks/"
fi
echo ""

# ── Check D: STOP PROTOCOL repeat ────────────────────────────────────────────
echo "--- Check D: STOP PROTOCOL repeat (check-stop-protocol-repeat.sh) ---"

if [ -f "$STOP_REPEAT" ]; then
    if ! bash "$STOP_REPEAT" "$TASK_ID" 2>&1; then
        echo ""
        echo "  STOP PROTOCOL REPEAT: ${TASK_ID} — retire or redesign, do NOT assign unchanged."
        echo "  The primary deliverable already exists on origin/main."
        echo "  Assigning again will produce the identical STOP PROTOCOL outcome."
        GATE_FAILED=1
    else
        echo "  PASS: ${TASK_ID} has no prior STOP PROTOCOL history."
    fi
else
    echo "  SKIP: check-stop-protocol-repeat.sh not found — sync checks from main:"
    echo "    git fetch origin main:main && git checkout main -- .hyperloop/checks/"
fi
echo ""

# ── Result ────────────────────────────────────────────────────────────────────
echo "========================================================================"
if [ "$GATE_FAILED" -gt 0 ]; then
    echo "RESULT: PRE-ASSIGNMENT GATE FAILED for ${TASK_ID}."
    echo ""
    echo "  Do NOT assign this task. Execute the fix commands above."
    echo "  Re-run after fixing to confirm exit 0."
    echo ""
    echo "EXIT 1 — Pre-assignment gate failed. Task must NOT be assigned."
    exit 1
fi

echo "RESULT: PRE-ASSIGNMENT GATE PASSED for ${TASK_ID}."
echo ""
echo "  All checks cleared. Task is safe to assign."
echo ""
echo "EXIT 0 — Pre-assignment gate passed. Proceed with assignment."
exit 0
