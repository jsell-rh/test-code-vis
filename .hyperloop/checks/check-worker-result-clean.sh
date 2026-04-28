#!/usr/bin/env bash
# check-worker-result-clean.sh
#
# Detects when an implementer pastes a FAIL run-all-checks.sh summary into
# worker-result.yaml and attempts to submit it as a completed deliverable.
#
# Observed pattern (task-014, cycles 1–8):
#   The implementer ran run-all-checks.sh (which exited 1), then pasted its
#   FAIL output — including the "RESULT: FAIL" summary line — verbatim into
#   worker-result.yaml and submitted.  check-no-zero-commit-reattempt.sh
#   and check-racf-prior-cycle.sh both caught this, but the implementer
#   repeated the pattern 8 consecutive times with zero code changes.
#
#   This check creates a self-enforcing loop: if the pasted run-all-checks.sh
#   output contains "RESULT: FAIL", this check itself exits 1, which causes
#   run-all-checks.sh to exit 1, which means the implementer cannot produce
#   a valid submission until the underlying failures are actually fixed.
#   A worker-result.yaml can ONLY pass run-all-checks.sh when ALL checks
#   passed in the run whose output was pasted.
#
# Algorithm:
#   1. Read worker-result.yaml.
#   2. Search for a "RESULT: FAIL" line inside the ## Check Script Results
#      section — the canonical location where check output is pasted.
#   3. Exit 1 if found; exit 0 otherwise.
#
# Exit 0 = worker-result.yaml not found, no Check Script Results section,
#          or pasted output shows RESULT: ALL PASS (or no summary line yet).
# Exit 1 = pasted output contains "RESULT: FAIL" — submission is invalid.

set -uo pipefail

RESULT_FILE=".hyperloop/worker-result.yaml"

if [[ ! -f "$RESULT_FILE" ]]; then
    echo "SKIP: $RESULT_FILE not found — nothing to check."
    exit 0
fi

# Extract only the ## Check Script Results section to avoid false positives
# from findings text that might quote a FAIL line.
SECTION=$(awk '
    /^## Check Script Results/ { in_section=1; next }
    /^## / && in_section       { in_section=0 }
    in_section                 { print }
' "$RESULT_FILE")

if [[ -z "$SECTION" ]]; then
    echo "SKIP: No '## Check Script Results' section found — report not yet written."
    exit 0
fi

# Look for the run-all-checks.sh summary FAIL line
FAIL_LINE=$(echo "$SECTION" | grep '^RESULT: FAIL' | head -1 || true)

if [[ -z "$FAIL_LINE" ]]; then
    echo "OK: Check Script Results section does not contain a FAIL summary — report is clean."
    exit 0
fi

echo "FAIL: worker-result.yaml '## Check Script Results' section contains a FAIL summary."
echo ""
echo "  Detected: $FAIL_LINE"
echo ""
echo "  You pasted the output of a run-all-checks.sh run that exited non-zero into"
echo "  your report and attempted to submit it. This is not a valid submission."
echo ""
echo "  A submission is only valid when run-all-checks.sh exits 0."
echo "  This check is part of run-all-checks.sh, so it will catch any attempt to"
echo "  paste a FAIL result: the report can only be clean when all checks pass."
echo ""
echo "  Protocol:"
echo "    1. Do NOT write or update worker-result.yaml while any check is failing."
echo "    2. Fix the underlying check failures first (apply the prescribed code changes)."
echo "    3. Run bash .hyperloop/checks/run-all-checks.sh until it exits 0."
echo "    4. THEN paste the clean output into worker-result.yaml."
echo "    5. Re-run bash .hyperloop/checks/run-all-checks.sh to confirm the report is valid."
exit 1
