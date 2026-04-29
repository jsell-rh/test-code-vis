#!/bin/bash
set -e

GODOT_PROJECT="godot"

if [ ! -d "$GODOT_PROJECT" ]; then
  echo "SKIP: No godot/ directory found. Extractor-only task."
  exit 0
fi

if [ ! -f "$GODOT_PROJECT/project.godot" ]; then
  echo "SKIP: No project.godot found. Godot project not initialized yet."
  exit 0
fi

echo "Compiling Godot project..."

TMPOUT=$(mktemp)
godot --headless --path "$GODOT_PROJECT" --quit 2>&1 | tee "$TMPOUT"

# Godot 4 exits 0 even when scene files fail to parse (e.g. a deleted script
# is still referenced by an [ext_resource] in a .tscn file). Detect the
# parse-error lines that Godot emits to stderr so we do not silently accept a
# broken scene file.  Root cause: task-108 fix commit deleted GDScript files
# but left main.tscn referencing them; godot-compile.sh reported success.
PARSE_ERRORS=$(grep -E "Parse Error:|Failed loading resource:|Attempt to open script.*File not found" "$TMPOUT" || true)
rm -f "$TMPOUT"

if [ -n "$PARSE_ERRORS" ]; then
  echo ""
  echo "FAIL: Godot emitted parse/load errors (process exited 0, but output"
  echo "      contains errors — Godot does not fail its exit code on parse errors)."
  echo ""
  echo "Offending lines:"
  echo "$PARSE_ERRORS"
  echo ""
  echo "Common cause: a .tscn scene file has an [ext_resource] path pointing to"
  echo "a .gd script that no longer exists. Remove the [ext_resource] declaration"
  echo "and all [node] references to it, and adjust load_steps accordingly."
  exit 1
fi

echo "Godot project compiles successfully."
