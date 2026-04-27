#!/bin/bash
# Verifies that the implementer's worker-result.yaml contains a "## Scope Check Output"
# section with the expected verbatim text from check-not-in-scope.sh.
#
# Run this AFTER drafting worker-result.yaml but BEFORE submitting.
# A missing or paraphrased section causes an automatic verifier FAIL.
#
# Recovery: if worker-result.yaml is absent from the working tree (e.g. deleted by an
# orchestrator cleanup commit), this script attempts to recover it from git history
# before failing.

REPORT=".hyperloop/worker-result.yaml"
RECOVERED=0

if [ ! -f "$REPORT" ]; then
  # Attempt to recover from the most recent git commit that contained the file.
  RECOVERY_SHA=$(git log --oneline -- "$REPORT" 2>/dev/null | head -1 | awk '{print $1}')
  if [ -n "$RECOVERY_SHA" ]; then
    echo "NOTE: $REPORT absent from working tree; recovering from commit $RECOVERY_SHA."
    REPORT_CONTENT=$(git show "${RECOVERY_SHA}:${REPORT}" 2>/dev/null)
    if [ -z "$REPORT_CONTENT" ]; then
      echo "FAIL: $REPORT not found and git recovery from $RECOVERY_SHA returned empty content."
      exit 1
    fi
    RECOVERED=1
    # Re-run checks against the recovered content (written to a temp file).
    TMP=$(mktemp)
    echo "$REPORT_CONTENT" > "$TMP"
    REPORT="$TMP"
    trap 'rm -f "$TMP"' EXIT
  else
    echo "FAIL: $REPORT not found and no prior git commit contains it — draft your report before running this check."
    exit 1
  fi
fi

if ! grep -q "^## Scope Check Output" "$REPORT"; then
  echo "FAIL: $REPORT is missing a '## Scope Check Output' section header."
  echo "      Add a standalone '## Scope Check Output' heading with the verbatim"
  echo "      stdout of '.hyperloop/checks/check-not-in-scope.sh' beneath it."
  echo "      Do NOT summarise the result in a bullet list — paste the raw output."
  exit 1
fi

# Accept either:
#   "OK: No prohibited"  — scope check passed (clean branch)
#   "FAIL: Prohibited"   — scope check failed, implementer truthfully pasted verbatim output
#
# Requiring ONLY the "OK" phrase creates a deadlock when a pre-existing artifact on main
# triggers check-not-in-scope.sh: the implementer cannot write the clean phrase (it would
# be falsification) and cannot omit it (this check would fail).  Accepting the FAIL phrase
# breaks the deadlock — truthful failure reporting is valid, and
# check-scope-report-not-falsified.sh will catch any attempt to write the clean phrase while
# the scope check actually fails.
if ! grep -q "OK: No prohibited" "$REPORT" && ! grep -q "FAIL: Prohibited" "$REPORT"; then
  echo "FAIL: The '## Scope Check Output' section does not contain the scope check output."
  echo "      Expected either:"
  echo "        - the clean phrase (scope check passed), or"
  echo "        - the failure phrase 'FAIL: Prohibited' (scope check failed — paste verbatim)"
  echo "      Paste the verbatim stdout of check-not-in-scope.sh unchanged."
  exit 1
fi

if [ "$RECOVERED" -eq 1 ]; then
  echo "OK: worker-result.yaml (recovered from git history) contains a valid '## Scope Check Output' section."
else
  echo "OK: worker-result.yaml contains a valid '## Scope Check Output' section (scope check ran and output was pasted verbatim)."
fi
exit 0
