#!/usr/bin/env bash
# check-primary-deliverable-not-on-main.sh
#
# PRE-IMPLEMENTATION GATE — verifies that the spec's primary deliverable
# function does NOT already exist on origin/main.
#
# Root cause it addresses (task-001 STOP PROTOCOL Round 1):
#   task-001 was assigned to implement a schema that was fully implemented on
#   origin/main. All 11 spec requirements were satisfied. The implementer
#   discovered this only after rebasing (all three implementation commits
#   resolved to empty diffs). An early grep at Sync Point 1 would have caught
#   this in seconds instead of spending a full task slot.
#
# This check is intentionally simple — it is a grep, not a semantic analysis.
# It catches the most common case: a function with the primary name already
# exists on main. It does NOT guarantee the spec is fully satisfied, but it
# surfaces the most obvious "already implemented" signal before any code is
# written.
#
# Usage:
#   bash check-primary-deliverable-not-on-main.sh <function_name>
#   bash check-primary-deliverable-not-on-main.sh <function_name> [path_pattern]
#
# Examples:
#   bash .hyperloop/checks/check-primary-deliverable-not-on-main.sh build_scene_graph
#   bash .hyperloop/checks/check-primary-deliverable-not-on-main.sh render_node godot/
#   bash .hyperloop/checks/check-primary-deliverable-not-on-main.sh compute_layout extractor/
#
# Exit codes:
#   0 — Function NOT found on origin/main. Safe to implement.
#   1 — Function FOUND on origin/main. File STOP PROTOCOL; do NOT implement.
#   2 — Missing required argument (function name).
#
# Note: When called from run-all-checks.sh with no args, exits 0 (SKIP).
# This check is a pre-implementation gate called explicitly by the implementer,
# not an automated post-implementation check.

set -uo pipefail

FUNCTION_NAME="${1:-}"
SEARCH_PATH="${2:-extractor/ godot/}"

# ── No-arg path (run-all-checks.sh compatibility) ────────────────────────────
if [ -z "$FUNCTION_NAME" ]; then
    echo "SKIP: No function name supplied — call explicitly before implementing:"
    echo "  bash .hyperloop/checks/check-primary-deliverable-not-on-main.sh <function_name>"
    exit 0
fi

# ── Ensure origin/main is up to date ─────────────────────────────────────────
git fetch origin main:main --quiet 2>/dev/null || true

# ── Search for the function on origin/main ───────────────────────────────────
# shellcheck disable=SC2086
MATCHES=$(git grep -n "def ${FUNCTION_NAME}" origin/main -- ${SEARCH_PATH} 2>/dev/null || true)

if [ -z "$MATCHES" ]; then
    echo "OK: 'def ${FUNCTION_NAME}' not found on origin/main — safe to implement."
    exit 0
fi

echo "======================================================================"
echo "STOP PROTOCOL CANDIDATE — PRIMARY DELIVERABLE ALREADY ON ORIGIN/MAIN"
echo "======================================================================"
echo ""
echo "  Function 'def ${FUNCTION_NAME}' was found on origin/main:"
echo ""
echo "$MATCHES" | sed 's/^/    /'
echo ""
echo "  Before writing any implementation code, verify whether the full spec"
echo "  is satisfied by the existing implementation:"
echo ""
echo "    1. Read the existing function on main:"
echo "       git show origin/main:<file_path> | grep -A 50 'def ${FUNCTION_NAME}'"
echo ""
echo "    2. Compare against each spec requirement."
echo ""
echo "    3. If ALL spec requirements are satisfied: file a STOP PROTOCOL"
echo "       finding immediately. Do NOT write implementation code."
echo ""
echo "    4. If some spec requirements are missing: note which ones are absent"
echo "       and implement only those missing portions. Do NOT re-implement"
echo "       what already exists."
echo ""
echo "  To determine the round count for your STOP PROTOCOL report:"
echo "    bash .hyperloop/checks/check-stop-protocol-repeat.sh <your-task-id>"
echo ""
echo "======================================================================"
echo "EXIT 1 — Primary deliverable found on origin/main. Verify before coding."
exit 1
