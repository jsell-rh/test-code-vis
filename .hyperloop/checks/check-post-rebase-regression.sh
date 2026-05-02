#!/usr/bin/env bash
# Post-rebase regression guard.
#
# Run immediately after every `git rebase origin/main` to catch the four most
# common rebase regression patterns before writing any implementation code.
#
# Bundles:
#   1. check-rebased-onto-main.sh     — branch ancestry is current
#   2. check-run-tests-suite-count.sh — no _run_suite() registrations lost
#   3. check-class-test-count.sh      — no class-method Python tests dropped
#   4. check-pytest-test-count.sh     — no top-level Python tests dropped
#
# Observed failures (task-082, task-089, task-029): all three dropped main's
# PortRenderer suite registration and 2 class-method tests during conflict
# resolution. Only checks 1 and 4 were in the prior post-rebase sequence;
# checks 2 and 3 were absent, so the regressions reached verifier review.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CHECKS=(
    "check-rebased-onto-main.sh"
    "check-run-tests-suite-count.sh"
    "check-class-test-count.sh"
    "check-pytest-test-count.sh"
)

EXIT=0

for CHECK in "${CHECKS[@]}"; do
    echo "--- ${CHECK} ---"
    if bash "${SCRIPT_DIR}/${CHECK}"; then
        echo "EXIT 0"
    else
        echo "EXIT 1 — FAIL"
        EXIT=1
    fi
    echo ""
done

if [ "${EXIT}" -ne 0 ]; then
    echo "FAIL: One or more post-rebase regression checks failed."
    echo "Fix all failures before running run-all-checks.sh or writing implementation code."
    exit 1
fi

echo "OK: All post-rebase regression checks passed."
exit 0
