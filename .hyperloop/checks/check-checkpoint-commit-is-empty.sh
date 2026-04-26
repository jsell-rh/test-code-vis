#!/usr/bin/env bash
# check-checkpoint-commit-is-empty.sh
# Verifies the checkpoint commit ("chore: begin <task-id>") contains NO file
# changes — i.e., it was created with `git commit --allow-empty`.
#
# Motivation: task-001 has repeatedly produced "Agent future missing or failed"
# despite overlay guidance requiring the checkpoint as the first action. One
# remaining failure mode is an agent that stages files (spec, task YAML, or
# source) before making the checkpoint commit, creating a non-empty first commit.
# A non-empty checkpoint commit indicates the agent read or modified files before
# branching, meaning a crash in the same moment would leave no clean liveness
# signal. This check enforces the empty-commit contract mechanically.
#
# A checkpoint commit that includes file changes also risks committing
# .hyperloop/state/ files (caught by check-no-state-files-committed.sh) and
# suggests the agent violated the "zero tool calls before checkpoint" rule.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo "SKIP: Detached HEAD — checkpoint empty-commit check not applicable"
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

# Find the checkpoint commit hash (search for "chore: begin " in commit subjects)
CHECKPOINT_HASH=$(git log main..HEAD --pretty=format:"%H %s" 2>/dev/null \
    | grep ' chore: begin ' | tail -1 | awk '{print $1}' || true)

if [ -z "$CHECKPOINT_HASH" ]; then
    echo "SKIP: No checkpoint commit found — check-checkpoint-commit.sh handles this"
    exit 0
fi

CHECKPOINT_SUBJECT=$(git log -1 --pretty=format:"%s" "$CHECKPOINT_HASH" 2>/dev/null || true)

# Count files changed in the checkpoint commit
FILE_COUNT=$(git show --stat "$CHECKPOINT_HASH" 2>/dev/null \
    | grep -c ' file changed\| files changed' || true)

# Alternative: check the diff directly (empty commit has no diff)
DIFF_LINES=$(git diff-tree --no-commit-id -r "$CHECKPOINT_HASH" 2>/dev/null | wc -l | tr -d ' ')

if [ "$DIFF_LINES" -eq 0 ]; then
    echo "OK: Checkpoint commit '$CHECKPOINT_SUBJECT' is empty (no file changes) — correct use of --allow-empty"
    exit 0
fi

echo "FAIL: Checkpoint commit '$CHECKPOINT_SUBJECT' contains file changes."
echo ""
echo "      The checkpoint commit MUST be created with:"
echo "        git commit --allow-empty -m \"chore: begin <task-id>\""
echo ""
echo "      A non-empty checkpoint indicates the agent staged or modified files"
echo "      BEFORE making the checkpoint commit, violating the zero-tool-calls-before-"
echo "      checkpoint protocol. This means a crash at that moment would produce"
echo "      'Agent future missing or failed' with no recoverable liveness signal."
echo ""
echo "      Files changed in the checkpoint commit ($CHECKPOINT_HASH):"
git diff-tree --no-commit-id -r --name-only "$CHECKPOINT_HASH" 2>/dev/null | sed 's/^/  /'
echo ""
echo "      Fix: reorder commits with an interactive rebase so the empty"
echo "      checkpoint commit comes first, or amend it to remove the files"
echo "      (moving them to a subsequent implementation commit)."
exit 1
