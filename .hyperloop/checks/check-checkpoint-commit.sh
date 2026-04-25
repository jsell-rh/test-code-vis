#!/usr/bin/env bash
# check-checkpoint-commit.sh
# Verifies the branch contains a "chore: begin <task-id>" checkpoint commit.
#
# Motivation: task-001 failed with "Agent future missing or failed" because the
# implementer never created the empty checkpoint commit required by the implementer
# overlay. Without the checkpoint, the orchestrator cannot distinguish a running
# agent from a crashed one, causing the entire task cycle to be lost.
#
# The checkpoint commit is the implementer's FIRST action — before reading any
# spec, exploring any code, or writing anything. This script catches the case
# where an implementer skipped it and still delivered work.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — checkpoint commit check not applicable"
    exit 0
fi

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "SKIP: On main branch — checkpoint commit check not applicable"
    exit 0
fi

# If branch has no commits at all, let check-branch-has-commits.sh handle it.
COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "SKIP: No commits above main — check-branch-has-commits.sh will catch this"
    exit 0
fi

# Look for a commit whose subject matches "chore: begin <something>"
CHECKPOINT=$(git log main..HEAD --pretty=format:"%s" 2>/dev/null \
    | grep -E '^chore: begin ' | head -1 || true)

if [ -z "$CHECKPOINT" ]; then
    echo "FAIL: No checkpoint commit found on branch '$CURRENT_BRANCH'."
    echo ""
    echo "      The implementer overlay requires the VERY FIRST action to be:"
    echo "        git commit --allow-empty -m \"chore: begin <task-id>\""
    echo "      Without it, the orchestrator cannot signal that the agent started,"
    echo "      and a crashed session causes the entire cycle to be lost."
    echo ""
    echo "      Commits present on this branch:"
    git log main..HEAD --pretty=format:"  %h %s" 2>/dev/null
    echo ""
    echo "      Add the checkpoint commit retroactively with:"
    echo "        git commit --allow-empty -m \"chore: begin <task-id>\""
    echo "      then reorder it to be first with an interactive rebase if needed."
    exit 1
fi

echo "OK: Checkpoint commit found — '$CHECKPOINT'"
exit 0
