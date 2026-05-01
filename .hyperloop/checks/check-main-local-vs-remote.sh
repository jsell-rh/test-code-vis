#!/usr/bin/env bash
# check-main-local-vs-remote.sh
#
# Verifies that local 'main' matches the cached origin/main ref.
#
# Two distinct failure modes with different root causes and fixes:
#
#   AHEAD  — local main has commits not on origin/main.
#            Root cause: orchestrator committed to local main without pushing.
#            Fix (ORCHESTRATOR): git push origin main
#            Implementers cannot resolve this — git fetch cannot rewind local main.
#
#   BEHIND — local main is missing commits that are on origin/main.
#            Root cause: implementer/verifier has a stale local main.
#            Fix (IMPLEMENTER/VERIFIER): git fetch origin main:main
#
#   DIVERGED — local and origin/main have different histories (force-push or rebase).
#              Fix: investigate carefully before taking action.
#
# Historical pattern:
#   task-108 rounds 7–9: orchestrator committed check-pass-report-no-raw-fail-lines.sh
#   to local main without pushing → every verifier worktree saw FAIL here → 3
#   extra rounds of FAST-FIX FAIL on an excellent implementation.
#
#   task-011, task-108 round 10 (same cycle): a process-improvement session committed
#   3 commits (chore(intake), process: fix spec-ref check, feat(tasks): intake) to
#   local main without pushing → both tasks failed here despite correct implementations.
#   The process-improvement commit itself (`process: fix spec-ref check`) was one of
#   the unpushed commits — the session that produced it did not push before closing.
#
# Exit 0 — local main matches origin/main (or remote ref unavailable: SKIP)
# Exit 1 — local main is ahead, behind, or diverged from origin/main

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

# Diagnose: ahead, behind, or diverged?
AHEAD=false
BEHIND=false

if git merge-base --is-ancestor "$ORIGIN" "$LOCAL" 2>/dev/null; then
  AHEAD=true
fi
if git merge-base --is-ancestor "$LOCAL" "$ORIGIN" 2>/dev/null; then
  BEHIND=true
fi

if $AHEAD && ! $BEHIND; then
  echo "FAIL (ORCHESTRATOR): local main ($LOCAL) is AHEAD of origin/main ($ORIGIN)."
  echo "  An orchestrator committed to local main without pushing. Implementers cannot"
  echo "  resolve this — 'git fetch origin main:main' cannot rewind local main."
  echo "  check-sync failures caused by this are ORCHESTRATOR errors, not implementer errors."
  echo ""
  echo "  Fix (ORCHESTRATOR — run on the main worktree, not a task worktree):"
  echo "    git push origin main"
  echo ""
  echo "  Verifiers: classify this failure as ORCHESTRATOR CONFIGURATION in findings."
  echo "  If this is the ONLY check failure and the branch is otherwise correct, apply"
  echo "  FAST-FIX classification — the required fix is 'git push origin main', not"
  echo "  an implementer sync commit."
  exit 1
fi

if $BEHIND && ! $AHEAD; then
  echo "FAIL (SYNC): local main ($LOCAL) is BEHIND origin/main ($ORIGIN)."
  echo "  Running 'git checkout main -- .hyperloop/checks/' with a stale local main"
  echo "  silently omits check scripts added to origin/main since your last fetch."
  echo ""
  echo "  Fix (run before every sync point):"
  echo "    git fetch origin main:main"
  echo "    git checkout main -- .hyperloop/checks/"
  echo "    bash .hyperloop/checks/check-checks-in-sync.sh"
  exit 1
fi

# Diverged — neither is ancestor of the other
echo "FAIL (DIVERGED): local main ($LOCAL) has diverged from origin/main ($ORIGIN)."
echo "  Local main and origin/main have different histories — possible force-push or rebase."
echo ""
echo "  Diagnose before acting (do NOT discard either side without understanding the diff):"
echo "    git log --oneline origin/main..main   # commits only on local main"
echo "    git log --oneline main..origin/main   # commits only on origin/main"
exit 1
