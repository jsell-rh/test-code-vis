#!/bin/bash
# check-script-skip-on-no-args.sh
#
# Validates that every check script exits 0 (SKIP) when called with no
# positional arguments.  Detects the anti-pattern where a script reads $1
# via ${1:-} but exits non-zero (typically exit 2 "usage error") when that
# argument is absent.
#
# Observed failure (task-119):
#   check-retry-not-scope-prohibited.sh exited 2 when called without a task
#   ID.  run-all-checks.sh calls every *.sh with no arguments, so every task
#   branch failed run-all-checks.sh even though all 46 other checks passed.
#   The correct pattern (from check-fail-report-classification.sh) is to
#   print "SKIP: ..." and exit 0 when the required argument is absent.
#
# Detection strategy (static analysis — no subprocess side-effects):
#   1. Consider only scripts that read a positional argument via ${1:-}.
#   2. In those scripts, find the first "exit N" statement (N = any digit).
#   3. If the first exit is exit 0, the empty-arg SKIP path is correct.
#   4. If the first exit is exit non-zero, the empty-arg check is wrong.
#
# Correct pattern:
#   ARG="${1:-}"
#   if [ -z "$ARG" ]; then
#       echo "SKIP: no <arg> provided."; exit 0   ← first exit must be 0
#   fi
#   if [ ! -f "$ARG" ]; then
#       echo "ERROR: ..."; exit 2                  ← exit 2 OK here (arg present)
#   fi
#
# Usage (from run-all-checks.sh — no argument needed):
#   bash .hyperloop/checks/check-script-skip-on-no-args.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename "${BASH_SOURCE[0]}")"

FAILED=0

for script in "$SCRIPT_DIR"/*.sh; do
    name="$(basename "$script")"
    [ "$name" = "$SELF" ] && continue
    [ "$name" = "run-all-checks.sh" ] && continue

    # Only inspect scripts that accept a positional argument via ${1:-}.
    grep -q '\${1:-}' "$script" || continue

    # Find the line number of the FIRST "exit N" statement (standalone exit).
    # Use '^[[:space:]]*exit [0-9]' to match only actual exit statements, not
    # occurrences inside heredocs, comments, or shell redirections like 2>&1.
    first_e0=$(grep -n '^[[:space:]]*exit 0' "$script" | head -1 | cut -d: -f1)
    first_e_nonzero=$(grep -n '^[[:space:]]*exit [1-9]' "$script" | head -1 | cut -d: -f1)

    if [ -z "$first_e0" ]; then
        # Script takes ${1:-} but never exits 0 — empty-arg SKIP path is missing.
        echo "FAIL: '$name' — reads \${1:-} but has no 'exit 0' path."
        echo "  Add a SKIP block before any exit non-zero:"
        echo "    if [ -z \"\$ARG\" ]; then echo \"SKIP: ...\"; exit 0; fi"
        FAILED=1
    elif [ -n "$first_e_nonzero" ] && [ "$first_e_nonzero" -lt "$first_e0" ]; then
        # The first non-zero exit comes BEFORE the first exit 0 — the empty-arg
        # check is firing with a non-zero code, which breaks run-all-checks.sh.
        echo "FAIL: '$name' — first exit non-zero (line $first_e_nonzero) precedes first exit 0 (line $first_e0)."
        echo "  The empty-arg check must exit 0 (SKIP), not exit non-zero."
        echo "  Correct pattern (from check-fail-report-classification.sh):"
        echo "    ARG=\"\${1:-}\""
        echo "    if [ -z \"\$ARG\" ]; then"
        echo "      echo \"SKIP: no <arg> provided.\"; exit 0"
        echo "    fi"
        FAILED=1
    fi
done

if [ "$FAILED" -eq 0 ]; then
    echo "OK: All argument-accepting check scripts exit 0 (SKIP) before any non-zero exit."
fi

exit "$FAILED"
