#!/usr/bin/env bash
# check-preloaded-gdscript-files.sh
#
# Purpose: Verify that every preload("res://...") call in the Godot project
# references a file that actually exists on disk.
#
# Pattern: preload("res://tests/test_foo.gd") → must exist at godot/tests/test_foo.gd
#
# Why this matters: A missing preloaded file causes Godot to throw a compile
# error at startup, silently preventing ALL tests from executing — including
# tests that do exist. The test runner reports zero results, not a failure,
# so missing files are easy to overlook during review.
#
# Observed failure (task-014): run_tests.gd preloaded test_readable_labels.gd
# and test_lod_manager.gd — neither file existed — causing the headless test
# suite to abort before any test ran.
#
# Exit 0 = all preload() targets exist (or no preload() calls found)
# Exit 1 = one or more preload() targets are missing

set -uo pipefail

GODOT_ROOT="godot"
FAIL=0
CHECKED=0
MISSING=()

if [[ ! -d "$GODOT_ROOT" ]]; then
    echo "SKIP: No godot/ directory found — not a Godot project."
    exit 0
fi

# Scan all GDScript files for preload("res://...") calls.
# Uses find to locate .gd files, then sed to extract the res:// path.
while IFS= read -r gd_file; do
    [[ -f "$gd_file" ]] || continue
    while IFS= read -r res_path; do
        [[ -z "$res_path" ]] && continue
        # Map res://path/to/file → godot/path/to/file
        local_path="${GODOT_ROOT}/${res_path#res://}"
        CHECKED=$((CHECKED + 1))
        if [[ ! -f "$local_path" ]]; then
            MISSING+=("${gd_file}  →  ${res_path}  (expected: ${local_path})")
            FAIL=1
        fi
    done < <(grep -E 'preload\("res://' "$gd_file" \
             | sed 's/.*preload("//; s/").*//' \
             | grep '^res://' || true)
done < <(find "$GODOT_ROOT" -name "*.gd" -type f 2>/dev/null)

if [[ $CHECKED -eq 0 ]]; then
    echo "SKIP: No preload(\"res://...\") calls found in ${GODOT_ROOT}/ GDScript files."
    exit 0
fi

if [[ $FAIL -ne 0 ]]; then
    echo "FAIL: One or more preload() targets do not exist on disk."
    echo ""
    echo "  Missing files:"
    for entry in "${MISSING[@]}"; do
        echo "    $entry"
    done
    echo ""
    echo "  A missing preloaded file causes Godot to throw a compile error before"
    echo "  any test executes.  ALL tests silently fail — the runner aborts"
    echo "  before reaching even the first test function."
    echo ""
    echo "  Fix: create the missing file(s), or remove the preload() call from"
    echo "  the test runner if the file is no longer needed."
    exit 1
fi

echo "OK: All ${CHECKED} preload() target(s) resolve to existing files."
exit 0
