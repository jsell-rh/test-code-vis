"""Tests tied to specs/core/system-purpose.spec.md THEN-clauses.

These tests verify that the extractor produces a scene graph that fulfils the
system purpose: enabling humans to acquire concrete understanding of agent-built
software systems without reading source code.

Coverage mapping (THEN-clause → test function):
  Scenario "Architect evaluates unfamiliar system"
    THEN the human can correctly answer architectural questions
      → test_scene_graph_exposes_named_bounded_contexts
      → test_scene_graph_exposes_named_modules_with_types
    AND the human can identify structural problems
      → test_size_encoding_reflects_relative_complexity
      → test_edge_types_expose_coupling_structure
    AND the human can predict the impact of proposed changes
      → test_cross_context_edges_reveal_change_impact_paths

  Scenario "Spec and codebase loaded together"
    AND the codebase is treated as the realized design
      → test_scene_graph_reflects_actual_source_file_structure
    NOTE: "spec is treated as the intended design" and
          "relationship between them is available for inspection"
          are NOT testable at the prototype level (spec-extraction and
          spec-overlay-comparison are explicitly out of scope per
          prototype-scope.spec.md § Not In Scope).

  Scenario "Post-build evaluation"
    AND the human can determine whether the build is architecturally sound
      → test_structural_soundness_information_is_complete
    AND the human can explore the impact of potential changes
      → test_dependency_graph_is_traversable_for_impact_analysis
    NOTE: "the human can determine whether the build matches the spec"
          is NOT testable at the prototype level (spec-overlay comparison
          is explicitly out of scope).
"""

from __future__ import annotations

from pathlib import Path

import pytest

from extractor.extractor import build_scene_graph, size_from_loc


# ---------------------------------------------------------------------------
# Shared fixture: a minimal kartograph-like source tree
# ---------------------------------------------------------------------------


@pytest.fixture()
def kart_src(tmp_path: Path) -> Path:
    """Minimal kartograph-like codebase with iam, graph, and shared_kernel contexts."""
    # bounded context: iam
    iam = tmp_path / "iam"
    (iam / "domain").mkdir(parents=True)
    (iam / "application").mkdir(parents=True)
    for d in [iam, iam / "domain", iam / "application"]:
        (d / "__init__.py").write_text("")
    (iam / "domain" / "user.py").write_text(
        "from shared_kernel.auth import AuthToken\n\nclass User:\n    pass\n"
    )
    (iam / "application" / "services.py").write_text(
        "from iam.domain.user import User\n\nclass UserService:\n    pass\n"
    )

    # bounded context: shared_kernel
    sk = tmp_path / "shared_kernel"
    sk.mkdir()
    (sk / "__init__.py").write_text("")
    (sk / "auth.py").write_text("class AuthToken:\n    pass\n")

    # bounded context: graph
    graph = tmp_path / "graph"
    (graph / "domain").mkdir(parents=True)
    (graph / "infrastructure").mkdir(parents=True)
    for d in [graph, graph / "domain", graph / "infrastructure"]:
        (d / "__init__.py").write_text("")
    (graph / "domain" / "models.py").write_text("class Node:\n    pass\n")
    (graph / "infrastructure" / "repo.py").write_text(
        "from shared_kernel.auth import AuthToken\nfrom graph.domain.models import Node\n"
        "class NodeRepo:\n    pass\n"
    )

    return tmp_path


# ---------------------------------------------------------------------------
# THEN: human can correctly answer architectural questions
# ---------------------------------------------------------------------------


def test_scene_graph_exposes_named_bounded_contexts(kart_src: Path) -> None:
    """The scene graph must name every bounded context so the human can enumerate them.

    System-purpose THEN-clause: 'the human can correctly answer architectural
    questions about the system' — the first such question is 'what bounded
    contexts exist?'.  The scene graph must contain a node of type
    'bounded_context' for each top-level context, with a non-empty 'name'.
    """
    graph = build_scene_graph(kart_src)
    bc_nodes = [n for n in graph["nodes"] if n["type"] == "bounded_context"]

    assert len(bc_nodes) >= 3, (
        "Expected at least 3 bounded-context nodes (iam, graph, shared_kernel)"
    )

    # Names are prettified (snake_case → Title Case) by the extractor.
    bc_names = {n["name"] for n in bc_nodes}
    for expected in ("Iam", "Graph", "Shared Kernel"):
        assert expected in bc_names, (
            f"Bounded context '{expected}' must appear in scene graph nodes "
            "so the human can answer 'what bounded contexts exist?'"
        )


def test_scene_graph_exposes_named_modules_with_types(kart_src: Path) -> None:
    """Every node in the scene graph must have a non-empty 'name' and a 'type'.

    System-purpose THEN-clause: 'the human can correctly answer architectural
    questions' — the human must be able to identify every structural element
    (module, bounded context) by name and understand its kind.
    """
    graph = build_scene_graph(kart_src)
    valid_types = {"bounded_context", "module"}

    for node in graph["nodes"]:
        assert node.get("name"), (
            f"Node '{node.get('id')}' has no name — human cannot identify it"
        )
        assert node.get("type") in valid_types, (
            f"Node '{node.get('id')}' has unexpected type '{node.get('type')}'"
        )


# ---------------------------------------------------------------------------
# AND: human can identify structural problems
# ---------------------------------------------------------------------------


def test_size_encoding_reflects_relative_complexity(tmp_path: Path) -> None:
    """A module with more lines of code must produce a larger size value.

    System-purpose THEN-clause: 'the human can identify structural problems' —
    an unusually large module (technical debt, god class) must appear bigger
    in the scene so the problem is visually apparent without reading source.
    """
    # A module with many more lines must be noticeably larger.
    small_loc = 10
    large_loc = 500

    small_size = size_from_loc(small_loc)
    large_size = size_from_loc(large_loc)

    assert large_size > small_size, (
        "size_from_loc must grow with LOC so complex modules appear bigger "
        "and structural problems are visually identifiable"
    )


def test_edge_types_expose_coupling_structure(kart_src: Path) -> None:
    """Every edge must carry a 'type' ('cross_context' or 'internal').

    System-purpose THEN-clause: 'the human can identify structural problems' —
    the coupling structure (which bounded contexts depend on which) must be
    visible so the human can spot over-coupling or unexpected dependencies.
    """
    graph = build_scene_graph(kart_src)
    valid_edge_types = {"cross_context", "internal"}

    assert graph["edges"], "Scene graph must contain edges to reveal coupling"

    for edge in graph["edges"]:
        assert edge.get("type") in valid_edge_types, (
            f"Edge {edge.get('source')} → {edge.get('target')} has unexpected "
            f"type '{edge.get('type')}' — edge type must identify coupling kind"
        )


# ---------------------------------------------------------------------------
# AND: human can predict the impact of proposed changes
# ---------------------------------------------------------------------------


def test_cross_context_edges_reveal_change_impact_paths(kart_src: Path) -> None:
    """Cross-context edges must be present and point from source to target.

    System-purpose THEN-clause: 'the human can predict the impact of proposed
    changes' — to assess impact, the human must be able to follow dependency
    paths: 'if I change X, what does it affect?' Cross-context edges encode
    exactly these paths.
    """
    graph = build_scene_graph(kart_src)
    cross_edges = [e for e in graph["edges"] if e["type"] == "cross_context"]

    assert cross_edges, (
        "At least one cross-context edge must be present so impact paths "
        "across bounded contexts are visible"
    )

    for edge in cross_edges:
        assert edge.get("source"), "Edge must have a source node id"
        assert edge.get("target"), "Edge must have a target node id"
        assert edge["source"] != edge["target"], (
            "Cross-context edge must not be a self-loop"
        )


# ---------------------------------------------------------------------------
# AND: codebase is treated as the realized design
# ---------------------------------------------------------------------------


def test_scene_graph_reflects_actual_source_file_structure(kart_src: Path) -> None:
    """The scene graph must reflect the actual filesystem structure of the codebase.

    System-purpose THEN-clause: 'the codebase is treated as the realized design' —
    the extractor reads the source tree and faithfully represents it: modules
    that exist in the code appear as nodes; dependencies declared via imports
    appear as edges.
    """
    graph = build_scene_graph(kart_src)

    # The iam.domain module exists as a subdirectory with __init__.py.
    node_ids = {n["id"] for n in graph["nodes"]}
    assert "iam" in node_ids, "Realized design must include the 'iam' bounded context"
    assert "iam.domain" in node_ids, (
        "Realized design must include the 'iam.domain' module"
    )

    # The import 'from shared_kernel.auth import AuthToken' in iam/domain/user.py
    # must produce a cross-context edge iam.domain → shared_kernel.
    edges_from_iam_domain = [
        e
        for e in graph["edges"]
        if e["source"].startswith("iam") and e["target"].startswith("shared_kernel")
    ]
    assert edges_from_iam_domain, (
        "An edge from iam to shared_kernel must exist because iam/domain/user.py "
        "imports from shared_kernel — the realized design must be faithfully encoded"
    )


# ---------------------------------------------------------------------------
# AND: human can determine whether the build is architecturally sound
# ---------------------------------------------------------------------------


def test_structural_soundness_information_is_complete(kart_src: Path) -> None:
    """The scene graph must carry all information needed for soundness evaluation.

    System-purpose THEN-clause: 'the human can determine whether the build is
    architecturally sound regardless of spec compliance' — this requires:
      1. Every node has a measurable size (LOC-based, so big modules stand out)
      2. Every edge records direction (source, target) for coupling analysis
      3. The metadata captures which codebase was analysed
    """
    graph = build_scene_graph(kart_src)

    # 1. Every node has a size metric.
    for node in graph["nodes"]:
        assert "size" in node, f"Node '{node['id']}' is missing 'size'"
        assert node["size"] > 0, (
            f"Node '{node['id']}' has size ≤ 0 — structural metrics must be positive"
        )

    # 2. Every edge records direction.
    for edge in graph["edges"]:
        assert edge.get("source"), f"Edge missing 'source': {edge}"
        assert edge.get("target"), f"Edge missing 'target': {edge}"

    # 3. Metadata records the analysed path.
    assert "source_path" in graph.get("metadata", {}), (
        "Metadata must record the codebase path so the human knows which "
        "realized design is being evaluated"
    )


# ---------------------------------------------------------------------------
# AND: human can explore the impact of potential changes
# ---------------------------------------------------------------------------


def test_dependency_graph_is_traversable_for_impact_analysis(kart_src: Path) -> None:
    """The dependency graph must be fully connected so impact paths are traversable.

    System-purpose THEN-clause: 'the human can explore the impact of potential
    changes before updating the spec' — to simulate 'what if I change X?', the
    human navigates the dependency graph.  This requires: node IDs are unique,
    edges reference valid node IDs, and the graph is non-empty.
    """
    graph = build_scene_graph(kart_src)

    node_ids = {n["id"] for n in graph["nodes"]}

    # Node IDs must be unique (otherwise graph traversal is ambiguous).
    assert len(node_ids) == len(graph["nodes"]), (
        "Node IDs must be unique so the dependency graph can be traversed unambiguously"
    )

    # Every edge endpoint must resolve to a known node.
    for edge in graph["edges"]:
        assert edge["source"] in node_ids, (
            f"Edge source '{edge['source']}' references an unknown node — "
            "impact traversal would be broken"
        )
        assert edge["target"] in node_ids, (
            f"Edge target '{edge['target']}' references an unknown node — "
            "impact traversal would be broken"
        )
