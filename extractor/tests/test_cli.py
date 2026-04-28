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
