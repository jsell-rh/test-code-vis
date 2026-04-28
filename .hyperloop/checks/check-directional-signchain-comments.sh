#!/usr/bin/env bash
# check-directional-signchain-comments.sh
#
# FAIL if any GDScript implementation file contains a directional calculation
# line (involving delta.x or delta.y) that has no sign-chain derivation comment
# (a # comment containing →) within the 15 lines preceding it.
#
# The convention allows a single derivation block that covers multiple consecutive
# calculation lines (e.g. pan), as long as that block appears in the same logical
# section before the calculations.
#
# Implementers MUST write a sign-chain comment before every directional calculation
# BLOCK. A derivation block present for pan but absent entirely for orbit means
# the orbit direction is accidental and will regress.
#
# Pattern caught: task-015 PARTIAL
#   camera_controller.gd line 128: _phi -= delta.x * orbit_speed
#   camera_controller.gd line 130: _theta = clamp(_theta - delta.y * ...)
#   Neither had any → comment within 15 lines above; pan did (lines 136-144).

set -uo pipefail

GODOT_SCRIPTS="godot/scripts"
LOOKBACK=15   # lines to search above a delta calculation for a → comment

if [[ ! -d "$GODOT_SCRIPTS" ]]; then
    echo "SKIP: $GODOT_SCRIPTS not found"
    exit 0
fi

FAIL=0
FINDINGS=()

while IFS= read -r -d '' file; do
    rel="$file"
    mapfile -t lines < "$file"
    n=${#lines[@]}

    for ((i=0; i<n; i++)); do
        line="${lines[$i]}"
        lineno=$((i+1))

        # Skip lines that are themselves comments
        if echo "$line" | grep -qE '^\s*#'; then
            continue
        fi

        # Match directional calculation lines: any non-comment line containing delta.x or delta.y
        if echo "$line" | grep -qE 'delta\.[xy]'; then
            # Search the preceding LOOKBACK lines for a # comment containing →
            found_signchain=0
            start=$(( i - LOOKBACK ))
            [[ $start -lt 0 ]] && start=0

            for ((j=start; j<i; j++)); do
                prev="${lines[$j]}"
                if echo "$prev" | grep -qE '^\s*#' && echo "$prev" | grep -q '→'; then
                    found_signchain=1
                    break
                fi
            done

            if [[ $found_signchain -eq 0 ]]; then
                FINDINGS+=("FAIL $rel:$lineno — no sign-chain comment (→) within $LOOKBACK lines before: $(echo "$line" | xargs)")
                FAIL=1
            fi
        fi
    done

done < <(find "$GODOT_SCRIPTS" -name "*.gd" -print0 2>/dev/null)

if [[ $FAIL -ne 0 ]]; then
    echo "FAIL: Directional calculation lines lack sign-chain derivation comments."
    echo "      Every delta.x / delta.y calculation block MUST have a # comment"
    echo "      containing → within $LOOKBACK lines above it, showing the full sign derivation."
    echo ""
    echo "Offending locations:"
    for f in "${FINDINGS[@]}"; do
        echo "  $f"
    done
    echo ""
    echo "Fix: add a # comment block with → before the offending calculation section. Example:"
    echo "  # drag right → delta.x > 0 → _phi -= positive → phi decreases → camera rotates CCW ✓"
    echo "  # drag down  → delta.y > 0 → _theta -= positive → theta decreases → tilts toward overhead ✓"
    echo "  _phi -= delta.x * orbit_speed"
    exit 1
fi

echo "OK: All directional calculation lines have sign-chain derivation comments (→)"
exit 0
