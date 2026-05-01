#!/usr/bin/env bash
# check-rebased-onto-main.sh
#
# Verifies the working branch has been rebased onto the current tip of origin/main.
# A branch that forked from main but was NEVER rebased after main advanced will have
# a merge-base behind origin/main — merging such a branch SILENTLY DELETES every
# commit main added after the fork point.
#
# Observed pattern (task-108, round 8):
#   Branch forked from db76c822; main advanced to b37b6863 (task-074 work merged).
#   Branch was never rebased. Diff against main showed -compute_structural_significance()
#   and -schema fields that task-074 had added. 161 tests passed because the deleted
#   test file (test_visual_primitives.gd) was simply never registered or executed.
#   check-branch-forked-from-main.sh passed (no foreign commits) — it detects a
#   different problem and cannot detect this regression pattern.
#
# This check fills the gap: it verifies origin/main IS an ancestor of HEAD.
#
# Exit 0 = branch includes all commits from origin/main (rebased or up to date).
# Exit 1 = branch is behind origin/main (rebase required before merge).
# Exit 0 (SKIP) = not on a task branch, or cannot resolve git refs.

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
    echo "SKIP: Not on a task branch."
    exit 0
fi

# Fetch to ensure origin/main is current before comparison.
git fetch origin main:main --quiet 2>/dev/null || true

ORIGIN_MAIN=$(git rev-parse origin/main 2>/dev/null || echo "")
if [[ -z "$ORIGIN_MAIN" ]]; then
    echo "SKIP: Cannot resolve origin/main — run 'git fetch origin' first."
    exit 0
fi

MERGE_BASE=$(git merge-base HEAD origin/main 2>/dev/null || echo "")
if [[ -z "$MERGE_BASE" ]]; then
    echo "SKIP: Cannot compute merge-base between HEAD and origin/main."
    exit 0
fi

if [[ "$MERGE_BASE" == "$ORIGIN_MAIN" ]]; then
    echo "OK: Branch '$CURRENT_BRANCH' is rebased onto origin/main (${ORIGIN_MAIN:0:7})."
    exit 0
fi

COMMITS_BEHIND=$(git rev-list "${MERGE_BASE}..origin/main" --count 2>/dev/null || echo "?")
echo "FAIL: Branch '$CURRENT_BRANCH' is NOT rebased onto origin/main."
echo ""
echo "  Fork point (merge-base): ${MERGE_BASE:0:7}"
echo "  origin/main HEAD:        ${ORIGIN_MAIN:0:7}"
echo "  Commits on main not in branch: $COMMITS_BEHIND"
echo ""
echo "  RISK: Merging this branch as-is would REVERT all $COMMITS_BEHIND commit(s)"
echo "  that main added after ${MERGE_BASE:0:7}. Inspect what would be lost:"
echo "    git log ${MERGE_BASE:0:7}..origin/main --oneline"
echo ""
echo "  Fix:"
echo "    git fetch origin main:main"
echo "    git rebase origin/main"
echo "    # During conflict resolution:"
echo "    #   KEEP all functions/files main added (the incoming 'theirs' side)."
echo "    #   Apply your changes ON TOP — never choose 'ours' to discard main work."
echo "    # After rebase completes:"
echo "    bash .hyperloop/checks/check-run-tests-suite-count.sh   # guard against suite regression"
echo "    bash .hyperloop/checks/run-all-checks.sh"
exit 1
