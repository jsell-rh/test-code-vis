#!/bin/bash
# Verify every [ext_resource] path in .tscn scene files resolves to a file
# that exists on disk.
#
# Root cause pattern (task-108): A fix commit deleted GDScript files but left
# the [ext_resource] declarations and [node] references intact in main.tscn.
# Godot --headless --quit exits 0 despite emitting parse errors, so
# godot-compile.sh falsely reports success. The GDScript test runner also
# bypasses this because it instantiates scripts directly without loading the
# scene file.
#
# This check detects dangling references before scene loading ever occurs.

GODOT_PROJECT="godot"

if [ ! -d "$GODOT_PROJECT" ]; then
  echo "SKIP: No godot/ directory found."
  exit 0
fi

if [ ! -f "$GODOT_PROJECT/project.godot" ]; then
  echo "SKIP: No project.godot found."
  exit 0
fi

# Collect all scene files
TSCN_FILES=$(find "$GODOT_PROJECT" -name "*.tscn" 2>/dev/null | sort)

if [ -z "$TSCN_FILES" ]; then
  echo "OK: No .tscn scene files found."
  exit 0
fi

FAILED=0

while IFS= read -r tscn_file; do
  # Extract every path="res://..." value from [ext_resource] lines only
  # (sub-resources are embedded and don't need on-disk files)
  while IFS= read -r res_path; do
    # Strip "res://" prefix and prepend project directory
    local_path="$GODOT_PROJECT/${res_path#res://}"

    if [ ! -f "$local_path" ]; then
      echo "FAIL: $tscn_file — dangling [ext_resource] reference"
      echo "      res path : $res_path"
      echo "      disk path: $local_path (not found)"
      FAILED=1
    fi
  done < <(
    grep '^\[ext_resource' "$tscn_file" \
      | grep -oE 'path="res://[^"]+"' \
      | sed 's/path="//;s/"$//'
  )
done <<< "$TSCN_FILES"

if [ "$FAILED" -ne 0 ]; then
  echo ""
  echo "FAIL: One or more .tscn files contain dangling resource references."
  echo "Fix: remove the [ext_resource] declaration AND every [node] that"
  echo "     references it via 'script = ExtResource(\"<id>\")'."
  exit 1
fi

echo "OK: All [ext_resource] paths in .tscn files resolve to existing files."
