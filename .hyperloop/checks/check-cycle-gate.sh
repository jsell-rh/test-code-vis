#!/bin/bash
# check-cycle-gate.sh
#
# ORCHESTRATOR CYCLE-START GATE — ONE COMMAND to run before reading any findings.
#
# Consolidates the mandatory cycle-start sequence into a single call:
#
#   Step 0 — Main/origin sync check (only when task IDs are supplied):
#     check-main-local-vs-remote.sh
#     Verifies local main == origin/main. An orchestrator with unpushed commits
#     causes check-main-local-vs-remote.sh to fail in every verifier worktree,
#     penalizing implementers for an orchestrator error they cannot observe.
#     Fix: git push origin main  (run before this script, not after).
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
#   Example (findings contain task-011, task-031, task-108):
#     bash .hyperloop/checks/check-cycle-gate.sh task-011 task-031 task-108
#
#   If no task IDs are supplied, only the queue audit (Step 1) runs.
#   Step 0 is skipped when no task IDs are supplied (run-all-checks.sh compat).
#
# Exit codes:
#   0 — Gate passed. Queue is clean; no finding tasks are scope-prohibited.
#       Proceed with reading findings and assigning work.
#   1 — Gate FAILED. Fix all reported issues before assigning any task.
#   2 — Usage error (missing required subscript).
#
# Rationale:
#   The prior two-step gate was skipped repeatedly. 20+ mis-assignments across
#   three prohibited specs occurred since it was introduced. Step 0 (main sync)
#   was added after task-108 rounds 7–9: orchestrator had unpushed local-main
#   commits that caused 3 extra FAIL rounds on an excellent implementation.

set -uo pipefail

QUEUE_AUDIT=".hyperloop/checks/check-no-prohibited-tasks-open.sh"
BAN_CHECK=".hyperloop/checks/check-banned-task-ids-closed.sh"
STATE_SCAN=".hyperloop/checks/check-state-branch-prohibited-tasks.sh"
RETRY_GATE=".hyperloop/checks/check-retry-not-scope-prohibited.sh"
MAIN_SYNC=".hyperloop/checks/check-main-local-vs-remote.sh"

if [ ! -f "$QUEUE_AUDIT" ]; then
    echo "ERROR: Queue audit script not found: $QUEUE_AUDIT"
    exit 2
fi

if [ ! -f "$BAN_CHECK" ]; then
    echo "ERROR: Banned task ID check not found: $BAN_CHECK"
    exit 2
fi

# STATE_SCAN is optional — log a warning if absent, don't fail.
# It is new and may not be present in older worktrees.

if [ ! -f "$RETRY_GATE" ]; then
    echo "ERROR: Retry gate script not found: $RETRY_GATE"
    exit 2
fi

GATE_FAILED=0

# ── Step 0: Main/origin sync check (orchestrator only — when task IDs supplied) ─
# Run-all-checks.sh calls this with no args (queue audit only). Checking main sync
# here is only meaningful for the orchestrator who is about to assign tasks.
# Implementers and verifiers already run check-main-local-vs-remote.sh directly.
if [ "$#" -gt 0 ] && [ -f "$MAIN_SYNC" ]; then
    echo "========================================================================"
    echo "CYCLE-START GATE — Step 0: Main/origin sync (push-before-assign check)"
    echo "========================================================================"
    echo ""
    if ! bash "$MAIN_SYNC"; then
        echo ""
        echo "  MAIN SYNC FAILED — run 'git push origin main' before assigning tasks."
        echo "  An unpushed local-main commit causes check-main-local-vs-remote.sh to"
        echo "  fail in EVERY verifier worktree, penalizing implementers for an orchestrator error."
        GATE_FAILED=1
    else
        echo "  Main/origin sync OK — safe to assign tasks."
    fi
    echo ""
fi

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
echo "========================================================================"
echo "CYCLE-START GATE — Step 1b: Banned task ID check (both branches)"
echo "========================================================================"
echo ""
echo "  Checks hyperloop/state branch AND working tree for banned task IDs."
echo "  Root cause: tasks closed on main but left open on hyperloop/state"
echo "  remain assignable — the orchestrator reads from hyperloop/state."
echo ""

if ! bash "$BAN_CHECK" --run; then
    echo ""
    echo "  BANNED TASK CHECK FAILED — permanently banned tasks are still open."
    echo "  Close them on the hyperloop/state branch (see fix commands above)."
    GATE_FAILED=1
else
    echo "  Banned task check passed — all banned IDs are closed on both branches."
fi

echo ""
echo "========================================================================"
echo "CYCLE-START GATE — Step 1c: State-branch prohibited-spec scan"
echo "========================================================================"
echo ""
echo "  Scans ALL open tasks on hyperloop/state for prohibited spec_refs."
echo "  This catches the gap: tasks closed on main but open on hyperloop/state."
echo "  Root cause of task-021 (2nd mis-assignment) and 30+ other infected tasks."
echo ""

if [ -f "$STATE_SCAN" ]; then
    if ! bash "$STATE_SCAN" --run; then
        echo ""
        echo "  STATE SCAN FAILED — prohibited tasks open on hyperloop/state."
        echo "  Close every PROHIBITED task on hyperloop/state before assigning."
        echo "  (WARN items are advisory — review before assigning those tasks.)"
        GATE_FAILED=1
    else
        echo "  State-branch scan passed — no prohibited spec_refs open on hyperloop/state."
        echo "  (WARN items above need orchestrator review before those tasks are assigned.)"
    fi
else
    echo "  SKIP: check-state-branch-prohibited-tasks.sh not found — sync checks from main."
    echo "    git fetch origin main:main && git checkout main -- .hyperloop/checks/"
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
