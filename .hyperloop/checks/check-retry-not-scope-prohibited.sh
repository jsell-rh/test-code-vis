#!/bin/bash
# check-retry-not-scope-prohibited.sh
#
# ORCHESTRATOR PRE-RETRY GATE — mandatory first action before scheduling any
# re-attempt, re-assignment, or new task number for a previously failed task.
#
# Three independent checks so each catches a scope-prohibition problem without
# depending on the others:
#
#   CHECK A — spec_ref scope check:
#     Reads the task's spec_ref from its task file and runs
#     check-assigned-spec-in-scope.sh on that spec directly.
#
#   CHECK B — task body keyword scan:
#     Searches the task body for prohibited spec file names and prohibited
#     feature keywords.  Catches cases where the spec_ref was updated away
#     from the prohibited spec but the task body still describes prohibited
#     features (as occurred with task-028 attempts 2-4: spec_ref was changed
#     to system-purpose.spec.md but the body still described conformance-mode
#     infrastructure — understanding-modes features).
#
#   CHECK C — review file classification:
#     Scans the task's review files for "INVALID ASSIGNMENT" language using
#     check-fail-report-classification.sh.  Catches cases where a prior
#     scope-prohibition FAIL was recorded in a review file.
#
# Any check failing causes exit 1 (retry FORBIDDEN).
#
# Usage:
#   bash .hyperloop/checks/check-retry-not-scope-prohibited.sh <task-id>
#
#   Example:
#     bash .hyperloop/checks/check-retry-not-scope-prohibited.sh task-028
#
# Exit codes:
#   0 — No scope-prohibition found; retry is permitted (still verify scope).
#   1 — Scope-prohibition detected; retry is FORBIDDEN.  Permanently close.
#   2 — Usage error or missing files.
#
# Rationale:
#   check-fail-report-classification.sh requires an explicit file path, adding
#   friction that allows the gate to be skipped.  This script removes that
#   friction: one command, one task ID, binary exit code.
#
#   Observed failure: task-028 was retried FOUR times despite a scope-
#   prohibition FAIL on every attempt.  The existing PRE-RETRY GATE was
#   described in the orchestrator overlay but not enforced mechanically.

set -uo pipefail

TASK_ID="${1:-}"
TASKS_DIR=".hyperloop/state/tasks"
REVIEWS_DIR=".hyperloop/state/reviews"
SCOPE_CHECK=".hyperloop/checks/check-assigned-spec-in-scope.sh"
CLASSIFY_SCRIPT=".hyperloop/checks/check-fail-report-classification.sh"

# ── Argument validation ───────────────────────────────────────────────────────
if [ -z "$TASK_ID" ]; then
    echo "ERROR: No task ID provided."
    echo "  Usage: $0 <task-id>"
    echo "  Example: $0 task-028"
    exit 2
fi

TASK_FILE="${TASKS_DIR}/${TASK_ID}.md"
if [ ! -f "$TASK_FILE" ]; then
    echo "ERROR: Task file not found: $TASK_FILE"
    exit 2
fi

if [ ! -f "$SCOPE_CHECK" ]; then
    echo "ERROR: Scope check script not found: $SCOPE_CHECK"
    exit 2
fi

if [ ! -f "$CLASSIFY_SCRIPT" ]; then
    echo "ERROR: Classification script not found: $CLASSIFY_SCRIPT"
    exit 2
fi

SCOPE_PROHIBITION_FOUND=0
TASK_BODY=$(cat "$TASK_FILE")

# ── CHECK A: spec_ref → check-assigned-spec-in-scope.sh ──────────────────────
echo "=== CHECK A: spec_ref scope check ==="
SPEC_REF=$(echo "$TASK_BODY" | grep -m1 '^spec_ref:' | sed 's/^spec_ref:[[:space:]]*//' | tr -d '\r')

if [ -z "$SPEC_REF" ] || [ "$SPEC_REF" = "null" ]; then
    echo "  SKIP: No spec_ref in task file (or value is null)."
    echo "  Run manually: bash ${SCOPE_CHECK} <spec-path>"
else
    echo "  Task: ${TASK_ID}  Spec: ${SPEC_REF}"
    echo ""
    if ! bash "$SCOPE_CHECK" "$SPEC_REF"; then
        echo ""
        echo "  → SCOPE-PROHIBITED: spec_ref '${SPEC_REF}' is prohibited."
        SCOPE_PROHIBITION_FOUND=1
    else
        echo "  → spec_ref passes scope check."
    fi
fi

echo ""

# ── CHECK B: task body keyword scan ──────────────────────────────────────────
# Catches prohibited content even when spec_ref has been updated away from the
# prohibited spec.  Two sub-checks:
#   B1 — Prohibited spec file names appear literally in the task body.
#   B2 — Prohibited feature keywords appear in requirement language.

echo "=== CHECK B: Task body keyword scan ==="

# B1: literal prohibited spec file names
declare -a PROHIBITED_SPEC_PATHS=(
    "specs/interaction/moldable-views.spec.md"
    "specs/core/understanding-modes.spec.md"
)
declare -a PROHIBITED_SPEC_LABELS=(
    "moldable views"
    "conformance/evaluation/simulation modes (understanding modes)"
)

for i in "${!PROHIBITED_SPEC_PATHS[@]}"; do
    PROHIBITED_PATH="${PROHIBITED_SPEC_PATHS[$i]}"
    PROHIBITED_LABEL="${PROHIBITED_SPEC_LABELS[$i]}"
    if echo "$TASK_BODY" | grep -q "$PROHIBITED_PATH"; then
        echo "  SCOPE-PROHIBITED: Task body references prohibited spec '${PROHIBITED_PATH}'."
        echo "    Feature: ${PROHIBITED_LABEL}"
        echo "    Authority: specs/prototype/prototype-scope.spec.md"
        SCOPE_PROHIBITION_FOUND=1
    fi
done

# B2: prohibited feature keywords in requirement language (SHALL/MUST + feature)
# Conformance / evaluation / simulation modes
if echo "$TASK_BODY" | grep -qiE "(conformance.mode|evaluation.mode|simulation.mode|spec.overlay.comparison|conformance.comparison)"; then
    echo "  SCOPE-PROHIBITED: Task body describes conformance/evaluation/simulation mode features."
    echo "    Authority: specs/prototype/prototype-scope.spec.md lines 89-91"
    SCOPE_PROHIBITION_FOUND=1
fi

# Moldable / LLM-question-driven views
if echo "$TASK_BODY" | grep -qiE "(moldable.view|question.driven.view|llm.*generat.*view)"; then
    echo "  SCOPE-PROHIBITED: Task body describes moldable/LLM-question-driven view features."
    echo "    Authority: specs/prototype/prototype-scope.spec.md line 93"
    SCOPE_PROHIBITION_FOUND=1
fi

# Data flow visualization
if echo "$TASK_BODY" | grep -qiE "(data.flow.visualization|visuali[sz]e.*data.flow)"; then
    echo "  SCOPE-PROHIBITED: Task body describes data flow visualization features."
    echo "    Authority: specs/prototype/prototype-scope.spec.md line 92"
    SCOPE_PROHIBITION_FOUND=1
fi

# First-person navigation
if echo "$TASK_BODY" | grep -qiE "(first.person.navigation|first.person.camera|first.person.view)"; then
    echo "  SCOPE-PROHIBITED: Task body describes first-person navigation features."
    echo "    Authority: specs/prototype/prototype-scope.spec.md line 95"
    SCOPE_PROHIBITION_FOUND=1
fi

if [ "$SCOPE_PROHIBITION_FOUND" -eq 0 ]; then
    echo "  → No prohibited keywords found in task body."
fi

echo ""

# ── CHECK C: review files → check-fail-report-classification.sh ──────────────
echo "=== CHECK C: Review file classification ==="

if [ ! -d "$REVIEWS_DIR" ]; then
    echo "  SKIP: Reviews directory not found: ${REVIEWS_DIR}"
else
    mapfile -t REVIEW_FILES < <(find "$REVIEWS_DIR" -name "${TASK_ID}-round-*.md" | sort)

    if [ "${#REVIEW_FILES[@]}" -eq 0 ]; then
        echo "  SKIP: No review files found for '${TASK_ID}'."
    else
        echo "  Checking ${#REVIEW_FILES[@]} review file(s) for '${TASK_ID}'..."
        for REVIEW_FILE in "${REVIEW_FILES[@]}"; do
            echo "    Checking: ${REVIEW_FILE}"
            if bash "$CLASSIFY_SCRIPT" "$REVIEW_FILE" 2>&1 | grep -q "SCOPE-PROHIBITION FAIL"; then
                echo "    → SCOPE-PROHIBITION FAIL detected."
                SCOPE_PROHIBITION_FOUND=1
            fi
        done
        echo "  Review scan complete."
    fi
fi

echo ""

# ── Result ────────────────────────────────────────────────────────────────────
if [ "$SCOPE_PROHIBITION_FOUND" -eq 1 ]; then
    echo "======================================================================"
    echo "RESULT: SCOPE-PROHIBITION detected for ${TASK_ID}."
    echo "======================================================================"
    echo ""
    echo "  This task's spec or body is prohibited for the prototype phase, OR a"
    echo "  prior attempt already returned a scope-prohibition FAIL.  No implementer"
    echo "  action can resolve this.  A re-worded task or new task number for the"
    echo "  same spec/feature produces the identical outcome."
    echo ""
    echo "  REQUIRED ACTIONS:"
    echo "    1. Permanently close ${TASK_ID} — do NOT schedule a re-attempt."
    echo "    2. Do NOT create a new task number for the same spec or feature."
    echo "    3. Verify the spec is listed in check-assigned-spec-in-scope.sh."
    echo "    4. Verify the spec appears in the prohibited-spec tables in"
    echo "       orchestrator-overlay.yaml and pm-overlay.yaml."
    echo "    5. Investigate how this spec/feature re-entered the candidate pool"
    echo "       and close that upstream gap."
    echo ""
    echo "EXIT 1 — Retry is FORBIDDEN."
    exit 1
fi

echo "======================================================================"
echo "RESULT: No scope-prohibition detected for ${TASK_ID}."
echo "======================================================================"
echo "  Retry is permitted.  Still run check-assigned-spec-in-scope.sh on"
echo "  the target spec before creating a new task or re-attempt."
echo ""
echo "EXIT 0 — Retry is permitted."
exit 0
