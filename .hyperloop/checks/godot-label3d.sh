#!/bin/bash
# Verify that every GDScript file creating a Label3D node also sets billboard and pixel_size.
# Label3D at default settings (BILLBOARD_DISABLED, pixel_size=0.005) is illegible in 3D.
set -e

GODOT_DIR="godot"

if [ ! -d "$GODOT_DIR" ]; then
  echo "SKIP: No godot/ directory found."
  exit 0
fi

# Find all GDScript files that call Label3D.new()
LABEL3D_FILES=$(grep -rl "Label3D\.new()" "$GODOT_DIR" --include="*.gd" 2>/dev/null || true)

if [ -z "$LABEL3D_FILES" ]; then
  echo "SKIP: No GDScript files create Label3D nodes."
  exit 0
fi

FAIL=0

for FILE in $LABEL3D_FILES; do
  # Skip test files — they may inspect properties without setting them,
  # or set them explicitly to test the implementation's output.
  case "$FILE" in
    */tests/*)
      continue
      ;;
  esac

  if ! grep -q "\.billboard\s*=" "$FILE"; then
    echo "FAIL: $FILE creates a Label3D but never sets .billboard"
    echo "  Add: label.billboard = BaseMaterial3D.BILLBOARD_ENABLED"
    FAIL=1
  fi

  if ! grep -q "\.pixel_size\s*=" "$FILE"; then
    echo "FAIL: $FILE creates a Label3D but never sets .pixel_size"
    echo "  Add: label.pixel_size = 0.05  # (or another legible value > 0.0)"
    FAIL=1
  fi
done

# Also check that test files assert both properties on Label3D nodes.
TEST_FILES=$(grep -rl "Label3D\|label3d\|label\.billboard\|label\.pixel_size" \
  "$GODOT_DIR/tests" --include="*.gd" 2>/dev/null || true)

for FILE in $TEST_FILES; do
  # Only inspect test files that also exercise annotate/Label3D creation.
  if grep -qE "Label3D|annotate" "$FILE"; then
    if ! grep -q "billboard" "$FILE"; then
      echo "FAIL: $FILE tests Label3D but does not assert .billboard"
      echo "  Add: _check(label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, ...)"
      FAIL=1
    fi
    if ! grep -q "pixel_size" "$FILE"; then
      echo "FAIL: $FILE tests Label3D but does not assert .pixel_size"
      echo "  Add: _check(label.pixel_size > 0.0, ...)"
      FAIL=1
    fi
  fi
done

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

echo "PASS: All Label3D nodes have billboard and pixel_size set and tested."
