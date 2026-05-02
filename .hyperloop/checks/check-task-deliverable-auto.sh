#!/usr/bin/env bash
# check-task-deliverable-auto.sh
#
# Automatically detects the task ID from the current branch name and verifies
# the branch contains files from the component named in the task title.
#
# This is the auto-detection companion to check-deliverable-component.sh.
# run-all-checks.sh calls every *.sh with no arguments, so
# check-deliverable-component.sh always SKIPs in that context (it requires an
# explicit task-id argument).  This script extracts the task ID from the branch
# name and delegates to the component check automatically — ensuring
# wrong-deliverable branches are caught by run-all-checks.sh without requiring
# a separate manual invocation.
#
# Observed failure (task-082): title "Extractor — structural significance (hub,
# bridge, peripheral, community)".  The implementer found compute_structural_
# significance() already on main and implemented Port Primitive (task-088 scope)
# instead.  check-deliverable-component.sh was not run manually with the task ID;
# and even if it had been, the old extractor regex "^(Python extractor|extractor:)"
# would not have matched the "Extractor —" separator style.  This auto-detection
# check closes the omission: run-all-checks.sh now always exercises the deliverable
# gate on task branches.
#
# Usage:
#   bash .hyperloop/checks/check-task-deliverable-auto.sh   # auto-detect
#
# Exit codes:
#   0 — component match confirmed, or SKIP (not a task branch / task file absent)
#   1 — task title names a component with zero matching files on the branch

set -uo pipefail

CHECKS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Auto-detect task ID from current branch name ─────────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Accept branch names like hyperloop/task-082 or task-082
TASK_ID=$(echo "$BRANCH" | grep -oP '(?<=hyperloop/)task-\d+' || true)
if [ -z "$TASK_ID" ]; then
    TASK_ID=$(echo "$BRANCH" | grep -oP '^task-\d+' || true)
fi

if [ -z "$TASK_ID" ]; then
    echo "SKIP: not on a hyperloop task branch (branch: ${BRANCH:-<detached HEAD>})"
    exit 0
fi

# ── Delegate to check-deliverable-component.sh ───────────────────────────────
exec bash "${CHECKS_DIR}/check-deliverable-component.sh" "$TASK_ID"
