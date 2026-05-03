#!/usr/bin/env bash
# check-process-improver-preflight.sh
#
# PROCESS-IMPROVER PREFLIGHT GATE — run at the start of every process-improver
# session BEFORE reading any finding content or writing any overlay.
#
# This script is the mechanical enforcement of the rule:
#   "The process-improver must close banned tasks on hyperloop/state before
#    doing anything else — not document that it should be done."
#
# Root cause it addresses:
#   task-078 triggered STOP PROTOCOL for 6 consecutive rounds. After each round
#   the process-improver added overlay documentation about the required closure
#   commands. The commands were never executed. The task remained in_progress on
#   hyperloop/state, causing the orchestrator to re-assign it every cycle.
#
# What this script does:
#   1. Runs check-banned-task-ids-closed.sh --run to detect open banned tasks.
#   2. If any are found, prints the exact fix commands and exits 1.
#   3. Also runs check-state-branch-prohibited-tasks.sh --run (if present) to
#      detect scope-prohibited tasks still open on hyperloop/state.
#
# Usage:
#   bash .hyperloop/checks/check-process-improver-preflight.sh
#
# Exit codes:
#   0 — All banned/prohibited tasks are closed. Proceed with pattern analysis.
#   1 — Open banned/prohibited tasks found. Execute fix commands before proceeding.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAN_CHECK="${SCRIPT_DIR}/check-banned-task-ids-closed.sh"
STATE_SCAN="${SCRIPT_DIR}/check-state-branch-prohibited-tasks.sh"
ORPHAN_CHECK="${SCRIPT_DIR}/check-state-branch-orphan-task-files.sh"

FAILED=0

echo "========================================================================"
echo "PROCESS-IMPROVER PREFLIGHT — Step 1: Banned task ID check (both branches)"
echo "========================================================================"
echo ""
echo "  Detects banned tasks still open on hyperloop/state."
echo "  These cause re-assignment loops regardless of orchestrator instructions."
echo ""

if [ -f "$BAN_CHECK" ]; then
    if ! bash "$BAN_CHECK" --run; then
        echo ""
        echo "  *** EXECUTE THE FIX COMMANDS ABOVE BEFORE PROCEEDING ***"
        echo "  Do not read findings. Do not write overlays. Execute the commands."
        FAILED=1
    fi
else
    echo "  WARNING: check-banned-task-ids-closed.sh not found at ${BAN_CHECK}"
    echo "  Sync from main: git fetch origin main:main && git checkout main -- .hyperloop/checks/"
fi

echo ""
echo "========================================================================"
echo "PROCESS-IMPROVER PREFLIGHT — Step 2: State-branch prohibited-spec scan"
echo "========================================================================"
echo ""
echo "  Detects scope-prohibited tasks still open on hyperloop/state."
echo ""

if [ -f "$STATE_SCAN" ]; then
    if ! bash "$STATE_SCAN" --run; then
        echo ""
        echo "  *** PROHIBITED TASKS OPEN ON HYPERLOOP/STATE — CLOSE BEFORE PROCEEDING ***"
        FAILED=1
    fi
else
    echo "  SKIP: check-state-branch-prohibited-tasks.sh not found — sync from main."
fi

echo ""
echo "========================================================================"
echo "PROCESS-IMPROVER PREFLIGHT — Step 3: Orphan task file check"
echo "========================================================================"
echo ""
echo "  Detects task files present on hyperloop/state but ABSENT from main."
echo "  These arise when a task is deleted from main without being deleted"
echo "  from hyperloop/state — causing re-assignment loops for closed tasks."
echo "  (Root cause of task-001 STOP PROTOCOL Rounds 3, 4, and 5.)"
echo ""

if [ -f "$ORPHAN_CHECK" ]; then
    if ! bash "$ORPHAN_CHECK" --run; then
        echo ""
        echo "  *** ORPHAN TASK FILES ON HYPERLOOP/STATE — DELETE BEFORE PROCEEDING ***"
        FAILED=1
    fi
else
    echo "  SKIP: check-state-branch-orphan-task-files.sh not found — sync from main."
fi

echo ""
echo "========================================================================"
if [ "$FAILED" -eq 1 ]; then
    echo "RESULT: PREFLIGHT FAILED — open banned/prohibited/orphan tasks detected."
    echo ""
    echo "  REQUIRED: Execute every fix command printed above."
    echo "  THEN: Re-run this preflight to confirm exit 0."
    echo "  THEN: Proceed with pattern analysis and overlay writing."
    echo ""
    echo "  Pattern to avoid: documenting the fix again without executing it."
    echo "  task-078 reached Round 6 because 5 prior sessions documented the"
    echo "  commands but none executed them."
    echo ""
    echo "EXIT 1 — Preflight failed. Fix state branch before proceeding."
    exit 1
fi

echo "RESULT: PREFLIGHT PASSED."
echo ""
echo "  No banned or prohibited tasks are open on hyperloop/state."
echo "  Proceed with reading findings and improving the process."
echo ""
echo "EXIT 0 — Preflight passed. Safe to proceed."
exit 0
