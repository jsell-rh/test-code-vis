#!/bin/bash
# check-end-to-end-integration-test.sh
#
# When a task requires end-to-end pipeline wiring (LLM producer → scene consumer),
# verify that at least one GDScript test exercises BOTH stages in a single test.
#
# Root cause (task-022): unit tests existed for LlmViewGenerator and SceneInterpreter
# individually, but no test called both in sequence. The spec required
# "end-to-end wiring" with an integration test. Two isolated unit tests do not
# constitute an integration test — the full call chain must appear in one test body.
#
# This check looks for a test file that references BOTH:
#   - a producer method (build_prompt, parse_response, or equivalent)
#   - a consumer method (apply_spec, render_spec, or equivalent)
#
# If both pipeline classes exist but no single test file references both stages,
# the check fails.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

GODOT_DIR="godot"
TESTS_DIR="$GODOT_DIR/tests"

if [ ! -d "$GODOT_DIR" ]; then
    echo "SKIP: No godot/ directory. Extractor-only task."
    exit 0
fi

if [ ! -f "$GODOT_DIR/project.godot" ]; then
    echo "SKIP: No project.godot. Godot project not initialised yet."
    exit 0
fi

# Only apply when BOTH a producer AND a consumer class exist in scripts/.
PRODUCER_EXISTS=$(grep -rl --include="*.gd" -E "func\s+(build_prompt|generate_prompt|parse_response)\s*\(" \
    "$GODOT_DIR/scripts/" 2>/dev/null || true)
CONSUMER_EXISTS=$(grep -rl --include="*.gd" -E "func\s+(apply_spec|apply_view|render_spec|interpret_spec)\s*\(" \
    "$GODOT_DIR/scripts/" 2>/dev/null || true)

if [ -z "$PRODUCER_EXISTS" ] || [ -z "$CONSUMER_EXISTS" ]; then
    echo "SKIP: Both a pipeline producer and consumer must exist for this check to apply."
    echo "      Producer (build_prompt / parse_response) found: ${PRODUCER_EXISTS:-none}"
    echo "      Consumer (apply_spec / render_spec) found: ${CONSUMER_EXISTS:-none}"
    exit 0
fi

echo "Producer class found: $PRODUCER_EXISTS"
echo "Consumer class found: $CONSUMER_EXISTS"

if [ ! -d "$TESTS_DIR" ]; then
    echo ""
    echo "FAIL: No godot/tests/ directory — integration tests are completely absent."
    exit 1
fi

# Look for a test file that references BOTH producer methods AND consumer methods.
# A file referencing only one stage is a unit test, not an integration test.
PRODUCER_PATTERNS=("build_prompt" "parse_response" "generate_prompt")
CONSUMER_PATTERNS=("apply_spec" "render_spec" "apply_view" "interpret_spec")

INTEGRATION_TEST_FOUND=""

for test_file in "$TESTS_DIR"/test_*.gd; do
    [ -f "$test_file" ] || continue

    HAS_PRODUCER=0
    HAS_CONSUMER=0

    for pat in "${PRODUCER_PATTERNS[@]}"; do
        if grep -q "$pat" "$test_file" 2>/dev/null; then
            HAS_PRODUCER=1
            break
        fi
    done

    for pat in "${CONSUMER_PATTERNS[@]}"; do
        if grep -q "$pat" "$test_file" 2>/dev/null; then
            HAS_CONSUMER=1
            break
        fi
    done

    if [ "$HAS_PRODUCER" -eq 1 ] && [ "$HAS_CONSUMER" -eq 1 ]; then
        INTEGRATION_TEST_FOUND="$test_file"
        break
    fi
done

if [ -z "$INTEGRATION_TEST_FOUND" ]; then
    echo ""
    echo "FAIL: No integration test found that exercises BOTH pipeline stages."
    echo ""
    echo "      Producer stage (build_prompt / parse_response) and consumer stage"
    echo "      (apply_spec / render_spec) each have unit tests, but NO single"
    echo "      test_*.gd file references both."
    echo ""
    echo "      An integration test is required when the spec says 'wire X → Y'."
    echo "      It must:"
    echo "        1. Call build_prompt(question, graph) to produce a prompt"
    echo "        2. Provide a mock LLM response (fixed JSON string)"
    echo "        3. Call parse_response(mock_response) to get a view spec"
    echo "        4. Call apply_spec(spec, anchors, scene_root) to mutate the scene"
    echo "        5. Assert the resulting scene-tree state (visible, position, etc.)"
    echo ""
    echo "      Two unit tests (one per stage) are NOT a substitute."
    exit 1
fi

echo ""
echo "OK: Integration test found that exercises both pipeline stages: $INTEGRATION_TEST_FOUND"
exit 0
