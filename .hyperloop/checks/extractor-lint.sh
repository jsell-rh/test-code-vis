#!/bin/bash
set -e

EXTRACTOR_DIR="extractor"

if [ ! -d "$EXTRACTOR_DIR" ]; then
  echo "SKIP: No extractor/ directory found. Godot-only task."
  exit 0
fi

echo "Linting extractor..."
ruff check "$EXTRACTOR_DIR"
ruff format --check "$EXTRACTOR_DIR"

if [ -d "tests" ] || [ -d "$EXTRACTOR_DIR/tests" ]; then
  echo "Running extractor tests..."
  pytest -x -q
fi

echo "Extractor checks passed."
