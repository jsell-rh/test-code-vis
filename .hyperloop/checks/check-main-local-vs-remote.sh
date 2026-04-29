#!/usr/bin/env bash
# check-main-local-vs-remote.sh
#
# Verifies that local 'main' matches the cached origin/main ref.
#
# A stale local 'main' causes:
#   git checkout main -- .hyperloop/checks/
# to pull an outdated set of check scripts, silently omitting new ones
# that were added to origin/main since the last fetch.
#
# Root cause observed: task-108 round-6 missed check-branch-forked-from-main.sh
# which was on origin/main before the sync but absent from local main.
#
# Run this BEFORE both sync points:
#   git fetch origin main:main          # update local main from remote
#   git checkout main -- .hyperloop/checks/
#   bash .hyperloop/checks/check-checks-in-sync.sh
#
# Exit 0 — local main matches origin/main (or remote ref unavailable: SKIP)
# Exit 1 — local main is behind or diverged from origin/main

set -euo pipefail

LOCAL=$(git rev-parse main 2>/dev/null || true)
ORIGIN=$(git rev-parse origin/main 2>/dev/null || true)

if [ -z "$LOCAL" ]; then
  echo "SKIP: local 'main' branch not found — cannot verify staleness."
  exit 0
fi

if [ -z "$ORIGIN" ]; then
  echo "SKIP: origin/main ref not found — run 'git fetch origin' to populate it."
  echo "  Without a remote ref, staleness cannot be detected."
  exit 0
fi

if [ "$LOCAL" = "$ORIGIN" ]; then
  echo "OK: local main ($LOCAL) matches origin/main — sync will be complete."
  exit 0
fi

echo "FAIL: local main ($LOCAL) does not match origin/main ($ORIGIN)."
echo "  Running 'git checkout main -- .hyperloop/checks/' with a stale local main"
echo "  silently omits check scripts added to origin/main since your last fetch."
echo ""
echo "  Fix (run before every sync point):"
echo "    git fetch origin main:main"
echo "    git checkout main -- .hyperloop/checks/"
echo "    bash .hyperloop/checks/check-checks-in-sync.sh"
exit 1
