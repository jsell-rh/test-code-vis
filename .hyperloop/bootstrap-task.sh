#!/usr/bin/env bash
# bootstrap-task.sh
# Performs the mandatory two-step checkpoint sequence as a single atomic command.
#
# Usage: bash .hyperloop/bootstrap-task.sh <task-id>
#   e.g. bash .hyperloop/bootstrap-task.sh task-001
#
# This script MUST be the implementer's very first Bash call.
# It replaces the manual two-command sequence:
#   git checkout -B <task-id>
#   git commit --allow-empty -m "chore: begin <task-id>"
#
# Motivation: "Agent future missing or failed" has recurred despite extensive
# overlay guidance because agents execute the two commands separately — a crash
# or wrong first call between them leaves no liveness signal.  Running this
# script as a single first Bash call is the safest path.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "ERROR: Usage: bash .hyperloop/bootstrap-task.sh <task-id>"
    echo "       Example: bash .hyperloop/bootstrap-task.sh task-001"
    exit 1
fi

TASK_ID="$1"

# Validate task-id looks like a task reference (non-empty, no spaces)
if [[ -z "$TASK_ID" || "$TASK_ID" =~ [[:space:]] ]]; then
    echo "ERROR: task-id must be non-empty and contain no spaces. Got: '$TASK_ID'"
    exit 1
fi

echo "=== bootstrap-task.sh: $TASK_ID ==="
echo ""

# Step 1: create/force-reset the task branch
echo "Step 1: git checkout -B $TASK_ID"
if ! git checkout -B "$TASK_ID"; then
    echo ""
    echo "ERROR: 'git checkout -B $TASK_ID' failed. STOP — do not proceed."
    echo "       Report this error verbatim and stop all implementation work."
    exit 1
fi

# Verify we are now on the correct branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" != "$TASK_ID" ]; then
    echo ""
    echo "ERROR: Branch mismatch after checkout."
    echo "       Expected: $TASK_ID"
    echo "       Got:      $CURRENT_BRANCH"
    echo "       STOP — do not proceed. Report this error verbatim."
    exit 1
fi

echo "       Branch confirmed: $CURRENT_BRANCH"
echo ""

# Step 2: empty checkpoint commit (liveness signal to orchestrator)
echo "Step 2: git commit --allow-empty -m 'chore: begin $TASK_ID'"
if ! git commit --allow-empty -m "chore: begin $TASK_ID"; then
    echo ""
    echo "ERROR: Checkpoint commit failed. STOP — do not proceed."
    echo "       Report this error verbatim and stop all implementation work."
    exit 1
fi

echo ""
echo "=== Bootstrap complete ==="
echo "Branch  : $CURRENT_BRANCH"
echo "Commit  : $(git log -1 --pretty=format:'%h %s')"
echo ""
echo "The orchestrator liveness signal is now registered."
echo "You may now read specs, explore code, and implement."
