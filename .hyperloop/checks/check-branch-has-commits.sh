#!/usr/bin/env bash
# check-branch-has-commits.sh
# Verifies the current branch has at least one commit above main.
#
# Motivation: task-025 submitted a branch identical to main — zero commits,
# no implementation at all. Every downstream check then reported against the
# unmodified codebase, producing spurious pre-existing failures. This script
# catches the empty-branch case before any other check runs.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — branch commit check not applicable"
    exit 0
fi

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "SKIP: On main branch — branch commit check not applicable"
    exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')

if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "FAIL: Branch '$CURRENT_BRANCH' has NO commits above main."
    echo "      This branch is identical to main — no implementation was committed."
    echo "      Commit your work before submitting. A submission with an empty branch"
    echo "      is not a partial implementation — it is no implementation at all."
    exit 1
fi

echo "OK: Branch '$CURRENT_BRANCH' has $COMMIT_COUNT commit(s) above main."
exit 0
