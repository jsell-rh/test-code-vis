#!/usr/bin/env bash
# check-branch-forked-from-main.sh
#
# Detects implementation commits on this branch that belong to a different task.
# This typically indicates the branch was forked from another task branch rather
# than directly from main, causing those commits to be inherited.
#
# Observed pattern (task-119):
#   Branch hyperloop/task-119 was forked from hyperloop/task-020 (or similar)
#   rather than from main.  Commit 5faf01e6 (Task-Ref: task-061) was inherited
#   and appeared above main.  The commit was genuine task-061 work; it should
#   be DROPPED — not reworded — via `git rebase --onto main`.
#
# Distinction from check-commit-trailer-task-ref.sh:
#   That check catches ALL Task-Ref mismatches and advises `reword`.
#   This check identifies commits already merged to main (i.e., truly inherited)
#   and advises DROP via --onto rebase, which is the correct fix for that case.
#
# Exit 0 = no inherited foreign-task commits detected, or SKIP.
# Exit 1 = inherited commits found; branch must be rebased onto main.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

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
INHERITED_LINE=""   # commits already merged to main (true inherited commits)
FOREIGN_LINE=""     # commits made on this branch with a wrong Task-Ref

# Walk commits oldest-to-newest so advice references the right SHA
while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue

    # Only inspect implementation commits (touches at least one non-.hyperloop/ file).
    CHANGED=$(git show --name-only --format="" "$sha" 2>/dev/null | grep -v '^$' || true)
    NON_HYPERLOOP=$(echo "$CHANGED" | grep -v '^\.hyperloop/' | grep -c '.' 2>/dev/null || true)
    [[ "$NON_HYPERLOOP" -eq 0 ]] && continue

    TASK_REF=$(git show -s --format="%B" "$sha" 2>/dev/null \
        | grep '^Task-Ref:' \
        | head -1 \
        | sed 's/^Task-Ref:[[:space:]]*//' \
        | tr -d '[:space:]' \
        || true)

    # No Task-Ref trailer: different issue, not flagged here.
    [[ -z "$TASK_REF" ]] && continue

    # Matching trailer: all good.
    [[ "$TASK_REF" == "$TASK_ID" ]] && continue

    # Foreign Task-Ref: determine whether this commit already exists on main.
    if git merge-base --is-ancestor "$sha" main 2>/dev/null; then
        INHERITED_LINE="${INHERITED_LINE}    ${sha:0:7}  Task-Ref: $TASK_REF  [on main — inherited from another task branch]\n"
        FAIL=1
    else
        FOREIGN_LINE="${FOREIGN_LINE}    ${sha:0:7}  Task-Ref: $TASK_REF  [made on this branch with wrong trailer — reword]\n"
        FAIL=1
    fi
done < <(git log main..HEAD --format="%H" --reverse 2>/dev/null)

if [[ $FAIL -eq 0 ]]; then
    echo "OK: No inherited foreign-task commits detected on '$CURRENT_BRANCH'."
    exit 0
fi

echo "FAIL: Branch '$CURRENT_BRANCH' contains commits that do not belong to $TASK_ID."
echo ""

if [[ -n "$INHERITED_LINE" ]]; then
    echo "  INHERITED commits (already on main — must be DROPPED, not reworded):"
    printf "%b" "$INHERITED_LINE"
    echo "  These commits arrived because the branch was forked from another task"
    echo "  branch instead of directly from main."
    echo ""
    echo "  Fix — rebase onto main, dropping the inherited commits:"
    echo "    git log --oneline main..HEAD         # identify which commits are yours"
    echo "    git rebase -i main                   # mark inherited commits as 'drop'"
    echo "    bash .hyperloop/checks/check-branch-forked-from-main.sh  # confirm exit 0"
    echo ""
    echo "  For future branches, always fork from main:"
    echo "    git checkout main && git checkout -b hyperloop/$TASK_ID"
fi

if [[ -n "$FOREIGN_LINE" ]]; then
    echo "  FOREIGN-TRAILER commits (made on this branch with wrong Task-Ref — reword):"
    printf "%b" "$FOREIGN_LINE"
    echo "  Fix:"
    echo "    git rebase -i main   # mark each as 'reword'; update Task-Ref to $TASK_ID"
fi

exit 1
