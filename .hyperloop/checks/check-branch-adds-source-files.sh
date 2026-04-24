#!/usr/bin/env bash
# check-branch-adds-source-files.sh
# Verifies the current branch has at least one commit that adds or modifies
# source files outside .hyperloop/.
#
# Motivation: task-030 submitted a branch where both implementation commits
# only modified .hyperloop/worker-result.yaml. The actual source files
# (understanding_overlay.gd, test_understanding_overlay.gd) were introduced
# by task-031's commit. Task-030 then wrote a worker result claiming those
# files as its own deliverable — a free-ride with no code contribution.
# This script catches that pattern mechanically.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — source-file check not applicable"
    exit 0
fi

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "SKIP: On main branch — source-file check not applicable"
    exit 0
fi

# If branch has no commits at all, let check-branch-has-commits.sh handle it.
COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "SKIP: No commits above main — check-branch-has-commits.sh will catch this"
    exit 0
fi

# Collect all files added or modified by commits on this branch, excluding .hyperloop/
SOURCE_FILES=$(git diff --name-only --diff-filter=AM main..HEAD 2>/dev/null \
    | grep -v '^\.hyperloop/' || true)

if [ -z "$SOURCE_FILES" ]; then
    echo "FAIL: This branch has no commits that add or modify source files outside .hyperloop/."
    echo "      All changes are confined to .hyperloop/ (e.g., worker-result.yaml only)."
    echo ""
    echo "      Commits on this branch:"
    git log main..HEAD --oneline 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "      Files changed on this branch (all paths):"
    git diff --name-only main..HEAD 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "      A worker result is only valid when the implementation files were committed"
    echo "      on THIS branch. Files introduced by a different task's commit do not count"
    echo "      as this task's deliverable — do not claim them."
    exit 1
fi

SOURCE_COUNT=$(echo "$SOURCE_FILES" | wc -l | tr -d ' ')
echo "OK: Branch adds/modifies $SOURCE_COUNT source file(s) outside .hyperloop/:"
echo "$SOURCE_FILES" | head -10 | sed 's/^/  /'
if [ "$SOURCE_COUNT" -gt 10 ]; then
    REMAINING=$((SOURCE_COUNT - 10))
    echo "  ... (and $REMAINING more)"
fi
exit 0
