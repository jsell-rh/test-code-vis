#!/usr/bin/env bash
# check-checkpoint-commit-is-first.sh
# Verifies the checkpoint commit ("chore: begin <task-id>") is the FIRST
# (oldest) commit on the branch, not merely present somewhere in history.
#
# Motivation: task-001 and task-007 both failed with "Agent future missing or
# failed" in the same cycle, both with branch: null (first attempt).  The
# existing check-checkpoint-commit.sh confirms the commit exists but does not
# verify ordering.  An agent that explores the repo before making the
# checkpoint commit still fails the orchestrator's liveness signal check if it
# times out or crashes mid-session — because the orchestrator reads the FIRST
# commit on the branch as the "agent alive" signal.  This check catches the
# ordering violation at submission time so it can be corrected before the next
# dispatch.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — checkpoint ordering check not applicable"
    exit 0
fi

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "SKIP: On main branch — check-not-on-main.sh handles this case"
    exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "SKIP: No commits above main — check-branch-has-commits.sh will catch this"
    exit 0
fi

# Get the OLDEST commit subject on the branch (--reverse puts oldest first)
FIRST_COMMIT=$(git log main..HEAD --reverse --pretty=format:"%s" 2>/dev/null | head -1 || true)

if echo "$FIRST_COMMIT" | grep -qE '^chore: begin '; then
    echo "OK: First (oldest) commit on branch is the checkpoint commit — '$FIRST_COMMIT'"
    exit 0
fi

echo "FAIL: The checkpoint commit is NOT the first commit on branch '$CURRENT_BRANCH'."
echo ""
echo "      First (oldest) commit found: '$FIRST_COMMIT'"
echo ""
echo "      The implementer overlay requires the checkpoint commit to be made"
echo "      as the very first Bash action — before any Read, Glob, Grep, or"
echo "      other tool call.  An agent that explores the repo before committing"
echo "      fails the orchestrator's liveness signal even if the checkpoint"
echo "      commit is added later in the session."
echo ""
echo "      All commits on this branch (oldest first):"
git log main..HEAD --reverse --pretty=format:"  %h %s" 2>/dev/null
echo ""
echo "      Fix: reorder with interactive rebase so the checkpoint is first:"
echo "        git rebase -i main"
echo "      Move the 'chore: begin ...' line to the TOP of the commit list."
exit 1
