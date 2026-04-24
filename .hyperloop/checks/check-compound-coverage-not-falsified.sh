#!/bin/bash
# check-compound-coverage-not-falsified.sh
#
# Cross-validates the compound THEN-clause coverage check result recorded in
# worker-result.yaml against the CURRENT exit code of
# check-compound-then-clause-coverage.sh.
#
# Catches: implementer runs run-all-checks.sh before fully populating the
# THEN→test mapping table (receiving SKIP because no "and" rows exist yet),
# then adds compound "AND"-prefixed rows to the table but submits without
# re-running checks — reporting stale SKIP/EXIT 0 while the check now exits 1.
#
# This is the same falsification pattern as check-scope-report-not-falsified.sh
# but applied to compound THEN-clause coverage.

REPORT=".hyperloop/worker-result.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$REPORT" ]; then
    echo "SKIP: No $REPORT found — cannot cross-validate compound coverage check."
    exit 0
fi

# Run the actual check now, against the current state of the file.
ACTUAL_OUTPUT=$(bash "$SCRIPT_DIR/check-compound-then-clause-coverage.sh" 2>&1)
ACTUAL_EXIT=$?

if [ "$ACTUAL_EXIT" -eq 0 ]; then
    echo "OK: check-compound-then-clause-coverage.sh exits 0 — no cross-validation needed."
    exit 0
fi

# The check currently fails. Inspect what the report claims for this check.
# run-all-checks.sh records output in this format:
#   --- check-compound-then-clause-coverage.sh ---
#   SKIP: ...   (or OK: ...)
#   [EXIT 0]
#
# We look for the check name followed within 5 lines by either a SKIP line
# or an [EXIT 0] line — either indicates a falsified passing result.
if grep -A5 "check-compound-then-clause-coverage" "$REPORT" | grep -qE '(^SKIP:|^\[EXIT 0\])'; then
    echo "FAIL: Falsification detected."
    echo "  check-compound-then-clause-coverage.sh exits $ACTUAL_EXIT (compound THEN-clauses"
    echo "  under-cited) but worker-result.yaml records SKIP or [EXIT 0] for this check."
    echo ""
    echo "  Root cause: checks were run before the THEN→test mapping table was finalized."
    echo "  After adding 'AND'-prefixed rows to the table, run-all-checks.sh was not re-run."
    echo ""
    echo "  Resolution: complete the mapping table first, then re-run:"
    echo "    bash .hyperloop/checks/run-all-checks.sh"
    echo "  and replace the entire ## Check Script Results section with the new output."
    echo ""
    echo "  Actual check output (current state of worker-result.yaml):"
    echo "$ACTUAL_OUTPUT"
    exit 1
fi

echo "OK: Compound coverage report is consistent with actual check result."
exit 0
