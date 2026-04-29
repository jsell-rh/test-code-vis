#!/bin/bash
# check-compute-functions-called-from-entry-point.sh
#
# Verifies that every compute_*() function defined in the extractor package
# is called from the pipeline entry point (build_scene_graph).
#
# Pattern caught (task-001 Req 7): compute_cascade_depth() was implemented
# and unit-tested in isolation, but build_scene_graph() never called it.
# Depth values were therefore absent from all output — a function that is
# correct and tested in isolation is dead code if the entry point never
# invokes it.
#
# Limitation: traces only direct calls in the entry-point file. Delegation
# through an intermediate helper is not followed. If you delegate, ensure
# the intermediate is itself called from build_scene_graph().

set -uo pipefail

EXTRACTOR_DIR="extractor"

if [ ! -d "$EXTRACTOR_DIR" ]; then
    echo "SKIP: No extractor/ directory — check not applicable."
    exit 0
fi

# Find the file containing build_scene_graph (production files only).
ENTRY_FILE=$(grep -rl "def build_scene_graph" "$EXTRACTOR_DIR" \
    --include="*.py" 2>/dev/null \
    | grep -v '/test_' \
    | head -1)

if [ -z "$ENTRY_FILE" ]; then
    echo "SKIP: build_scene_graph() not found in extractor — check not applicable."
    exit 0
fi

echo "Entry point file: $ENTRY_FILE"

# Collect all compute_* function names defined in non-test extractor source.
COMPUTE_FNS=$(grep -rh "^def compute_" "$EXTRACTOR_DIR" \
    --include="*.py" 2>/dev/null \
    | grep -v '/test_' \
    | sed 's/def \(compute_[a-zA-Z0-9_]*\).*/\1/' \
    | sort -u)

if [ -z "$COMPUTE_FNS" ]; then
    echo "OK: No compute_* functions defined in extractor — nothing to wire-check."
    exit 0
fi

FAIL=0

for FN in $COMPUTE_FNS; do
    # A call appears as: compute_foo( or assigned via alias then called.
    # We check the entry-point file for the name followed by '(' which
    # covers direct calls and variable aliases like: fn = compute_foo; fn(...)
    # The latter is rare enough that direct-call coverage is sufficient.
    if grep -q "${FN}(" "$ENTRY_FILE"; then
        echo "OK: ${FN}() is called from ${ENTRY_FILE}"
    else
        echo ""
        echo "FAIL: ${FN}() is defined in extractor but is NOT called from ${ENTRY_FILE}"
        echo "  build_scene_graph() must call ${FN}() (or a helper that calls it)"
        echo "  so its output is embedded in the scene graph returned to callers."
        echo "  A utility tested in isolation but unreachable from the entry point"
        echo "  is dead code — its results never appear in any output."
        echo ""
        echo "  Fix options:"
        echo "    (a) Add a call to ${FN}() inside build_scene_graph() and embed"
        echo "        its return value into the appropriate output structure."
        echo "    (b) If a helper already calls it, call that helper from"
        echo "        build_scene_graph() and verify the chain with grep."
        FAIL=1
    fi
done

exit "$FAIL"
