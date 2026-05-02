#!/usr/bin/env bash
# check-deliverable-component.sh TASK_ID
#
# Reads the task definition and verifies the branch diff contains at least one
# file from the component the task title names. Prevents wrong-deliverable
# failures where an implementer writes Python extractor code when the task
# requires Godot GDScript (or vice versa).
#
# Observed failure (task-038):
#   Task title: "Implement Port primitive renderer in Godot (public interface
#   points on Container membrane)".  The single branch commit was
#   `feat(extractor): emit weight on individual cross_context and internal edges`.
#   Zero godot/ files existed on the branch. check-branch-has-impl-files.sh
#   passed (extractor/ files are non-.hyperloop/), but the deliverable was from
#   the wrong component entirely.
#
# Usage:
#   bash .hyperloop/checks/check-deliverable-component.sh task-038
#
# Exit codes:
#   0 — component match confirmed, or SKIP (no arg / task file not found)
#   1 — task title signals a component that has zero changed files on the branch

set -uo pipefail

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
    echo "SKIP: no task ID provided — run manually: $0 <task-id>"
    exit 0
fi

TASK_FILE=".hyperloop/state/tasks/${TASK_ID}.md"
if [ ! -f "$TASK_FILE" ]; then
    echo "SKIP: task file not found: $TASK_FILE"
    exit 0
fi

# Extract the task title (first line starting with "title:")
TITLE=$(grep '^title:' "$TASK_FILE" | head -1 | sed 's/^title:[[:space:]]*//' | tr -d '"')

if [ -z "$TITLE" ]; then
    echo "SKIP: could not extract title from $TASK_FILE"
    exit 0
fi

# Get all non-.hyperloop/ files changed on this branch above main
DIFF_FILES=$(git diff --name-only main..HEAD 2>/dev/null | grep -v '^\.hyperloop/' || true)

FAIL=0

# ── Godot component check ─────────────────────────────────────────────────────
# Title contains "Godot" or "GDScript" → at least one godot/ file must exist.
if echo "$TITLE" | grep -qiE "godot|GDScript|\.gd\b"; then
    if [ -z "$DIFF_FILES" ] || ! echo "$DIFF_FILES" | grep -q '^godot/'; then
        echo "FAIL: task title references Godot but no godot/ files changed on this branch."
        echo ""
        echo "  Task:  $TASK_ID"
        echo "  Title: $TITLE"
        echo ""
        echo "  Non-.hyperloop/ files changed on this branch:"
        if [ -z "$DIFF_FILES" ]; then
            echo "    (none)"
        else
            echo "$DIFF_FILES" | sed 's/^/    /'
        fi
        echo ""
        echo "  A task that requires Godot work MUST produce at least one file under godot/."
        echo "  If you only changed extractor/ files, you have built the wrong deliverable."
        echo "  Read the task description carefully and implement the correct component."
        FAIL=1
    else
        GODOT_COUNT=$(echo "$DIFF_FILES" | grep '^godot/' | wc -l | tr -d ' ')
        echo "OK [Godot]: $GODOT_COUNT godot/ file(s) present in branch diff."
    fi
fi

# ── Python extractor component check ─────────────────────────────────────────
# Title contains "extractor" or "Python extractor" → at least one extractor/ file must exist.
# Note: many Godot tasks also reference extractor concepts; only flag when the
# title STARTS with "extractor" or "Python" to avoid false positives.
if echo "$TITLE" | grep -qiE "^(Python extractor|extractor:)"; then
    if [ -z "$DIFF_FILES" ] || ! echo "$DIFF_FILES" | grep -q '^extractor/'; then
        echo "FAIL: task title names the Python extractor but no extractor/ files changed."
        echo ""
        echo "  Task:  $TASK_ID"
        echo "  Title: $TITLE"
        echo ""
        echo "  Non-.hyperloop/ files changed on this branch:"
        if [ -z "$DIFF_FILES" ]; then
            echo "    (none)"
        else
            echo "$DIFF_FILES" | sed 's/^/    /'
        fi
        echo ""
        echo "  A task that requires Python extractor work MUST produce at least one"
        echo "  file under extractor/."
        FAIL=1
    else
        EXT_COUNT=$(echo "$DIFF_FILES" | grep '^extractor/' | wc -l | tr -d ' ')
        echo "OK [Extractor]: $EXT_COUNT extractor/ file(s) present in branch diff."
    fi
fi

if [ "$FAIL" -eq 0 ] && ! echo "$TITLE" | grep -qiE "godot|GDScript|\.gd\b|^(Python extractor|extractor:)"; then
    echo "SKIP: task title '$TITLE' does not clearly name a single component — check not applicable."
    exit 0
fi

exit "$FAIL"
