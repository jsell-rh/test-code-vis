"""
CLI entry point for the code-vis extractor.

Usage:
    python -m extractor <src_path> [--output <output.json>]

Arguments:
    src_path    Path to the Python source tree to analyse.
                For kartograph, this is typically: /path/to/kartograph/src/api

Options:
    --output    Path for the output JSON file.  Defaults to ``scene_graph.json``
                in the current directory.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from extractor.extractor import build_scene_graph


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m extractor",
        description="Extract a JSON scene graph from a Python codebase.",
    )
    parser.add_argument(
        "src_path",
        type=Path,
        help="Root directory of the Python source tree to analyse.",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=Path("scene_graph.json"),
        help="Path to write the output JSON file (default: scene_graph.json).",
    )
    args = parser.parse_args(argv)

    src_path: Path = args.src_path.resolve()
    if not src_path.exists():
        print(f"error: source path does not exist: {src_path}", file=sys.stderr)
        return 1
    if not src_path.is_dir():
        print(f"error: source path is not a directory: {src_path}", file=sys.stderr)
        return 1

    print(f"Extracting scene graph from: {src_path}", file=sys.stderr)
    graph = build_scene_graph(src_path)

    output_path: Path = args.output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(graph, indent=2), encoding="utf-8")

    node_count = len(graph["nodes"])
    edge_count = len(graph["edges"])
    print(
        f"Wrote {node_count} nodes and {edge_count} edges to: {output_path}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
