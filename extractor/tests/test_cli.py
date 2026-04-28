"""Tests for the CLI entry point and stdlib-only constraint.

Covers two THEN-clauses from specs/extraction/code-extraction.spec.md:
  - "runs as a standalone CLI tool" (Requirement: CLI output)
  - "requires no dependencies beyond stdlib" (Requirement: No dependencies)
"""

from __future__ import annotations

import ast
import sys
from pathlib import Path

import pytest

from extractor.__main__ import main


# ---------------------------------------------------------------------------
# Requirement: CLI output
# THEN the tool runs as a standalone CLI and produces valid JSON output.
# ---------------------------------------------------------------------------


class TestCliEntryPoint:
    def test_main_exits_zero_on_valid_src(self, tmp_path: Path) -> None:
        """main() returns 0 when given a valid source directory."""
        # Minimal Python package.
        pkg = tmp_path / "myapp"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")

        out = tmp_path / "out.json"
        rc = main([str(tmp_path), "--output", str(out)])
        assert rc == 0

    def test_main_creates_output_file(self, tmp_path: Path) -> None:
        """main() writes a JSON file at the requested output path."""
        pkg = tmp_path / "billing"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")

        out = tmp_path / "graph.json"
        rc = main([str(tmp_path), "--output", str(out)])
        assert rc == 0
        assert out.exists()

    def test_main_output_is_valid_json(self, tmp_path: Path) -> None:
        """main() output is valid, parseable JSON."""
        import json

        pkg = tmp_path / "orders"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")

        out = tmp_path / "scene.json"
        rc = main([str(tmp_path), "--output", str(out)])
        assert rc == 0

        data = json.loads(out.read_text())
        assert "nodes" in data
        assert "edges" in data
        assert "metadata" in data

    def test_main_returns_nonzero_for_missing_path(self, tmp_path: Path) -> None:
        """main() returns non-zero when source path does not exist."""
        missing = tmp_path / "does_not_exist"
        out = tmp_path / "out.json"
        rc = main([str(missing), "--output", str(out)])
        assert rc != 0


# ---------------------------------------------------------------------------
# Requirement: No dependencies
# THEN the extractor requires no dependencies beyond the Python stdlib.
# ---------------------------------------------------------------------------


class TestStdlibOnly:
    def test_extractor_imports_are_stdlib_only(self) -> None:
        """All imports in extractor/ must resolve to stdlib modules.

        Parses every .py file in the extractor package with ast, collects all
        top-level Import and ImportFrom names, and asserts each resolves to a
        stdlib module or the extractor package itself.

        Uses sys.stdlib_module_names (available Python 3.10+) — the canonical
        mechanism for checking stdlib membership.
        """
        extractor_root = Path(__file__).parent.parent
        stdlib_names: frozenset[str] = sys.stdlib_module_names  # type: ignore[attr-defined]

        for py_file in sorted(extractor_root.rglob("*.py")):
            # Skip test files — they may use pytest and other test helpers.
            if "tests" in py_file.parts:
                continue

            source = py_file.read_text(encoding="utf-8", errors="replace")
            try:
                tree = ast.parse(source, filename=str(py_file))
            except SyntaxError:
                continue

            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        top = alias.name.split(".")[0]
                        assert top in stdlib_names or top == "extractor", (
                            f"{py_file.relative_to(extractor_root.parent)}: "
                            f"non-stdlib import '{alias.name}' — "
                            "the extractor must depend only on the standard library."
                        )
                elif isinstance(node, ast.ImportFrom) and node.level == 0:
                    if node.module:
                        top = node.module.split(".")[0]
                        assert top in stdlib_names or top == "extractor", (
                            f"{py_file.relative_to(extractor_root.parent)}: "
                            f"non-stdlib import 'from {node.module}' — "
                            "the extractor must depend only on the standard library."
                        )
