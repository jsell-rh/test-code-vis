#!/bin/bash
# Verifies that aggregate-edge rendering exists when the spatial-structure spec
# requires it AND the current branch modifies LOD/visualization code.
#
# Spec (spatial-structure.spec.md § "Far — bounded context architecture"):
#   "cross-context dependencies are shown as single aggregate edges per context
#    pair, with weight indicating total import count"
#
# Hiding all individual edges satisfies "individual edges not visible" but NOT
# "aggregate edges per pair are visible". These are distinct requirements.
#
# Only FAILS when:
#   (a) The spatial-structure spec requires aggregate edges, AND
#   (b) This branch introduces or modifies LOD/visualization files, AND
#   (c) No aggregate-edge grouping logic is found anywhere in godot/scripts/.

set -e

FAIL=0

# ── Gate 1: does the spec require aggregate edges? ─────────────────────────────
SPEC="specs/visualization/spatial-structure.spec.md"
if [ ! -f "$SPEC" ]; then
  echo "OK: $SPEC not found — check skipped."
  exit 0
fi

if ! grep -qi "aggregate edge" "$SPEC" 2>/dev/null; then
  echo "OK: Spec does not require aggregate edges — check skipped."
  exit 0
fi

# ── Gate 2: does this branch touch LOD or visualization code? ─────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

LOD_CANDIDATES=$(grep -rl \
    "_apply_far\|_apply_near\|_apply_medium\|update_lod\b\|lod_manager\|SpatialStructure\|spatial_structure" \
    godot/scripts/ godot/autoload/ 2>/dev/null || true)

BRANCH_LOD=""
for f in $LOD_CANDIDATES; do
  if [[ "$BRANCH" == "main" || "$BRANCH" == "HEAD" ]]; then
    BRANCH_LOD="$BRANCH_LOD $f"
  elif git log main..HEAD --oneline -- "$f" 2>/dev/null | grep -q .; then
    BRANCH_LOD="$BRANCH_LOD $f"
  fi
done

if [ -z "$BRANCH_LOD" ]; then
  echo "OK: This branch does not modify LOD/visualization files — aggregate-edge check not applicable."
  exit 0
fi

# ── Gate 3: does any script implement aggregate edge grouping? ─────────────────
# Look for the semantic pattern: grouping/building edges indexed by context pair.
# Accept any of these naming conventions implementers might reasonably choose.
AGG_IMPL=$(grep -rl \
    "aggregate_edge\|AggregateEdge\|agg_edge\|edges_by_context\|context_pair\|_per_context\|per_pair\|group_edges\|edge_groups\|aggregate.*edge\|edge.*aggregate" \
    godot/scripts/ godot/autoload/ 2>/dev/null || true)

if [ -z "$AGG_IMPL" ]; then
  echo "FAIL: This branch modifies LOD/visualization code but no aggregate-edge"
  echo "  implementation was found in godot/scripts/ or godot/autoload/."
  echo ""
  echo "  The spec requires (at FAR distance):"
  echo "    'cross-context dependencies are shown as single aggregate edges per"
  echo "     context pair, with weight indicating total import count'"
  echo ""
  echo "  Hiding all individual cross-context edges does NOT satisfy this."
  echo "  Required: a script that:"
  echo "    1. Groups cross-context edges by (source_context, target_context) pair"
  echo "    2. Sums import counts per pair"
  echo "    3. Renders one MeshInstance3D / ImmediateMesh line per pair,"
  echo "       with visual weight proportional to total import count"
  echo ""
  echo "  Expected naming hints: aggregate_edge, edges_by_context, context_pair,"
  echo "  or equivalent grouping logic targeting a LOD-far rendering pass."
  FAIL=1
fi

# ── Summary ────────────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
  echo "OK: Aggregate-edge implementation found."
  for f in $AGG_IMPL; do echo "  $f"; done
fi

exit "$FAIL"
