"""Tests for the extractor CLI entry point and stdlib-only constraint.

Covers NFR spec scenarios:
  - "it runs as a standalone Python script or CLI tool"
    (calls main([...]) and asserts rc=0 and valid JSON output)
  - "it requires no dependencies beyond the Python standard library and tree-sitter
    (or ast module)"
    (inspects every import in the extractor package and asserts all are stdlib or
    the extractor package itself)
"""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

import pytest

from extractor.__main__ import main


# ---------------------------------------------------------------------------
# Fixture: minimal kartograph-like source tree
# ---------------------------------------------------------------------------


@pytest.fixture()
def src(tmp_path: Path) -> Path:
    """Return a minimal source tree with three bounded contexts."""
    # Bounded context: iam
    iam = tmp_path / "iam"
    (iam / "domain").mkdir(parents=True)
    (iam / "application").mkdir(parents=True)
    for d in [iam, iam / "domain", iam / "application"]:
        (d / "__init__.py").write_text("")
    (iam / "domain" / "models.py").write_text(
        "from shared_kernel.auth import AuthToken\nclass User:\n    pass\n"
    )
    (iam / "application" / "services.py").write_text(
        "from iam.domain import User\nclass UserService:\n    pass\n"
    )

    # Bounded context: shared_kernel
    sk = tmp_path / "shared_kernel"
    sk.mkdir()
    (sk / "__init__.py").write_text("")
    (sk / "auth.py").write_text("class AuthToken:\n    pass\n")

    # Bounded context: graph
    graph = tmp_path / "graph"
    (graph / "domain").mkdir(parents=True)
    (graph / "infrastructure").mkdir(parents=True)
    for d in [graph, graph / "domain", graph / "infrastructure"]:
        (d / "__init__.py").write_text("")
    (graph / "infrastructure" / "repo.py").write_text(
        "from shared_kernel.auth import AuthToken\nfrom graph.domain import Node\n"
    )
    (graph / "domain" / "models.py").write_text("class Node:\n    pass\n")

    return tmp_path


# ---------------------------------------------------------------------------
# CLI entry-point tests
# ---------------------------------------------------------------------------


class TestCliEntryPoint:
    """Requirement: it runs as a standalone CLI tool."""

    def test_main_produces_json_output(self, src: Path, tmp_path: Path) -> None:
        """main() exits 0 and writes a valid JSON file with nodes/edges/metadata."""
        output = tmp_path / "out.json"
        rc = main([str(src), "--output", str(output)])
        assert rc == 0, "main() should return 0 on success"
        assert output.exists(), "Output JSON file must be created"
        data = json.loads(output.read_text())
        assert "nodes" in data, "JSON output must have a 'nodes' key"
        assert "edges" in data, "JSON output must have an 'edges' key"
        assert "metadata" in data, "JSON output must have a 'metadata' key"

    def test_main_nodes_are_non_empty(self, src: Path, tmp_path: Path) -> None:
        """main() produces at least one node (the bounded contexts)."""
        output = tmp_path / "out.json"
        rc = main([str(src), "--output", str(output)])
        assert rc == 0
        data = json.loads(output.read_text())
        assert len(data["nodes"]) > 0, "nodes list must be non-empty"

    def test_main_default_output_filename(self, src: Path, tmp_path: Path) -> None:
        """When --output is omitted, main() writes to scene_graph.json in cwd."""
        import os

        original_cwd = Path.cwd()
        try:
            os.chdir(tmp_path)
            rc = main([str(src)])
            assert rc == 0
            output = tmp_path / "scene_graph.json"
            assert output.exists(), "Default output file 'scene_graph.json' must exist"
            data = json.loads(output.read_text())
            assert "nodes" in data
        finally:
            os.chdir(original_cwd)

    def test_main_returns_1_on_missing_src(self, tmp_path: Path) -> None:
        """main() returns exit code 1 when the src_path does not exist."""
        nonexistent = tmp_path / "does_not_exist"
        rc = main([str(nonexistent), "--output", str(tmp_path / "out.json")])
        assert rc == 1, "main() should return 1 for a non-existent source path"

    def test_main_returns_1_on_file_src(self, tmp_path: Path) -> None:
        """main() returns exit code 1 when src_path is a file, not a directory."""
        a_file = tmp_path / "file.py"
        a_file.write_text("")
        rc = main([str(a_file), "--output", str(tmp_path / "out.json")])
        assert rc == 1, "main() should return 1 when src_path is a file"

    def test_main_output_nodes_have_required_keys(
        self, src: Path, tmp_path: Path
    ) -> None:
        """Every node in the JSON output has id, name, type, parent, position, size."""
        output = tmp_path / "out.json"
        main([str(src), "--output", str(output)])
        data = json.loads(output.read_text())
        required = {"id", "name", "type", "parent", "position", "size"}
        for node in data["nodes"]:
            missing = required - node.keys()
            assert not missing, f"Node {node.get('id')} missing keys: {missing}"

    def test_main_output_edges_have_required_keys(
        self, src: Path, tmp_path: Path
    ) -> None:
        """Every edge in the JSON output has source, target, type."""
        output = tmp_path / "out.json"
        main([str(src), "--output", str(output)])
        data = json.loads(output.read_text())
        required = {"source", "target", "type"}
        for edge in data["edges"]:
            missing = required - edge.keys()
            assert not missing, f"Edge missing keys: {missing}"


# ---------------------------------------------------------------------------
# Stdlib-only constraint test
# ---------------------------------------------------------------------------


class TestStdlibOnlyImports:
    """Requirement: requires no dependencies beyond the Python standard library."""

    def test_extractor_uses_only_stdlib_imports(self) -> None:
        """All top-level imports in the extractor package resolve to stdlib modules.

        Inspects every .py file in the extractor/ package directory (excluding
        test files) using the ast module and asserts that every imported module
        name is either:
          - a member of sys.stdlib_module_names (standard library), OR
          - the 'extractor' package itself (intra-package imports), OR
          - '__future__' (PEP 236 future annotations)
        """
        # Locate the extractor package directory via its __init__.py.
        extractor_pkg = Path(__file__).parent.parent  # extractor/
        assert extractor_pkg.name == "extractor", (
            f"Expected package dir 'extractor', got '{extractor_pkg.name}'"
        )

        stdlib_names: frozenset[str] = frozenset(sys.stdlib_module_names)
        allowed_prefixes = ("extractor",)

        violations: list[str] = []

        # Iterate all .py files in the package (not tests/).
        for py_file in sorted(extractor_pkg.rglob("*.py")):
            # Skip test files.
            if "tests" in py_file.parts:
                continue
            source = py_file.read_text(encoding="utf-8")
            tree = ast.parse(source, filename=str(py_file))

            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        top_level = alias.name.split(".")[0]
                        if (
                            top_level in stdlib_names
                            or top_level.startswith(allowed_prefixes)
                            or top_level == "__future__"
                        ):
                            continue
                        violations.append(
                            f"{py_file.relative_to(extractor_pkg.parent)}: "
                            f"import {alias.name!r} is not stdlib"
                        )

                elif isinstance(node, ast.ImportFrom):
                    if node.level and node.level > 0:
                        # Relative import — always within the extractor package.
                        continue
                    module = node.module or ""
                    top_level = module.split(".")[0]
                    if (
                        top_level in stdlib_names
                        or top_level.startswith(allowed_prefixes)
                        or top_level == "__future__"
                    ):
                        continue
                    violations.append(
                        f"{py_file.relative_to(extractor_pkg.parent)}: "
                        f"from {module!r} import ... is not stdlib"
                    )

        assert not violations, (
            "Extractor package contains non-stdlib imports:\n"
            + "\n".join(f"  {v}" for v in violations)
        )
