#!/bin/bash
# auto-clean-banned-state-tasks.sh
#
# ACTION SCRIPT — auto-deletes permanently banned task files from hyperloop/state.
#
# WHY THIS EXISTS:
#   check-state-branch-post-commit.sh correctly detects banned task re-introduction
#   but only prints fix commands. The orchestrator's cycle-update commits have
#   re-created task-001.md on hyperloop/state after EVERY process-improver deletion
#   across 10+ rounds because those printed fix commands were never executed.
#
#   This script executes the deletion automatically, so the fix no longer depends
#   on the orchestrator reading and manually running multi-step commands.
#
# USAGE:
#   bash .hyperloop/checks/auto-clean-banned-state-tasks.sh
#
#   Run this BEFORE check-cycle-gate.sh at every cycle start and AFTER every
#   commit to hyperloop/state. check-cycle-gate.sh validates; this script repairs.
#
# EXIT CODES:
#   0 — Clean (no banned files found, or found-and-deleted successfully).
#   1 — Git error prevented deletion. Manual intervention required.
#
# WHEN TO RUN:
#   1. First action before check-cycle-gate.sh at every cycle start.
#   2. Immediately after every "cycle update" commit to hyperloop/state.
#   This is the replacement for manually running fix commands from
#   check-state-branch-post-commit.sh.

set -uo pipefail

STATE_BRANCH="hyperloop/state"
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
echo "AUTO-CLEAN — banned task files on ${STATE_BRANCH}"
echo "======================================================================"
echo ""

# Fetch latest state of the state branch before scanning
git fetch origin "${STATE_BRANCH}:${STATE_BRANCH}" 2>/dev/null || true

# Phase 1: detect without checkout (fast, no git state mutation)
TO_DELETE=()
for TASK_ID in "${BANNED_IDS[@]}"; do
    FILE="${TASKS_DIR}/${TASK_ID}.md"
    if git show "${STATE_BRANCH}:${FILE}" >/dev/null 2>&1; then
        TO_DELETE+=("$TASK_ID")
        echo "  BANNED FILE DETECTED: ${FILE} (will auto-delete)"
    fi
done

if [ "${#TO_DELETE[@]}" -eq 0 ]; then
    echo "  No banned task files on ${STATE_BRANCH} — nothing to clean."
    echo ""
    echo "EXIT 0 — Already clean."
    exit 0
fi

echo ""
echo "  Auto-deleting ${#TO_DELETE[@]} banned task file(s) from ${STATE_BRANCH}..."
echo ""

# Save original branch/HEAD so we can return after deletion
ORIG_REF=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse HEAD)

# Stash uncommitted changes (staged + unstaged) before switching branches
STASHED=0
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "  Stashing uncommitted changes before branch switch..."
    git stash push -q -m "auto-clean-banned-state-tasks: temporary stash"
    STASHED=1
fi

# Phase 2: checkout state branch, delete, commit, push
if ! git checkout "${STATE_BRANCH}" -q; then
    echo "  ERROR: could not checkout ${STATE_BRANCH}. Manual deletion required."
    [ "$STASHED" -eq 1 ] && git stash pop -q
    exit 1
fi

ACTUALLY_DELETED=()
for TASK_ID in "${TO_DELETE[@]}"; do
    FILE="${TASKS_DIR}/${TASK_ID}.md"
    if [ -f "$FILE" ]; then
        rm "$FILE"
        git add "$FILE"
        ACTUALLY_DELETED+=("$TASK_ID")
        echo "  Deleted: $FILE"
    fi
done

if [ "${#ACTUALLY_DELETED[@]}" -gt 0 ]; then
    DELETED_LIST=$(printf '%s ' "${ACTUALLY_DELETED[@]}")
    git commit -m "chore(tasks): auto-delete banned task file(s) from state branch: ${DELETED_LIST% }

Permanently banned tasks re-introduced by cycle-update commit. Auto-cleaned by
auto-clean-banned-state-tasks.sh to prevent re-assignment loop recurrence.

Spec-Ref: .hyperloop/agents/process
Task-Ref: process-improvement"

    if ! git push origin "${STATE_BRANCH}"; then
        echo ""
        echo "  ERROR: git push failed. Commit is local only."
        echo "  Manual push required: git push origin ${STATE_BRANCH}"
        git checkout "${ORIG_REF}" -q
        [ "$STASHED" -eq 1 ] && git stash pop -q
        exit 1
    fi
    echo ""
    echo "  Committed and pushed ${#ACTUALLY_DELETED[@]} deletion(s) to ${STATE_BRANCH}."
fi

# Return to original branch
git checkout "${ORIG_REF}" -q
[ "$STASHED" -eq 1 ] && git stash pop -q

echo ""
echo "======================================================================"
echo "RESULT: Auto-clean complete. ${#ACTUALLY_DELETED[@]} file(s) deleted from ${STATE_BRANCH}."
echo ""
echo "EXIT 0 — Banned task files removed."
exit 0
