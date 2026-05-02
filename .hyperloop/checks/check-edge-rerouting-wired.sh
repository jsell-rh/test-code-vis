#!/usr/bin/env bash
# check-edge-rerouting-wired.sh
#
# Verifies that _path_edge_entries is not only WRITTEN (appended to) but also
# READ (iterated) in GDScript files that define collapse_cluster or
# expand_cluster. An unread tracking array is dead state — edge re-routing
# cannot happen if the array is never consumed.
#
# Observed failure (task-068):
#   _path_edge_entries was declared on line 50 of main.gd and populated via
#   .append() calls inside _create_edge() (lines 722, 753). But neither
#   collapse_cluster() nor expand_cluster() ever read it — no `for entry in
#   _path_edge_entries:` loop existed anywhere in the file. Four edge re-routing
#   THEN-clauses were MISSING as a direct result.
#
# The check looks for:
#   (a) a GDScript file that uses _path_edge_entries
#   (b) AND also defines collapse_cluster or expand_cluster
#   (c) AND has NO `for ... in _path_edge_entries` iteration anywhere in the file
#
# When (a)+(b) are true and (c) fires, the implementer has built the data
# structure and the operations but failed to wire them together.
#
# Exit codes:
#   0 — no violation found (or no applicable files — SKIP)
#   1 — _path_edge_entries is populated but never iterated in a file with
#       collapse/expand functions

set -uo pipefail

FAIL=0
CHECKED=0

for GD_FILE in godot/scripts/*.gd; do
    [ -f "$GD_FILE" ] || continue

    # Skip if _path_edge_entries is not mentioned in this file at all
    grep -q "_path_edge_entries" "$GD_FILE" || continue

    # Skip if neither collapse_cluster nor expand_cluster is defined
    if ! grep -qE "^func collapse_cluster|^func expand_cluster" "$GD_FILE"; then
        continue
    fi

    CHECKED=$((CHECKED + 1))

    # Check for a read pattern: a for-loop iterating over _path_edge_entries
    # Pattern: `for <var> in _path_edge_entries`
    if ! grep -qE "for\s+\w+\s+in\s+_path_edge_entries" "$GD_FILE"; then
        echo "FAIL: $GD_FILE"
        echo "  _path_edge_entries is declared/populated in this file AND collapse_cluster"
        echo "  or expand_cluster is defined — but _path_edge_entries is NEVER iterated."
        echo ""
        echo "  Usage sites found (all writes — no reads):"
        grep -n "_path_edge_entries" "$GD_FILE" | sed 's/^/    /'
        echo ""
        echo "  Edge re-routing requires iterating _path_edge_entries inside collapse_cluster()"
        echo "  and expand_cluster() to find edges whose endpoints must move to the supernode."
        echo "  Populating the array without ever reading it is dead state."
        echo ""
        echo "  Required pattern inside collapse_cluster():"
        echo "    for entry in _path_edge_entries:"
        echo "        if entry[\"source\"] in members or entry[\"target\"] in members:"
        echo "            # move edge endpoint to supernode position"
        FAIL=1
    fi
done

if [ "$CHECKED" -eq 0 ]; then
    echo "SKIP: no GDScript files found with both _path_edge_entries and collapse/expand functions."
    exit 0
fi

if [ "$FAIL" -eq 0 ]; then
    echo "OK: _path_edge_entries is iterated (read) in all files that define collapse/expand functions."
fi

exit "$FAIL"
