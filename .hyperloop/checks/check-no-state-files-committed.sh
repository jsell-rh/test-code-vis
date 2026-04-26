#!/usr/bin/env bash
# check-no-state-files-committed.sh
# Verifies the task branch has NOT committed any .hyperloop/state/ files.
#
# Motivation: task-007 failed twice with "3 consecutive rebase/merge failures.
# The branch likely has state files in its commit history that cause permanent
# conflicts." .hyperloop/state/ files (task YAMLs, review files, intake records)
# are managed exclusively by the orchestrator and written to main directly.
# When an implementer stages them (e.g. via `git add -A`), they appear in the
# branch history and conflict with the orchestrator's version on main at rebase
# time — making the branch permanently unmergeable.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — state-file check not applicable"
    exit 0
fi

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "SKIP: On main branch — state-file check not applicable"
    exit 0
fi

# Check if branch has any commits at all; let the other check handle that.
COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "SKIP: No commits above main — check-branch-has-commits.sh will catch this"
    exit 0
fi

# Find any .hyperloop/state/ files committed on this branch.
STATE_FILES=$(git diff --name-only main..HEAD 2>/dev/null \
    | grep '^\.hyperloop/state/' || true)

if [ -n "$STATE_FILES" ]; then
    echo "FAIL: Branch commits include .hyperloop/state/ files managed by the orchestrator."
    echo ""
    echo "      These files conflict with the orchestrator's own state on main and"
    echo "      will cause permanent rebase failures, forcing a branch reset."
    echo ""
    echo "      State files found on this branch:"
    echo "$STATE_FILES" | sed 's/^/  /'
    echo ""
    echo "      Remove them from the branch history:"
    echo "        git filter-branch --index-filter \\"
    echo "          'git rm --cached --ignore-unmatch .hyperloop/state/*' HEAD"
    echo "      OR cherry-pick only non-state commits onto a fresh branch."
    echo ""
    echo "      Prevention: never use 'git add -A' or 'git add .'. Stage only"
    echo "      source files and .hyperloop/worker-result.yaml explicitly."
    exit 1
fi

echo "OK: No .hyperloop/state/ files committed on branch '$CURRENT_BRANCH'."
exit 0
