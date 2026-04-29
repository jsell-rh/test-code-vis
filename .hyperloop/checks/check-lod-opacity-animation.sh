#!/bin/bash
# Verifies that LOD implementations introduced or modified by this branch use
# animated opacity (Tween / modulate.a) rather than binary .visible toggles.
#
# Spec (spatial-structure.spec.md § "Smooth transitions between levels"):
#   "elements fade in or out with animated opacity, never appearing or
#    disappearing instantly"
#
# Only FAILS for LOD files that were introduced or modified by the current branch.
# Pre-existing files from main are reported as NOTEs (informational).

set -e

FAIL=0

# ── Find LOD manager files (any GDScript with LOD transition functions) ────────
ALL_LOD=$(grep -rl \
    "_apply_far\|_apply_near\|_apply_medium\|update_lod\b" \
    godot/scripts/ godot/autoload/ 2>/dev/null || true)

if [ -z "$ALL_LOD" ]; then
  echo "OK: No LOD manager files found — check skipped."
  exit 0
fi

# ── Partition into branch-new vs pre-existing ──────────────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
NEW_LOD=""
OLD_LOD=""

for f in $ALL_LOD; do
  if [[ "$BRANCH" == "main" || "$BRANCH" == "HEAD" ]]; then
    NEW_LOD="$NEW_LOD $f"
  elif git log main..HEAD --oneline -- "$f" 2>/dev/null | grep -q .; then
    NEW_LOD="$NEW_LOD $f"
  else
    OLD_LOD="$OLD_LOD $f"
  fi
done

# ── Check branch-new LOD files — FAIL if binary only ──────────────────────────
for f in $NEW_LOD; do
  if grep -q "\.visible\s*=" "$f" 2>/dev/null; then
    if ! grep -q "Tween\|modulate\.a\|create_tween" "$f" 2>/dev/null; then
      echo "FAIL: $f sets .visible directly for LOD transitions without any opacity animation."
      echo "  Spec requires 'fade in or out with animated opacity, never appearing or"
      echo "  disappearing instantly'. Use Tween.tween_property(node, \"modulate:a\","
      echo "  target_alpha, duration) — do not use .visible = true/false for transitions"
      echo "  that the spec describes as smooth, animated, or fading."
      FAIL=1
    fi
  fi
done

# ── Report pre-existing files as NOTEs (informational only) ───────────────────
for f in $OLD_LOD; do
  if grep -q "\.visible\s*=" "$f" 2>/dev/null; then
    if ! grep -q "Tween\|modulate\.a\|create_tween" "$f" 2>/dev/null; then
      echo "NOTE: $f (pre-existing on main) uses binary .visible toggle without opacity"
      echo "  animation — this is a pre-existing spec gap, not attributed to this branch."
    fi
  fi
done

# ── Summary ────────────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
  if [ -z "$NEW_LOD" ]; then
    echo "OK: No LOD files introduced or modified by this branch — check not applicable."
  else
    echo "OK: Branch LOD files include Tween/modulate.a opacity animation."
  fi
fi

exit "$FAIL"
