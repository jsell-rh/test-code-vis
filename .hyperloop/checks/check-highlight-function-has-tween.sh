#!/usr/bin/env bash
# check-highlight-function-has-tween.sh
#
# Verifies that GDScript files introduced or modified by this branch which define
# highlight or color-application functions also contain create_tween for animated
# in-tree transitions.
#
# Observed failure (task-070): _apply_node_color() in independence_query.gd set
# albedo_color directly with no Tween code. Spec clauses requiring "animated
# smoothly" and "transition animated" were PARTIAL because the animation
# architecture was absent — not merely untestable in headless mode.
#
# Rule: any GDScript function that applies a highlight or color change to scene
# nodes (name contains "highlight", "apply.*color", or "animate.*color") MUST
# include create_tween in an is_inside_tree() branch for in-tree animation, plus
# a direct assignment for the headless (test) path.
#
# Required pattern:
#   func _apply_node_color(node: Node3D, color: Color) -> void:
#       if is_inside_tree():
#           var tween := create_tween()
#           tween.tween_property(node, "material_override:albedo_color", color, 0.3)
#       else:
#           var mat := StandardMaterial3D.new()
#           mat.albedo_color = color
#           node.material_override = mat
#
# Exit 0 = all checked files include create_tween, or no relevant files.
# Exit 1 = a file defines highlight/color-application functions without create_tween.

set -uo pipefail

FAIL=0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

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

    # Does this file define a highlight or color-application function?
    if ! grep -qE "^func (highlight_|_highlight_|_apply_.*color|_animate_.*color|apply_.*highlight|clear_.*highlight)" "$f" 2>/dev/null; then
        continue
    fi

    CHECKED=$((CHECKED + 1))

    # File has highlight/color-application functions — must contain create_tween.
    if ! grep -q "create_tween" "$f" 2>/dev/null; then
        echo "FAIL: $f — defines highlight/color-application functions but contains no create_tween."
        echo ""
        echo "  Matching functions:"
        grep -nE "^func (highlight_|_highlight_|_apply_.*color|_animate_.*color|apply_.*highlight|clear_.*highlight)" "$f" \
            | sed 's/^/    /'
        echo ""
        echo "  Spec clauses requiring 'animated smoothly' or 'transition animated' need:"
        echo "    if is_inside_tree():"
        echo "        var tween := create_tween()"
        echo "        tween.tween_property(node, \"property\", target, duration)"
        echo "    else:"
        echo "        node.property = target  # headless: direct assignment"
        echo ""
        echo "  PASS-WITH-NOTE applies only when create_tween EXISTS in an is_inside_tree()"
        echo "  branch. If no create_tween exists anywhere in the file, the animation"
        echo "  architecture is absent and the clause is PARTIAL, not PASS-WITH-NOTE."
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then
    if [ "$CHECKED" -eq 0 ]; then
        echo "OK: No highlight/color-application functions found in branch-modified godot/scripts/ files."
    else
        echo "OK: $CHECKED file(s) with highlight/color-application functions all include create_tween."
    fi
fi

exit "$FAIL"
