#!/bin/bash
# Verifies that the implementer's worker-result.yaml contains a "## Scope Check Output"
# section with the expected verbatim text from check-not-in-scope.sh.
#
# Run this AFTER drafting worker-result.yaml but BEFORE submitting.
# A missing or paraphrased section causes an automatic verifier FAIL.

REPORT=".hyperloop/worker-result.yaml"

if [ ! -f "$REPORT" ]; then
  echo "FAIL: $REPORT not found — draft your report before running this check."
  exit 1
fi

if ! grep -q "^## Scope Check Output" "$REPORT"; then
  echo "FAIL: $REPORT is missing a '## Scope Check Output' section header."
  echo "      Add a standalone '## Scope Check Output' heading with the verbatim"
  echo "      stdout of '.hyperloop/checks/check-not-in-scope.sh' beneath it."
  echo "      Do NOT summarise the result in a bullet list — paste the raw output."
  exit 1
fi

if ! grep -q "OK: No prohibited" "$REPORT"; then
  echo "FAIL: The '## Scope Check Output' section in $REPORT does not contain"
  echo "      the expected text 'OK: No prohibited'."
  echo "      Paste the verbatim stdout of check-not-in-scope.sh unchanged."
  exit 1
fi

echo "OK: worker-result.yaml contains a valid '## Scope Check Output' section."
exit 0
