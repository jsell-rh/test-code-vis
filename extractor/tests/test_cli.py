"""Tests for the extractor CLI entry point and stdlib-only constraint.

Covers:
  - 'runs as a standalone CLI tool' THEN-clause from the prototype spec
    → test_main_exits_zero, test_main_writes_json_output
  - 'requires no dependencies beyond stdlib' constraint
    → test_extractor_imports_are_stdlib_only
"""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

import pytest

from extractor.__main__ import main


# ---------------------------------------------------------------------------
# Requirement: CLI entry point
# ---------------------------------------------------------------------------


@pytest.fixture()
def minimal_src(tmp_path: Path) -> Path:
    """Minimal valid Python source tree for CLI testing."""
    bc = tmp_path / "orders"
    bc.mkdir()
    (bc / "__init__.py").write_text("")
    (bc / "service.py").write_text("class OrderService:\n    pass\n")
    return tmp_path


def test_main_exits_zero(minimal_src: Path, tmp_path: Path) -> None:
    """CLI must exit 0 when given a valid source path."""
    out = tmp_path / "out.json"
    rc = main([str(minimal_src), "--output", str(out)])
    assert rc == 0


def test_main_writes_json_output(minimal_src: Path, tmp_path: Path) -> None:
    """CLI must write a valid JSON scene graph to the specified output path."""
    out = tmp_path / "scene_graph.json"
    rc = main([str(minimal_src), "--output", str(out)])
    assert rc == 0
    assert out.exists(), "Output file must be created by main()"
    graph = json.loads(out.read_text())
    assert "nodes" in graph
    assert "edges" in graph
    assert "metadata" in graph


def test_main_output_has_exactly_four_top_level_keys(
    minimal_src: Path, tmp_path: Path
) -> None:
    """CLI output must contain exactly the four schema-required top-level keys.

    Spec (scene-graph-schema.spec.md § Schema Structure):
    THEN it contains a 'nodes' array, an 'edges' array, a 'metadata' object,
    and a 'clusters' array — AND no other top-level fields are present.
    """
    out = tmp_path / "scene_graph.json"
    rc = main([str(minimal_src), "--output", str(out)])
    assert rc == 0
    graph = json.loads(out.read_text())
    assert set(graph.keys()) == {"nodes", "edges", "metadata", "clusters"}, (
        f"Output must have exactly {{nodes, edges, metadata, clusters}}; "
        f"got {sorted(graph.keys())}"
    )


def test_main_output_metadata_has_source_path(
    minimal_src: Path, tmp_path: Path
) -> None:
    """CLI output metadata must record the source codebase path.

    Spec (scene-graph-schema.spec.md § Extraction metadata):
    THEN the metadata contains the source codebase path.
    """
    out = tmp_path / "scene_graph.json"
    rc = main([str(minimal_src), "--output", str(out)])
    assert rc == 0
    graph = json.loads(out.read_text())
    meta = graph["metadata"]
    assert "source_path" in meta, "metadata must contain 'source_path'"
    # source_path must be non-empty and reference the resolved input path
    assert meta["source_path"] != "", "metadata source_path must not be empty"
    assert str(minimal_src.resolve()) in meta["source_path"], (
        f"metadata source_path '{meta['source_path']}' must contain "
        f"the resolved input path '{minimal_src.resolve()}'"
    )


def test_main_output_metadata_has_iso8601_timestamp(
    minimal_src: Path, tmp_path: Path
) -> None:
    """CLI output metadata must record an ISO-8601 extraction timestamp.

    Spec (scene-graph-schema.spec.md § Extraction metadata):
    THEN the metadata contains ... the timestamp of extraction.
    """
    out = tmp_path / "scene_graph.json"
    rc = main([str(minimal_src), "--output", str(out)])
    assert rc == 0
    graph = json.loads(out.read_text())
    meta = graph["metadata"]
    assert "timestamp" in meta, "metadata must contain 'timestamp'"
    ts = meta["timestamp"]
    assert isinstance(ts, str) and len(ts) > 0, "timestamp must be a non-empty string"
    # ISO-8601 UTC timestamps contain 'T' as date/time separator and 'Z' or '+00:00'
    assert "T" in ts, f"timestamp '{ts}' must be ISO-8601 (expected 'T' separator)"


def test_main_output_passes_schema_validation(
    minimal_src: Path, tmp_path: Path
) -> None:
    """CLI output must pass validate_scene_graph without errors.

    The extractor enforces the schema contract at write time: the JSON file
    is only written if it passes the structural validator.
    Spec (scene-graph-schema.spec.md § Schema Structure).
    """
    from extractor.schema import validate_scene_graph

    out = tmp_path / "scene_graph.json"
    rc = main([str(minimal_src), "--output", str(out)])
    assert rc == 0
    graph = json.loads(out.read_text())
    # Must not raise — the output always conforms to the schema contract.
    validate_scene_graph(graph)


def test_main_returns_nonzero_for_missing_path(tmp_path: Path) -> None:
    """CLI must return non-zero when the source path does not exist."""
    missing = tmp_path / "does_not_exist"
    rc = main([str(missing)])
    assert rc != 0


# ---------------------------------------------------------------------------
# Requirement: stdlib-only imports
# ---------------------------------------------------------------------------

_EXTRACTOR_PKG = Path(__file__).parent.parent  # extractor/

# Only scan production source files, not tests (tests may import pytest etc.)
_PRODUCTION_FILES = [
    "extractor.py",
    "__init__.py",
    "__main__.py",
    "schema.py",
]


def _collect_top_level_imports(pkg: Path) -> list[str]:
    """Return the top-level module names imported by the extractor's production files."""
    names: list[str] = []
    for filename in _PRODUCTION_FILES:
        py_file = pkg / filename
        if not py_file.exists():
            continue
        try:
            tree = ast.parse(py_file.read_text(encoding="utf-8"))
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    names.append(alias.name.split(".")[0])
            elif isinstance(node, ast.ImportFrom):
                if node.module is not None and node.level == 0:
                    names.append(node.module.split(".")[0])
    return names


def test_extractor_imports_are_stdlib_only() -> None:
    """Every top-level import in the extractor package must be from the stdlib.

    The extractor spec requires no third-party dependencies.
    'extractor' itself is the only allowed non-stdlib name (internal package).
    """
    stdlib = sys.stdlib_module_names  # type: ignore[attr-defined]
    imported = _collect_top_level_imports(_EXTRACTOR_PKG)
    violations = [
        name for name in imported if name not in stdlib and name != "extractor"
    ]
    assert violations == [], (
        f"Non-stdlib imports found in extractor package: {sorted(set(violations))}. "
        "The extractor must use only the Python standard library."
    )
