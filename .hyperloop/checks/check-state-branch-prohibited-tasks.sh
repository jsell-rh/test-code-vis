#!/bin/bash
# check-state-branch-prohibited-tasks.sh
#
# PROCESS-IMPROVEMENT SESSION GATE — scan the hyperloop/state branch for
# prohibited specs across ALL open tasks, not just hardcoded banned IDs.
#
# Root cause this script addresses:
#   check-no-prohibited-tasks-open.sh scans the working tree (main).
#   check-banned-task-ids-closed.sh checks hardcoded IDs on both branches.
#   Neither script scans ALL tasks on hyperloop/state for the full prohibited-spec
#   list.  This is the gap: a task closed on main but open on hyperloop/state with
#   a prohibited spec_ref will pass both existing checks.
#
#   Observed pattern (task-021 cycle 2, task-024 cycle 8):
#     - Both tasks: status=closed on main, status=in_progress on hyperloop/state
#     - check-no-prohibited-tasks-open.sh → EXIT 0 (reads main)
#     - check-banned-task-ids-closed.sh → EXIT 0 when task-021 was not yet banned
#     - Orchestrator read from hyperloop/state → kept assigning prohibited specs
#
# Usage:
#   bash .hyperloop/checks/check-state-branch-prohibited-tasks.sh --run
#
#   Run at the start of every process-improvement session that receives
#   INVALID ASSIGNMENT findings, and at cycle-start before assigning tasks.
#
# Exit codes:
#   0 — No prohibited specs found among open tasks on hyperloop/state.
#   1 — At least one open task on hyperloop/state references a prohibited spec.
#
# No-arg path (run-all-checks.sh compatibility):
#   Exits 0 (SKIP) when called without --run.

set -uo pipefail

ARG="${1:-}"
if [ -z "$ARG" ]; then
    echo "SKIP: process-improvement session gate — run manually:"
    echo "  bash .hyperloop/checks/check-state-branch-prohibited-tasks.sh --run"
    exit 0
fi

TASKS_DIR=".hyperloop/state/tasks"
STATE_BRANCH="hyperloop/state"

# ── Prohibited spec paths (must match check-assigned-spec-in-scope.sh) ────────
declare -a PROHIBITED_SPECS=(
    "specs/interaction/moldable-views.spec.md"
    "specs/core/understanding-modes.spec.md"
    "specs/visualization/data-flow.spec.md"
)
declare -a PROHIBITED_FEATURES=(
    "moldable views (LLM-powered question-driven views)"
    "conformance/evaluation/simulation modes (understanding modes)"
    "data flow visualization"
)
declare -a PROHIBITED_AUTHORITIES=(
    "specs/prototype/prototype-scope.spec.md line 93"
    "specs/prototype/prototype-scope.spec.md lines 89-91"
    "specs/prototype/prototype-scope.spec.md line 92"
)

# ── Prohibited body keywords ───────────────────────────────────────────────────
CONFORMANCE_PAT="(conformance.mode|evaluation.mode|simulation.mode|spec.overlay.comparison|conformance.comparison)"
MOLDABLE_PAT="(moldable.view|question.driven.view|llm.*generat.*view)"
DATAFLOW_PAT="(data.flow.visualization|visuali[sz]e.*data.flow)"
FIRSTPERSON_PAT="(first.person.navigation|first.person.camera|first.person.view)"

# ── Determine state branch ref ─────────────────────────────────────────────────
STATE_REF=""
if git rev-parse --verify "${STATE_BRANCH}" >/dev/null 2>&1; then
    STATE_REF="${STATE_BRANCH}"
elif git rev-parse --verify "origin/${STATE_BRANCH}" >/dev/null 2>&1; then
    STATE_REF="origin/${STATE_BRANCH}"
fi

if [ -z "$STATE_REF" ]; then
    echo "SKIP: Branch '${STATE_BRANCH}' not found (neither local nor remote)."
    echo "  Cannot scan hyperloop/state for prohibited tasks."
    exit 0
fi

echo "Scanning ${STATE_REF} for prohibited specs among open tasks..."
echo ""

# ── List task files on state branch ───────────────────────────────────────────
mapfile -t STATE_TASK_PATHS < <(
    git ls-tree --name-only "${STATE_REF}:${TASKS_DIR}" 2>/dev/null \
        | grep '^task-.*\.md$' \
        | sed "s|^|${TASKS_DIR}/|" \
        | sort
)

if [ "${#STATE_TASK_PATHS[@]}" -eq 0 ]; then
    echo "SKIP: No task files found on ${STATE_REF}:${TASKS_DIR}"
    exit 0
fi

PROHIBITED_FOUND=0
WARN_FOUND=0
SCANNED=0

for TASK_PATH in "${STATE_TASK_PATHS[@]}"; do
    TASK_ID=$(basename "$TASK_PATH" .md)
    TASK_BODY=$(git show "${STATE_REF}:${TASK_PATH}" 2>/dev/null || true)
    if [ -z "$TASK_BODY" ]; then
        continue
    fi

    TASK_STATUS=$(echo "$TASK_BODY" | grep -m1 '^status:' \
        | sed 's/^status:[[:space:]]*//' | tr -d '\r')

    # Skip closed and complete tasks — they cannot be re-assigned.  Closed
    # documentation may legitimately name prohibited features to record why
    # features were deferred.  Complete tasks were finished before prohibition
    # was established; their spec_refs are historical records, not active queues.
    if [ "$TASK_STATUS" = "closed" ] || [ "$TASK_STATUS" = "complete" ]; then
        continue
    fi

    SCANNED=$((SCANNED + 1))

    SPEC_REF=$(echo "$TASK_BODY" | grep -m1 '^spec_ref:' \
        | sed 's/^spec_ref:[[:space:]]*//' \
        | tr -d '\r' \
        | cut -d'@' -f1 \
        | sed 's|^\./||')

    # CHECK A: spec_ref against prohibited path list
    if [ -n "$SPEC_REF" ] && [ "$SPEC_REF" != "null" ]; then
        for i in "${!PROHIBITED_SPECS[@]}"; do
            if [ "${SPEC_REF#./}" = "${PROHIBITED_SPECS[$i]#./}" ]; then
                echo "PROHIBITED [${TASK_ID}] on ${STATE_REF}: spec_ref=${SPEC_REF}"
                echo "  Status on state branch: ${TASK_STATUS}"
                echo "  Feature: ${PROHIBITED_FEATURES[$i]}"
                echo "  Authority: ${PROHIBITED_AUTHORITIES[$i]}"
                echo "  Fix: close this task on ${STATE_BRANCH} branch:"
                echo "    git checkout ${STATE_BRANCH}"
                echo "    sed -i 's/^status:.*/status: closed/' ${TASK_PATH}"
                echo "    sed -i 's/^spec_ref:.*/spec_ref: null/' ${TASK_PATH}"
                echo "    git add ${TASK_PATH}"
                echo "    git commit -m 'chore(tasks): permanently close banned task ${TASK_ID} on state branch'"
                echo "    git push origin ${STATE_BRANCH}"
                echo "    git checkout main"
                echo ""
                PROHIBITED_FOUND=1
            fi
        done
    fi

    # CHECK B: prohibited body/title keywords (advisory — needs orchestrator review)
    # These catch tasks whose spec_ref is not in the prohibited list but whose
    # title or body names a prohibited feature directly.  Output as WARN so the
    # orchestrator investigates before closing (the task may be partially valid).
    TASK_TITLE=$(echo "$TASK_BODY" | grep -m1 '^title:' | sed "s/^title:[[:space:]]*//" | tr -d "'\"")
    KEYWORD_WARN=""
    if echo "$TASK_TITLE $TASK_BODY" | grep -qiE "$CONFORMANCE_PAT"; then
        KEYWORD_WARN="conformance/evaluation/simulation mode (lines 89-91)"
    fi
    if echo "$TASK_TITLE $TASK_BODY" | grep -qiE "$MOLDABLE_PAT"; then
        KEYWORD_WARN="moldable/LLM-question-driven view (line 93)"
    fi
    if echo "$TASK_TITLE $TASK_BODY" | grep -qiE "$DATAFLOW_PAT"; then
        KEYWORD_WARN="data flow visualization (line 92)"
    fi
    if echo "$TASK_TITLE $TASK_BODY" | grep -qiE "$FIRSTPERSON_PAT"; then
        KEYWORD_WARN="first-person navigation (line 95)"
    fi
    if [ -n "$KEYWORD_WARN" ]; then
        echo "WARN [${TASK_ID}] on ${STATE_REF}: title/body names a prohibited feature."
        echo "  Detected feature: ${KEYWORD_WARN}"
        echo "  Title: ${TASK_TITLE}"
        echo "  Action: orchestrator must review spec_ref and task body before assigning."
        echo "    If the primary feature is prohibited, close this task on ${STATE_BRANCH}."
        echo "    If only part of the spec is prohibited, update task scope accordingly."
        echo ""
        WARN_FOUND=1
    fi
done

echo "Scanned ${SCANNED} open task(s) on ${STATE_REF}."
echo ""

if [ "$PROHIBITED_FOUND" -eq 1 ]; then
    echo "======================================================================"
    echo "RESULT: PROHIBITED TASKS OPEN ON ${STATE_REF}."
    echo "======================================================================"
    echo ""
    echo "  The orchestrator reads task state from the ${STATE_BRANCH} branch."
    echo "  Tasks with a prohibited spec_ref that are open on ${STATE_BRANCH} WILL"
    echo "  be re-assigned — regardless of their status on main."
    echo "  Close every PROHIBITED task above on ${STATE_BRANCH} before assigning."
    echo ""
    if [ "$WARN_FOUND" -eq 1 ]; then
        echo "  WARN tasks above need orchestrator review — do not auto-close them;"
        echo "  verify whether their primary feature is prohibited before deciding."
        echo ""
    fi
    echo "EXIT 1 — Prohibited tasks open on state branch. Fix before assigning."
    exit 1
fi

if [ "$WARN_FOUND" -eq 1 ]; then
    echo "======================================================================"
    echo "RESULT: No spec_ref-prohibited tasks open on ${STATE_REF}."
    echo "  BUT: WARN tasks above have titles/bodies naming prohibited features."
    echo "  Review them before assigning — they may describe prohibited work."
    echo "======================================================================"
    echo "EXIT 0 — No definitive spec_ref prohibitions. Review WARN items."
    exit 0
fi

echo "======================================================================"
echo "RESULT: No prohibited specs among open tasks on ${STATE_REF}."
echo "======================================================================"
echo "EXIT 0 — State branch is clean."
exit 0
