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

# Find any .hyperloop/state/ files actually committed on this branch.
# We use git log (not git diff) so that state files updated on main AFTER
# this branch last rebased do not produce false positives.  git diff
# main..HEAD compares the two tips, so a file changed on main post-rebase
# appears in the diff even though the implementer never staged it.
# git log main..HEAD enumerates only commits that exist on this branch but
# not on main, and lists only files those commits actually touched.
STATE_FILES=$(git log main..HEAD --name-only --pretty="" 2>/dev/null \
    | grep '^\.hyperloop/state/' | sort -u || true)

if [ -n "$STATE_FILES" ]; then
    echo "FAIL: Branch commits include .hyperloop/state/ files managed by the orchestrator."
    echo ""
    echo "      These files conflict with the orchestrator's own state on main and"
    echo "      will cause permanent rebase failures, forcing a branch reset."
    echo ""
    echo "      State files committed on this branch:"
    echo "$STATE_FILES" | sed 's/^/  /'
    echo ""
    echo "      To confirm: run 'git log main..HEAD --oneline -- <file>' for each"
    echo "      listed file and verify a commit on this branch introduced it."
    echo ""
    echo "      Remove them from the branch history (branch commits only — NOT main):"
    echo "        git filter-branch --index-filter \\"
    echo "          'git rm --cached --ignore-unmatch .hyperloop/state/*' \\"
    echo "          -- main..HEAD"
    echo "      OR cherry-pick only non-state commits onto a fresh branch."
    echo ""
    echo "      CAUTION: If check-checkpoint-commit-is-first.sh ALSO fails, you must"
    echo "      run filter-branch (above) FIRST, then 'git rebase -i main' to reorder"
    echo "      commits.  Reversing the order invalidates the rebase plan because"
    echo "      filter-branch rewrites commit SHAs.  See check-combined-rewrite-guide.sh"
    echo "      for the exact combined command sequence."
    echo ""
    echo "      Prevention: never use 'git add -A' or 'git add .'. Stage only"
    echo "      source files and .hyperloop/worker-result.yaml explicitly."
    exit 1
fi

echo "OK: No .hyperloop/state/ files committed on branch '$CURRENT_BRANCH'."
exit 0
