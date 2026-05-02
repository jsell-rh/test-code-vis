#!/usr/bin/env bash
# check-reposition-function-has-tween.sh
#
# Verifies that GDScript files introduced or modified by this branch which define
# repositioning or rerouting functions also contain create_tween for animated
# in-tree transitions.
#
# Observed failure (task-068): _reposition_edge_visual() in main.gd set positions
# directly with no Tween code. The function docstring falsely claimed "In scene-tree
# contexts a Tween slides the visual." Spec clauses requiring edge endpoints to
# "slide not jump" during collapse/expand were PARTIAL because the animation
# architecture was entirely absent.
#
# check-highlight-function-has-tween.sh did not catch this because the function
# name matched neither the highlight_ nor _apply_.*color patterns — it was a
# repositioning function with a different naming convention.
#
# Rule: any GDScript function responsible for repositioning or rerouting scene
# nodes (name starts with _reposition_, _reroute_, _relocate_, or _slide_) MUST
# include create_tween in an is_inside_tree() branch for in-tree animation, plus
# a direct assignment for the headless (test) path.
#
# Required pattern:
#   func _reposition_edge_visual(visual: Node3D, new_pos: Vector3) -> void:
#       if is_inside_tree():
#           var tween := create_tween()
#           tween.tween_property(visual, "position", new_pos, 0.3)
#       else:
#           visual.position = new_pos  # headless: direct assignment
#
# A comment deferring Tween to "future improvement" does NOT satisfy this rule.
# Implement the Tween branch now, or escalate via a FAIL report.
#
# Exit 0 = all checked files include create_tween, or no relevant files found.
# Exit 1 = a file defines repositioning/rerouting functions without create_tween.

set -uo pipefail

FAIL=0

# Find GDScript files in godot/scripts/ introduced or modified by this branch.
# Test files (godot/tests/*.gd) are excluded — they use direct assignment by design.
CHANGED_GD=$(git diff --name-only main..HEAD 2>/dev/null \
    | grep "^godot/scripts/.*\.gd$" || true)

if [ -z "$CHANGED_GD" ]; then
    echo "OK: No godot/scripts/*.gd files changed on this branch — check skipped."
    exit 0
fi

CHECKED=0

for f in $CHANGED_GD; do
    [ -f "$f" ] || continue

    # Does this file define a repositioning or rerouting function?
    if ! grep -qE "^func (_reposition_|_reroute_|_relocate_|_slide_)" "$f" 2>/dev/null; then
        continue
    fi

    CHECKED=$((CHECKED + 1))

    # File has repositioning/rerouting functions — must contain create_tween.
    if ! grep -q "create_tween" "$f" 2>/dev/null; then
        echo "FAIL: $f — defines repositioning/rerouting functions but contains no create_tween."
        echo ""
        echo "  Matching functions:"
        grep -nE "^func (_reposition_|_reroute_|_relocate_|_slide_)" "$f" \
            | sed 's/^/    /'
        echo ""
        echo "  Spec clauses requiring 'slides not jumps' or 'smooth animation' need:"
        echo "    if is_inside_tree():"
        echo "        var tween := create_tween()"
        echo "        tween.tween_property(visual, \"position\", new_pos, 0.3)"
        echo "    else:"
        echo "        visual.position = new_pos  # headless: direct assignment"
        echo ""
        echo "  PASS-WITH-NOTE applies ONLY when create_tween EXISTS in an is_inside_tree()"
        echo "  branch. A '# future improvement' deferral comment does NOT satisfy this"
        echo "  requirement — it is a PARTIAL gap. Implement the Tween branch now, or"
        echo "  escalate via a FAIL report explaining the architectural constraint."
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then
    if [ "$CHECKED" -eq 0 ]; then
        echo "OK: No repositioning/rerouting functions found in branch-modified godot/scripts/ files."
    else
        echo "OK: $CHECKED file(s) with repositioning/rerouting functions all include create_tween."
    fi
fi

exit "$FAIL"
