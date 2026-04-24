"""Integration test: extractor against the real kartograph codebase.

Spec requirement (prototype-scope.spec.md — Target Codebase):
  GIVEN the kartograph codebase
  WHEN the user runs the extractor
  THEN a JSON scene graph file is produced
  AND the scene graph contains the expected bounded contexts
      (iam, graph, shared_kernel).
  AND the visualization reflects the actual structure of the codebase
      (module-level nodes are produced inside those bounded contexts).

This test runs the extractor CLI against ~/code/kartograph/src/api and
asserts that the output JSON contains the known bounded contexts and
at least one module-level node.
It is skipped when the kartograph codebase is not present (CI without the
local filesystem clone).
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from extractor.__main__ import main

KARTOGRAPH_SRC = Path.home() / "code" / "kartograph" / "src" / "api"


@pytest.mark.skipif(
    not KARTOGRAPH_SRC.exists(),
    reason="kartograph codebase not available at ~/code/kartograph/src/api",
)
def test_kartograph_integration_bounded_contexts(tmp_path: Path) -> None:
    """Extractor must discover known kartograph bounded contexts.

    GIVEN the kartograph codebase at ~/code/kartograph/src/api
    WHEN main() is invoked against that path
    THEN the output JSON contains bounded context nodes for iam, graph,
         and shared_kernel.
    """
    out = tmp_path / "scene_graph.json"
    rc = main([str(KARTOGRAPH_SRC), "--output", str(out)])

    assert rc == 0, "Extractor CLI must exit 0 on kartograph source"
    assert out.exists(), "Extractor must write an output file"

    graph = json.loads(out.read_text(encoding="utf-8"))
    assert "nodes" in graph, "Scene graph must have a 'nodes' key"
    assert "edges" in graph, "Scene graph must have an 'edges' key"

    # Collect the ids of all bounded-context nodes.
    context_ids = {
        nd["id"] for nd in graph["nodes"] if nd.get("type") == "bounded_context"
    }

    # The three well-known bounded contexts that kartograph ships with.
    for expected in ("iam", "graph", "shared_kernel"):
        assert expected in context_ids, (
            f"Expected bounded context '{expected}' not found in scene graph. "
            f"Found contexts: {sorted(context_ids)}"
        )


@pytest.mark.skipif(
    not KARTOGRAPH_SRC.exists(),
    reason="kartograph codebase not available at ~/code/kartograph/src/api",
)
def test_kartograph_extraction_produces_modules(tmp_path: Path) -> None:
    """Extractor must produce module-level nodes reflecting the actual structure.

    GIVEN the kartograph codebase at ~/code/kartograph/src/api
    WHEN main() is invoked against that path
    THEN the output JSON contains at least one node with type 'module',
         demonstrating that the visualization reflects the actual internal
         structure of the codebase (not just top-level bounded contexts).
    """
    out = tmp_path / "scene_graph.json"
    rc = main([str(KARTOGRAPH_SRC), "--output", str(out)])

    assert rc == 0, "Extractor CLI must exit 0 on kartograph source"

    graph = json.loads(out.read_text(encoding="utf-8"))
    module_nodes = [nd for nd in graph["nodes"] if nd.get("type") == "module"]

    assert len(module_nodes) > 0, (
        "Extractor must produce at least one module-level node from the kartograph "
        "codebase, reflecting its internal structure. "
        f"Only found node types: {sorted({nd.get('type') for nd in graph['nodes']})}"
    )
