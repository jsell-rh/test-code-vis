#!/bin/bash
# check-coordinator-calls-pipeline.sh
#
# Verify that the pipeline consumer (SceneInterpreter / apply_spec or equivalent)
# is actually CALLED from a coordinator script (main.gd or similar) — not merely
# defined in its own class file.
#
# Root cause (task-022): check-pipeline-wiring.sh found `apply_spec` in
# scene_interpreter.gd, but that matched the DEFINITION (`func apply_spec(…)`),
# not a call from a coordinator. main.gd never referenced the class at all.
# A method defined but never called means the pipeline is completely unwired.
#
# Exit 0 = OK or SKIP.  Exit 1 = FAIL.

set -uo pipefail

GODOT_DIR="godot"

if [ ! -d "$GODOT_DIR" ]; then
    echo "SKIP: No godot/ directory. Extractor-only task."
    exit 0
fi

if [ ! -f "$GODOT_DIR/project.godot" ]; then
    echo "SKIP: No project.godot. Godot project not initialised yet."
    exit 0
fi

# Only apply this check when a pipeline consumer class exists.
CONSUMER_DEF_FILES=$(grep -rl --include="*.gd" -E "func\s+(apply_spec|apply_view|render_spec|interpret_spec|update_scene)\s*\(" \
    "$GODOT_DIR/scripts/" 2>/dev/null || true)

if [ -z "$CONSUMER_DEF_FILES" ]; then
    echo "SKIP: No pipeline consumer method (apply_spec / render_spec / etc.) found in godot/scripts/."
    echo "      This check only applies to tasks that implement a view-spec consumer."
    exit 0
fi

echo "Pipeline consumer defined in: $CONSUMER_DEF_FILES"

# Also check if a pipeline producer (LlmViewGenerator / build_prompt) exists.
PRODUCER_DEF_FILES=$(grep -rl --include="*.gd" -E "func\s+(build_prompt|generate_prompt|create_prompt)\s*\(" \
    "$GODOT_DIR/scripts/" 2>/dev/null || true)

if [ -n "$PRODUCER_DEF_FILES" ]; then
    echo "Pipeline producer defined in: $PRODUCER_DEF_FILES"
fi

FAIL=0

# -----------------------------------------------------------------------
# 1. Consumer call-site check.
#    Look for files that CALL the consumer method (pattern with open-paren)
#    but are NOT the file that defines it (which contains "func apply_spec").
# -----------------------------------------------------------------------
CONSUMER_CALL_PATTERNS=("apply_spec\s*\(" "apply_view\s*\(" "render_spec\s*\(" "interpret_spec\s*\(" "update_scene\s*\(")
CALLER_FILES=""

for pattern in "${CONSUMER_CALL_PATTERNS[@]}"; do
    # Collect all .gd files in scripts/ that match the call pattern
    CANDIDATES=$(grep -rl --include="*.gd" -E "$pattern" "$GODOT_DIR/scripts/" 2>/dev/null || true)
    for f in $CANDIDATES; do
        # Skip the file if it contains the function DEFINITION (func apply_spec...)
        if grep -qE "func\s+(apply_spec|apply_view|render_spec|interpret_spec|update_scene)\s*\(" "$f" 2>/dev/null; then
            continue
        fi
        CALLER_FILES="$CALLER_FILES $f"
    done
done

CALLER_FILES=$(echo "$CALLER_FILES" | tr ' ' '\n' | sort -u | grep -v '^$' || true)

if [ -z "$CALLER_FILES" ]; then
    echo ""
    echo "FAIL: Pipeline consumer is defined but never CALLED from outside its own file."
    echo "      The consumer method (apply_spec / etc.) exists in a class, but no"
    echo "      coordinator script (main.gd or equivalent) calls it."
    echo "      The pipeline is defined but completely unwired."
    echo ""
    echo "      Required: main.gd (or a coordinator) must contain a line like:"
    echo "        scene_interpreter.apply_spec(spec, _anchors, self)"
    echo "        var interp = SceneInterpreter.new(); interp.apply_spec(...)"
    echo ""
    echo "      Defining apply_spec() inside scene_interpreter.gd does NOT wire"
    echo "      the pipeline — only a call site in a coordinator does."
    FAIL=1
else
    echo "Consumer caller(s) found: $CALLER_FILES"
fi

# -----------------------------------------------------------------------
# 2. Producer call-site check (if a producer also exists).
#    Verify that a coordinator calls build_prompt / generate_prompt too.
# -----------------------------------------------------------------------
if [ -n "$PRODUCER_DEF_FILES" ]; then
    PRODUCER_CALL_PATTERNS=("build_prompt\s*\(" "generate_prompt\s*\(" "create_prompt\s*\(")
    PRODUCER_CALLERS=""

    for pattern in "${PRODUCER_CALL_PATTERNS[@]}"; do
        CANDIDATES=$(grep -rl --include="*.gd" -E "$pattern" "$GODOT_DIR/scripts/" 2>/dev/null || true)
        for f in $CANDIDATES; do
            # Skip the definition file itself
            if grep -qE "func\s+(build_prompt|generate_prompt|create_prompt)\s*\(" "$f" 2>/dev/null; then
                continue
            fi
            PRODUCER_CALLERS="$PRODUCER_CALLERS $f"
        done
    done

    PRODUCER_CALLERS=$(echo "$PRODUCER_CALLERS" | tr ' ' '\n' | sort -u | grep -v '^$' || true)

    if [ -z "$PRODUCER_CALLERS" ]; then
        echo ""
        echo "FAIL: Pipeline producer (build_prompt / etc.) is defined but never CALLED"
        echo "      from outside its own class file."
        echo "      A coordinator must call build_prompt() to start the LLM pipeline."
        FAIL=1
    else
        echo "Producer caller(s) found: $PRODUCER_CALLERS"
    fi
fi

# -----------------------------------------------------------------------
# Result
# -----------------------------------------------------------------------
if [ "$FAIL" -eq 1 ]; then
    exit 1
fi

echo ""
echo "OK: Pipeline consumer (and producer if applicable) are called from coordinator scripts."
exit 0
