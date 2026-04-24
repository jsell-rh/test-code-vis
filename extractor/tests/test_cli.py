"""Tests for the CLI entry point and stdlib-only constraint.

Validates that:
- The main() CLI entry point in extractor/__main__.py runs successfully and
  produces valid JSON output.
- All imports in the extractor package come from the Python standard library.

References:
  specs/prototype/nfr.spec.md  (stdlib-only constraint)
  specs/extraction/code-extraction.spec.md  (CLI tool requirement)
"""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


class TestCLIEntryPoint:
    """The extractor MUST run as a standalone CLI tool (main() in __main__.py)."""

    def test_main_returns_zero_on_valid_source(self, tmp_path: Path) -> None:
        """main([src, --output, out]) returns 0 and writes valid JSON."""
        # Minimal Python package — one bounded context with one source file.
        iam = tmp_path / "iam"
        iam.mkdir()
        (iam / "__init__.py").write_text("")
        (iam / "models.py").write_text("class User:\n    pass\n")

        output_path = tmp_path / "scene_graph.json"

        from extractor.__main__ import main

        rc = main([str(tmp_path), "--output", str(output_path)])

        assert rc == 0, "main() must return 0 on success"
        assert output_path.exists(), "main() must create the output JSON file"

        graph = json.loads(output_path.read_text(encoding="utf-8"))
        assert "nodes" in graph, "Output JSON must contain 'nodes'"
        assert "edges" in graph, "Output JSON must contain 'edges'"
        assert "metadata" in graph, "Output JSON must contain 'metadata'"

    def test_main_returns_nonzero_on_missing_source(self, tmp_path: Path) -> None:
        """main() returns non-zero when source path does not exist."""
        from extractor.__main__ import main

        rc = main([str(tmp_path / "does_not_exist")])
        assert rc != 0, "main() must return non-zero when source path is missing"

    def test_main_output_contains_bounded_context_node(self, tmp_path: Path) -> None:
        """main() discovers bounded contexts and writes them as nodes."""
        billing = tmp_path / "billing"
        billing.mkdir()
        (billing / "__init__.py").write_text("")
        (billing / "service.py").write_text("class BillingService:\n    pass\n")

        output_path = tmp_path / "out.json"
        from extractor.__main__ import main

        rc = main([str(tmp_path), "--output", str(output_path)])

        assert rc == 0
        graph = json.loads(output_path.read_text(encoding="utf-8"))
        node_ids = {n["id"] for n in graph["nodes"]}
        assert "billing" in node_ids, "Discovered bounded context must appear in nodes"


# ---------------------------------------------------------------------------
# Stdlib-only constraint
# ---------------------------------------------------------------------------


class TestStdlibOnly:
    """All imports in the extractor package MUST come from the standard library.

    The extractor is specified as having no third-party dependencies.
    This test inspects every .py file in extractor/ (excluding tests/) using
    ast and asserts every top-level import module is in sys.stdlib_module_names
    or belongs to the extractor package itself.
    """

    def test_extractor_imports_are_stdlib_only(self) -> None:
        """Every top-level import in extractor/ (non-test) is stdlib or self."""
        extractor_dir = Path(__file__).parent.parent  # extractor/

        non_stdlib: list[str] = []

        for py_file in sorted(extractor_dir.rglob("*.py")):
            # Skip the tests/ sub-package — only check production code.
            relative = py_file.relative_to(extractor_dir)
            if relative.parts[0] == "tests":
                continue

            try:
                tree = ast.parse(
                    py_file.read_text(encoding="utf-8"), filename=str(py_file)
                )
            except SyntaxError:
                continue  # syntax errors in production code are caught elsewhere

            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        top_module = alias.name.split(".")[0]
                        if (
                            top_module not in sys.stdlib_module_names
                            and top_module != "extractor"
                        ):
                            non_stdlib.append(f"{py_file.name}: import {alias.name!r}")
                elif isinstance(node, ast.ImportFrom):
                    # Relative imports (level > 0) are always intra-package.
                    if node.level == 0 and node.module:
                        top_module = node.module.split(".")[0]
                        if (
                            top_module not in sys.stdlib_module_names
                            and top_module != "extractor"
                        ):
                            non_stdlib.append(
                                f"{py_file.name}: from {node.module!r} import ..."
                            )

        assert not non_stdlib, (
            "Non-stdlib imports found in extractor production code:\n"
            + "\n".join(f"  {line}" for line in non_stdlib)
        )
