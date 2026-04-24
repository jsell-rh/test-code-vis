#!/bin/bash
# check-reflects-mapping-consistency.sh
#
# Detects the "missed-sibling" pattern: two "X reflects Y" THEN-clauses that
# share the same concept keyword (the Y in "reflects Y") but cite different
# tests. This is the mechanical signature of a partial fix — one sibling was
# corrected to an algorithm-quality test while another was left pointing at a
# rendering-fidelity test (or vice-versa).
#
# A rendering-fidelity test loads pre-computed fixture values and asserts they
# appear unchanged in the scene tree. It passes even if the algorithm is random.
# When two "reflects Y" clauses diverge on test choice, at least one is wrong.
#
# Origin: task-034 — "position reflects coupling relationships" was left mapped
# to test_anchor_positions_match_json (rendering-fidelity) while the companion
# clause "relative positions reflect coupling" was correctly mapped to
# test_coupled_bcs_are_closer_than_uncoupled (algorithm-quality).
#
# How it works:
#   1. Extract every markdown table row in worker-result.yaml that contains
#      the word "reflects".
#   2. From each row, parse the THEN-clause (column 2) and the cited test
#      (column 3, first token).
#   3. Extract the first word after "reflects" as the concept keyword.
#   4. If two rows share a concept keyword but cite different tests, FAIL.
#
# False positives: rare — two distinct properties sharing the same first word
# after "reflects". When this occurs, the FAIL output names both rows so the
# reviewer can judge manually.

set -uo pipefail

RESULT_FILE=".hyperloop/worker-result.yaml"

if [[ ! -f "$RESULT_FILE" ]]; then
    echo "SKIP: $RESULT_FILE not found."
    exit 0
fi

# Extract table rows that contain "reflect" or "reflects" (case-insensitive)
# NOTE: use '^|' (literal pipe) not '^\|' — in GNU grep BRE, '\|' is the
# alternation operator, so '^\|' matches every line (^ OR empty-string).
reflects_rows=$(grep -iP '\breflects?\b' "$RESULT_FILE" | grep '^|' || true)

if [[ -z "$reflects_rows" ]]; then
    echo "SKIP: No 'reflect(s)' THEN-clauses found in mapping table."
    exit 0
fi

FAIL=0
# Maps concept keyword → first test seen for that concept
declare -A concept_to_test
# Maps concept keyword → clause text (for error messages)
declare -A concept_to_clause
# Separate integer counter: bash 5.2 treats ${#declare -A arr[@]} as unbound
# under set -u when the array was declared but never assigned.
concept_count=0

while IFS= read -r row; do
    # Parse markdown table cells: | THEN-clause | test-name | verdict |
    then_clause=$(echo "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    test_cell=$(echo "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
    # Take only the first whitespace-separated token from the test cell
    # (handles "test_foo + test_bar" compound entries — first test is enough
    # to detect divergence within the concept group)
    test_name=$(echo "$test_cell" | awk '{print $1}')

    [[ -z "$then_clause" || -z "$test_name" ]] && continue
    # Only process rows whose THEN-clause actually contains "reflect" or "reflects"
    echo "$then_clause" | grep -qiP '\breflects?\b' || continue

    # Extract the first word that follows "reflect(s) " (case-insensitive)
    # \K resets the match start so we don't need a fixed-width lookbehind;
    # handles both "reflect" and "reflects" (singular/plural).
    concept=$(echo "$then_clause" \
        | grep -oiP '\breflects?\s+\K\w+' \
        | head -1 \
        | tr '[:upper:]' '[:lower:]' || true)
    [[ -z "$concept" ]] && continue

    if [[ -v "concept_to_test[$concept]" ]]; then
        prev_test="${concept_to_test[$concept]}"
        prev_clause="${concept_to_clause[$concept]}"
        if [[ "$prev_test" != "$test_name" ]]; then
            echo "FAIL: Two 'reflects $concept' THEN-clauses cite different tests:"
            echo "  Clause A: $(echo "$prev_clause" | cut -c1-80) → $prev_test"
            echo "  Clause B: $(echo "$then_clause" | cut -c1-80) → $test_name"
            echo "  At least one is likely a rendering-fidelity test (loads pre-computed"
            echo "  values; passes even if the algorithm is random). Open both tests,"
            echo "  read their fixtures and asserts, and update any wrong-predicate mapping"
            echo "  to the algorithm-quality test (varies '$concept' in fixture, asserts"
            echo "  relative output changes accordingly)."
            FAIL=1
        fi
    else
        concept_to_test[$concept]="$test_name"
        concept_to_clause[$concept]="$then_clause"
        ((concept_count++)) || true
    fi
done <<< "$reflects_rows"

if [[ $FAIL -eq 1 ]]; then
    exit 1
fi

count=$concept_count
echo "OK: All $count 'reflects' concept group(s) cite consistent tests across THEN-clauses."
exit 0
