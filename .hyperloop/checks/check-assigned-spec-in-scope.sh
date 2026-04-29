#!/bin/bash
# check-assigned-spec-in-scope.sh
#
# STEP 0 TOOL — run this BEFORE reading your assigned spec in detail.
#
# Validates that a spec file does not describe a feature prohibited by
# specs/prototype/prototype-scope.spec.md.  Exits non-zero and prints a
# clear FAIL message if the spec is prohibited so the implementer can write
# the failure report immediately without needing to reason through the spec.
#
# Usage (manual — Step 0):
#   bash .hyperloop/checks/check-assigned-spec-in-scope.sh <spec-path>
#
# Usage (via run-all-checks.sh — no argument):
#   Script SKIPs gracefully so the master runner is not broken.
#
# When called from run-all-checks.sh the spec-level gate is informational;
# the code-level gate (check-not-in-scope.sh) is the authoritative barrier
# for completed branches.
#
# Observed failure (task-024, Repeated):
#   specs/interaction/moldable-views.spec.md was assigned as a task twice.
#   Each time the implementer had to manually reason through Step 0 before
#   discovering the assignment was invalid.  This script makes that detection
#   instantaneous and mechanical.

set -uo pipefail

SPEC_FILE="${1:-}"

# ── No argument: skip gracefully (called from run-all-checks.sh) ──────────────
if [ -z "$SPEC_FILE" ]; then
    echo "SKIP: No spec path provided — run manually at Step 0:"
    echo "  bash .hyperloop/checks/check-assigned-spec-in-scope.sh <spec-path>"
    exit 0
fi

if [ ! -f "$SPEC_FILE" ]; then
    echo "ERROR: Spec file not found: $SPEC_FILE"
    exit 1
fi

FAIL=0

# ── 1. Known prohibited spec files (by canonical path) ───────────────────────
# These specs describe features that are unconditionally excluded from the
# prototype phase.  Assigning them as implementer tasks is an INVALID ASSIGNMENT.
# Populated from specs/prototype/prototype-scope.spec.md § "Not In Scope".
#
# When a spec is repeatedly mis-assigned, add its path here so future mis-
# assignments are caught in under one second without any human reasoning.

declare -a PROHIBITED_SPECS=(
    "specs/interaction/moldable-views.spec.md"
)

MATCHED_PROHIBITED=0
for prohibited in "${PROHIBITED_SPECS[@]}"; do
    norm_input="${SPEC_FILE#./}"
    norm_prohibited="${prohibited#./}"
    if [ "$norm_input" = "$norm_prohibited" ]; then
        echo "FAIL: INVALID ASSIGNMENT — '$SPEC_FILE' is a permanently prohibited spec."
        echo "  This spec describes a feature explicitly excluded from the prototype phase."
        echo "  Prohibited feature: moldable views (LLM-powered question-driven views)"
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 93"
        echo ""
        echo "  Do NOT read the spec further.  Do NOT write any implementation code."
        echo "  Write a FAIL report that quotes this output verbatim and stop."
        FAIL=1
        MATCHED_PROHIBITED=1
        break
    fi
done

# ── 2. Prohibited feature keyword search in spec content ──────────────────────
# Applied only to specs OUTSIDE specs/prototype/ (the prototype-scope spec
# itself mentions every prohibited feature by design and must not self-trigger).
# Catches prohibited features assigned under alternative spec file names.
# Patterns target IMPLEMENTING language (SHALL/MUST + feature), not reference language.

_norm_path="${SPEC_FILE#./}"

# Only run keyword check for specs not already caught by the path list and
# not inside specs/prototype/ (where the authoritative scope definitions live).
if [ "$MATCHED_PROHIBITED" -eq 0 ] && [[ "$_norm_path" != specs/prototype/* ]]; then
    _spec_content=$(cat "$SPEC_FILE")

    # Moldable views: look for SHALL/MUST combined with LLM-or-question-driven view language.
    # Requires both a requirement verb AND the feature concept to reduce false positives.
    if echo "$_spec_content" | grep -qi "shall\|must" && \
       echo "$_spec_content" | grep -qi \
           "moldable.view\|question.driven.view\|llm.*generat.*view\|natural.language.*question.*view\|view.*from.*natural.language"; then
        echo "FAIL: Spec content matches prohibited feature: moldable views (LLM-powered question-driven views)"
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 93"
        FAIL=1
    fi

    # Spec extraction: look for SHALL/MUST + spec extraction language.
    if echo "$_spec_content" | grep -qi "shall\|must" && \
       echo "$_spec_content" | grep -qi "extract.*spec.node\|spec.overlay.comparison\|parse.*spec.file"; then
        echo "FAIL: Spec content matches prohibited feature: spec extraction"
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 94"
        FAIL=1
    fi

    # Conformance / evaluation / simulation modes: active SHALL/MUST language.
    if echo "$_spec_content" | grep -qiE "(shall|must).*(conformance mode|evaluation mode|simulation mode)"; then
        echo "FAIL: Spec content matches prohibited feature: conformance/evaluation/simulation mode"
        echo "  Authority: specs/prototype/prototype-scope.spec.md lines 89-91"
        FAIL=1
    fi

    # Data flow visualization: look for SHALL/MUST + data flow visualization language.
    if echo "$_spec_content" | grep -qi "shall\|must" && \
       echo "$_spec_content" | grep -qi "data.flow.visualization\|visuali[sz]e.*data.flow"; then
        echo "FAIL: Spec content matches prohibited feature: data flow visualization"
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 92"
        FAIL=1
    fi

    # First-person navigation: look for SHALL/MUST + first-person navigation language.
    if echo "$_spec_content" | grep -qi "shall\|must" && \
       echo "$_spec_content" | grep -qi "first.person.navigation\|first.person.camera\|first.person.view"; then
        echo "FAIL: Spec content matches prohibited feature: first-person navigation"
        echo "  Authority: specs/prototype/prototype-scope.spec.md line 95"
        FAIL=1
    fi
fi

# ── Result ────────────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
    echo "OK: '$SPEC_FILE' does not match any prohibited feature."
    echo "  Assignment appears in-scope — continue to manual Step 0 review against"
    echo "  specs/prototype/prototype-scope.spec.md § 'Not In Scope'."
fi

exit "$FAIL"
