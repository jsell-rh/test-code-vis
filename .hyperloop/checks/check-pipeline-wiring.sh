#!/bin/bash
# Verify that the view-spec pipeline is wired end-to-end:
#   Stage 1: LLMViewGenerator.parse_response() produces a ViewSpec dictionary.
#   Stage 2: Something consumes that dictionary and applies it to the live 3D scene
#            (sets node.visible, node.position, material color, etc.).
#
# A codebase that only has Stage 1 passes all compile and dict-assertion tests
# but leaves the pipeline incomplete. This check catches that gap mechanically.

set -e

GODOT_DIR="godot"

if [ ! -d "$GODOT_DIR" ]; then
  echo "SKIP: No godot/ directory. Extractor-only task."
  exit 0
fi

if [ ! -f "$GODOT_DIR/project.godot" ]; then
  echo "SKIP: No project.godot. Godot project not initialised yet."
  exit 0
fi

FAIL=0

# ---------------------------------------------------------------------------
# 1. Stage 1 — parse_response() (or equivalent) must exist.
# ---------------------------------------------------------------------------
PARSE_FILES=$(grep -rl "parse_response\|parse_view_spec\|parse_llm_response" "$GODOT_DIR/scripts/" 2>/dev/null || true)
if [ -z "$PARSE_FILES" ]; then
  echo "SKIP: No parse_response / parse_view_spec function found in godot/scripts/."
  echo "      This check only applies to tasks that implement the LLM→view-spec pipeline."
  exit 0
fi

echo "Stage 1 (view-spec producer) found in: $PARSE_FILES"

# ---------------------------------------------------------------------------
# 2. Stage 2 — something must consume the view spec and mutate scene nodes.
#    Evidence: code that sets node.visible, .position, material albedo_color,
#    creates Label3D, or draws a line — in response to view-spec operations.
#
#    We look for at least ONE of these scene-mutation patterns outside of test
#    files (tests asserting the renderer is fine; the renderer itself is what we want).
# ---------------------------------------------------------------------------
SCENE_MUTATION_PATTERNS=(
  "\.visible\s*="
  "\.position\s*="
  "albedo_color\s*="
  "Label3D\.new"
  "ImmediateMesh\|ArrayMesh\|draw.*line\|MeshInstance3D.*connect\|add_child.*line"
  "apply_operation\|apply_spec\|apply_view\|render_spec\|interpret_spec\|update_scene"
)

CONSUMER_FOUND=0
for pattern in "${SCENE_MUTATION_PATTERNS[@]}"; do
  # Search scripts/ but not tests/ — we want production consumer code, not test assertions.
  MATCHES=$(grep -rl --include="*.gd" -E "$pattern" "$GODOT_DIR/scripts/" 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    CONSUMER_FOUND=1
    echo "Stage 2 (scene consumer) evidence — pattern '$pattern' found in: $MATCHES"
    break
  fi
done

if [ "$CONSUMER_FOUND" -eq 0 ]; then
  echo ""
  echo "FAIL: Stage 2 of the view-spec pipeline is missing."
  echo "      parse_response() (or equivalent) produces a view-spec dictionary,"
  echo "      but NO script in godot/scripts/ applies that spec to the live 3D scene."
  echo "      Expected: a script that reads the view-spec operations and calls"
  echo "        node.visible = false/true   (for hide/show ops)"
  echo "        node.position = Vector3(…)  (for arrange ops)"
  echo "        mat.albedo_color = Color(…) (for highlight ops)"
  echo "        Label3D.new() + add_child()  (for annotate ops)"
  echo "        line geometry               (for connect ops)"
  echo "      Use any file name not on the spec's prohibited list."
  FAIL=1
fi

# ---------------------------------------------------------------------------
# 3. Rendering tests — tests/ must contain at least one test that instantiates
#    a real Node3D and asserts a scene-tree property (not just a dict key).
# ---------------------------------------------------------------------------
if [ -d "$GODOT_DIR/tests" ]; then
  NODE3D_TEST=$(grep -rl --include="test_*.gd" -E "Node3D|MeshInstance3D|Label3D" "$GODOT_DIR/tests/" 2>/dev/null || true)
  PROPERTY_ASSERT=$(grep -rl --include="test_*.gd" -E "\.visible|\.position\.|albedo_color" "$GODOT_DIR/tests/" 2>/dev/null || true)

  if [ -z "$NODE3D_TEST" ] || [ -z "$PROPERTY_ASSERT" ]; then
    echo ""
    echo "FAIL: No rendering test found in godot/tests/."
    echo "      At least one test_*.gd must instantiate a real Node3D/Label3D/MeshInstance3D"
    echo "      and assert a scene-tree property (.visible, .position, albedo_color, etc.)."
    echo "      Dict-key assertions (spec.has('op'), spec['operations'][0]['op'] == 'show')"
    echo "      do NOT satisfy rendering THEN clauses."
    FAIL=1
  else
    echo "Stage 2 rendering tests found: $PROPERTY_ASSERT"
  fi
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if [ "$FAIL" -eq 1 ]; then
  exit 1
fi

echo ""
echo "OK: View-spec pipeline appears wired end-to-end (producer + consumer + rendering tests)."
exit 0
