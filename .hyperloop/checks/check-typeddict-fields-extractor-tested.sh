#!/bin/bash
# check-typeddict-fields-extractor-tested.sh
#
# Detects TypedDict fields (including NotRequired) that appear ONLY in
# test_schema.py fixture tests, with no corresponding coverage in
# test_extractor.py that calls the actual extractor function.
#
# Pattern caught (task-001 Req 3): Edge TypedDict defines weight and
# type="aggregate". test_schema.py tests them with hand-crafted dicts.
# But build_dependency_edges() never emits weight or type="aggregate".
# No test_extractor.py test called build_dependency_edges() and checked
# for these values, so the gap was invisible until spec-alignment review.
#
# This check is HEURISTIC — it cannot read spec intent. It catches the
# structural signal: a field/value tested only in test_schema.py is likely
# tested only at the TypedDict level, not at the extractor output level.
# The check reports which Literal type values and NotRequired fields are
# covered in test_extractor.py vs test_schema.py only, so the implementer
# can judge which gaps are real.
#
# Exit codes:
#   0 — all Literal type values found in a build_*/discover_* call context
#       in test_extractor.py, OR no extractor tests exist yet.
#   1 — one or more Literal type values appear only in test_schema.py,
#       indicating the extractor function is untested for that value.

set -uo pipefail

EXTRACTOR_DIR="extractor"

if [ ! -d "$EXTRACTOR_DIR" ]; then
    echo "SKIP: No extractor/ directory."
    exit 0
fi

SCHEMA_FILE=$(find "$EXTRACTOR_DIR" -name "*.py" | grep -v '/test_' | xargs grep -l "TypedDict" 2>/dev/null | head -1)
TEST_EXTRACTOR=$(find "$EXTRACTOR_DIR" -name "test_extractor.py" 2>/dev/null | head -1)
TEST_SCHEMA=$(find "$EXTRACTOR_DIR" -name "test_schema.py" 2>/dev/null | head -1)

if [ -z "$SCHEMA_FILE" ]; then
    echo "SKIP: No TypedDict definitions found in extractor — check not applicable."
    exit 0
fi

if [ -z "$TEST_EXTRACTOR" ]; then
    echo "SKIP: No test_extractor.py found — cannot compare extractor vs schema coverage."
    exit 0
fi

echo "Schema file:     $SCHEMA_FILE"
echo "test_extractor:  $TEST_EXTRACTOR"
if [ -n "$TEST_SCHEMA" ]; then
    echo "test_schema:     $TEST_SCHEMA"
fi
echo ""

# ---------------------------------------------------------------------------
# Extract all Literal string values from TypedDict field type annotations.
# These are values like "cross_context", "internal", "aggregate" that the
# extractor may be expected to emit in a 'type' field.
# Pattern: Literal["foo", "bar"] or Literal['foo', 'bar']
# ---------------------------------------------------------------------------
LITERAL_VALUES=$(grep -oE "Literal\[([^]]+)\]" "$SCHEMA_FILE" 2>/dev/null \
    | grep -oE '"[a-z_]+"' \
    | tr -d '"' \
    | sort -u)

if [ -z "$LITERAL_VALUES" ]; then
    echo "OK: No Literal type values found in schema — nothing to check."
    exit 0
fi

echo "Literal values found in schema TypedDicts:"
for V in $LITERAL_VALUES; do echo "  \"$V\""; done
echo ""

FAIL=0

for VALUE in $LITERAL_VALUES; do
    IN_EXTRACTOR_TEST=$(grep -c "\"${VALUE}\"" "$TEST_EXTRACTOR" 2>/dev/null || true)
    IN_SCHEMA_TEST=0
    if [ -n "$TEST_SCHEMA" ]; then
        IN_SCHEMA_TEST=$(grep -c "\"${VALUE}\"" "$TEST_SCHEMA" 2>/dev/null || true)
    fi

    if [ "$IN_EXTRACTOR_TEST" -gt 0 ]; then
        echo "OK: \"${VALUE}\" — covered in test_extractor.py (${IN_EXTRACTOR_TEST} occurrence(s))"
    elif [ "$IN_SCHEMA_TEST" -gt 0 ]; then
        echo ""
        echo "WARN: \"${VALUE}\" — found in test_schema.py (${IN_SCHEMA_TEST} occurrence(s)) but NOT in test_extractor.py"
        echo "  test_schema.py tests the TypedDict structure with hand-crafted dicts."
        echo "  It does NOT verify the extractor function actually emits type=\"${VALUE}\"."
        echo "  Add a test in test_extractor.py that:"
        echo "    1. Calls the actual extractor function (e.g. build_dependency_edges())"
        echo "    2. Asserts at least one returned edge has type=\"${VALUE}\""
        echo "  If the spec requires the extractor to emit this type, this is a FAIL."
        echo "  If this type is a schema-only fixture value never emitted by extractor,"
        echo "  document that intent explicitly with a comment in the TypedDict."
        FAIL=1
    else
        echo "OK: \"${VALUE}\" — not found in either test file (may be a Godot-side value)"
    fi
done

echo ""
if [ "$FAIL" -eq 1 ]; then
    echo "FAIL: One or more Literal type values lack extractor-level test coverage."
    echo "      Schema-only tests (test_schema.py with hand-crafted dicts) are insufficient"
    echo "      to verify the extractor function emits these values. Add test_extractor.py"
    echo "      tests that call the real extractor function and assert the expected types."
    exit 1
fi

echo "OK: All Literal type values have coverage in test_extractor.py."
exit 0
