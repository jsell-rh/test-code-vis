#!/bin/bash
# check-no-prohibited-tasks-open.sh
#
# ORCHESTRATOR QUEUE AUDIT — run once at the start of each cycle to detect
# prohibited specs in the task queue before assigning any work.
#
# Observed pattern: scope-prohibited tasks (task-024, task-028, task-031)
# were re-assigned cycle after cycle despite "PERMANENTLY CLOSED" entries in
# the orchestrator overlay table.  A single command that audits ALL task files
# at once — rather than requiring per-task manual checks — removes the friction
# that allows prohibited tasks to re-enter the queue.
#
# Usage:
#   bash .hyperloop/checks/check-no-prohibited-tasks-open.sh --run
#
# Exit codes:
#   0  — No prohibited specs found in any task file.
#   1  — At least one task file references a prohibited spec. See output.
#
# No-arg path (run-all-checks.sh compatibility):
#   Script exits 0 (SKIP) when called without --run.  This is an orchestrator
#   tool, not an implementer check — it must not block task branches.
#
# Rules:
#   - Checks spec_ref field against the known prohibited spec file list.
#   - Checks task body for prohibited spec file names and feature keywords.
#   - Skips tasks with status: closed — closed tasks cannot be re-assigned,
#     and their bodies may legitimately describe prohibited features as
#     documentation of WHY those features are excluded from scope.
#   - If it exits 1: permanently close every flagged task before assigning
#     any work.  Do NOT create replacement tasks for prohibited specs.

set -uo pipefail

ARG="${1:-}"
if [ -z "$ARG" ]; then
    echo "SKIP: orchestrator queue audit — run manually at cycle start:"
    echo "  bash .hyperloop/checks/check-no-prohibited-tasks-open.sh --run"
    exit 0
fi

TASKS_DIR=".hyperloop/state/tasks"

if [ ! -d "$TASKS_DIR" ]; then
    echo "SKIP: Tasks directory not found: ${TASKS_DIR}"
    exit 0
fi

# ── Prohibited spec paths (canonical, append-only) ────────────────────────────
declare -a PROHIBITED_SPEC_PATHS=(
    "specs/interaction/moldable-views.spec.md"
    "specs/core/understanding-modes.spec.md"
    "specs/visualization/data-flow.spec.md"
)
declare -a PROHIBITED_SPEC_FEATURES=(
    "moldable views (LLM-powered question-driven views)"
    "conformance/evaluation/simulation modes (understanding modes)"
    "data flow visualization"
)

# ── Prohibited body keywords (catches spec re-framed under different spec_ref) ─
# Patterns from check-retry-not-scope-prohibited.sh CHECK B.
CONFORMANCE_PAT="(conformance.mode|evaluation.mode|simulation.mode|spec.overlay.comparison|conformance.comparison)"
MOLDABLE_PAT="(moldable.view|question.driven.view|llm.*generat.*view)"
DATAFLOW_PAT="(data.flow.visualization|visuali[sz]e.*data.flow)"
FIRSTPERSON_PAT="(first.person.navigation|first.person.camera|first.person.view)"

PROHIBITED_FOUND=0
TASK_COUNT=0

mapfile -t TASK_FILES < <(find "$TASKS_DIR" -maxdepth 1 -name "task-*.md" | sort)

if [ "${#TASK_FILES[@]}" -eq 0 ]; then
    echo "SKIP: No task files found in ${TASKS_DIR}"
    exit 0
fi

for TASK_FILE in "${TASK_FILES[@]}"; do
    TASK_ID=$(basename "$TASK_FILE" .md)
    TASK_BODY=$(cat "$TASK_FILE")
    TASK_COUNT=$((TASK_COUNT + 1))

    # Skip closed tasks — they cannot be re-assigned.  Closed documentation
    # records may legitimately describe prohibited features to explain scope
    # exclusions; scanning them for prohibited keywords produces false positives.
    TASK_STATUS=$(echo "$TASK_BODY" | grep -m1 '^status:' | sed 's/^status:[[:space:]]*//' | tr -d '\r')
    if [ "$TASK_STATUS" = "closed" ]; then
        continue
    fi

    # Extract spec_ref, stripping any @hash suffix (Spec-Ref format)
    SPEC_REF=$(echo "$TASK_BODY" | grep -m1 '^spec_ref:' \
        | sed 's/^spec_ref:[[:space:]]*//' \
        | tr -d '\r' \
        | cut -d'@' -f1 \
        | sed 's|^\./||')

    # CHECK A: spec_ref against prohibited path list
    if [ -n "$SPEC_REF" ] && [ "$SPEC_REF" != "null" ]; then
        for i in "${!PROHIBITED_SPEC_PATHS[@]}"; do
            PROHIBITED_PATH="${PROHIBITED_SPEC_PATHS[$i]}"
            PROHIBITED_FEATURE="${PROHIBITED_SPEC_FEATURES[$i]}"
            if [ "${SPEC_REF#./}" = "${PROHIBITED_PATH#./}" ]; then
                echo "PROHIBITED [${TASK_ID}] spec_ref: ${SPEC_REF}"
                echo "  Feature: ${PROHIBITED_FEATURE}"
                echo "  Action:  permanently close ${TASK_ID} — do NOT assign or retry."
                PROHIBITED_FOUND=1
            fi
        done
    fi

    # CHECK B: prohibited spec file names in body (catches spec_ref workarounds)
    for i in "${!PROHIBITED_SPEC_PATHS[@]}"; do
        PROHIBITED_PATH="${PROHIBITED_SPEC_PATHS[$i]}"
        PROHIBITED_FEATURE="${PROHIBITED_SPEC_FEATURES[$i]}"
        if echo "$TASK_BODY" | grep -q "$PROHIBITED_PATH"; then
            # Avoid double-reporting if already caught by CHECK A
            if [ "${SPEC_REF#./}" != "${PROHIBITED_PATH#./}" ]; then
                echo "PROHIBITED [${TASK_ID}] body references: ${PROHIBITED_PATH}"
                echo "  Feature: ${PROHIBITED_FEATURE}"
                echo "  Action:  permanently close ${TASK_ID} — do NOT assign or retry."
                PROHIBITED_FOUND=1
            fi
        fi
    done

    # CHECK C: prohibited feature keywords in task body (catches renamed tasks)
    if echo "$TASK_BODY" | grep -qiE "$CONFORMANCE_PAT"; then
        echo "PROHIBITED [${TASK_ID}] body describes conformance/evaluation/simulation mode features."
        echo "  Authority: specs/prototype/prototype-scope.spec.md lines 89-91"
        echo "  Action:  permanently close ${TASK_ID} — do NOT assign or retry."
        PROHIBITED_FOUND=1
    fi

    if echo "$TASK_BODY" | grep -qiE "$MOLDABLE_PAT"; then
        echo "PROHIBITED [${TASK_ID}] body describes moldable/LLM-question-driven view features."
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 93"
        echo "  Action:  permanently close ${TASK_ID} — do NOT assign or retry."
        PROHIBITED_FOUND=1
    fi

    if echo "$TASK_BODY" | grep -qiE "$DATAFLOW_PAT"; then
        echo "PROHIBITED [${TASK_ID}] body describes data flow visualization features."
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 92"
        echo "  Action:  permanently close ${TASK_ID} — do NOT assign or retry."
        PROHIBITED_FOUND=1
    fi

    if echo "$TASK_BODY" | grep -qiE "$FIRSTPERSON_PAT"; then
        echo "PROHIBITED [${TASK_ID}] body describes first-person navigation features."
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 95"
        echo "  Action:  permanently close ${TASK_ID} — do NOT assign or retry."
        PROHIBITED_FOUND=1
    fi
done

echo ""
echo "Scanned ${TASK_COUNT} task file(s) in ${TASKS_DIR}."
echo ""

if [ "$PROHIBITED_FOUND" -eq 1 ]; then
    echo "======================================================================"
    echo "RESULT: PROHIBITED SPECS DETECTED IN TASK QUEUE."
    echo "======================================================================"
    echo ""
    echo "  Required actions before assigning any task this cycle:"
    echo "    1. Permanently close every flagged task above."
    echo "    2. Do NOT create replacement tasks for prohibited specs."
    echo "    3. Do NOT assign any task until this script exits 0."
    echo "    4. Re-run this script after closing flagged tasks to confirm queue is clean."
    echo ""
    echo "EXIT 1 — Task queue contains prohibited specs. Resolve before proceeding."
    exit 1
fi

echo "======================================================================"
echo "RESULT: No prohibited specs detected in task queue."
echo "======================================================================"
echo "EXIT 0 — Task queue is clean. Proceed with assignment."
exit 0
