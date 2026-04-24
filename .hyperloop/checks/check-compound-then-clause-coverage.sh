#!/bin/bash
# check-compound-then-clause-coverage.sh
#
# Verifies that THEN-clauses listing multiple capabilities joined by "and"
# (e.g. "pan, zoom, and rotate") cite at least 2 test functions in the
# THEN→test mapping.
#
# A compound THEN-clause mapped to a single test that covers only one of the
# listed capabilities is a wrong-predicate mapping — identical to an unmapped
# clause. This check catches the mechanical case where the implementer cited
# exactly one test for a multi-capability requirement.
#
# Note: This check is necessary but not sufficient. A compound clause with 2+
# tests still requires the verifier to read each test body and confirm each
# cited test actually covers its respective capability.

RESULT_FILE=".hyperloop/worker-result.yaml"

if [ ! -f "$RESULT_FILE" ]; then
    echo "SKIP: No $RESULT_FILE found — cannot check compound THEN-clause coverage."
    exit 0
fi

FAIL=0
CHECKED=0

# Scan markdown table rows for compound THEN-clauses.
# A compound clause contains the word "and" surrounded by word boundaries.
# Table row format: | THEN text | test_name(s) | PASS |
#
# We look at lines that:
#   1. Start with | (markdown table row)
#   2. Are NOT the header/separator row (--- pattern)
#   3. Contain " and " in the THEN-clause (first cell)
#
while IFS= read -r line; do
    # Skip separator rows and header rows
    echo "$line" | grep -qE '^\|[-: |]+\|' && continue

    # Only process table data rows
    echo "$line" | grep -qE '^\|' || continue

    # Extract first cell (THEN-clause text)
    first_cell=$(echo "$line" | awk -F'|' '{print $2}' | xargs)

    # Skip rows where first cell does not contain " and " (word boundary)
    echo "$first_cell" | grep -qwi 'and' || continue

    # Count test_ references in this row
    test_count=$(echo "$line" | grep -oE '\btest_[a-zA-Z0-9_]+' | wc -l)
    CHECKED=$((CHECKED + 1))

    if [ "$test_count" -lt 2 ]; then
        echo "FAIL: Compound THEN-clause '${first_cell}' contains 'and' but cites only ${test_count} test(s) — must cite ≥2 (one per capability)."
        FAIL=1
    else
        echo "OK: '${first_cell}' cites ${test_count} test(s) for compound clause."
    fi
done < "$RESULT_FILE"

if [ "$CHECKED" -eq 0 ]; then
    echo "SKIP: No compound THEN-clauses (containing 'and') found in THEN→test mapping."
    exit 0
fi

if [ "$FAIL" -eq 0 ]; then
    echo "OK: All ${CHECKED} compound THEN-clause(s) cite multiple tests."
fi

exit "$FAIL"
