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
godot --headless --path "$GODOT_PROJECT" --quit 2>&1

echo "Godot project compiles successfully."
