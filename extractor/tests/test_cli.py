"""Tests for the extractor CLI entry point and stdlib-only constraint.

Covers two mandatory requirements:
  1. The CLI entry point (main() in extractor/__main__.py) is exercisable
     as a standalone command and returns exit code 0 with valid JSON output.
  2. The extractor package uses only Python standard-library imports (no
     third-party dependencies), verified by inspecting every .py file with
     the ast module and checking each import against sys.stdlib_module_names.
"""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

from extractor.__main__ import main


# ---------------------------------------------------------------------------
# Requirement: CLI entry point
# ---------------------------------------------------------------------------


class TestCLIEntryPoint:
    """The extractor MUST run as a standalone CLI tool (python -m extractor)."""

    def test_main_returns_zero_on_valid_src(self, tmp_path: Path) -> None:
        """main() must exit 0 when given a valid source directory."""
        # Build a minimal Python package so the extractor has something to find.
        pkg = tmp_path / "mycontext"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        (pkg / "service.py").write_text("class Service:\n    pass\n")

        out = tmp_path / "out.json"
        rc = main([str(tmp_path), "--output", str(out)])
        assert rc == 0, f"main() returned non-zero exit code: {rc}"

    def test_main_writes_valid_json(self, tmp_path: Path) -> None:
        """main() must write a JSON file that is parseable."""
        pkg = tmp_path / "mycontext"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")

        out = tmp_path / "graph.json"
        rc = main([str(tmp_path), "--output", str(out)])
        assert rc == 0
        assert out.exists(), "Output JSON file was not created"
        content = out.read_text(encoding="utf-8")
        parsed = json.loads(content)
        assert "nodes" in parsed
        assert "edges" in parsed
        assert "metadata" in parsed

    def test_main_returns_nonzero_for_missing_path(self, tmp_path: Path) -> None:
        """main() must return non-zero when the source path does not exist."""
        rc = main([str(tmp_path / "nonexistent")])
        assert rc != 0

    def test_main_output_node_count_matches_json(self, tmp_path: Path) -> None:
        """main() writes all discovered nodes to the JSON file."""
        for bc in ("alpha", "beta"):
            pkg = tmp_path / bc
            pkg.mkdir()
            (pkg / "__init__.py").write_text("")

        out = tmp_path / "result.json"
        rc = main([str(tmp_path), "--output", str(out)])
        assert rc == 0
        parsed = json.loads(out.read_text(encoding="utf-8"))
        ids = {n["id"] for n in parsed["nodes"]}
        assert "alpha" in ids
        assert "beta" in ids


# ---------------------------------------------------------------------------
# Requirement: stdlib-only imports
# ---------------------------------------------------------------------------


class TestStdlibOnlyImports:
    """The extractor MUST NOT import any third-party package.

    Every import in every .py file under extractor/ must resolve to either:
      * A Python standard-library module (in sys.stdlib_module_names), or
      * The extractor package itself (internal relative imports).
    """

    def test_all_extractor_imports_are_stdlib(self) -> None:
        """Every top-level import in the extractor production code must be a
        stdlib module or the 'extractor' package itself.

        Only production .py files are checked (extractor/__init__.py,
        extractor/extractor.py, extractor/schema.py, extractor/__main__.py).
        Test files are excluded because they are allowed to import pytest.
        """
        extractor_dir = Path(__file__).parent.parent  # extractor/
        # Collect only the production source files — exclude tests/
        production_files = [
            f for f in sorted(extractor_dir.rglob("*.py")) if "tests" not in f.parts
        ]
        imports: list[str] = []
        for py_file in production_files:
            try:
                tree = ast.parse(py_file.read_text(encoding="utf-8"))
            except SyntaxError:
                continue
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        imports.append(alias.name.split(".")[0])
                elif isinstance(node, ast.ImportFrom):
                    if node.level and node.level > 0:
                        continue
                    if node.module:
                        imports.append(node.module.split(".")[0])

        stdlib = sys.stdlib_module_names  # frozenset, Python 3.10+
        allowed = stdlib | {"extractor"}  # internal package

        third_party = [name for name in imports if name not in allowed]
        assert not third_party, (
            f"Third-party imports detected in extractor/: {sorted(set(third_party))}. "
            "The extractor must use only Python standard-library modules."
        )
