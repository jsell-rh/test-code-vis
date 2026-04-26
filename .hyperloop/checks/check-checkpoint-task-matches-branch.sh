#!/usr/bin/env bash
# check-checkpoint-task-matches-branch.sh
# Verifies the checkpoint commit's task-id matches the current branch name.
#
# Motivation: task-007 produced "Agent future missing or failed" after two
# consecutive branch resets.  One failure mode in post-reset dispatches is
# that an agent makes `git commit --allow-empty -m "chore: begin task-007"`
# while still on 'main' or while still on a different stale task branch —
# because it ran 'git checkout task-007' (lowercase -b) which silently
# switched to the stale local branch rather than force-resetting to HEAD.
#
# The combined symptom: check-checkpoint-commit.sh passes (the commit text
# is correct), check-not-on-main.sh passes (current branch is not main),
# but the checkpoint commit is for task-007 while the branch is task-NNN —
# or the branch is task-007 but the commit says "chore: begin task-006".
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — task-branch match check not applicable"
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

# Find the checkpoint commit subject
CHECKPOINT=$(git log main..HEAD --pretty=format:"%s" 2>/dev/null \
    | grep -E '^chore: begin ' | head -1 || true)

if [ -z "$CHECKPOINT" ]; then
    echo "SKIP: No checkpoint commit found — check-checkpoint-commit.sh handles this"
    exit 0
fi

# Extract the task-id from the checkpoint commit message (everything after "chore: begin ")
CHECKPOINT_TASK=$(echo "$CHECKPOINT" | sed 's/^chore: begin //')

# The branch name may be prefixed (e.g. "task-007" or "hyperloop/task-007").
# Normalise by extracting the last path component.
BRANCH_LEAF=$(echo "$CURRENT_BRANCH" | sed 's|.*/||')

if [ "$CHECKPOINT_TASK" = "$BRANCH_LEAF" ]; then
    echo "OK: Checkpoint task-id '$CHECKPOINT_TASK' matches branch '$CURRENT_BRANCH'"
    exit 0
fi

echo "FAIL: Checkpoint commit task-id does not match the current branch."
echo ""
echo "      Current branch : $CURRENT_BRANCH  (leaf: $BRANCH_LEAF)"
echo "      Checkpoint says: chore: begin $CHECKPOINT_TASK"
echo ""
echo "      This means the checkpoint commit was made on a DIFFERENT branch"
echo "      or from a prior task cycle, and is now present in this branch's"
echo "      history via cherry-pick or incorrect rebase."
echo ""
echo "      Root cause: 'git checkout -B <task-id>' was not used (or failed),"
echo "      so the branch was not correctly reset before the checkpoint commit."
echo "      Using lowercase '-b' or no flag silently reuses a stale local branch,"
echo "      leaving stale commits (including wrong-task checkpoints) in history."
echo ""
echo "      Fix:"
echo "        1. git checkout main"
echo "        2. git checkout -B $BRANCH_LEAF     # capital -B: force-reset"
echo "        3. git commit --allow-empty -m 'chore: begin $BRANCH_LEAF'"
echo "        4. Cherry-pick only non-state commits from the old branch."
exit 1
