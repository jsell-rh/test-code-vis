#!/usr/bin/env bash
# check-not-on-main.sh
# Fails if the current branch is 'main'.
#
# Motivation: task-001 recurred with "Agent future missing or failed" because
# implementers sometimes make the checkpoint commit on 'main' (following the
# "first Bash call = git commit" rule literally, before reading the branch-null
# rule that requires `git checkout -B` first).  A checkpoint commit on 'main'
# is invisible to `git log main..HEAD` on the task branch and causes the
# orchestrator to see no signal that the agent ran.
#
# This check catches the symptom at submission time so the problem can be
# corrected before the verifier runs.
#
# Exit 0 = OK.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — branch identity check not applicable"
    exit 0
fi

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "FAIL: Current branch is 'main'."
    echo ""
    echo "      Implementers MUST work on a task branch, never on 'main'."
    echo "      A checkpoint commit made on 'main' is invisible to the"
    echo "      orchestrator (git log main..HEAD shows nothing) and causes"
    echo "      the task cycle to be reported as 'Agent future missing or failed'."
    echo ""
    echo "      Fix: create the task branch and re-make the checkpoint commit:"
    echo "        git checkout -B <task-id>"
    echo "        git commit --allow-empty -m \"chore: begin <task-id>\""
    echo "      then cherry-pick or re-apply any implementation commits."
    exit 1
fi

echo "OK: Current branch is '$CURRENT_BRANCH' (not main)"
exit 0
