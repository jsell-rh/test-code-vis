#!/usr/bin/env bash
# check-main-not-diverged.sh
#
# SESSION-END GUARD for orchestrator/intake/process-improvement sessions.
#
# Checks for TWO failure modes that cause check-main-local-vs-remote.sh to
# fail in every verifier worktree, penalizing implementers for orchestrator errors:
#
#   AHEAD    — local main has commits not on origin/main.
#              Cause: committed locally without pushing.
#              Fix: git push origin main
#
#   DIVERGED — local main and origin/main have unrelated histories.
#              Cause: committed locally without first fetching origin (a PR
#              merged to origin/main while local commits were being made).
#              Fix: git fetch origin main:main && git merge origin/main
#                   git push origin main
#
# This script is intended as a LAST ACTION for any session that commits to main.
# It fetches origin/main so divergence is detected even with a stale remote ref.
#
# Historical pattern:
#   task-012 (1st failure): orchestrator committed check scripts to local main
#     without pushing → AHEAD state.
#   task-012 (2nd failure): intake + process-improvement sessions both committed
#     without pushing → AHEAD state again.
#   task-012 (3rd failure): PR #224 (f038e7c6) merged to origin while local main
#     had unpushed commits 6ea54878 + b28dcc36 → DIVERGED state. Push rejected
#     as non-fast-forward. Required merge commit 601b9613 to resolve.
#
# Exit 0 — local main matches origin/main. Safe to close session.
# Exit 1 — mismatch detected. Resolve and re-run before closing session.

set -uo pipefail

# Fetch so we have the current remote state (catches incoming PR merges).
echo "Fetching origin/main to detect incoming PR merges..."
if ! git fetch origin main 2>/dev/null; then
  echo "WARN: Could not fetch origin/main — proceeding with cached remote ref."
  echo "  Run 'git fetch origin' manually to ensure remote ref is current."
fi

LOCAL=$(git rev-parse main 2>/dev/null || true)
ORIGIN=$(git rev-parse origin/main 2>/dev/null || true)

if [ -z "$LOCAL" ]; then
  echo "SKIP: local 'main' branch not found."
  exit 0
fi

if [ -z "$ORIGIN" ]; then
  echo "SKIP: origin/main ref not found — cannot verify staleness."
  exit 0
fi

if [ "$LOCAL" = "$ORIGIN" ]; then
  echo "OK: local main ($LOCAL) matches origin/main — session is safe to close."
  exit 0
fi

AHEAD=false
BEHIND=false

if git merge-base --is-ancestor "$ORIGIN" "$LOCAL" 2>/dev/null; then
  AHEAD=true
fi
if git merge-base --is-ancestor "$LOCAL" "$ORIGIN" 2>/dev/null; then
  BEHIND=true
fi

if $AHEAD && ! $BEHIND; then
  echo "FAIL (AHEAD): local main ($LOCAL) is AHEAD of origin/main ($ORIGIN)."
  echo "  Cause: committed to local main without pushing."
  echo ""
  echo "  Fix (run now — do NOT close session until check-main-local-vs-remote.sh exits 0):"
  echo "    git push origin main"
  echo "    bash .hyperloop/checks/check-main-local-vs-remote.sh"
  exit 1
fi

if $BEHIND && ! $AHEAD; then
  echo "FAIL (BEHIND): local main ($LOCAL) is BEHIND origin/main ($ORIGIN)."
  echo "  A fetch updated origin/main beyond local main."
  echo ""
  echo "  Fix:"
  echo "    git merge origin/main"
  echo "    git push origin main"
  echo "    bash .hyperloop/checks/check-main-local-vs-remote.sh"
  exit 1
fi

# Diverged — neither is ancestor of the other
AHEAD_COMMITS=$(git log --oneline "$ORIGIN..main" | wc -l | tr -d ' ')
BEHIND_COMMITS=$(git log --oneline "main..$ORIGIN" | wc -l | tr -d ' ')

echo "FAIL (DIVERGED): local main ($LOCAL) has diverged from origin/main ($ORIGIN)."
echo "  Local main is $AHEAD_COMMITS commit(s) ahead and $BEHIND_COMMITS commit(s) behind."
echo ""
echo "  Cause: committed to local main WITHOUT first fetching origin. A PR was merged"
echo "  to origin/main (or someone pushed) while local commits were being added."
echo "  Running 'git push origin main' will fail as non-fast-forward."
echo ""
echo "  Commits only on local main:"
git log --oneline "$ORIGIN..main"
echo ""
echo "  Commits only on origin/main:"
git log --oneline "main..$ORIGIN"
echo ""
echo "  Fix (run now — integrate origin THEN push):"
echo "    git merge origin/main     # integrate the PR merge commit"
echo "    git push origin main      # push the resulting merge"
echo "    bash .hyperloop/checks/check-main-local-vs-remote.sh"
echo ""
echo "  Prevention: always run 'git fetch origin main:main' BEFORE committing to"
echo "  local main. If origin is ahead, merge first, then commit, then push."
exit 1
