#!/bin/bash
# check-state-branch-post-commit.sh
#
# ORCHESTRATOR MANDATORY POST-COMMIT CHECK — run after EVERY commit to
# hyperloop/state (including cycle update commits) to detect banned task
# files being re-introduced.
#
# Root cause this script addresses:
#   The orchestrator's "cycle update" commits to hyperloop/state were
#   RE-CREATING task-001.md as a new file (status: in_progress) even after
#   the process-improver had deleted it.  This caused STOP PROTOCOL Rounds
#   3, 4, 5, 6, and 7 for task-001 — a pattern of delete→cycle-update-recreates→
#   repeat that no amount of overlay documentation stopped.
#
#   Evidence (hyperloop/state git log):
#     41bbaa01 chore(tasks): delete permanently banned task-001 (Round 7)
#     b29e1e42 orchestrator: cycle update         ← RE-CREATED task-001.md
#     54d86ba2 chore(tasks): delete permanently banned task-001 (Round 6)
#     085fbd0d orchestrator: cycle update         ← RE-CREATED task-001.md
#     ... (same pattern × 4 more rounds)
#
#   check-banned-task-ids-closed.sh and check-state-branch-orphan-task-files.sh
#   both correctly detect the re-introduction — but only if run.
#   The orchestrator was not running them after cycle update commits.
#
# Usage:
#   bash .hyperloop/checks/check-state-branch-post-commit.sh
#
# Exit codes:
#   0 — No banned task files are present on hyperloop/state.
#   1 — At least one banned task file was re-introduced. Fix commands printed.
#
# When to run:
#   After EVERY commit to hyperloop/state — especially "cycle update" commits
#   that write multiple task files at once.  Run it BEFORE switching back to
#   main; if it exits 1, delete the re-introduced files in the same git session.

set -uo pipefail

STATE_BRANCH="hyperloop/state"
TASKS_DIR=".hyperloop/state/tasks"

# ── Permanently banned task IDs (keep in sync with check-banned-task-ids-closed.sh) ──
BANNED_IDS=(
    "task-001"  # 8x STOP PROTOCOL — cycle-update re-creates this file; check-pre-assignment.sh added after Round 8
    "task-021"
    "task-024"
    "task-028"
    "task-031"
    "task-078"
)

# Fetch the current state of hyperloop/state from origin
git fetch origin "${STATE_BRANCH}:${STATE_BRANCH}" 2>/dev/null || true

echo "========================================================================"
echo "STATE-BRANCH POST-COMMIT CHECK — banned task re-introduction detection"
echo "========================================================================"
echo ""
echo "  Verifies no banned task file was written to ${STATE_BRANCH}."
echo "  Run after EVERY commit to ${STATE_BRANCH}."
echo ""

FOUND=0
for TASK_ID in "${BANNED_IDS[@]}"; do
    FILE_PATH="${TASKS_DIR}/${TASK_ID}.md"
    if git show "${STATE_BRANCH}:${FILE_PATH}" >/dev/null 2>&1; then
        STATUS=$(git show "${STATE_BRANCH}:${FILE_PATH}" 2>/dev/null \
            | grep '^status:' | head -1 | sed 's/status: //' || echo "unknown")
        echo "  BANNED TASK RE-INTRODUCED: ${TASK_ID} (status: ${STATUS}) found on ${STATE_BRANCH}"
        echo "  Delete immediately (do NOT switch back to main first):"
        echo ""
        echo "    git checkout ${STATE_BRANCH}"
        echo "    rm ${FILE_PATH}"
        echo "    git add ${FILE_PATH}"
        echo "    git commit -m 'chore(tasks): re-delete banned ${TASK_ID} from state branch'"
        echo "    git push origin ${STATE_BRANCH}"
        echo "    git checkout main"
        echo ""
        FOUND=$((FOUND + 1))
    fi
done

echo "========================================================================"
if [ "$FOUND" -gt 0 ]; then
    echo "RESULT: ${FOUND} BANNED TASK(S) RE-INTRODUCED ON ${STATE_BRANCH}."
    echo ""
    echo "  Execute ALL delete commands above before continuing."
    echo "  Banned tasks on ${STATE_BRANCH} cause re-assignment loops."
    echo ""
    echo "EXIT 1 — Banned task re-introduction detected."
    exit 1
fi

echo "RESULT: No banned task re-introduction detected."
echo "  ${STATE_BRANCH} contains no banned task files."
echo ""
echo "EXIT 0 — Post-commit check passed."
exit 0
