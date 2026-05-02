#!/bin/bash
# check-individual-edge-weight.sh
#
# Verifies that build_dependency_edges() accumulates and emits a "weight"
# field on individual cross_context and internal edges — not only on aggregate
# edges.
#
# Blocking failure pattern (task-023): the spec says "each edge carries the
# import count (number of individual import statements between the pair)."
# build_dependency_edges() accumulated weight for aggregate edges only.
# Individual cross_context / internal edges were built from a deduplicated set
# with no per-(source,target) import count and no "weight" key.
# No test verified the field on individual edges.
#
# This check has two gates:
#   Gate 1 — Implementation: does the individual edge construction dict include
#             a "weight" key, AND does the function accumulate a per-pair count
#             for non-aggregate edges?
#   Gate 2 — Test coverage:  does test_extractor.py contain at least one
#             assertion that a cross_context or internal edge has "weight"?
#
# Exit codes:
#   0 — both gates pass (or the extractor does not exist — SKIP)
#   1 — one or both gates fail

set -uo pipefail

EXTRACTOR_SRC="extractor/extractor.py"
TEST_FILE="extractor/tests/test_extractor.py"

if [ ! -f "$EXTRACTOR_SRC" ]; then
    echo "SKIP: $EXTRACTOR_SRC not found — check not applicable."
    exit 0
fi

FAIL=0

# ── Gate 1: Implementation — individual edge dict includes "weight" ───────────
#
# The construction of individual cross_context / internal edges in
# build_dependency_edges() uses a pattern like:
#   {"source": src, "target": tgt, "type": etype}    ← no "weight" (FAIL)
#   {"source": src, "target": tgt, "type": etype, "weight": count}  ← OK
#
# We find the line(s) where the individual edge dicts are built (keyed by
# "type": etype or "type": "cross_context" or "type": "internal" in a list
# comprehension or loop that is NOT in the aggregate block), then check whether
# "weight" appears in a 5-line window around it.

INDIVIDUAL_CONSTRUCTION_LINES=$(grep -n '"type": etype\|"type":\s*"cross_context"\|"type":\s*"internal"' \
    "$EXTRACTOR_SRC" 2>/dev/null | grep -v 'aggregate' | grep -v '^\s*#' || true)

WEIGHT_IN_INDIVIDUAL=""
if [ -n "$INDIVIDUAL_CONSTRUCTION_LINES" ]; then
    while IFS= read -r hit; do
        line_num=$(echo "$hit" | cut -d: -f1)
        START=$(( line_num - 2 ))
        END=$(( line_num + 5 ))
        [ "$START" -lt 1 ] && START=1
        WINDOW=$(sed -n "${START},${END}p" "$EXTRACTOR_SRC" 2>/dev/null)
        if echo "$WINDOW" | grep -q '"weight"'; then
            WEIGHT_IN_INDIVIDUAL="line $line_num"
            break
        fi
    done <<< "$INDIVIDUAL_CONSTRUCTION_LINES"
fi

# Also check: does the function have a per-pair accumulator for non-aggregate
# edges (a dict keyed on (src,tgt) tuples that is NOT bc_pair_weight)?
# Acceptable names: mod_pair_weight, edge_pair_count, pair_count, etc.
INDIVIDUAL_ACCUMULATOR=$(grep -n \
    'mod_pair_weight\|edge_pair_count\|pair_count\|module_pair_weight\|import_weight\|cc_weight\|int_weight' \
    "$EXTRACTOR_SRC" 2>/dev/null | grep -v '^\s*#' || true)

if [ -z "$WEIGHT_IN_INDIVIDUAL" ] && [ -z "$INDIVIDUAL_ACCUMULATOR" ]; then
    echo ""
    echo "FAIL [Gate 1]: build_dependency_edges() does not emit 'weight' on"
    echo "  individual cross_context / internal edges."
    echo ""
    echo "  The spec SHALL: 'each edge carries the import count (number of individual"
    echo "  import statements between the pair).'"
    echo ""
    if [ -n "$INDIVIDUAL_CONSTRUCTION_LINES" ]; then
        echo "  Individual edge construction found at:"
        echo "$INDIVIDUAL_CONSTRUCTION_LINES" | sed 's/^/    /'
        echo "  but the 'weight' key is absent from those dicts."
    fi
    echo ""
    echo "  Required fix in build_dependency_edges():"
    echo "    1. Replace the raw_edges set with a dict[tuple, int] that accumulates"
    echo "       import count per (source_id, target_id, etype) triple:"
    echo "         raw_edge_count: dict[tuple[str,str,str], int] = {}"
    echo "         raw_edge_count[key] = raw_edge_count.get(key, 0) + 1"
    echo "    2. Emit weight on each individual edge:"
    echo "         {'source': src, 'target': tgt, 'type': etype, 'weight': count}"
    FAIL=1
else
    echo "OK [Gate 1]: Individual edge 'weight' field detected."
    [ -n "$WEIGHT_IN_INDIVIDUAL" ] && echo "  ('weight' key in individual edge dict near $WEIGHT_IN_INDIVIDUAL)"
    [ -n "$INDIVIDUAL_ACCUMULATOR" ] && echo "  (per-pair accumulator found for non-aggregate edges)"
fi

# ── Gate 2: Test coverage — test asserts weight on a non-aggregate edge ───────
#
# We look for a test in test_extractor.py that asserts 'weight' on an edge
# whose type is cross_context or internal (not only aggregate).

if [ ! -f "$TEST_FILE" ]; then
    echo ""
    echo "FAIL [Gate 2]: $TEST_FILE not found — cannot verify individual edge weight tests."
    FAIL=1
else
    # Check 1: test function name hints
    NAMED_TEST=$(grep -n \
        'def test.*cross.*weight\|def test.*internal.*weight\|def test.*individual.*weight\|def test.*module.*edge.*weight\|def test.*edge.*weight.*cross\|def test.*edge.*weight.*internal\|def test.*non.aggregate.*weight\|def test.*weight.*non.aggregate' \
        "$TEST_FILE" 2>/dev/null || true)

    # Check 2: "cross_context" or "internal" and "weight" in proximity (25-line window)
    # NOTE: the proximity hit must assert PRESENCE of weight ("weight" in e or e["weight"]),
    # NOT absence ("weight" not in e / assert "weight" not in ...). A test that asserts
    # the field is absent is the opposite of coverage — it is a false positive.
    PROXIMITY_HIT=""
    while IFS= read -r hit; do
        line_num=$(echo "$hit" | cut -d: -f1)
        START=$(( line_num - 5 ))
        END=$(( line_num + 25 ))
        [ "$START" -lt 1 ] && START=1
        WINDOW=$(sed -n "${START},${END}p" "$TEST_FILE" 2>/dev/null)
        if echo "$WINDOW" | grep -q '"weight"'; then
            # Exclude if the window only mentions aggregate
            if echo "$WINDOW" | grep '"weight"' | grep -q 'aggregate'; then
                continue
            fi
            # Exclude if every "weight" line in the window is a NOT-IN assertion
            # (asserting absence: `"weight" not in e` or `not in.*weight`)
            WEIGHT_LINES=$(echo "$WINDOW" | grep '"weight"')
            PRESENCE_LINES=$(echo "$WEIGHT_LINES" | grep -v 'not in\|not_in' || true)
            if [ -n "$PRESENCE_LINES" ]; then
                PROXIMITY_HIT="line $line_num"
                break
            fi
        fi
    done < <(grep -n '"cross_context"\|"internal"' "$TEST_FILE" 2>/dev/null \
        | grep -v '^\s*#' || true)

    if [ -z "$NAMED_TEST" ] && [ -z "$PROXIMITY_HIT" ]; then
        echo ""
        echo "FAIL [Gate 2]: No test in $TEST_FILE asserts 'weight' on a"
        echo "  cross_context or internal edge."
        echo ""
        echo "  test_aggregate_edge_has_weight covers aggregate edges only."
        echo "  A separate test is required, e.g.:"
        echo ""
        echo "    def test_cross_context_edge_has_weight(self, src: Path) -> None:"
        echo "        \"\"\"Every cross_context edge carries a weight field (import count).\"\"\""
        echo "        edges = build_dependency_edges(src, nodes)"
        echo "        cc_edges = [e for e in edges if e['type'] == 'cross_context']"
        echo "        assert cc_edges, 'Expected at least one cross_context edge'"
        echo "        for e in cc_edges:"
        echo "            assert 'weight' in e, f'cross_context edge missing weight: {e}'"
        echo "            assert e['weight'] >= 1, f'weight must be >= 1: {e}'"
        FAIL=1
    else
        echo "OK [Gate 2]: Test coverage for individual edge weight found."
        [ -n "$NAMED_TEST" ] && echo "  (named test: $(echo "$NAMED_TEST" | head -1 | sed 's/^[[:space:]]*//'))"
        [ -n "$PROXIMITY_HIT" ] && echo "  (weight assertion near cross_context/internal at $PROXIMITY_HIT)"
    fi
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "OK: Individual cross_context/internal edges carry weight — implementation and tests confirmed."
    exit 0
else
    echo "[EXIT 1 — FAIL]: Individual edge weight check failed. See details above."
    exit 1
fi
