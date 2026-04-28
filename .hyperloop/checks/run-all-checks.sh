#!/bin/bash
# run-all-checks.sh
# Master runner: executes every *.sh in this directory (except itself)
# and aggregates results. Exits 1 if ANY check exits non-zero.
#
# Usage: bash .hyperloop/checks/run-all-checks.sh
# Both implementers and verifiers MUST use this runner and paste its
# complete output in their submission report. Running individual checks
# selectively is insufficient — this runner ensures none are omitted.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename "${BASH_SOURCE[0]}")"

OVERALL_FAIL=0
RAN=0

echo "=== run-all-checks.sh ==="
echo ""

for script in "$SCRIPT_DIR"/*.sh; do
    name="$(basename "$script")"
    [ "$name" = "$SELF" ] && continue
    [ -x "$script" ] || chmod +x "$script"

    RAN=$((RAN + 1))
    echo "--- $name ---"
    if bash "$script"; then
        echo "[EXIT 0]"
    else
        echo "[EXIT $? — FAIL]"
        OVERALL_FAIL=1
    fi
    echo ""
done

if [ $RAN -eq 0 ]; then
    echo "WARNING: No check scripts found in $SCRIPT_DIR"
    exit 0
fi

echo "=== Summary: $RAN check(s) run ==="
if [ $OVERALL_FAIL -ne 0 ]; then
    echo "RESULT: FAIL — one or more checks exited non-zero"
    exit 1
fi
echo "RESULT: ALL PASS"
