#!/bin/bash
# check-fail-report-classification.sh
#
# PRE-RETRY GATE — run this on a FAIL report before scheduling any re-attempt.
#
# Classifies a FAIL report as one of two types:
#   EXIT 0 — Implementation FAIL: checks/tests failed; a retry is appropriate.
#   EXIT 1 — Scope-prohibition FAIL: the assignment was invalid; NO retry, ever.
#
# Usage:
#   bash .hyperloop/checks/check-fail-report-classification.sh <fail-report-path>
#
# When to run:
#   Before creating ANY re-attempt task (same task ID or new task number) for
#   a previously failed task.  If this exits 1, permanently close the original
#   task and do NOT create a re-attempt.
#
# Observed failure (task-028 re-attempted as task-031):
#   task-028 returned a scope-prohibition FAIL ("INVALID ASSIGNMENT" for
#   specs/core/understanding-modes.spec.md).  This was treated as an
#   implementation FAIL and retried as task-031, which produced the identical FAIL.
#   Two wasted cycles; the FAIL report contained zero implementer-fixable content.

set -uo pipefail

FAIL_REPORT="${1:-}"

if [ -z "$FAIL_REPORT" ]; then
    echo "Usage: $0 <fail-report-path>"
    echo "  Provide the path to the FAIL report file to classify."
    exit 2
fi

if [ ! -f "$FAIL_REPORT" ]; then
    echo "ERROR: FAIL report not found: $FAIL_REPORT"
    exit 2
fi

CONTENT=$(cat "$FAIL_REPORT")

# Scope-prohibition FAILs contain "INVALID ASSIGNMENT" — injected verbatim by
# implementers per protocol when check-assigned-spec-in-scope.sh exits non-zero.
if echo "$CONTENT" | grep -q "INVALID ASSIGNMENT"; then
    echo "CLASSIFICATION: SCOPE-PROHIBITION FAIL"
    echo ""
    echo "  This FAIL report contains 'INVALID ASSIGNMENT' — the assigned spec is"
    echo "  prohibited for the prototype phase.  No implementer action can resolve"
    echo "  this.  A different implementer, a re-worded task, or a new task number"
    echo "  for the same spec reaches the identical result."
    echo ""
    echo "  REQUIRED ACTIONS:"
    echo "    1. Permanently close this task — do NOT schedule a re-attempt."
    echo "    2. Do NOT create a new task number for the same spec."
    echo "    3. Verify the prohibited spec is listed in check-assigned-spec-in-scope.sh."
    echo "    4. Verify the spec appears in the prohibited-spec tables in"
    echo "       orchestrator-overlay.yaml and pm-overlay.yaml."
    echo "    5. Investigate how this spec re-entered the candidate pool and close"
    echo "       that upstream gap."
    echo ""
    echo "EXIT 1 — Retry is FORBIDDEN."
    exit 1
fi

echo "CLASSIFICATION: IMPLEMENTATION FAIL"
echo ""
echo "  No 'INVALID ASSIGNMENT' language detected.  This appears to be an"
echo "  implementation FAIL (failing checks, missing tests, broken code) that"
echo "  an implementer can resolve.  Scheduling a re-attempt is appropriate."
echo ""
echo "EXIT 0 — Retry is permitted."
exit 0
