#!/bin/bash
# Verifies that when LOD/visualization code is modified, ALL spec-defined LOD
# levels (Near, Medium, Far) have corresponding GDScript behavioral tests.
#
# A branch that implements Medium LOD changes but ships no Near or Far test
# coverage is incomplete, even if the other levels existed before the branch.
#
# Spec authority: specs/visualization/spatial-structure.spec.md
#
# Only FAILS when:
#   (a) The spatial-structure spec defines multiple LOD levels, AND
#   (b) This branch introduces or modifies LOD/visualization files, AND
#   (c) One or more LOD levels lack any matching behavioral test in godot/tests/.

set -e

FAIL=0
SPEC="specs/visualization/spatial-structure.spec.md"

# ── Gate 1: Does the spec define multiple LOD levels? ─────────────────────────
if [ ! -f "$SPEC" ]; then
  echo "OK: $SPEC not found — check skipped."
  exit 0
fi

# Require at least two of {Near, Medium, Far} to be present in the spec.
LEVEL_COUNT=0
grep -qi "near\b" "$SPEC" 2>/dev/null && LEVEL_COUNT=$((LEVEL_COUNT + 1)) || true
grep -qi "medium\b" "$SPEC" 2>/dev/null && LEVEL_COUNT=$((LEVEL_COUNT + 1)) || true
grep -qi "\bfar\b" "$SPEC" 2>/dev/null && LEVEL_COUNT=$((LEVEL_COUNT + 1)) || true

if [ "$LEVEL_COUNT" -lt 2 ]; then
  echo "OK: Spec does not define multiple LOD levels — check skipped."
  exit 0
fi

# ── Gate 2: Does this branch touch LOD/visualization code? ────────────────────
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
  echo "OK: This branch does not modify LOD/visualization files — LOD level test check not applicable."
  exit 0
fi

echo "LOD/visualization files modified by this branch:"
for f in $BRANCH_LOD; do echo "  $f"; done
echo ""

# ── Gate 3: Check test coverage for each LOD level ───────────────────────────
# We search all test files for function bodies that mention each level's
# characteristic keywords.  The search is intentionally broad — any test that
# exercises the level (by name or by the behaviour it requires) counts.

TEST_DIR="godot/tests"

check_lod_level() {
  local level_label="$1"
  local pattern="$2"

  if [ ! -d "$TEST_DIR" ]; then
    echo "FAIL: $TEST_DIR does not exist — no tests at all."
    FAIL=1
    return
  fi

  MATCHED=$(grep -rli "$pattern" "$TEST_DIR"/test_*.gd 2>/dev/null || true)

  if [ -z "$MATCHED" ]; then
    echo "FAIL: No behavioral test found for LOD level '$level_label'."
    echo "  The spatial-structure spec defines Near/Medium/Far LOD levels."
    echo "  When LOD code is modified, each level must have a behavioral test in $TEST_DIR/."
    echo "  Keyword pattern searched: $pattern"
    echo "  Add a test that instantiates nodes, invokes the LOD handler for this"
    echo "  level, and asserts the resulting scene-tree state."
    FAIL=1
  else
    echo "OK: '$level_label' LOD level test found."
    for f in $MATCHED; do echo "  $f"; done
  fi
}

# Near — full detail: individual modules and edges are visible
check_lod_level "Near (full detail)" \
    "apply_near\|near.*lod\|lod.*near\|_near\b\|near.*detail\|full.*detail"

# Medium — module structure within bounded contexts
check_lod_level "Medium (module structure)" \
    "apply_medium\|medium.*lod\|lod.*medium\|_medium\b\|module.*structure"

# Far — bounded context architecture, aggregate edges
check_lod_level "Far (aggregate edges / bounded context)" \
    "apply_far\|far.*lod\|lod.*far\|_far\b\|aggregate.*edge\|AggregateEdge\|agg_edge\|edges_by_context\|context_pair"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "OK: All LOD levels (Near / Medium / Far) have behavioral test coverage."
fi

exit "$FAIL"
