#!/usr/bin/env bash
# check-task-ref-report-not-falsified.sh
#
# Cross-validates the check-commit-trailer-task-ref result in worker-result.yaml
# against the CURRENT exit code of check-commit-trailer-task-ref.sh.
#
# Observed pattern (task-001, cycle 18):
#   The implementer's worker-result.yaml contained:
#     "OK: All Task-Ref trailers on implementation commits match branch task ID 'task-001'."
#     "[EXIT 0]"
#   while check-commit-trailer-task-ref.sh actually exits 1 because commit 997ac24
#   still carries Task-Ref: task-007. The commit hash was unchanged, proving
#   git rebase -i was never executed. The implementer wrote the expected (passing)
#   output rather than the actual check output.
#
# Algorithm:
#   1. Skip if worker-result.yaml is absent (another check handles that).
#   2. Run check-commit-trailer-task-ref.sh and capture exit code.
#   3. If it exits 1 (mismatched trailers) AND the report claims "OK: All Task-Ref
#      trailers", emit FAIL (falsification).
#   4. Exit 0 otherwise (check passes, or report is honest about the failure).
#
# Exit 0 = report is consistent with actual check result.
# Exit 1 = report claims OK while check exits 1 (falsification).

set -uo pipefail

REPORT=".hyperloop/worker-result.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$REPORT" ]]; then
    echo "SKIP: $REPORT not found — check-report-scope-section.sh will catch this."
    exit 0
fi

# Run the actual trailer check and capture both output and exit code.
TRAILER_OUTPUT=$(bash "$SCRIPT_DIR/check-commit-trailer-task-ref.sh" 2>&1)
TRAILER_EXIT=$?

if [[ "$TRAILER_EXIT" -ne 0 ]]; then
    # The check is currently failing (mismatched Task-Ref found).
    # If the report claims a pass, that is falsification.
    if grep -q "OK: All Task-Ref trailers" "$REPORT"; then
        echo "FAIL: Falsification detected."
        echo "  check-commit-trailer-task-ref.sh exits $TRAILER_EXIT (mismatched Task-Ref present) but"
        echo "  worker-result.yaml contains 'OK: All Task-Ref trailers' in Check Script Results."
        echo "  The reported output does not reflect the actual check result."
        echo ""
        echo "  Likely cause: git rebase -i was not completed — the commit hash is unchanged."
        echo "  Verify with: git log --oneline main..HEAD"
        echo "  A reworded commit will have a different SHA than before the rebase."
        echo ""
        echo "  Actual check-commit-trailer-task-ref.sh output:"
        echo "$TRAILER_OUTPUT"
        exit 1
    fi
fi

echo "OK: Task-Ref report section is consistent with actual check-commit-trailer-task-ref.sh result."
exit 0
