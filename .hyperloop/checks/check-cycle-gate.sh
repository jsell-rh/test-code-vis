#!/bin/bash
# check-cycle-gate.sh
#
# ORCHESTRATOR CYCLE-START GATE — ONE COMMAND to run before reading any findings.
#
# Consolidates the two-step mandatory cycle-start sequence into a single call:
#
#   Step 1 — Queue audit (all task files):
#     check-no-prohibited-tasks-open.sh --run
#
#   Step 2 — Per-finding retry gate (one per task ID in findings):
#     check-retry-not-scope-prohibited.sh <task-id>   [repeated for each ID]
#
# Usage:
#   bash .hyperloop/checks/check-cycle-gate.sh <task-id> [task-id ...]
#
#   Example (findings contain task-024, task-028, task-031):
#     bash .hyperloop/checks/check-cycle-gate.sh task-024 task-028 task-031
#
#   If no task IDs are supplied, only the queue audit (Step 1) runs.
#
# Exit codes:
#   0 — Gate passed. Queue is clean; no finding tasks are scope-prohibited.
#       Proceed with reading findings and assigning work.
#   1 — Gate FAILED. Prohibited specs detected. Permanently close every
#       flagged task. Do NOT assign or retry any flagged task. Re-run after
#       closing to confirm exit 0.
#   2 — Usage error (missing required subscript).
#
# Rationale:
#   The prior two-step gate (separate commands for queue audit and per-task
#   retry check) was skipped repeatedly because of the friction of running
#   two commands with different arguments. 20 mis-assignments across three
#   prohibited specs have occurred since the gate was introduced. A single
#   command with all task IDs removes that friction while preserving all
#   mechanical checks.
#
# No-arg SKIP (run-all-checks.sh compatibility):
#   Called with no args from run-all-checks.sh: runs Step 1 only (queue audit).
#   This is intentional — the queue audit is always safe to run without task IDs.
#   The per-task retry gate (Step 2) requires IDs from the cycle's findings and
#   is meaningful only at cycle start, not per-branch.

set -uo pipefail

QUEUE_AUDIT=".hyperloop/checks/check-no-prohibited-tasks-open.sh"
RETRY_GATE=".hyperloop/checks/check-retry-not-scope-prohibited.sh"

if [ ! -f "$QUEUE_AUDIT" ]; then
    echo "ERROR: Queue audit script not found: $QUEUE_AUDIT"
    exit 2
fi

if [ ! -f "$RETRY_GATE" ]; then
    echo "ERROR: Retry gate script not found: $RETRY_GATE"
    exit 2
fi

GATE_FAILED=0

# ── Step 1: Full queue audit ──────────────────────────────────────────────────
echo "========================================================================"
echo "CYCLE-START GATE — Step 1: Queue audit (all task files)"
echo "========================================================================"
echo ""

if ! bash "$QUEUE_AUDIT" --run; then
    echo ""
    echo "  QUEUE AUDIT FAILED — prohibited specs detected in task queue."
    GATE_FAILED=1
else
    echo "  Queue audit passed — no prohibited specs in task queue."
fi

echo ""

# ── Step 2: Per-finding retry gate ───────────────────────────────────────────
if [ "$#" -gt 0 ]; then
    echo "========================================================================"
    echo "CYCLE-START GATE — Step 2: Per-finding retry gate ($# task IDs)"
    echo "========================================================================"
    echo ""

    for TASK_ID in "$@"; do
        echo "--- ${TASK_ID} ---"
        if ! bash "$RETRY_GATE" "$TASK_ID"; then
            echo ""
            echo "  SCOPE-PROHIBITED: ${TASK_ID} — permanently close, do NOT retry or rename."
            GATE_FAILED=1
        else
            echo "  ${TASK_ID}: No scope-prohibition detected."
        fi
        echo ""
    done
else
    echo "========================================================================"
    echo "CYCLE-START GATE — Step 2: Per-finding retry gate (no task IDs supplied)"
    echo "========================================================================"
    echo ""
    echo "  SKIP: No task IDs provided. Supply finding task IDs as arguments:"
    echo "    bash .hyperloop/checks/check-cycle-gate.sh task-024 task-028 task-031"
    echo ""
fi

# ── Result ────────────────────────────────────────────────────────────────────
echo "========================================================================"
if [ "$GATE_FAILED" -eq 1 ]; then
    echo "RESULT: CYCLE-START GATE FAILED."
    echo ""
    echo "  Required actions before assigning ANY task this cycle:"
    echo "    1. Permanently close every SCOPE-PROHIBITED task listed above."
    echo "    2. Do NOT re-assign any flagged task under any task ID or spec path."
    echo "    3. Do NOT create a new task number for a prohibited spec or feature."
    echo "    4. Re-run this script after closing tasks to confirm gate passes:"
    echo "         bash .hyperloop/checks/check-cycle-gate.sh <task-ids...>"
    echo "    5. Only proceed with assignment after this script exits 0."
    echo ""
    echo "EXIT 1 — Gate failed. Do NOT proceed with assignment this cycle."
    exit 1
fi

echo "RESULT: CYCLE-START GATE PASSED."
echo ""
echo "  Queue is clean. No finding tasks are scope-prohibited."
echo "  Proceed with reading findings and assigning work."
echo ""
echo "EXIT 0 — Gate passed. Proceed."
exit 0
