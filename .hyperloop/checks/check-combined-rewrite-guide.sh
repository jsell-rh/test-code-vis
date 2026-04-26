#!/usr/bin/env bash
# check-combined-rewrite-guide.sh
#
# Detects when BOTH a state-file violation (F2) AND a checkpoint-ordering
# violation (F4) are present on the same branch simultaneously.
#
# Observed pattern (task-007, cycles 1–5): the implementer attempted the fixes
# separately across multiple cycles, each time rewriting only part of the
# required change.  The correct sequence is:
#   1. filter-branch  — removes state files from all branch commits.
#   2. rebase -i      — reorders commits so checkpoint is first.
# These MUST run in this order because filter-branch rewrites commit SHAs,
# which invalidates any rebase plan made before it runs.
#
# This check does NOT add a new blocking failure — the individual checks
# (check-no-state-files-committed.sh and check-checkpoint-commit-is-first.sh)
# already block submission.  Its purpose is to emit a single, consolidated
# remediation guide when both violations coexist, so the implementer can
# resolve them in one coordinated operation rather than discovering the
# ordering constraint after a failed partial fix.
#
# Exit 0 always (guidance only — other checks provide the blocking gate).

set -uo pipefail

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "HEAD" || "$CURRENT_BRANCH" == "main" ]]; then
  echo "SKIP: Not on a task branch — combined rewrite guide not applicable."
  exit 0
fi

COMMIT_COUNT=$(git log main..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COMMIT_COUNT" -eq 0 ]]; then
  echo "SKIP: No commits above main — combined rewrite guide not applicable."
  exit 0
fi

# ── Detect F2: state files in branch history ──────────────────────────────────
STATE_FILES=$(git log main..HEAD --name-only --pretty="" 2>/dev/null \
  | grep '^\.hyperloop/state/' | sort -u || true)
HAS_STATE_VIOLATION=0
[[ -n "$STATE_FILES" ]] && HAS_STATE_VIOLATION=1

# ── Detect F4: checkpoint commit is not the oldest commit on branch ───────────
FIRST_COMMIT=$(git log main..HEAD --reverse --pretty=format:"%s" 2>/dev/null | head -1 || true)
HAS_ORDER_VIOLATION=0
if ! echo "$FIRST_COMMIT" | grep -qE '^chore: begin '; then
  HAS_ORDER_VIOLATION=1
fi

# ── Both violations present → emit combined guide ─────────────────────────────
if [[ $HAS_STATE_VIOLATION -eq 1 && $HAS_ORDER_VIOLATION -eq 1 ]]; then
  TASK_ID=$(echo "$CURRENT_BRANCH" | sed 's|hyperloop/||')
  cat <<EOF
GUIDE: Both F2 (state files in history) and F4 (checkpoint not first) detected
       on branch '$CURRENT_BRANCH'.  These require a single coordinated rewrite.

  MANDATORY ORDER — do NOT reverse these steps:

  Step 1 — Remove state files from branch commit history (NOT main):
    git filter-branch --index-filter \\
      'git rm --cached --ignore-unmatch .hyperloop/state/*' \\
      -- main..HEAD

    (This rewrites commit SHAs — any rebase plan made before this step
    will be invalid.  Always run filter-branch FIRST.)

  Step 2 — Reorder commits so checkpoint is oldest:
    git rebase -i main
    (In the editor: move 'chore: begin ${TASK_ID}' to the TOP of the list,
    save, and quit.)

  Step 3 — Verify both fixes:
    git log main..HEAD --oneline -- '.hyperloop/state/'
    # → must return EMPTY (no state files in branch history)

    git log main..HEAD --reverse --pretty=format:"%s" | head -1
    # → must return: chore: begin ${TASK_ID}

  Step 4 — Run checks to confirm:
    bash .hyperloop/checks/check-no-state-files-committed.sh
    bash .hyperloop/checks/check-checkpoint-commit-is-first.sh
    # → both must exit 0 before running run-all-checks.sh

  REMINDER: Do NOT add new commits between Step 1 and Step 2 — doing so
  will reintroduce checkpoint-ordering violations after the rebase.
EOF
  exit 0
fi

# ── Single violation — point to the individual check ─────────────────────────
if [[ $HAS_STATE_VIOLATION -eq 1 ]]; then
  echo "INFO: State-file violation (F2) detected without checkpoint-ordering violation."
  echo "      See check-no-state-files-committed.sh output for remediation commands."
  exit 0
fi

if [[ $HAS_ORDER_VIOLATION -eq 1 ]]; then
  echo "INFO: Checkpoint-ordering violation (F4) detected without state-file violation."
  echo "      Run 'git rebase -i main' and move 'chore: begin ...' to the top."
  exit 0
fi

echo "OK: No combined rewrite condition detected on branch '$CURRENT_BRANCH'."
exit 0
