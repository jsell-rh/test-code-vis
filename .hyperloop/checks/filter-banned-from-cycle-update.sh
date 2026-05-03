#!/bin/bash
# filter-banned-from-cycle-update.sh
#
# ACTION SCRIPT — removes banned task files from git staging area BEFORE
# committing a cycle-update to hyperloop/state.
#
# WHY THIS EXISTS:
#   auto-clean-banned-state-tasks.sh and check-state-branch-post-commit.sh both
#   detect banned task re-introduction AFTER the commit. The orchestrator's
#   cycle-update commits have continued to re-create task-001.md across 10+
#   rounds because even "auto-clean after commit" creates a window where the
#   banned file exists on hyperloop/state — and the orchestrator is not reliably
#   running the post-commit cleanup.
#
#   This script closes the gap by unstaging banned task files BEFORE git commit.
#   Running it immediately before `git commit` on hyperloop/state means banned
#   files can never enter the commit in the first place.
#
# USAGE — run this immediately before every `git commit` on hyperloop/state:
#
#   # Stage all your cycle-update changes first:
#   git add .hyperloop/state/tasks/
#
#   # Then filter out any banned files before committing:
#   bash .hyperloop/checks/filter-banned-from-cycle-update.sh
#
#   # Then commit (banned files are now unstaged):
#   git commit -m "orchestrator: cycle update"
#
# EXIT CODES:
#   0 — Clean (no banned files were staged, or they were successfully unstaged).
#   1 — Script encountered a git error during unstaging.
#
# NOTE: This script must be run while on hyperloop/state (or when staging
# changes intended for hyperloop/state). It operates on the git index only.

set -uo pipefail

TASKS_DIR=".hyperloop/state/tasks"

# ── Keep in sync with check-banned-task-ids-closed.sh ──────────────────────
BANNED_IDS=(
    "task-001"  # scene-graph-schema.spec.md — 10x+ STOP PROTOCOL
    "task-021"  # data-flow.spec.md (scope-prohibited)
    "task-024"  # moldable-views.spec.md (scope-prohibited)
    "task-028"  # understanding-modes.spec.md (scope-prohibited + body prohibition)
    "task-031"  # understanding-modes.spec.md (scope-prohibited)
    "task-078"  # Symbol Table Extraction — superseded by task-075
)

echo "======================================================================"
echo "FILTER-BANNED-FROM-CYCLE-UPDATE — pre-commit staging filter"
echo "======================================================================"
echo ""

REMOVED=0
for TASK_ID in "${BANNED_IDS[@]}"; do
    FILE="${TASKS_DIR}/${TASK_ID}.md"
    # Check if the file is currently staged (in the index)
    if git diff --cached --name-only | grep -qF "${FILE}"; then
        echo "  BANNED FILE STAGED: ${FILE} — unstaging before commit"
        if git restore --staged "${FILE}" 2>/dev/null || git reset HEAD "${FILE}" 2>/dev/null; then
            echo "  Unstaged: ${FILE}"
            REMOVED=$((REMOVED + 1))
        else
            echo "  ERROR: could not unstage ${FILE}. Aborting."
            exit 1
        fi
    fi
done

echo ""
if [ "$REMOVED" -gt 0 ]; then
    echo "======================================================================"
    echo "RESULT: Filtered ${REMOVED} banned task file(s) from staging area."
    echo "  The banned files will NOT be included in the next git commit."
    echo ""
    echo "EXIT 0 — Staged changes are clean. Safe to git commit."
else
    echo "======================================================================"
    echo "RESULT: No banned task files were staged. Nothing to filter."
    echo ""
    echo "EXIT 0 — Staging area is already clean."
fi

exit 0
