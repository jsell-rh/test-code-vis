"""Tests for the core extraction logic.

Validates that the extractor discovers modules, computes metrics,
extracts dependencies, and builds valid scene graphs as described in
specs/extraction/code-extraction.spec.md.

Tests use temporary directories instead of the live kartograph codebase
so they remain hermetic and fast.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

import math

from extractor.extractor import (
    _order_by_coupling,
    build_dependency_edges,
    build_scene_graph,
    classify_edge_type,
    compute_layout,
    compute_loc,
    discover_bounded_contexts,
    discover_submodules,
    extract_imports_from_file,
    get_target_node_id,
    is_bounded_context,
    is_internal_module,
    is_python_package,
    size_from_loc,
)
from extractor.schema import Node


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def src(tmp_path: Path) -> Path:
    """Return a minimal kartograph-like source tree in a temp directory."""
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
    (sk).mkdir()
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

    # Non-context package (should be excluded)
    tests = tmp_path / "tests"
    tests.mkdir()
    (tests / "__init__.py").write_text("")

    return tmp_path


# ---------------------------------------------------------------------------
# Requirement: Filesystem predicates
# ---------------------------------------------------------------------------


class TestFilesystemPredicates:
    def test_is_python_package_true(self, tmp_path: Path) -> None:
        (tmp_path / "__init__.py").write_text("")
        assert is_python_package(tmp_path)

    def test_is_python_package_false_no_init(self, tmp_path: Path) -> None:
        subdir = tmp_path / "notapkg"
        subdir.mkdir()
        assert not is_python_package(subdir)

    def test_is_python_package_false_not_dir(self, tmp_path: Path) -> None:
        f = tmp_path / "file.py"
        f.write_text("")
        assert not is_python_package(f)

    def test_is_bounded_context_true(self, tmp_path: Path) -> None:
        pkg = tmp_path / "iam"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        assert is_bounded_context(pkg)

    def test_is_bounded_context_excludes_tests(self, tmp_path: Path) -> None:
        pkg = tmp_path / "tests"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        assert not is_bounded_context(pkg)

    def test_is_bounded_context_excludes_underscored(self, tmp_path: Path) -> None:
        pkg = tmp_path / "__pycache__"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        assert not is_bounded_context(pkg)

    def test_is_internal_module_true(self, tmp_path: Path) -> None:
        pkg = tmp_path / "domain"
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")
        assert is_internal_module(pkg)


# ---------------------------------------------------------------------------
# Requirement: Complexity Metrics
# ---------------------------------------------------------------------------


class TestComplexityMetrics:
    def test_compute_loc_counts_python_lines(self, tmp_path: Path) -> None:
        (tmp_path / "a.py").write_text("x = 1\ny = 2\n")
        (tmp_path / "b.py").write_text("z = 3\n")
        assert compute_loc(tmp_path) == 3

    def test_compute_loc_recursive(self, tmp_path: Path) -> None:
        sub = tmp_path / "sub"
        sub.mkdir()
        (sub / "c.py").write_text("a = 1\nb = 2\nc = 3\n")
        (tmp_path / "d.py").write_text("d = 4\n")
        assert compute_loc(tmp_path) == 4

    def test_compute_loc_empty_dir(self, tmp_path: Path) -> None:
        assert compute_loc(tmp_path) == 0

    def test_size_from_loc_minimum(self) -> None:
        assert size_from_loc(0) == 0.5

    def test_size_from_loc_grows_with_loc(self) -> None:
        assert size_from_loc(1000) > size_from_loc(100)

    def test_size_from_loc_is_float(self) -> None:
        assert isinstance(size_from_loc(500), float)


# ---------------------------------------------------------------------------
# Requirement: Import extraction
# ---------------------------------------------------------------------------


class TestImportExtraction:
    def test_extract_absolute_import(self, tmp_path: Path) -> None:
        f = tmp_path / "mod.py"
        f.write_text("import shared_kernel\n")
        assert "shared_kernel" in extract_imports_from_file(f)

    def test_extract_from_import(self, tmp_path: Path) -> None:
        f = tmp_path / "mod.py"
        f.write_text("from graph.domain.models import Node\n")
        assert "graph.domain.models" in extract_imports_from_file(f)

    def test_relative_imports_excluded(self, tmp_path: Path) -> None:
        f = tmp_path / "mod.py"
        f.write_text("from . import sibling\n")
        assert "sibling" not in extract_imports_from_file(f)

    def test_syntax_error_returns_empty(self, tmp_path: Path) -> None:
        f = tmp_path / "bad.py"
        f.write_text("def broken(:\n")
        assert extract_imports_from_file(f) == []

    def test_get_target_node_id_exact_match(self) -> None:
        ids = {"iam", "iam.domain", "iam.application"}
        assert get_target_node_id("iam.domain", ids) == "iam.domain"

    def test_get_target_node_id_sub_module(self) -> None:
        ids = {"iam", "iam.domain", "iam.application"}
        assert get_target_node_id("iam.domain.models", ids) == "iam.domain"

    def test_get_target_node_id_bc_level(self) -> None:
        ids = {"iam", "iam.domain"}
        assert get_target_node_id("iam.nonexistent.deep", ids) == "iam"

    def test_get_target_node_id_unknown(self) -> None:
        ids = {"iam", "graph"}
        assert get_target_node_id("requests.utils", ids) is None


# ---------------------------------------------------------------------------
# Requirement: Edge classification
# ---------------------------------------------------------------------------


class TestEdgeClassification:
    def test_classify_cross_context(self) -> None:
        assert classify_edge_type("graph", "shared_kernel") == "cross_context"

    def test_classify_internal(self) -> None:
        assert classify_edge_type("iam", "iam") == "internal"


# ---------------------------------------------------------------------------
# Requirement: Module Discovery
# ---------------------------------------------------------------------------


class TestModuleDiscovery:
    def test_discovers_bounded_contexts(self, src: Path) -> None:
        nodes = discover_bounded_contexts(src)
        ids = {n["id"] for n in nodes}
        assert "iam" in ids
        assert "graph" in ids
        assert "shared_kernel" in ids

    def test_excludes_tests_directory(self, src: Path) -> None:
        nodes = discover_bounded_contexts(src)
        ids = {n["id"] for n in nodes}
        assert "tests" not in ids

    def test_bounded_context_node_has_required_keys(self, src: Path) -> None:
        nodes = discover_bounded_contexts(src)
        assert nodes, "Should discover at least one bounded context"
        node = nodes[0]
        for key in ("id", "name", "type", "position", "size", "parent"):
            assert key in node, f"Missing key: {key}"

    def test_bounded_context_type(self, src: Path) -> None:
        nodes = discover_bounded_contexts(src)
        for n in nodes:
            assert n["type"] == "bounded_context"

    def test_bounded_context_parent_is_none(self, src: Path) -> None:
        nodes = discover_bounded_contexts(src)
        for n in nodes:
            assert n["parent"] is None

    def test_bounded_context_has_metrics_loc(self, src: Path) -> None:
        nodes = discover_bounded_contexts(src)
        for n in nodes:
            assert "metrics" in n
            assert "loc" in n["metrics"]
            assert isinstance(n["metrics"]["loc"], int)

    def test_discovers_submodules_in_iam(self, src: Path) -> None:
        nodes = discover_submodules(src, "iam")
        ids = {n["id"] for n in nodes}
        assert "iam.domain" in ids
        assert "iam.application" in ids

    def test_submodule_parent_references_bc(self, src: Path) -> None:
        nodes = discover_submodules(src, "iam")
        for n in nodes:
            assert n["parent"] == "iam"

    def test_submodule_type_is_module(self, src: Path) -> None:
        nodes = discover_submodules(src, "iam")
        for n in nodes:
            assert n["type"] == "module"

    def test_submodule_id_is_dotted(self, src: Path) -> None:
        nodes = discover_submodules(src, "iam")
        for n in nodes:
            assert "." in n["id"]

    def test_submodule_has_metrics_loc(self, src: Path) -> None:
        nodes = discover_submodules(src, "iam")
        for n in nodes:
            assert "metrics" in n
            assert isinstance(n["metrics"]["loc"], int)


# ---------------------------------------------------------------------------
# Requirement: Dependency Extraction
# ---------------------------------------------------------------------------


class TestDependencyExtraction:
    def test_cross_context_edge_created(self, src: Path) -> None:
        """graph (or iam) should import from shared_kernel."""
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        edge_pairs = {(e["source"], e["target"]) for e in edges}
        # iam.domain imports from shared_kernel → cross-context edge iam→shared_kernel
        assert ("iam", "shared_kernel") in edge_pairs

    def test_cross_context_edge_type(self, src: Path) -> None:
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        for e in edges:
            if e["source"] == "iam" and e["target"] == "shared_kernel":
                assert e["type"] == "cross_context"
                break
        else:
            pytest.fail("Expected iam→shared_kernel cross_context edge not found")

    def test_internal_edge_created(self, src: Path) -> None:
        """iam.application should import from iam.domain."""
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        edge_pairs = {(e["source"], e["target"]) for e in edges}
        assert ("iam.application", "iam.domain") in edge_pairs

    def test_internal_edge_type(self, src: Path) -> None:
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        for e in edges:
            if e["source"] == "iam.application" and e["target"] == "iam.domain":
                assert e["type"] == "internal"
                break
        else:
            pytest.fail("Expected iam.application→iam.domain internal edge not found")

    def test_no_self_edges(self, src: Path) -> None:
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        for e in edges:
            assert e["source"] != e["target"], f"Self-edge detected: {e}"

    def test_edges_have_required_keys(self, src: Path) -> None:
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        for e in edges:
            for key in ("source", "target", "type"):
                assert key in e, f"Edge missing key '{key}': {e}"


# ---------------------------------------------------------------------------
# Requirement: Layout
# ---------------------------------------------------------------------------


@pytest.fixture()
def src_coupling(tmp_path: Path) -> Path:
    """A source tree with 4 bounded contexts where auth↔shared_kernel are
    coupled and billing↔reporting are coupled, for layout ordering tests."""
    for bc in ["auth", "billing", "reporting", "shared_kernel"]:
        pkg = tmp_path / bc
        pkg.mkdir()
        (pkg / "__init__.py").write_text("")

    # auth imports from shared_kernel (coupling: auth → shared_kernel)
    (tmp_path / "auth" / "service.py").write_text(
        "from shared_kernel.token import Token\n"
    )
    # billing imports from reporting (coupling: billing → reporting)
    (tmp_path / "billing" / "invoice.py").write_text(
        "from reporting.summary import Report\n"
    )
    return tmp_path


class TestLayout:
    def test_all_nodes_have_positions_after_layout(self, src: Path) -> None:
        nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src, bc["id"]))

        compute_layout(nodes)
        for n in nodes:
            pos = n["position"]
            assert "x" in pos and "y" in pos and "z" in pos

    def test_bounded_contexts_have_distinct_positions(self, src: Path) -> None:
        nodes = discover_bounded_contexts(src)
        compute_layout(nodes)
        positions = [(n["position"]["x"], n["position"]["z"]) for n in nodes]
        assert len(set(positions)) == len(positions), "BC positions should be distinct"

    def test_child_nodes_are_near_parent_position(self, src: Path) -> None:
        """Spec: child node positions are stored as LOCAL offsets.

        After compute_layout, every module node's position is a LOCAL offset
        relative to its parent BC (i.e. the magnitude of child["position"] is
        ≤ bc_radius * 0.4, the mod_radius cap). Godot's main.gd adds the parent
        world position at render time — so we verify the stored value is small.
        """
        nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src, bc["id"]))

        compute_layout(nodes)

        bc_count = sum(1 for n in nodes if n["type"] == "bounded_context")
        bc_radius = min(max(5.0, bc_count * 2.5), 80.0)
        max_local_offset = bc_radius * 0.4  # mod_radius cap

        for n in nodes:
            if n["parent"] is None:
                continue
            cx = n["position"]["x"]
            cy = n["position"]["y"]
            cz = n["position"]["z"]
            local_dist = math.sqrt(cx**2 + cy**2 + cz**2)
            assert local_dist <= max_local_offset, (
                f"Child {n['id']} local offset magnitude {local_dist:.2f} exceeds "
                f"max_offset {max_local_offset:.2f}. "
                "Child position must be a LOCAL offset (not an absolute world coordinate)."
            )

    def test_child_position_is_local_offset(self, tmp_path: Path) -> None:
        """Spec: child position must equal the local circular offset, not parent + offset.

        This test places the parent BC at a NON-ZERO world position and asserts
        the child's stored position equals the local orbit offset directly.
        If the extractor stored absolute coordinates, the child x would be
        parent_x + local_offset_x (≈ 6.5), not just local_offset_x (1.5).
        """
        # 1 bounded context, 1 child module.
        bc_dir = tmp_path / "payments"
        bc_dir.mkdir()
        (bc_dir / "__init__.py").write_text("")
        mod_dir = bc_dir / "invoicing"
        mod_dir.mkdir()
        (mod_dir / "__init__.py").write_text("")

        nodes: list[Node] = discover_bounded_contexts(tmp_path)
        for bc in list(nodes):
            nodes.extend(discover_submodules(tmp_path, bc["id"]))
        compute_layout(nodes)

        bc_node = next(n for n in nodes if n["type"] == "bounded_context")
        child_node = next(n for n in nodes if n["type"] == "module")

        # With 1 BC: bc_radius = min(max(5.0, 1*2.5), 80.0) = 5.0; angle=0 → x=5.0
        parent_x: float = bc_node["position"]["x"]
        assert parent_x != 0.0, "Parent BC must be at a non-zero position"

        # With 1 child: mod_radius = min(max(1.5, 1*0.9), 5.0*0.4) = 1.5; angle=0 → x=1.5
        expected_local_x: float = min(max(1.5, 1 * 0.9), 5.0 * 0.4) * math.cos(0.0)
        assert child_node["position"]["x"] == pytest.approx(expected_local_x), (
            f"Child position x must be the local offset {expected_local_x:.4f}, "
            f"not the absolute coordinate (parent_x + offset = "
            f"{parent_x + expected_local_x:.4f})"
        )
        # Confirm it is NOT stored as absolute world coordinate.
        assert child_node["position"]["x"] != pytest.approx(parent_x + expected_local_x)

    def test_coupled_bcs_are_closer_than_uncoupled(self, src_coupling: Path) -> None:
        """Spec: tightly coupled nodes have smaller distances between them.

        With 4 BCs where auth↔shared_kernel are coupled and billing is
        uncoupled to auth, the layout must place auth and shared_kernel
        adjacent in the ring (closer than auth to billing).
        """
        nodes = discover_bounded_contexts(src_coupling)
        edges = build_dependency_edges(src_coupling, nodes)
        compute_layout(nodes, edges)

        node_pos = {
            n["id"]: (n["position"]["x"], n["position"]["y"], n["position"]["z"])
            for n in nodes
        }

        def dist(a: str, b: str) -> float:
            ax, ay, az = node_pos[a]
            bx, by, bz = node_pos[b]
            return math.sqrt((ax - bx) ** 2 + (ay - by) ** 2 + (az - bz) ** 2)

        # auth→shared_kernel are coupled; billing is not coupled to auth.
        # The coupled pair must be at most as close as any uncoupled pair
        # (greedy ordering puts coupled nodes adjacent in the ring).
        assert dist("auth", "shared_kernel") < dist("auth", "billing"), (
            "Coupled pair auth↔shared_kernel should be closer than uncoupled "
            "pair auth↔billing."
        )

    def test_order_by_coupling_places_coupled_adjacent(self) -> None:
        """Unit test for _order_by_coupling: coupled BCs end up next to each other."""
        from extractor.schema import Edge

        bc_a: Node = {
            "id": "a",
            "name": "A",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.0,
            "parent": None,
        }
        bc_b: Node = {
            "id": "b",
            "name": "B",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.0,
            "parent": None,
        }
        bc_c: Node = {
            "id": "c",
            "name": "C",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.0,
            "parent": None,
        }
        bc_d: Node = {
            "id": "d",
            "name": "D",
            "type": "bounded_context",
            "position": {"x": 0.0, "y": 0.0, "z": 0.0},
            "size": 1.0,
            "parent": None,
        }
        edges: list[Edge] = [
            {"source": "a", "target": "b", "type": "cross_context"},
        ]
        ordered = _order_by_coupling([bc_a, bc_b, bc_c, bc_d], edges)
        ids = [n["id"] for n in ordered]
        # 'a' starts first; 'b' (coupled to a) must immediately follow
        assert ids[0] == "a"
        assert ids[1] == "b", (
            f"Coupled BC 'b' should be adjacent to 'a' in the circle ordering, "
            f"got {ids}"
        )


# ---------------------------------------------------------------------------
# Requirement: JSON Scene Graph Output
# ---------------------------------------------------------------------------


class TestSceneGraphOutput:
    def test_build_scene_graph_has_required_keys(self, src: Path) -> None:
        graph = build_scene_graph(src)
        assert "nodes" in graph
        assert "edges" in graph
        assert "metadata" in graph

    def test_nodes_include_bounded_contexts(self, src: Path) -> None:
        graph = build_scene_graph(src)
        ids = {n["id"] for n in graph["nodes"]}
        assert "iam" in ids
        assert "graph" in ids
        assert "shared_kernel" in ids

    def test_nodes_include_internal_modules(self, src: Path) -> None:
        graph = build_scene_graph(src)
        ids = {n["id"] for n in graph["nodes"]}
        assert "iam.domain" in ids
        assert "iam.application" in ids

    def test_edges_non_empty(self, src: Path) -> None:
        graph = build_scene_graph(src)
        assert len(graph["edges"]) > 0

    def test_metadata_has_source_path(self, src: Path) -> None:
        graph = build_scene_graph(src)
        assert "source_path" in graph["metadata"]
        assert str(src) in graph["metadata"]["source_path"]

    def test_metadata_has_timestamp(self, src: Path) -> None:
        graph = build_scene_graph(src)
        ts = graph["metadata"]["timestamp"]
        assert isinstance(ts, str)
        assert "T" in ts  # ISO-8601 format

    def test_output_is_json_serialisable(self, src: Path) -> None:
        graph = build_scene_graph(src)
        serialised = json.dumps(graph)
        restored = json.loads(serialised)
        assert len(restored["nodes"]) == len(graph["nodes"])

    def test_node_ids_are_unique(self, src: Path) -> None:
        graph = build_scene_graph(src)
        ids = [n["id"] for n in graph["nodes"]]
        assert len(ids) == len(set(ids))

    def test_every_node_has_position(self, src: Path) -> None:
        graph = build_scene_graph(src)
        for n in graph["nodes"]:
            pos = n["position"]
            assert "x" in pos and "y" in pos and "z" in pos
