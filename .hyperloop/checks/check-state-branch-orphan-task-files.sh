#!/bin/bash
# check-state-branch-orphan-task-files.sh
#
# PROCESS-IMPROVER AND CYCLE-START GATE — detects task files present on
# hyperloop/state but ABSENT from main.  These "orphan" files arise when a
# task is permanently closed by deleting its file from main WITHOUT also
# deleting it from hyperloop/state.
#
# Root cause this script addresses:
#   task-001 reached STOP PROTOCOL Round 5 because of a recurring "delete
#   from main, forget hyperloop/state" pattern.  The orchestrator writes
#   "cycle update" commits to hyperloop/state; if the task file was absent
#   from main but still in_progress on hyperloop/state, the cycle update
#   re-assigns the banned task.  check-banned-task-ids-closed.sh catches this
#   for HARDCODED IDs — this script catches it for ANY task file, providing a
#   general-purpose orphan detector that does not require BANNED_IDS registration.
#
#   Round 3: task-001 deleted from main (a64de325), not from hyperloop/state.
#   Round 4: process-improver documented the fix but did not execute it.
#   Round 5: orchestrator cycle update (2eb29e78) re-added task-001 to
#             hyperloop/state as in_progress after prior process-improver
#             deletion at 51ac462b.
#   Rounds 3–5: same mechanical gap, same outcome.
#
# Usage:
#   bash .hyperloop/checks/check-state-branch-orphan-task-files.sh --run
#
# Exit codes:
#   0 — All task files on hyperloop/state are also present on main.
#   1 — At least one task file is on hyperloop/state but absent from main.
#
# No-arg path (run-all-checks.sh compatibility):
#   Exits 0 (SKIP) when called without --run.  This is an orchestrator /
#   process-improver gate — it must not block implementer task branches.

set -uo pipefail

ARG="${1:-}"
if [ -z "$ARG" ]; then
    echo "SKIP: orchestrator/process-improver gate — run manually:"
    echo "  bash .hyperloop/checks/check-state-branch-orphan-task-files.sh --run"
    exit 0
fi

STATE_BRANCH="hyperloop/state"
TASKS_DIR=".hyperloop/state/tasks"

# Fetch remote hyperloop/state to get current view
git fetch origin "${STATE_BRANCH}:${STATE_BRANCH}" 2>/dev/null || true

echo "======================================================================"
echo "ORPHAN TASK FILE CHECK — task files on ${STATE_BRANCH} absent from main"
echo "======================================================================"
echo ""
echo "  Detects task files deleted from main but left on hyperloop/state."
echo "  Orphan files allow re-assignment of permanently closed tasks."
echo ""

# Get list of task files on hyperloop/state
STATE_TASK_FILES=$(git ls-tree -r --name-only "${STATE_BRANCH}" -- "${TASKS_DIR}/" 2>/dev/null | grep -E '\.md$' || true)

if [ -z "$STATE_TASK_FILES" ]; then
    echo "  No task files found on ${STATE_BRANCH}."
    echo ""
    echo "======================================================================"
    echo "RESULT: No orphan task files detected."
    echo "EXIT 0 — Orphan check passed."
    exit 0
fi

ORPHANS_FOUND=0

while IFS= read -r FILE_PATH; do
    # Check if this file exists on main (working tree)
    if ! git show "origin/main:${FILE_PATH}" >/dev/null 2>&1; then
        if [ "$ORPHANS_FOUND" -eq 0 ]; then
            echo "  ORPHAN TASK FILES DETECTED:"
            echo ""
        fi

        # Get the task ID from filename
        TASK_ID=$(basename "${FILE_PATH}" .md)

        # Get status from hyperloop/state
        STATE_STATUS=$(git show "${STATE_BRANCH}:${FILE_PATH}" 2>/dev/null | grep '^status:' | head -1 | sed 's/status: //' || echo "unknown")

        echo "  ORPHAN [${TASK_ID}] — present on ${STATE_BRANCH} (status: ${STATE_STATUS}) but ABSENT from main"
        echo "    File: ${FILE_PATH}"
        echo "    This task was deleted from main without being deleted from ${STATE_BRANCH}."
        echo "    The orchestrator reads from ${STATE_BRANCH} — this file causes re-assignment loops."
        echo ""
        echo "    Fix (delete from ${STATE_BRANCH}):"
        echo "      git checkout ${STATE_BRANCH}"
        echo "      rm ${FILE_PATH}"
        echo "      git add ${FILE_PATH}"
        echo "      git commit -m 'chore(tasks): delete orphaned ${TASK_ID} from state branch'"
        echo "      git push origin ${STATE_BRANCH}"
        echo "      git checkout main"
        echo ""

        ORPHANS_FOUND=$((ORPHANS_FOUND + 1))
    fi
done <<< "$STATE_TASK_FILES"

echo "======================================================================"
if [ "$ORPHANS_FOUND" -gt 0 ]; then
    echo "RESULT: ${ORPHANS_FOUND} ORPHAN TASK FILE(S) DETECTED."
    echo ""
    echo "  Execute ALL fix commands above before assigning any task."
    echo "  Orphan files cause re-assignment loops for permanently closed tasks."
    echo ""
    echo "EXIT 1 — Orphan files found. Delete from ${STATE_BRANCH} before proceeding."
    exit 1
fi

echo "RESULT: No orphan task files detected."
echo "  All task files on ${STATE_BRANCH} are also present on main."
echo ""
echo "EXIT 0 — Orphan check passed."
exit 0
