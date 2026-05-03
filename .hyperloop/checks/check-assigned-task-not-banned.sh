#!/usr/bin/env bash
# check-assigned-task-not-banned.sh
#
# AUTOMATIC BANNED TASK DETECTION — included in run-all-checks.sh.
#
# Infers the current task ID from the branch name (convention:
# hyperloop/<task-id>) and checks it against the permanently banned
# task list.  Fires automatically for ANY agent (implementer or verifier)
# running run-all-checks.sh on a banned task branch.
#
# Root cause this script addresses:
#   task-001 reached STOP PROTOCOL Round 9.  All prior mechanical checks
#   (check-pre-assignment.sh, check-state-branch-post-commit.sh,
#   check-cycle-gate.sh) require EXPLICIT execution by the orchestrator
#   before assignment — and were not run.  This script fires automatically
#   in the standard run-all-checks.sh suite without requiring any additional
#   orchestrator action: the first time any agent runs checks on a banned
#   branch, this script exits 1 and names the exact fix.
#
#   Prior path: orchestrator assigns banned task → implementer discovers
#   feature is on main → files STOP PROTOCOL report → orchestrator re-assigns.
#   New path:   orchestrator assigns banned task → implementer runs Sync
#   Point 1 → this script exits 1 with INVALID ASSIGNMENT → implementer
#   files INVALID ASSIGNMENT report in the same session, no STOP PROTOCOL.
#
# Exit codes:
#   0 — Branch task ID is not in the banned list, or branch name does not
#       match the hyperloop/<task-id> convention (e.g., main, feature branches).
#       Non-hyperloop branches are SKIPped — this check is task-branch specific.
#   1 — Branch task ID is permanently banned.  Full fix commands are printed.

set -uo pipefail

# ── Permanently banned task IDs (keep in sync with check-banned-task-ids-closed.sh) ──
BANNED_IDS=(
    "task-001"  # 9x STOP PROTOCOL — scene-graph-schema spec fully on main
    "task-021"  # data-flow.spec.md (scope-prohibited)
    "task-024"  # moldable-views.spec.md (scope-prohibited; 8 mis-assignments)
    "task-028"  # understanding-modes.spec.md (scope-prohibited; 9 attempts)
    "task-031"  # understanding-modes.spec.md (scope-prohibited; 6 runs)
    "task-078"  # Symbol Table Extraction — superseded by task-075 (5x STOP PROTOCOL)
)

# ── Infer task ID from branch name ───────────────────────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Only check branches matching the hyperloop/<task-id> convention.
# Skip main, feature/*, and other non-task branches.
if [[ ! "$BRANCH" =~ ^hyperloop/(task-[0-9]+)$ ]]; then
    echo "SKIP: Branch '${BRANCH}' does not match hyperloop/<task-id> convention."
    echo "      Banned task check only applies to task branches."
    echo "EXIT 0 — Not a task branch; check skipped."
    exit 0
fi

TASK_ID="${BASH_REMATCH[1]}"

echo "========================================================================"
echo "ASSIGNED TASK BANNED CHECK — ${TASK_ID} (branch: ${BRANCH})"
echo "========================================================================"
echo ""

# ── Check against banned list ─────────────────────────────────────────────────
IS_BANNED=0
for BAN_ID in "${BANNED_IDS[@]}"; do
    if [ "$TASK_ID" = "$BAN_ID" ]; then
        IS_BANNED=1
        break
    fi
done

if [ "$IS_BANNED" -eq 0 ]; then
    echo "PASS: ${TASK_ID} is not in the permanently banned task list."
    echo ""
    echo "EXIT 0 — Task is not banned. Proceed with normal implementation."
    exit 0
fi

# ── Banned task detected ──────────────────────────────────────────────────────
echo "INVALID ASSIGNMENT — ${TASK_ID} IS PERMANENTLY BANNED"
echo ""
echo "  This task number is in the permanently banned list and MUST NOT be"
echo "  assigned, implemented, or reviewed.  The orchestrator made an"
echo "  assignment error.  Do NOT write any implementation code."
echo ""
echo "  Stop immediately and file an INVALID ASSIGNMENT report."
echo ""
echo "  Required implementer/verifier action:"
echo "    1. Do NOT write any code or run further checks."
echo "    2. File your worker-result.yaml with the following content:"
echo ""
echo "       result: invalid_assignment"
echo "       reason: ${TASK_ID} is permanently banned (check-assigned-task-not-banned.sh EXIT 1)"
echo ""
echo "  Required orchestrator actions:"
echo "    1. Do NOT re-assign ${TASK_ID} under any task ID, spec_ref, or framing."
echo "    2. Delete the task file from BOTH branches:"
echo ""
echo "       # On hyperloop/state:"
echo "       git checkout hyperloop/state"
echo "       rm .hyperloop/state/tasks/${TASK_ID}.md"
echo "       git add .hyperloop/state/tasks/${TASK_ID}.md"
echo "       git commit -m 'chore(tasks): re-delete banned ${TASK_ID} from state branch'"
echo "       git push origin hyperloop/state"
echo "       git checkout main"
echo ""
echo "       # On main (if file exists):"
echo "       rm -f .hyperloop/state/tasks/${TASK_ID}.md"
echo "       git add .hyperloop/state/tasks/${TASK_ID}.md"
echo "       git commit -m 'chore(tasks): re-delete banned ${TASK_ID} from main'"
echo "       git push origin main"
echo ""
echo "    3. Verify closure:"
echo "       bash .hyperloop/checks/check-banned-task-ids-closed.sh --run"
echo "       # Must exit 0 on both branches."
echo ""
echo "    4. Run check-pre-assignment.sh before assigning any replacement task."
echo ""
echo "EXIT 1 — INVALID ASSIGNMENT. Task ${TASK_ID} is permanently banned."
exit 1
