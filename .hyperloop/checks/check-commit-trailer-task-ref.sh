#!/usr/bin/env bash
# check-commit-trailer-task-ref.sh
#
# Verifies that implementation commits on a task branch carry a Task-Ref
# commit trailer that matches the branch's task ID.
#
# Observed pattern (task-014):
#   The sole implementation commit (997ac245) carried Task-Ref: task-007
#   while the branch was hyperloop/task-014.  This indicates the commit was
#   copied from another task without updating the trailer, making the audit
#   trail unreliable.
#
# Algorithm:
#   1. Extract the task ID from the branch name (hyperloop/task-NNN → task-NNN).
#   2. Walk implementation commits (those that touch non-.hyperloop/ files).
#   3. For each commit that HAS a Task-Ref trailer, verify it equals task-NNN.
#   4. Exit 1 if any mismatch is found.
#
# Note: commits with NO Task-Ref trailer are not flagged here — a separate
# check or review step handles trailer presence.  This check focuses on
# mismatched (wrong-task) trailers, which are the observed failure mode.
#
# Exit 0 = all Task-Ref trailers match the branch task ID, or SKIP.
# Exit 1 = one or more commits carry a wrong Task-Ref.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

# Extract task ID from branch name (e.g., hyperloop/task-014 → task-014)
TASK_ID=$(echo "$CURRENT_BRANCH" | grep -oE 'task-[0-9]+' | head -1 || true)
if [[ -z "$TASK_ID" ]]; then
    echo "SKIP: Branch name '$CURRENT_BRANCH' does not contain a task-NNN identifier."
    exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COMMIT_COUNT" -le 0 ]]; then
    echo "SKIP: No commits above main."
    exit 0
fi

FAIL=0
MISMATCHED=""

while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue

    # Classify as implementation commit: touches at least one non-.hyperloop/ file.
    CHANGED=$(git show --name-only --format="" "$sha" 2>/dev/null | grep -v '^$' || true)
    NON_HYPERLOOP=$(echo "$CHANGED" | grep -v '^\.hyperloop/' | grep -c '.' 2>/dev/null || true)
    [[ "$NON_HYPERLOOP" -eq 0 ]] && continue  # process/report-only commit — skip

    # Read the Task-Ref trailer from this commit.
    TASK_REF=$(git show -s --format="%B" "$sha" 2>/dev/null \
        | grep '^Task-Ref:' \
        | head -1 \
        | sed 's/^Task-Ref:[[:space:]]*//' \
        | tr -d '[:space:]' \
        || true)

    # No Task-Ref at all — a different issue; not flagged here.
    [[ -z "$TASK_REF" ]] && continue

    if [[ "$TASK_REF" != "$TASK_ID" ]]; then
        MISMATCHED="${MISMATCHED}  ${sha:0:7}  Task-Ref: $TASK_REF  (expected $TASK_ID)\n"
        FAIL=1
    fi
done < <(git log main..HEAD --format="%H" 2>/dev/null)

if [[ $FAIL -eq 0 ]]; then
    echo "OK: All Task-Ref trailers on implementation commits match branch task ID '$TASK_ID'."
    exit 0
fi

echo "FAIL: One or more implementation commits carry a Task-Ref that does not match the branch."
echo ""
echo "  Branch:   $CURRENT_BRANCH"
echo "  Expected: Task-Ref: $TASK_ID"
echo ""
echo "  Mismatched commits:"
printf "%b" "$MISMATCHED"
echo ""
echo "  This typically happens when a commit is copied from another task without"
echo "  updating the Task-Ref trailer.  Fix with an interactive rebase:"
echo "    git rebase -i main   # mark each affected commit as 'reword'"
echo "    # update Task-Ref: <old> to Task-Ref: $TASK_ID in each message"
echo ""
echo "  Confirm the branch task ID before each commit:"
echo "    git rev-parse --abbrev-ref HEAD   # shows hyperloop/$TASK_ID"
exit 1
