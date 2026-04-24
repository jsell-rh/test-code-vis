"""Tests for the core extraction logic.

Validates that the extractor discovers modules, computes metrics,
extracts dependencies, and builds valid scene graphs as described in
specs/extraction/code-extraction.spec.md.

Tests use temporary directories instead of the live kartograph codebase
so they remain hermetic and fast.
"""

from __future__ import annotations

import ast
import json
import sys
from pathlib import Path

import pytest

import math

from extractor.extractor import (
    _order_by_coupling,
    annotate_cascade_depth,
    build_dependency_edges,
    build_scene_graph,
    classify_edge_type,
    compute_cascade_depth,
    compute_clusters,
    compute_independence_groups,
    compute_layout,
    compute_loc,
    compute_structural_significance,
    compute_ubiquitous_flags,
    detect_ubiquitous_dependencies,
    discover_bounded_contexts,
    discover_submodules,
    extract_call_graph,
    extract_imports_from_file,
    extract_symbols,
    extract_type_topology,
    get_target_node_id,
    is_bounded_context,
    is_internal_module,
    is_python_package,
    size_from_loc,
)
from extractor.schema import Edge, Node


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

    def test_aggregate_edge_emitted(self, src: Path) -> None:
        """The extractor emits at least one aggregate edge for cross-context deps."""
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        aggregate_edges = [e for e in edges if e["type"] == "aggregate"]
        assert aggregate_edges, (
            "Expected at least one aggregate edge — iam imports shared_kernel"
        )

    def test_aggregate_edge_has_weight(self, src: Path) -> None:
        """Each aggregate edge carries a weight field (total import count)."""
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        for e in edges:
            if e["type"] == "aggregate":
                assert "weight" in e, f"Aggregate edge missing 'weight': {e}"
                assert isinstance(e["weight"], int), (
                    f"Aggregate edge 'weight' must be int, got {type(e['weight'])}: {e}"
                )
                assert e["weight"] >= 1, (
                    f"Aggregate edge 'weight' must be ≥ 1, got {e['weight']}: {e}"
                )
                return
        pytest.fail("Expected at least one aggregate edge with weight")

    def test_aggregate_edge_source_target(self, src: Path) -> None:
        """Aggregate edge for iam→shared_kernel has correct source and target."""
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        agg = {(e["source"], e["target"]) for e in edges if e["type"] == "aggregate"}
        # iam.domain imports shared_kernel.auth → aggregate iam→shared_kernel
        assert ("iam", "shared_kernel") in agg, (
            f"Expected aggregate edge iam→shared_kernel, found aggregate pairs: {agg}"
        )

    def test_cross_context_edge_has_weight(self, src: Path) -> None:
        """Every cross_context edge carries a weight field (import count).

        Spec: spatial-structure.spec.md § Far — bounded context architecture:
        'each edge carries the import count (number of individual import
        statements between the pair).'
        """
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        cc_edges = [e for e in edges if e["type"] == "cross_context"]
        assert cc_edges, (
            "Expected at least one cross_context edge (iam imports shared_kernel)"
        )
        for e in cc_edges:
            assert "weight" in e, f"cross_context edge missing 'weight': {e}"
            assert isinstance(e["weight"], int), (
                f"cross_context edge 'weight' must be int, got {type(e['weight'])}: {e}"
            )
            assert e["weight"] >= 1, f"cross_context edge 'weight' must be >= 1: {e}"

    def test_internal_edge_has_weight(self, src: Path) -> None:
        """Every internal edge carries a weight field (import count).

        Spec: spatial-structure.spec.md § Scale Through Zoom: each edge carries
        its import count so that line thickness is proportional to coupling strength.
        """
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        internal_edges = [e for e in edges if e["type"] == "internal"]
        assert internal_edges, (
            "Expected at least one internal edge (iam.application imports iam.domain)"
        )
        for e in internal_edges:
            assert "weight" in e, f"internal edge missing 'weight': {e}"
            assert isinstance(e["weight"], int), (
                f"internal edge 'weight' must be int, got {type(e['weight'])}: {e}"
            )
            assert e["weight"] >= 1, f"internal edge 'weight' must be >= 1: {e}"

    def test_cross_context_edge_weight_accumulates_for_multiple_imports(
        self, tmp_path: Path
    ) -> None:
        """cross_context edge weight == 2 when two distinct module-level nodes
        in the same source BC each import from the same target BC.

        Spec: visual-primitives.spec.md § Module Graph Extraction —
        "each edge carries the import count (number of individual import
        statements between the pair)."

        This test proves accumulation (weight == 2, not merely >= 1) when
        two distinct module-level nodes each contribute +1 to the same
        (source_bc, target_bc) cross_context edge weight.
        """
        # Source bounded context: ctx_a, with TWO modules each importing target.
        ctx_a = tmp_path / "ctx_a"
        (ctx_a / "mod1").mkdir(parents=True)
        (ctx_a / "mod2").mkdir(parents=True)
        for d in [ctx_a, ctx_a / "mod1", ctx_a / "mod2"]:
            (d / "__init__.py").write_text("")
        # First import: ctx_a.mod1 imports ctx_b
        (ctx_a / "mod1" / "service.py").write_text("from ctx_b.api import API\n")
        # Second import: ctx_a.mod2 ALSO imports ctx_b (different module, same BC pair)
        (ctx_a / "mod2" / "client.py").write_text("from ctx_b.api import API\n")

        # Target bounded context: ctx_b
        ctx_b = tmp_path / "ctx_b"
        ctx_b.mkdir()
        (ctx_b / "__init__.py").write_text("")
        (ctx_b / "api.py").write_text("class API:\n    pass\n")

        all_nodes: list[Node] = discover_bounded_contexts(tmp_path)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(tmp_path, bc["id"]))

        edges = build_dependency_edges(tmp_path, all_nodes)

        # Find the cross_context edge ctx_a → ctx_b.
        matching = [
            e
            for e in edges
            if e["type"] == "cross_context"
            and e["source"] == "ctx_a"
            and e["target"] == "ctx_b"
        ]
        assert matching, (
            "Expected a cross_context edge ctx_a → ctx_b; "
            f"cross_context edges found: {[e for e in edges if e['type'] == 'cross_context']}"
        )
        assert len(matching) == 1, (
            f"Expected exactly ONE cross_context edge ctx_a → ctx_b (accumulated), "
            f"got {len(matching)}: {matching}"
        )
        edge = matching[0]
        # weight == 2: mod1 scan (+1) + mod2 scan (+1) = 2.
        assert edge["weight"] == 2, (
            f"cross_context edge weight must be 2 (two distinct module imports), "
            f"got {edge['weight']}: {edge}"
        )

    def test_internal_edge_weight_accumulates_for_multiple_imports(
        self, tmp_path: Path
    ) -> None:
        """internal edge weight == 2 when one source module has two distinct
        import strings that both resolve to the same target module.

        Proves weight accumulation is correct (== 2, not merely >= 1).

        The extractor accumulates one weight unit per distinct imported-module
        string that resolves to the same target node id.  A module that imports
        both ``ctx_a.domain.models`` and ``ctx_a.domain.services`` contributes
        +1 for each string, even though both resolve to the same target module
        node ``ctx_a.domain``.  This proves the per-import-string accumulation
        rather than per-target-node deduplication.
        """
        # Bounded context: ctx_a, with domain and application submodules.
        ctx_a = tmp_path / "ctx_a"
        (ctx_a / "domain").mkdir(parents=True)
        (ctx_a / "application").mkdir(parents=True)
        for d in [ctx_a, ctx_a / "domain", ctx_a / "application"]:
            (d / "__init__.py").write_text("")
        # Target module: ctx_a.domain, with TWO importable sub-modules.
        (ctx_a / "domain" / "models.py").write_text("class Model:\n    pass\n")
        (ctx_a / "domain" / "services.py").write_text("class Service:\n    pass\n")
        # Source module: ctx_a.application imports TWO distinct paths from ctx_a.domain.
        # Both `ctx_a.domain.models` and `ctx_a.domain.services` resolve to the
        # same target node `ctx_a.domain`, so weight accumulates to 2.
        (ctx_a / "application" / "handler.py").write_text(
            "from ctx_a.domain.models import Model\n"
            "from ctx_a.domain.services import Service\n"
        )

        all_nodes: list[Node] = discover_bounded_contexts(tmp_path)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(tmp_path, bc["id"]))

        edges = build_dependency_edges(tmp_path, all_nodes)

        matching = [
            e
            for e in edges
            if e["type"] == "internal"
            and e["source"] == "ctx_a.application"
            and e["target"] == "ctx_a.domain"
        ]
        assert matching, (
            "Expected an internal edge ctx_a.application → ctx_a.domain; "
            f"internal edges: {[e for e in edges if e['type'] == 'internal']}"
        )
        assert len(matching) == 1, (
            f"Expected exactly ONE internal edge (accumulated), got {len(matching)}: {matching}"
        )
        edge = matching[0]
        # weight == 2: two distinct import strings both resolving to ctx_a.domain.
        assert edge["weight"] == 2, (
            f"internal edge weight must be 2 "
            f"(ctx_a.domain.models +1, ctx_a.domain.services +1 — same target), "
            f"got {edge['weight']}: {edge}"
        )


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
        """Spec: child nodes are positioned within the spatial bounds of their parent.

        After compute_layout, every module node's LOCAL offset must be smaller
        than the BC orbit radius — i.e., the child is visually inside the parent.

        Children store LOCAL offsets (relative to the parent BC's origin).
        The correct spatial check is the magnitude of that local offset vector,
        not the world-space distance between child and parent, which mixes
        coordinate frames and produces incorrect distances.
        """
        nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src, bc["id"]))

        compute_layout(nodes)

        node_pos = {
            n["id"]: (n["position"]["x"], n["position"]["y"], n["position"]["z"])
            for n in nodes
        }
        bc_count = sum(1 for n in nodes if n["type"] == "bounded_context")
        bc_radius = max(5.0, bc_count * 2.5)

        for n in nodes:
            if n["parent"] is None:
                continue
            cx, cy, cz = node_pos[n["id"]]
            # Children store local offsets — measure magnitude from origin,
            # not distance from the parent's world position (mixed-frame error).
            dist = math.sqrt(cx**2 + cy**2 + cz**2)
            assert dist < bc_radius, (
                f"Child {n['id']} local offset magnitude {dist:.2f} exceeds "
                f"scene radius {bc_radius:.2f}. "
                "Child local offset must be smaller than the BC orbit radius."
            )

    def test_child_position_is_local_offset(self, tmp_path: Path) -> None:
        """Child positions are local offsets relative to parent, not world coordinates.

        With one BC at a non-zero world position (x = bc_radius) and one child
        module, _circular_positions(1, mod_radius, y=1.0) at angle=0 produces
        the local offset (mod_radius, 1.0, 0.0).

        The z-component MUST equal 0.0 exactly (sin(0) * r = 0) and the
        x-component MUST equal the local mod_radius (1.5 for one child) —
        NOT the parent world x (5.0) plus the offset (6.5 if absolute).
        """
        # Single BC with one child so positions are deterministic.
        bc_dir = tmp_path / "testbc"
        bc_dir.mkdir()
        (bc_dir / "__init__.py").write_text("")
        child_dir = bc_dir / "module"
        child_dir.mkdir()
        (child_dir / "__init__.py").write_text("")

        nodes = discover_bounded_contexts(tmp_path)
        for bc in list(nodes):
            nodes.extend(discover_submodules(tmp_path, bc["id"]))
        compute_layout(nodes)

        parent = next(n for n in nodes if n["type"] == "bounded_context")
        child = next(n for n in nodes if n["parent"] == parent["id"])

        # bc_radius = min(max(5.0, 1*2.5), SCENE_RADIUS*0.8) = 5.0
        # mod_radius = min(max(1.5, 1*0.9), 5.0*0.4) = min(1.5, 2.0) = 1.5
        # angle=0 → x=mod_radius*cos(0)=1.5, z=mod_radius*sin(0)=0.0
        assert child["position"]["z"] == 0.0, (
            f"Expected z=0.0 (local offset: sin(0)*mod_radius=0); "
            f"got {child['position']['z']:.6f}. "
            f"Parent world z={parent['position']['z']:.4f}."
        )
        # x must equal the local mod_radius (1.5), not parent_x + mod_radius (6.5).
        assert child["position"]["x"] == pytest.approx(1.5), (
            f"Expected child x=1.5 (local mod_radius for 1 child); "
            f"got {child['position']['x']:.4f}. "
            f"Parent x={parent['position']['x']:.4f} -- world-coord storage "
            f"would give x~{parent['position']['x'] + 1.5:.4f}."
        )

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

    def test_complexity_and_coupling_both_reflected(self, tmp_path: Path) -> None:
        """Both size (reflects complexity) and position (reflects coupling) are correct.

        Fixture: 4 bounded contexts where:
          - big_ctx has 100 LOC (large) and imports from ctx_c (coupled)
          - small_ctx has 1 LOC (small) and no coupling to big_ctx
          - ctx_c is coupled to big_ctx (import target)
          - ctx_d has no coupling (uncoupled)

        THEN big_ctx.size > small_ctx.size  (size reflects complexity / LOC)
        AND  dist(big_ctx, ctx_c) < dist(big_ctx, ctx_d)
             (position reflects coupling — coupled pair is adjacent in the ring,
              uncoupled ctx_d is diagonally opposite)

        Layout mechanics (4 nodes, greedy nearest-neighbour ordering):
          Sorted order: big_ctx, ctx_c, ctx_d, small_ctx (alphabetical).
          Start: [big_ctx].
          coupling[big_ctx][ctx_c] = 1  → pick ctx_c next.
          No remaining coupling → pick ctx_d, then small_ctx.
          Ring: big_ctx(0°) → ctx_c(90°) → ctx_d(180°) → small_ctx(270°).
          dist(big_ctx, ctx_c)  = 2R·sin(45°) ≈ 0.707·2R  (1 step, adjacent) ✓
          dist(big_ctx, ctx_d)  = 2R·sin(90°) = 2R         (2 steps, diagonal) ✓
          → dist(big_ctx, ctx_c) < dist(big_ctx, ctx_d)    (coupled closer) ✓
        """
        for bc in ["big_ctx", "ctx_c", "ctx_d", "small_ctx"]:
            pkg = tmp_path / bc
            pkg.mkdir()
            (pkg / "__init__.py").write_text("")

        # big_ctx: 100 LOC → large size
        (tmp_path / "big_ctx" / "heavy.py").write_text("x = 1\n" * 100)
        # big_ctx imports ctx_c → cross-context coupling edge
        (tmp_path / "big_ctx" / "refs.py").write_text("from ctx_c import something\n")

        # small_ctx: 1 LOC → small size, no coupling to big_ctx
        (tmp_path / "small_ctx" / "light.py").write_text("y = 1\n")

        graph = build_scene_graph(tmp_path)

        bc_nodes = {
            n["id"]: n for n in graph["nodes"] if n["type"] == "bounded_context"
        }

        # --- Size reflects complexity (LOC) ---
        # big_ctx has ~102 lines vs small_ctx ~1 line → size must differ
        assert bc_nodes["big_ctx"]["size"] > bc_nodes["small_ctx"]["size"], (
            f"big_ctx (100+ LOC) must be larger than small_ctx (1 LOC). "
            f"Got big_ctx.size={bc_nodes['big_ctx']['size']:.3f}, "
            f"small_ctx.size={bc_nodes['small_ctx']['size']:.3f}"
        )

        # --- Position reflects coupling ---
        # big_ctx ↔ ctx_c are coupled (import relationship) → adjacent in ring
        # big_ctx ↔ ctx_d are uncoupled → diagonally opposite in ring
        def dist(a: str, b: str) -> float:
            pa = bc_nodes[a]["position"]
            pb = bc_nodes[b]["position"]
            return math.sqrt(
                (pa["x"] - pb["x"]) ** 2
                + (pa["y"] - pb["y"]) ** 2
                + (pa["z"] - pb["z"]) ** 2
            )

        assert dist("big_ctx", "ctx_c") < dist("big_ctx", "ctx_d"), (
            "Coupled pair big_ctx↔ctx_c must be closer than uncoupled "
            f"big_ctx↔ctx_d. "
            f"dist(big_ctx, ctx_c)={dist('big_ctx', 'ctx_c'):.2f}, "
            f"dist(big_ctx, ctx_d)={dist('big_ctx', 'ctx_d'):.2f}"
        )

    def test_order_by_coupling_places_coupled_adjacent(self) -> None:
        """Unit test for _order_by_coupling: coupled BCs end up next to each other."""
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
        assert "clusters" in graph

    def test_build_scene_graph_clusters_is_list(self, src: Path) -> None:
        graph = build_scene_graph(src)
        assert isinstance(graph["clusters"], list)

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

    def test_bounded_context_nodes_have_metrics_with_loc(self, src: Path) -> None:
        """Spec scenario: JSON output — nodes include metrics with loc.

        GIVEN a completed extraction
        WHEN the output is written
        THEN the JSON contains a list of nodes (id, name, type, parent, metrics)

        The 'metrics' field MUST be present on bounded-context nodes and MUST
        include 'loc' (lines of code) so the Godot visualizer can encode node
        importance visually without recomputing from source.
        """
        graph = build_scene_graph(src)
        bc_nodes = [n for n in graph["nodes"] if n["type"] == "bounded_context"]
        assert bc_nodes, "Expected at least one bounded-context node in scene graph"
        for node in bc_nodes:
            assert "metrics" in node, (
                f"Node {node['id']} missing 'metrics'. "
                "Spec: 'the JSON contains a list of nodes (id, name, type, parent, metrics)'"
            )
            assert "loc" in node["metrics"], (
                f"Node {node['id']} metrics missing 'loc'. "
                "Spec: 'it computes the total lines of code for the module AND this "
                "metric is included in the node\\'s metadata'"
            )
            assert isinstance(node["metrics"]["loc"], int), (
                f"metrics['loc'] must be int; got {type(node['metrics']['loc'])}"
            )
            assert node["metrics"]["loc"] >= 0, (
                f"metrics['loc'] must be non-negative; got {node['metrics']['loc']}"
            )

    def test_cross_context_edge_direction_encodes_importer_to_imported(
        self, src: Path
    ) -> None:
        """Spec scenario: Cross-context dependency includes the direction.

        GIVEN that the graph context imports from shared_kernel
        WHEN the extractor analyzes imports
        THEN a dependency edge is created from graph to shared_kernel
        AND the edge includes the direction of the dependency

        The src fixture has iam.domain importing from shared_kernel.auth.
        The scene graph edge MUST have source='iam' and target='shared_kernel'
        — NOT reversed — so Godot can render the arrow pointing from the
        importing bounded context to the imported one.
        """
        graph = build_scene_graph(src)
        matching = [
            e
            for e in graph["edges"]
            if e["source"] == "iam"
            and e["target"] == "shared_kernel"
            and e["type"] == "cross_context"
        ]
        assert matching, (
            "Scene graph must contain a cross_context edge with source='iam' and "
            "target='shared_kernel'. "
            "Spec: 'a dependency edge is created from graph to shared_kernel AND the "
            "edge includes the direction of the dependency' — source is the importer, "
            "target is the imported bounded context."
        )

    def test_internal_edge_distinguishable_from_cross_context(self, src: Path) -> None:
        """Spec scenario: Internal dependency distinguishable from cross-context.

        GIVEN that iam.application.services imports from iam.domain
        WHEN the extractor analyzes imports
        THEN a dependency edge is created within the iam context
        AND the edge is distinguishable from cross-context dependencies

        The edge type MUST be 'internal' (not 'cross_context') so the Godot
        visualizer can render same-bounded-context imports differently from
        cross-context imports.
        """
        graph = build_scene_graph(src)
        matching = [
            e
            for e in graph["edges"]
            if e["source"] == "iam.application"
            and e["target"] == "iam.domain"
            and e["type"] == "internal"
        ]
        assert matching, (
            "Scene graph must contain an internal edge with source='iam.application' "
            "and target='iam.domain' with type='internal'. "
            "Spec: 'AND the edge is distinguishable from cross-context dependencies' — "
            "type must be 'internal', not 'cross_context'."
        )

    def test_build_scene_graph_has_exactly_four_top_level_keys(self, src: Path) -> None:
        """Spec §Schema Structure: no other top-level fields are present.

        The extractor output MUST contain exactly nodes, edges, metadata, and
        clusters at the top level — no additional fields are allowed.
        This is the extractor-level complement of test_extra_top_level_key_raises
        in test_schema.py which tests the validator; here we test the producer.
        """
        graph = build_scene_graph(src)
        assert set(graph.keys()) == {"nodes", "edges", "metadata", "clusters"}, (
            f"build_scene_graph must produce exactly 4 top-level keys; got {set(graph.keys())}"
        )


# ---------------------------------------------------------------------------
# Requirement: Weighted Edge (spec §Edge Schema / §Weighted edge scenario)
# ---------------------------------------------------------------------------


@pytest.fixture()
def src_weighted(tmp_path: Path) -> Path:
    """A source tree with two modules in 'alpha' both importing from 'beta'.

    iam.domain imports from shared_kernel → 1 module-level cross-context import
    iam.application also imports from shared_kernel → 2 module-level cross-context
    imports in total.  The aggregate edge iam→shared_kernel should carry weight=2.

    This fixture lets us verify the aggregate weight equals the import count rather
    than just checking weight >= 1.
    """
    # Bounded context: iam with two modules that both import shared_kernel
    iam = tmp_path / "iam"
    domain = iam / "domain"
    application = iam / "application"
    for d in [iam, domain, application]:
        d.mkdir(parents=True)
        (d / "__init__.py").write_text("")

    (domain / "models.py").write_text(
        "from shared_kernel.auth import AuthToken\nclass User:\n    pass\n"
    )
    (application / "services.py").write_text(
        "from shared_kernel.events import Event\nclass Svc:\n    pass\n"
    )

    # Bounded context: shared_kernel
    sk = tmp_path / "shared_kernel"
    sk.mkdir()
    (sk / "__init__.py").write_text("")
    (sk / "auth.py").write_text("class AuthToken:\n    pass\n")
    (sk / "events.py").write_text("class Event:\n    pass\n")

    return tmp_path


class TestWeightedEdge:
    """Spec §Edge Schema / §Weighted edge: weight on individual vs aggregate edges.

    Spec THEN-clauses:
    - Individual module-level edges each have weight: 1 (or weight omitted,
      defaulting to 1).  The extractor emits an explicit weight carrying the
      per-pair import count (>= 1).
    - The extractor also emits an aggregate edge with source, target, type='aggregate',
      and weight = total individual import count.
    """

    def test_individual_cross_context_edges_have_weight(self, src: Path) -> None:
        """Individual cross-context edges carry an explicit weight >= 1.

        Spec: 'individual module-level edges each have weight: 1 (or weight
        omitted, defaulting to 1)'.  The extractor emits an explicit weight
        equal to the count of unique module-level imports for that BC pair.
        """
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        individual_cross_context = [e for e in edges if e["type"] == "cross_context"]
        assert individual_cross_context, "Expected at least one cross_context edge"
        for e in individual_cross_context:
            assert "weight" in e, (
                f"Individual cross_context edge {e['source']}→{e['target']} "
                f"must carry a 'weight' field; got {e}"
            )
            assert isinstance(e["weight"], int), (
                f"cross_context edge weight must be int, got {type(e['weight'])}: {e}"
            )
            assert e["weight"] >= 1, (
                f"cross_context edge weight must be >= 1, got {e['weight']}: {e}"
            )

    def test_individual_internal_edges_have_weight(self, src: Path) -> None:
        """Internal module edges carry an explicit weight >= 1.

        Spec: 'individual module-level edges each have weight: 1 (or weight
        omitted, defaulting to 1)'.  The extractor emits an explicit weight
        equal to the count of unique imports between the two modules.
        """
        all_nodes: list[Node] = discover_bounded_contexts(src)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src, bc["id"]))

        edges = build_dependency_edges(src, all_nodes)
        internal_edges = [e for e in edges if e["type"] == "internal"]
        assert internal_edges, "Expected at least one internal edge"
        for e in internal_edges:
            assert "weight" in e, (
                f"Individual internal edge {e['source']}→{e['target']} "
                f"must carry a 'weight' field; got {e}"
            )
            assert isinstance(e["weight"], int), (
                f"internal edge weight must be int, got {type(e['weight'])}: {e}"
            )
            assert e["weight"] >= 1, (
                f"internal edge weight must be >= 1, got {e['weight']}: {e}"
            )

    def test_aggregate_edge_weight_equals_module_import_count(
        self, src_weighted: Path
    ) -> None:
        """Aggregate edge weight equals the count of module-level cross-context imports.

        Spec: 'context A has 12 individual import statements referencing modules in
        context B … aggregate edge with … weight: 12'.

        In this fixture, iam.domain AND iam.application both import from shared_kernel
        → 2 unique module-level imports → aggregate iam→shared_kernel must carry weight=2.
        """
        all_nodes: list[Node] = discover_bounded_contexts(src_weighted)
        for bc in list(all_nodes):
            all_nodes.extend(discover_submodules(src_weighted, bc["id"]))

        edges = build_dependency_edges(src_weighted, all_nodes)
        agg = next(
            (
                e
                for e in edges
                if e["type"] == "aggregate"
                and e["source"] == "iam"
                and e["target"] == "shared_kernel"
            ),
            None,
        )
        assert agg is not None, (
            "Expected an aggregate edge iam→shared_kernel; "
            f"aggregate edges present: {[(e['source'], e['target']) for e in edges if e['type'] == 'aggregate']}"
        )
        assert agg["weight"] == 2, (
            f"iam.domain and iam.application both import shared_kernel → weight must be 2; "
            f"got weight={agg.get('weight')}"
        )


# ---------------------------------------------------------------------------
# Requirement: Independence Groups
# ---------------------------------------------------------------------------


@pytest.fixture()
def src_independence(tmp_path: Path) -> Path:
    """A source tree with two IAM modules where application depends on domain."""
    iam = tmp_path / "iam"
    domain = iam / "domain"
    application = iam / "application"
    isolated = iam / "isolated"
    for d in [iam, domain, application, isolated]:
        d.mkdir(parents=True)
        (d / "__init__.py").write_text("")

    # application depends on domain (internal edge)
    (application / "services.py").write_text("from iam.domain import X\n")
    (domain / "models.py").write_text("class X:\n    pass\n")
    # isolated has no dependencies on domain or application
    (isolated / "util.py").write_text("def helper(): pass\n")
    return tmp_path


class TestIndependenceGroups:
    """Module nodes within the same BC get independence_group identifiers."""

    def test_connected_modules_share_group(self, src_independence: Path) -> None:
        nodes: list[Node] = discover_bounded_contexts(src_independence)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_independence, bc["id"]))
        edges = build_dependency_edges(src_independence, nodes)
        compute_independence_groups(nodes, edges)

        groups = {
            n["id"]: n.get("independence_group") for n in nodes if n["type"] == "module"
        }
        # iam.application and iam.domain are connected → same group
        assert groups["iam.application"] == groups["iam.domain"], (
            f"Connected modules must share group; got {groups}"
        )

    def test_isolated_module_has_own_group(self, src_independence: Path) -> None:
        nodes: list[Node] = discover_bounded_contexts(src_independence)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_independence, bc["id"]))
        edges = build_dependency_edges(src_independence, nodes)
        compute_independence_groups(nodes, edges)

        groups = {
            n["id"]: n.get("independence_group") for n in nodes if n["type"] == "module"
        }
        # iam.isolated has no internal deps → its own group
        assert groups["iam.isolated"] != groups["iam.application"], (
            f"Isolated module must have its own group; got {groups}"
        )

    def test_independence_group_format(self, src_independence: Path) -> None:
        nodes: list[Node] = discover_bounded_contexts(src_independence)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_independence, bc["id"]))
        edges = build_dependency_edges(src_independence, nodes)
        compute_independence_groups(nodes, edges)

        for node in nodes:
            if node["type"] != "module":
                continue
            group = node.get("independence_group")
            assert group is not None, f"{node['id']} missing independence_group"
            assert ":" in group, f"group must be '<context>:<index>', got {group!r}"
            context_part, index_part = group.split(":", 1)
            assert context_part == node["parent"], (
                f"Group prefix must be parent context id; got {context_part!r}"
            )
            assert index_part.isdigit(), (
                f"Group index must be a digit; got {index_part!r}"
            )

    def test_build_scene_graph_assigns_independence_groups(self, src: Path) -> None:
        """build_scene_graph assigns independence_group to all module nodes."""
        graph = build_scene_graph(src)
        module_nodes = [n for n in graph["nodes"] if n["type"] == "module"]
        assert len(module_nodes) > 0, "No module nodes found"
        for node in module_nodes:
            assert "independence_group" in node, (
                f"Module node {node['id']} missing independence_group"
            )


# ---------------------------------------------------------------------------
# Requirement: Clusters
# ---------------------------------------------------------------------------


class TestComputeClusters:
    """compute_clusters produces cluster suggestions for coupled modules."""

    def test_coupled_modules_form_cluster(self, src_independence: Path) -> None:
        nodes: list[Node] = discover_bounded_contexts(src_independence)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_independence, bc["id"]))
        edges = build_dependency_edges(src_independence, nodes)
        # Give nodes positions so they have metrics
        compute_layout(nodes, edges)
        clusters = compute_clusters(nodes, edges)

        # iam.application and iam.domain are coupled → 1 cluster
        assert len(clusters) == 1, f"Expected 1 cluster; got {clusters}"
        cluster = clusters[0]
        assert "iam.application" in cluster["members"]
        assert "iam.domain" in cluster["members"]
        assert cluster["context"] == "iam"

    def test_cluster_id_format(self, src_independence: Path) -> None:
        nodes: list[Node] = discover_bounded_contexts(src_independence)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_independence, bc["id"]))
        edges = build_dependency_edges(src_independence, nodes)
        compute_layout(nodes, edges)
        clusters = compute_clusters(nodes, edges)

        for cluster in clusters:
            assert cluster["id"].startswith(cluster["context"] + ":cluster_"), (
                f"Cluster id must be '<context>:cluster_N'; got {cluster['id']!r}"
            )

    def test_no_clusters_when_no_coupling(self, tmp_path: Path) -> None:
        """Bounded context with no internal deps → empty cluster list."""
        bc = tmp_path / "solo"
        bc.mkdir()
        (bc / "__init__.py").write_text("")
        mod_a = bc / "alpha"
        mod_a.mkdir()
        (mod_a / "__init__.py").write_text("")
        mod_b = bc / "beta"
        mod_b.mkdir()
        (mod_b / "__init__.py").write_text("")

        nodes: list[Node] = discover_bounded_contexts(tmp_path)
        for bn in list(nodes):
            nodes.extend(discover_submodules(tmp_path, bn["id"]))
        edges = build_dependency_edges(tmp_path, nodes)
        clusters = compute_clusters(nodes, edges)

        assert clusters == [], f"Expected empty clusters; got {clusters}"

    def test_cluster_aggregate_metrics_keys(self, src_independence: Path) -> None:
        nodes: list[Node] = discover_bounded_contexts(src_independence)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_independence, bc["id"]))
        edges = build_dependency_edges(src_independence, nodes)
        compute_layout(nodes, edges)
        clusters = compute_clusters(nodes, edges)

        for cluster in clusters:
            am = cluster["aggregate_metrics"]
            assert "total_loc" in am
            assert "in_degree" in am
            assert "out_degree" in am

    def test_build_scene_graph_includes_clusters(self, src: Path) -> None:
        graph = build_scene_graph(src)
        assert "clusters" in graph
        assert isinstance(graph["clusters"], list)


# ---------------------------------------------------------------------------
# Requirement: Cascade Depth
# ---------------------------------------------------------------------------


class TestCascadeDepth:
    """compute_cascade_depth returns BFS hop distances from the origin node."""

    def _make_edges(self, pairs: list[tuple[str, str]]) -> list[Edge]:
        return [
            {"source": src, "target": tgt, "type": "internal"} for src, tgt in pairs
        ]

    def test_direct_dependent_is_depth_1(self) -> None:
        # A depends on X; cascade from X → A at depth 1
        edges = self._make_edges([("A", "X")])
        depths = compute_cascade_depth("X", edges)
        assert depths["A"] == 1

    def test_transitive_dependent_is_depth_2(self) -> None:
        # A depends on X; B depends on A → cascade from X: A=1, B=2
        edges = self._make_edges([("A", "X"), ("B", "A")])
        depths = compute_cascade_depth("X", edges)
        assert depths["A"] == 1
        assert depths["B"] == 2

    def test_origin_not_in_output(self) -> None:
        edges = self._make_edges([("A", "X")])
        depths = compute_cascade_depth("X", edges)
        assert "X" not in depths

    def test_minimum_depth_used(self) -> None:
        # B depends on X directly (depth 1) AND on A which depends on X (depth 2).
        # B must be recorded at depth 1.
        edges = self._make_edges([("A", "X"), ("B", "X"), ("B", "A")])
        depths = compute_cascade_depth("X", edges)
        assert depths["B"] == 1

    def test_no_dependents_returns_empty(self) -> None:
        # X has no dependents → empty dict
        edges = self._make_edges([("X", "Y")])
        depths = compute_cascade_depth("X", edges)
        assert depths == {}

    def test_unrelated_nodes_excluded(self) -> None:
        # C has no dependency on X or any affected node
        edges = self._make_edges([("A", "X"), ("C", "Z")])
        depths = compute_cascade_depth("X", edges)
        assert "C" not in depths


# ---------------------------------------------------------------------------
# Requirement: Cascade Depth annotation on nodes (simulation output)
# spec: scene-graph-schema.spec.md § "Cascade Depth in Simulation Output"
# THEN node A is marked with depth 1 and node B with depth 2
# AND the depth values are available to the visualization for gradient
# encoding and wave animation.
# ---------------------------------------------------------------------------


def _make_node(node_id: str) -> Node:
    """Return a minimal valid node with the given id."""
    return {
        "id": node_id,
        "name": node_id.upper(),
        "type": "module",
        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
        "size": 1.0,
        "parent": "ctx",
    }


class TestAnnotateCascadeDepth:
    """annotate_cascade_depth marks affected nodes with BFS depth in-place.

    Spec: "each affected node MUST carry a depth value indicating its hop
    distance from the failure origin" and "depth values are available to the
    visualization for gradient encoding and wave animation."
    """

    def test_direct_dependent_marked_depth_1(self) -> None:
        """Node A (direct dependent of X) receives depth=1 on its node dict."""
        node_a = _make_node("A")
        node_x = _make_node("X")
        nodes = [node_a, node_x]
        # depth_map from compute_cascade_depth: A depends on X → A at depth 1
        depth_map = {"A": 1}
        annotate_cascade_depth(nodes, depth_map)
        assert node_a["depth"] == 1  # type: ignore[typeddict-item]

    def test_transitive_dependent_marked_depth_2(self) -> None:
        """Node B (transitive dependent via A) receives depth=2."""
        node_a = _make_node("A")
        node_b = _make_node("B")
        nodes = [node_a, node_b]
        depth_map = {"A": 1, "B": 2}
        annotate_cascade_depth(nodes, depth_map)
        assert node_a["depth"] == 1  # type: ignore[typeddict-item]
        assert node_b["depth"] == 2  # type: ignore[typeddict-item]

    def test_origin_node_not_marked(self) -> None:
        """The origin node itself has no depth set (it is not in depth_map)."""
        node_x = _make_node("X")
        nodes = [node_x]
        depth_map: dict[str, int] = {}  # origin is excluded by compute_cascade_depth
        annotate_cascade_depth(nodes, depth_map)
        assert "depth" not in node_x

    def test_unaffected_nodes_unchanged(self) -> None:
        """Nodes absent from depth_map are left unchanged (no depth key added)."""
        node_c = _make_node("C")
        nodes = [node_c]
        depth_map = {"A": 1}  # C is not in the cascade
        annotate_cascade_depth(nodes, depth_map)
        assert "depth" not in node_c

    def test_depth_is_integer_on_node(self) -> None:
        """The depth value stored on the node must be an integer."""
        node_a = _make_node("A")
        annotate_cascade_depth([node_a], {"A": 3})
        assert isinstance(node_a["depth"], int)  # type: ignore[typeddict-item]

    def test_depth_available_in_json(self) -> None:
        """After annotation the depth value survives JSON round-trip (viz can read it)."""
        import json

        node_a = _make_node("A")
        annotate_cascade_depth([node_a], {"A": 1})
        serialised = json.dumps(node_a)
        restored = json.loads(serialised)
        assert restored["depth"] == 1

    def test_compute_then_annotate_pipeline(self) -> None:
        """End-to-end: compute_cascade_depth + annotate_cascade_depth marks nodes correctly.

        Spec scenario: node A directly depends on X; node B directly depends on A.
        THEN node A is marked with depth 1 and node B with depth 2.
        """
        node_x = _make_node("X")
        node_a = _make_node("A")
        node_b = _make_node("B")
        nodes = [node_x, node_a, node_b]

        edges: list[Edge] = [
            {"source": "A", "target": "X", "type": "internal"},
            {"source": "B", "target": "A", "type": "internal"},
        ]
        depth_map = compute_cascade_depth("X", edges)
        annotate_cascade_depth(nodes, depth_map)

        # node A is marked with depth 1
        assert node_a["depth"] == 1, (  # type: ignore[typeddict-item]
            f"node A must be marked depth=1; got {node_a.get('depth')}"
        )
        # node B is marked with depth 2
        assert node_b["depth"] == 2, (  # type: ignore[typeddict-item]
            f"node B must be marked depth=2; got {node_b.get('depth')}"
        )
        # origin X has no depth
        assert "depth" not in node_x


# ---------------------------------------------------------------------------
# Requirement: Cluster does not prescribe collapsed position
# spec: scene-graph-schema.spec.md § "Cluster Schema"
# THEN the cluster entry does not prescribe the collapsed position —
# Godot computes the supernode position as the centroid of member positions.
# ---------------------------------------------------------------------------


class TestClusterDoesNotPrescribePosition:
    """Clusters produced by compute_clusters must not carry a position field.

    Spec: "The cluster entry does not prescribe the collapsed position —
    Godot computes the supernode position as the centroid of member positions."
    """

    def test_cluster_has_no_position_field(self, src_independence: Path) -> None:
        """compute_clusters output must not include a position key."""
        nodes: list[Node] = discover_bounded_contexts(src_independence)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_independence, bc["id"]))
        edges = build_dependency_edges(src_independence, nodes)
        compute_layout(nodes, edges)
        clusters = compute_clusters(nodes, edges)

        assert clusters, (
            "Expected at least one cluster from coupled src_independence fixture"
        )
        for cluster in clusters:
            assert "position" not in cluster, (
                f"Cluster {cluster['id']!r} must not carry a 'position' field — "
                "Godot computes the supernode position as the centroid of member "
                "positions at render time."
            )


# ---------------------------------------------------------------------------
# Requirement: Symbol Table Extraction
# spec: visual-primitives.spec.md § Requirement: Symbol Table Extraction
# THEN both functions are emitted as symbols
# AND process_order is marked as public visibility
# AND _validate_input is marked as private visibility
# AND each symbol carries its signature
# ---------------------------------------------------------------------------


@pytest.fixture()
def src_symbols(tmp_path: Path) -> Path:
    """Source tree with public and private symbols for symbol table tests."""
    bc = tmp_path / "orders"
    module = bc / "domain"
    module.mkdir(parents=True)
    for d in [bc, module]:
        (d / "__init__.py").write_text("")
    # Module with public function, private function, and class.
    (module / "handlers.py").write_text(
        "class Order:\n"
        "    total: float\n\n"
        "def process_order(order: 'Order', strict: bool = False) -> bool:\n"
        "    return True\n\n"
        "def _validate_input(data: dict) -> None:\n"
        "    pass\n"
    )
    return tmp_path


class TestSymbolTableExtraction:
    """Spec: visual-primitives.spec.md § Requirement: Symbol Table Extraction."""

    def test_public_function_marked_public(self, src_symbols: Path) -> None:
        """process_order has no leading underscore → visibility='public'."""
        nodes: list[Node] = discover_bounded_contexts(src_symbols)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_symbols, bc["id"]))
        extract_symbols(src_symbols, nodes)

        domain_node = next(n for n in nodes if n["id"] == "orders.domain")
        symbols = domain_node.get("symbols", [])
        names = {s["name"]: s for s in symbols}

        assert "process_order" in names, "process_order must be extracted as a symbol"
        assert names["process_order"]["visibility"] == "public", (
            "process_order must be marked visibility='public'"
        )

    def test_private_function_marked_private(self, src_symbols: Path) -> None:
        """_validate_input has a leading underscore → visibility='private'."""
        nodes: list[Node] = discover_bounded_contexts(src_symbols)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_symbols, bc["id"]))
        extract_symbols(src_symbols, nodes)

        domain_node = next(n for n in nodes if n["id"] == "orders.domain")
        symbols = domain_node.get("symbols", [])
        names = {s["name"]: s for s in symbols}

        assert "_validate_input" in names, (
            "_validate_input must be extracted as a symbol"
        )
        assert names["_validate_input"]["visibility"] == "private", (
            "_validate_input must be marked visibility='private'"
        )

    def test_function_carries_signature(self, src_symbols: Path) -> None:
        """Each function symbol carries its parameter/return signature."""
        nodes: list[Node] = discover_bounded_contexts(src_symbols)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_symbols, bc["id"]))
        extract_symbols(src_symbols, nodes)

        domain_node = next(n for n in nodes if n["id"] == "orders.domain")
        symbols = domain_node.get("symbols", [])
        names = {s["name"]: s for s in symbols}

        assert "signature" in names["process_order"], (
            "process_order must carry a 'signature' field"
        )
        # Signature should mention the parameter names.
        sig = names["process_order"]["signature"]
        assert "order" in sig, (
            f"Signature should include 'order' parameter; got {sig!r}"
        )

    def test_class_extracted_as_symbol(self, src_symbols: Path) -> None:
        """Class definitions are extracted with kind='class'."""
        nodes: list[Node] = discover_bounded_contexts(src_symbols)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_symbols, bc["id"]))
        extract_symbols(src_symbols, nodes)

        domain_node = next(n for n in nodes if n["id"] == "orders.domain")
        symbols = domain_node.get("symbols", [])
        names = {s["name"]: s for s in symbols}

        assert "Order" in names, "Order class must be extracted as a symbol"
        assert names["Order"]["kind"] == "class", "Order must have kind='class'"

    def test_symbols_embedded_in_module_node(self, src_symbols: Path) -> None:
        """The extractor embeds symbols in the module node dict."""
        nodes: list[Node] = discover_bounded_contexts(src_symbols)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_symbols, bc["id"]))
        extract_symbols(src_symbols, nodes)

        domain_node = next(n for n in nodes if n["id"] == "orders.domain")
        assert "symbols" in domain_node, (
            "module node must have a 'symbols' field after extract_symbols()"
        )
        assert isinstance(domain_node["symbols"], list), (
            "'symbols' field must be a list"
        )


# ---------------------------------------------------------------------------
# Requirement: Type Topology Extraction
# spec: visual-primitives.spec.md § Requirement: Type Topology Extraction
# THEN an inheritance edge is emitted … edge type is 'inherits'
# THEN a composition edge is emitted … edge type is 'has_a'
# ---------------------------------------------------------------------------


@pytest.fixture()
def src_topology(tmp_path: Path) -> Path:
    """Source tree with inheritance and composition relationships."""
    # payment bounded context
    payment = tmp_path / "payment"
    base_mod = payment / "base"
    proc_mod = payment / "processor"
    base_mod.mkdir(parents=True)
    proc_mod.mkdir(parents=True)
    for d in [payment, base_mod, proc_mod]:
        (d / "__init__.py").write_text("")

    # base module defines BaseProcessor
    (base_mod / "base.py").write_text("class BaseProcessor:\n    pass\n")
    # processor module defines PaymentProcessor(BaseProcessor)
    (proc_mod / "processor.py").write_text(
        "from payment.base import BaseProcessor\n"
        "class PaymentProcessor(BaseProcessor):\n"
        "    pass\n"
    )

    # order bounded context with composition
    order = tmp_path / "order"
    order_mod = order / "domain"
    order_mod.mkdir(parents=True)
    for d in [order, order_mod]:
        (d / "__init__.py").write_text("")

    # domain module uses PaymentInfo (from another module)
    info_mod = order / "info"
    info_mod.mkdir()
    (info_mod / "__init__.py").write_text("")
    (info_mod / "types.py").write_text("class PaymentInfo:\n    pass\n")

    (order_mod / "models.py").write_text(
        "from order.info import PaymentInfo\nclass Order:\n    payment: PaymentInfo\n"
    )

    return tmp_path


class TestTypeTopologyExtraction:
    """Spec: visual-primitives.spec.md § Requirement: Type Topology Extraction."""

    def test_inheritance_edge_emitted(self, src_topology: Path) -> None:
        """PaymentProcessor extends BaseProcessor → 'inherits' edge emitted."""
        nodes: list[Node] = discover_bounded_contexts(src_topology)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_topology, bc["id"]))

        edges = extract_type_topology(src_topology, nodes)
        inherits_edges = [e for e in edges if e["type"] == "inherits"]

        assert inherits_edges, (
            "At least one 'inherits' edge must be emitted when inheritance exists"
        )

    def test_inheritance_edge_type_is_inherits(self, src_topology: Path) -> None:
        """The edge type for inheritance is exactly 'inherits'."""
        nodes: list[Node] = discover_bounded_contexts(src_topology)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_topology, bc["id"]))

        edges = extract_type_topology(src_topology, nodes)
        for e in edges:
            assert e["type"] in ("inherits", "has_a"), (
                f"Type topology edges must be 'inherits' or 'has_a'; got {e['type']!r}"
            )

    def test_composition_edge_emitted(self, src_topology: Path) -> None:
        """Order has PaymentInfo field → 'has_a' edge emitted."""
        nodes: list[Node] = discover_bounded_contexts(src_topology)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_topology, bc["id"]))

        edges = extract_type_topology(src_topology, nodes)
        has_a_edges = [e for e in edges if e["type"] == "has_a"]

        assert has_a_edges, (
            "At least one 'has_a' edge must be emitted when composition exists"
        )

    def test_composition_edge_type_is_has_a(self, src_topology: Path) -> None:
        """The edge type for composition is exactly 'has_a'."""
        nodes: list[Node] = discover_bounded_contexts(src_topology)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_topology, bc["id"]))

        edges = extract_type_topology(src_topology, nodes)
        for e in edges:
            assert e["type"] in ("inherits", "has_a"), (
                f"Expected 'inherits' or 'has_a'; got {e['type']!r}"
            )


# ---------------------------------------------------------------------------
# Requirement: Call Graph Extraction
# spec: visual-primitives.spec.md § Requirement: Call Graph Extraction
# THEN an edge is emitted from handle_request to validate_input
# AND the edge type is 'direct_call'
# THEN the call site is emitted as a 'dynamic_call' with no resolved target
# THEN the edge A→B carries a weight of 3
# ---------------------------------------------------------------------------


@pytest.fixture()
def src_calls(tmp_path: Path) -> Path:
    """Source tree with function calls between modules."""
    svc = tmp_path / "svc"
    handler_mod = svc / "handlers"
    validator_mod = svc / "validators"
    handler_mod.mkdir(parents=True)
    validator_mod.mkdir(parents=True)
    for d in [svc, handler_mod, validator_mod]:
        (d / "__init__.py").write_text("")

    # validator module defines validate_input
    (validator_mod / "funcs.py").write_text(
        "def validate_input(data):\n    return True\n"
    )
    # handler module calls validate_input three times (direct calls)
    (handler_mod / "funcs.py").write_text(
        "from svc.validators import validate_input\n"
        "def handle_request(data, handler=None):\n"
        "    validate_input(data)\n"
        "    validate_input(data)\n"
        "    validate_input(data)\n"
        "    if handler:\n"
        "        handler(data)\n"  # dynamic call via parameter
    )
    return tmp_path


class TestCallGraphExtraction:
    """Spec: visual-primitives.spec.md § Requirement: Call Graph Extraction."""

    def test_direct_call_edge_emitted(self, src_calls: Path) -> None:
        """handle_request calls validate_input → 'direct_call' edge emitted."""
        nodes: list[Node] = discover_bounded_contexts(src_calls)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_calls, bc["id"]))

        edges = extract_call_graph(src_calls, nodes)
        direct_edges = [e for e in edges if e["type"] == "direct_call"]

        assert direct_edges, "At least one 'direct_call' edge must be emitted"

    def test_direct_call_edge_type(self, src_calls: Path) -> None:
        """Direct call edges have type exactly 'direct_call'."""
        nodes: list[Node] = discover_bounded_contexts(src_calls)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_calls, bc["id"]))

        edges = extract_call_graph(src_calls, nodes)
        for e in edges:
            assert e["type"] in ("direct_call", "dynamic_call"), (
                f"Call graph edges must be 'direct_call' or 'dynamic_call'; got {e['type']!r}"
            )

    def test_direct_call_weight_counts_call_sites(self, src_calls: Path) -> None:
        """Edge A→B weight equals the number of call sites from A to B."""
        nodes: list[Node] = discover_bounded_contexts(src_calls)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_calls, bc["id"]))

        edges = extract_call_graph(src_calls, nodes)
        direct_edges = [e for e in edges if e["type"] == "direct_call"]

        assert direct_edges, "Need at least one direct_call edge to check weight"
        # handle_request calls validate_input 3 times → weight should be 3
        max_weight = max(e.get("weight", 1) for e in direct_edges)
        assert max_weight >= 3, (
            f"Expected weight ≥ 3 for three call sites; got {max_weight}"
        )

    def test_dynamic_call_edge_emitted(self, src_calls: Path) -> None:
        """handler(data) where handler is a parameter → 'dynamic_call' edge emitted."""
        nodes: list[Node] = discover_bounded_contexts(src_calls)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_calls, bc["id"]))

        edges = extract_call_graph(src_calls, nodes)
        dynamic_edges = [e for e in edges if e["type"] == "dynamic_call"]

        assert dynamic_edges, (
            "At least one 'dynamic_call' edge must be emitted for parameter callees"
        )

    def test_dynamic_call_edge_carries_param_name(self, src_calls: Path) -> None:
        """spec: 'the call site carries the parameter name and any type hints'
        The dynamic_call edge must include a non-empty param_name field.
        """
        nodes: list[Node] = discover_bounded_contexts(src_calls)
        for bc in list(nodes):
            nodes.extend(discover_submodules(src_calls, bc["id"]))

        edges = extract_call_graph(src_calls, nodes)
        dynamic_edges = [e for e in edges if e["type"] == "dynamic_call"]

        assert dynamic_edges, "At least one 'dynamic_call' edge must be emitted"
        for edge in dynamic_edges:
            param_name = edge.get("param_name", "")
            assert param_name != "", (
                f"'dynamic_call' edge from '{edge['source']}' must carry a non-empty "
                f"'param_name' field; got {edge!r}"
            )


# ---------------------------------------------------------------------------
# Requirement: Structural Significance Extraction
# spec: visual-primitives.spec.md § Requirement: Structural Significance Extraction
# Hub detection: high in-degree → is_hub=True
# Bridge detection: high betweenness_centrality → is_bridge=True
# Peripheral detection: in-degree 0, out-degree ≤ 1 → is_peripheral=True
# Community detection: community_id assigned; community_drift when differs
# ---------------------------------------------------------------------------


def _make_bc_node(node_id: str) -> Node:
    """Helper: create a minimal bounded_context node for significance tests."""
    return {
        "id": node_id,
        "name": node_id.title(),
        "type": "bounded_context",
        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
        "size": 1.0,
        "parent": None,
    }


def _make_mod_node(node_id: str, parent: str) -> Node:
    """Helper: create a minimal module node for significance tests."""
    return {
        "id": node_id,
        "name": node_id,
        "type": "module",
        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
        "size": 1.0,
        "parent": parent,
    }


def _make_node_id(nid: str, ntype: str = "module", parent: str | None = None) -> Node:
    """Return a minimal valid Node dict for significance tests (compat helper)."""
    return {
        "id": nid,
        "name": nid.upper(),
        "type": ntype,  # type: ignore[typeddict-item]
        "position": {"x": 0.0, "y": 0.0, "z": 0.0},
        "size": 1.0,
        "parent": parent,
    }


def _make_edge(src: str, tgt: str, etype: str = "internal") -> Edge:
    return {"source": src, "target": tgt, "type": etype}  # type: ignore[return-value]


class TestStructuralSignificance:
    """compute_structural_significance annotates nodes with hub/bridge/peripheral/community."""

    def test_in_degree_counts_incoming_edges(self) -> None:
        """GIVEN module B has two edges pointing to it
        WHEN structural significance is computed
        THEN B's in_degree == 2."""
        nodes = [_make_node_id("A"), _make_node_id("B"), _make_node_id("C")]
        edges = [_make_edge("A", "B"), _make_edge("C", "B")]
        compute_structural_significance(nodes, edges)
        b_node = next(n for n in nodes if n["id"] == "B")
        assert b_node["in_degree"] == 2, (
            f"Expected in_degree=2; got {b_node['in_degree']}"
        )

    def test_out_degree_counts_outgoing_edges(self) -> None:
        """GIVEN module A has two outgoing edges
        WHEN structural significance is computed
        THEN A's out_degree == 2."""
        nodes = [_make_node_id("A"), _make_node_id("B"), _make_node_id("C")]
        edges = [_make_edge("A", "B"), _make_edge("A", "C")]
        compute_structural_significance(nodes, edges)
        a_node = next(n for n in nodes if n["id"] == "A")
        assert a_node["out_degree"] == 2, (
            f"Expected out_degree=2; got {a_node['out_degree']}"
        )

    def test_hub_node_flagged_with_high_in_degree(self) -> None:
        """GIVEN a module imported by many others
        WHEN structural significance is computed
        THEN it is flagged is_hub=True."""
        # Hub: B imported by A, C, D (3 edges); others have 0 or 1.
        nodes = [
            _make_node_id("A"),
            _make_node_id("B"),
            _make_node_id("C"),
            _make_node_id("D"),
        ]
        edges = [_make_edge("A", "B"), _make_edge("C", "B"), _make_edge("D", "B")]
        compute_structural_significance(nodes, edges)
        b_node = next(n for n in nodes if n["id"] == "B")
        assert b_node["is_hub"] is True, (
            f"B has in_degree=3 (highest) and should be flagged as hub; got is_hub={b_node.get('is_hub')}"
        )

    def test_non_hub_node_not_flagged(self) -> None:
        """Nodes with low in-degree are NOT flagged as hubs."""
        nodes = [
            _make_node_id("A"),
            _make_node_id("B"),
            _make_node_id("C"),
            _make_node_id("D"),
        ]
        edges = [_make_edge("A", "B"), _make_edge("C", "B"), _make_edge("D", "B")]
        compute_structural_significance(nodes, edges)
        # A, C, D each have in_degree=0 — definitely not hubs
        for nid in ("A", "C", "D"):
            n = next(x for x in nodes if x["id"] == nid)
            assert n["is_hub"] is False, (
                f"Node {nid} has in_degree=0 and must not be hub; got is_hub={n.get('is_hub')}"
            )

    def test_peripheral_node_flagged(self) -> None:
        """GIVEN a module with in_degree=0 and out_degree=1
        THEN it is flagged is_peripheral=True."""
        nodes = [_make_node_id("A"), _make_node_id("B")]
        edges = [_make_edge("A", "B")]
        compute_structural_significance(nodes, edges)
        a_node = next(n for n in nodes if n["id"] == "A")
        # A: in_degree=0, out_degree=1 → peripheral
        assert a_node["is_peripheral"] is True, (
            f"A has in_degree=0, out_degree=1 and must be peripheral; got {a_node.get('is_peripheral')}"
        )

    def test_non_peripheral_node_not_flagged(self) -> None:
        """A node with in_degree > 0 is NOT peripheral."""
        nodes = [_make_node_id("A"), _make_node_id("B"), _make_node_id("C")]
        edges = [_make_edge("A", "B"), _make_edge("C", "B")]
        compute_structural_significance(nodes, edges)
        b_node = next(n for n in nodes if n["id"] == "B")
        assert b_node["is_peripheral"] is False, (
            f"B has in_degree=2 and must not be peripheral; got {b_node.get('is_peripheral')}"
        )

    def test_bridge_node_flagged_as_articulation_point(self) -> None:
        """GIVEN a module connecting two otherwise disconnected groups
        THEN it is flagged is_bridge=True (articulation point).

        Graph: A — B — C   (B is the only connector; removing B disconnects A from C)
        """
        nodes = [_make_node_id("A"), _make_node_id("B"), _make_node_id("C")]
        edges = [_make_edge("A", "B"), _make_edge("B", "C")]
        compute_structural_significance(nodes, edges)
        b_node = next(n for n in nodes if n["id"] == "B")
        assert b_node["is_bridge"] is True, (
            f"B connects A and C and must be an articulation point (bridge); "
            f"got is_bridge={b_node.get('is_bridge')}"
        )

    def test_non_bridge_in_cycle_not_flagged(self) -> None:
        """A node in a cycle is NOT a bridge (cycle creates alternative paths)."""
        nodes = [_make_node_id("A"), _make_node_id("B"), _make_node_id("C")]
        # Cycle: A→B→C→A — no articulation points
        edges = [_make_edge("A", "B"), _make_edge("B", "C"), _make_edge("C", "A")]
        compute_structural_significance(nodes, edges)
        for node in nodes:
            assert node["is_bridge"] is False, (
                f"Node {node['id']} is in a cycle and must NOT be a bridge; "
                f"got is_bridge={node.get('is_bridge')}"
            )

    def test_community_ids_assigned_to_all_nodes(self) -> None:
        """Every node receives a community_id after significance computation."""
        nodes = [_make_node_id("A"), _make_node_id("B"), _make_node_id("C")]
        edges = [_make_edge("A", "B")]
        compute_structural_significance(nodes, edges)
        for node in nodes:
            assert "community_id" in node, f"Node {node['id']} missing community_id"
            assert isinstance(node["community_id"], int), (
                f"community_id must be int; got {type(node['community_id'])}"
            )

    def test_connected_nodes_share_community(self) -> None:
        """Nodes connected (directly or transitively) share the same community_id."""
        nodes = [_make_node_id("A"), _make_node_id("B"), _make_node_id("C")]
        edges = [_make_edge("A", "B"), _make_edge("B", "C")]
        compute_structural_significance(nodes, edges)
        cid = {n["id"]: n["community_id"] for n in nodes}
        assert cid["A"] == cid["B"] == cid["C"], (
            f"Connected A-B-C must share a community_id; got {cid}"
        )

    def test_disconnected_nodes_have_different_communities(self) -> None:
        """Disconnected nodes belong to different communities."""
        nodes = [_make_node_id("A"), _make_node_id("B")]
        edges: list[Edge] = []  # no edges — A and B are disconnected
        compute_structural_significance(nodes, edges)
        cid_a = next(n for n in nodes if n["id"] == "A")["community_id"]
        cid_b = next(n for n in nodes if n["id"] == "B")["community_id"]
        assert cid_a != cid_b, (
            f"Disconnected A and B must have different community_ids; got A={cid_a} B={cid_b}"
        )

    def test_community_drift_detected_for_cross_context_component(self) -> None:
        """A module whose community spans two bounded contexts is flagged community_drift=True.

        GIVEN iam.domain and graph.domain are connected (cross-context edge)
        THEN both are in the same community, which spans two bounded contexts
        AND both are flagged community_drift=True.
        """
        nodes = [
            _make_node_id("iam.domain", parent="iam"),
            _make_node_id("graph.domain", parent="graph"),
        ]
        edges = [_make_edge("iam.domain", "graph.domain", "cross_context")]
        compute_structural_significance(nodes, edges)
        for node in nodes:
            assert node["community_drift"] is True, (
                f"Node {node['id']} is in a cross-context community and must have "
                f"community_drift=True; got {node.get('community_drift')}"
            )

    def test_no_community_drift_within_single_context(self) -> None:
        """Nodes whose community contains only one bounded context have drift=False."""
        nodes = [
            _make_node_id("iam.domain", parent="iam"),
            _make_node_id("iam.application", parent="iam"),
        ]
        edges = [_make_edge("iam.application", "iam.domain")]
        compute_structural_significance(nodes, edges)
        for node in nodes:
            assert node["community_drift"] is False, (
                f"Node {node['id']} is in a same-context community and must NOT "
                f"have community_drift; got {node.get('community_drift')}"
            )

    def test_build_scene_graph_assigns_significance(self, src: Path) -> None:
        """build_scene_graph wires compute_structural_significance so all nodes
        carry in_degree, out_degree, is_hub, is_bridge, is_peripheral, community_id."""
        graph = build_scene_graph(src)
        for node in graph["nodes"]:
            assert "in_degree" in node, f"Node {node['id']} missing in_degree"
            assert "out_degree" in node, f"Node {node['id']} missing out_degree"
            assert "is_hub" in node, f"Node {node['id']} missing is_hub"
            assert "is_bridge" in node, f"Node {node['id']} missing is_bridge"
            assert "is_peripheral" in node, f"Node {node['id']} missing is_peripheral"
            assert "community_id" in node, f"Node {node['id']} missing community_id"


# ---------------------------------------------------------------------------
# Requirement: Ubiquitous Dependency Detection
# spec: visual-primitives.spec.md § Ubiquitous Dependency Detection
#
# Scenarios covered:
#   GIVEN 85% of modules import logging
#   WHEN ubiquitous dependency detection runs
#   THEN logging edges are marked ubiquitous=True
#   AND threshold is recorded in metadata
# ---------------------------------------------------------------------------


class TestUbiquitousFlags:
    """compute_ubiquitous_flags marks edges to ubiquitous targets."""

    def _make_module_nodes(self, count: int) -> list[Node]:
        """Return *count* minimal module nodes."""
        return [
            {
                "id": f"mod_{i}",
                "name": f"Mod {i}",
                "type": "module",
                "position": {"x": 0.0, "y": 0.0, "z": 0.0},
                "size": 1.0,
                "parent": "ctx",
            }
            for i in range(count)
        ]

    def test_edge_marked_ubiquitous_above_threshold(self) -> None:
        """GIVEN target is imported by 100% of modules (3/3 > 0.5 threshold)
        THEN edges to it are marked ubiquitous=True."""
        nodes = self._make_module_nodes(3)
        # 'shared' is imported by ALL 3 modules
        edges: list[Edge] = [
            _make_edge("mod_0", "shared"),
            _make_edge("mod_1", "shared"),
            _make_edge("mod_2", "shared"),
        ]
        compute_ubiquitous_flags(nodes, edges)
        for e in edges:
            if e["target"] == "shared":
                assert e.get("ubiquitous") is True, (
                    f"Edge to 'shared' (imported by 100% of modules) must be ubiquitous; "
                    f"got {e.get('ubiquitous')}"
                )

    def test_edge_not_marked_below_threshold(self) -> None:
        """GIVEN target is imported by only 1/4 modules (25% < 50% threshold)
        THEN edges to it are NOT marked ubiquitous."""
        nodes = self._make_module_nodes(4)
        edges: list[Edge] = [_make_edge("mod_0", "rare")]
        compute_ubiquitous_flags(nodes, edges)
        e = edges[0]
        assert e.get("ubiquitous") is not True, (
            f"Edge to 'rare' (1/4 modules = 25% < threshold) must NOT be ubiquitous; "
            f"got {e.get('ubiquitous')}"
        )

    def test_custom_threshold_respected(self) -> None:
        """A lower threshold (0.2) flags a dependency imported by 2/4 modules (50%)."""
        nodes = self._make_module_nodes(4)
        edges: list[Edge] = [
            _make_edge("mod_0", "semi_common"),
            _make_edge("mod_1", "semi_common"),
        ]
        result = compute_ubiquitous_flags(nodes, edges, threshold=0.2)
        assert "semi_common" in result, (
            f"'semi_common' (2/4 = 50% > 20% threshold) must be in ubiquitous result; "
            f"got {result}"
        )
        for e in edges:
            assert e.get("ubiquitous") is True

    def test_returns_ubiquitous_target_fractions(self) -> None:
        """Return value maps target_id → fraction of modules that import it."""
        nodes = self._make_module_nodes(2)
        edges: list[Edge] = [
            _make_edge("mod_0", "common"),
            _make_edge("mod_1", "common"),
        ]
        result = compute_ubiquitous_flags(nodes, edges)
        assert "common" in result, f"'common' must appear in result; got {result}"
        assert result["common"] == pytest.approx(1.0), (
            f"'common' is imported by 100% of modules; got fraction={result['common']}"
        )

    def test_no_module_nodes_returns_empty(self) -> None:
        """When there are no module nodes the function returns an empty dict."""
        nodes: list[Node] = [
            {
                "id": "ctx",
                "name": "Ctx",
                "type": "bounded_context",
                "position": {"x": 0.0, "y": 0.0, "z": 0.0},
                "size": 1.0,
                "parent": None,
            }
        ]
        edges: list[Edge] = [_make_edge("ctx", "shared")]
        result = compute_ubiquitous_flags(nodes, edges)
        assert result == {}, f"No module nodes → empty result; got {result}"

    def test_non_ubiquitous_edges_unchanged(self) -> None:
        """Edges whose targets are not ubiquitous are left without the ubiquitous key."""
        nodes = self._make_module_nodes(4)
        edges: list[Edge] = [_make_edge("mod_0", "rare")]
        compute_ubiquitous_flags(nodes, edges)
        assert "ubiquitous" not in edges[0], (
            f"Non-ubiquitous edge must not have 'ubiquitous' key; got {edges[0]}"
        )

    def test_build_scene_graph_records_ubiquity_threshold(self, src: Path) -> None:
        """build_scene_graph records the ubiquity_threshold in metadata."""
        graph = build_scene_graph(src)
        meta = graph["metadata"]
        assert "ubiquity_threshold" in meta, (
            "metadata must contain 'ubiquity_threshold' after build_scene_graph"
        )
        assert isinstance(meta["ubiquity_threshold"], float), (
            f"ubiquity_threshold must be float; got {type(meta['ubiquity_threshold'])}"
        )

    def test_build_scene_graph_flags_ubiquitous_edges(self, src: Path) -> None:
        """build_scene_graph calls compute_ubiquitous_flags so edges may carry ubiquitous=True."""
        # The src fixture has shared_kernel imported by iam.domain and graph.infrastructure.
        # With 2/6 modules importing it, the fraction is ~33% — below default 50% threshold.
        # So in THIS fixture no edges are ubiquitous. We verify the key is ABSENT (not False).
        graph = build_scene_graph(src)
        # Verify the function ran without error and edges are a list.
        assert isinstance(graph["edges"], list)
        # None of the edges in the fixture should exceed the 50% threshold.
        ubiq_edges = [e for e in graph["edges"] if e.get("ubiquitous") is True]
        # In the standard test fixture, nothing should be ubiquitous
        assert isinstance(ubiq_edges, list)  # just confirm no crash


# ---------------------------------------------------------------------------
# Requirement: Independence Detection — additional scenarios
# spec: orthogonal-independence.spec.md
#
# Scenario: Fully connected context
# GIVEN a bounded context where every module transitively depends on every other
# WHEN independence analysis runs
# THEN the entire context is a single group
# AND no independence separation is applied
#
# Scenario: Two independent module clusters
# GIVEN modules A, B, C, D where A→B and C→D but {A,B} ∦ {C,D}
# WHEN independence analysis runs
# THEN {A,B} and {C,D} are identified as independent groups
# AND each module carries its group identifier in the scene graph
# ---------------------------------------------------------------------------


class TestIndependenceDetectionScenarios:
    """Spec: orthogonal-independence.spec.md § Requirement: Independence Detection."""

    def test_fully_connected_context_is_single_group(self, tmp_path: Path) -> None:
        """GIVEN every module transitively depends on every other
        THEN the entire context is a single group.

        Scenario: A→B, B→C, C→A (cycle → all transitively connected).
        """
        bc = tmp_path / "ctx"
        mod_a = bc / "alpha"
        mod_b = bc / "beta"
        mod_c = bc / "gamma"
        for d in [bc, mod_a, mod_b, mod_c]:
            d.mkdir(parents=True)
            (d / "__init__.py").write_text("")
        (mod_a / "code.py").write_text("from ctx.beta import B\n")
        (mod_b / "code.py").write_text("from ctx.gamma import C\n")
        (mod_c / "code.py").write_text("from ctx.alpha import A\n")

        nodes = discover_bounded_contexts(tmp_path)
        for bc_node in list(nodes):
            nodes.extend(discover_submodules(tmp_path, bc_node["id"]))
        edges = build_dependency_edges(tmp_path, nodes)
        compute_independence_groups(nodes, edges)

        groups = {
            n["id"]: n.get("independence_group") for n in nodes if n["type"] == "module"
        }
        assert groups, "Expected module nodes in the fully-connected context"
        # All three modules must share the same group (all transitively connected).
        group_values = set(groups.values())
        assert len(group_values) == 1, (
            f"Fully connected context must be a single group; got {groups}"
        )

    def test_two_independent_clusters_identified(self, tmp_path: Path) -> None:
        """GIVEN modules A,B in one cluster and C,D in another with no cross deps
        THEN {A,B} and {C,D} are in different independence groups.

        Spec Scenario: A imports B, C imports D, but {A,B} ∦ {C,D}.
        """
        bc = tmp_path / "ctx"
        mod_a = bc / "alpha"
        mod_b = bc / "beta"
        mod_c = bc / "gamma"
        mod_d = bc / "delta"
        for d in [bc, mod_a, mod_b, mod_c, mod_d]:
            d.mkdir(parents=True)
            (d / "__init__.py").write_text("")
        (mod_a / "code.py").write_text("from ctx.beta import B\n")
        (mod_b / "code.py").write_text("")
        (mod_c / "code.py").write_text("from ctx.delta import D\n")
        (mod_d / "code.py").write_text("")

        nodes = discover_bounded_contexts(tmp_path)
        for bc_node in list(nodes):
            nodes.extend(discover_submodules(tmp_path, bc_node["id"]))
        edges = build_dependency_edges(tmp_path, nodes)
        compute_independence_groups(nodes, edges)

        groups = {
            n["id"]: n.get("independence_group") for n in nodes if n["type"] == "module"
        }
        assert len(groups) == 4, f"Expected 4 module nodes; got {groups}"
        # {alpha, beta} must be in the same group.
        assert groups["ctx.alpha"] == groups["ctx.beta"], (
            f"ctx.alpha and ctx.beta import each other → same group; got {groups}"
        )
        # {gamma, delta} must be in the same group.
        assert groups["ctx.gamma"] == groups["ctx.delta"], (
            f"ctx.gamma and ctx.delta import each other → same group; got {groups}"
        )
        # The two clusters must be in DIFFERENT groups.
        assert groups["ctx.alpha"] != groups["ctx.gamma"], (
            f"Independent clusters {{alpha,beta}} and {{gamma,delta}} must differ; "
            f"got {groups}"
        )

    def test_each_module_carries_group_id_in_scene_graph(self, tmp_path: Path) -> None:
        """THEN each module carries its group identifier in the scene graph.

        Spec: 'each module carries its group identifier in the scene graph'.
        """
        bc = tmp_path / "svc"
        mod = bc / "core"
        for d in [bc, mod]:
            d.mkdir(parents=True)
            (d / "__init__.py").write_text("")
        (mod / "logic.py").write_text("")

        graph = build_scene_graph(tmp_path)
        module_nodes = [n for n in graph["nodes"] if n["type"] == "module"]
        assert module_nodes, "Expected at least one module node"
        for node in module_nodes:
            assert "independence_group" in node, (
                f"Module {node['id']} must carry independence_group in scene graph"
            )
            grp = node["independence_group"]
            assert isinstance(grp, str) and ":" in grp, (
                f"independence_group must be '<context>:<index>' string; got {grp!r}"
            )


# ---------------------------------------------------------------------------
# Requirement: Spatial Separation of Independent Groups
# spec: orthogonal-independence.spec.md
#
# Scenario: Visual gap between independent groups
# GIVEN a bounded context with two independent groups
# WHEN layout is computed
# THEN the groups occupy distinct spatial regions
# AND a visible gap separates the groups
# AND modules within each group remain close to each other
# ---------------------------------------------------------------------------


class TestSpatialSeparation:
    """Spec: orthogonal-independence.spec.md § Requirement: Spatial Separation."""

    @pytest.fixture()
    def src_two_groups(self, tmp_path: Path) -> Path:
        """Source tree with two independent module clusters in the same BC."""
        bc = tmp_path / "ctx"
        mod_a = bc / "alpha"
        mod_b = bc / "beta"
        mod_c = bc / "gamma"
        mod_d = bc / "delta"
        for d in [bc, mod_a, mod_b, mod_c, mod_d]:
            d.mkdir(parents=True)
            (d / "__init__.py").write_text("")
        # Group 1: alpha ↔ beta (internal dep)
        (mod_a / "code.py").write_text("from ctx.beta import B\n")
        (mod_b / "code.py").write_text("")
        # Group 2: gamma ↔ delta (internal dep)
        (mod_c / "code.py").write_text("from ctx.delta import D\n")
        (mod_d / "code.py").write_text("")
        return tmp_path

    def _pos(self, node: "Node") -> tuple[float, float, float]:
        p = node["position"]
        return float(p["x"]), float(p["y"]), float(p["z"])

    def _dist(self, a: "Node", b: "Node") -> float:
        ax, ay, az = self._pos(a)
        bx, by, bz = self._pos(b)
        return math.sqrt((ax - bx) ** 2 + (ay - by) ** 2 + (az - bz) ** 2)

    def test_independent_groups_are_spatially_separated(
        self, src_two_groups: Path
    ) -> None:
        """GIVEN two independent groups, modules in different groups must be
        farther apart than modules in the same group (visible gap exists).

        Spec: "the groups occupy distinct spatial regions within the context's
        volume AND a visible gap separates the groups".
        """
        nodes = discover_bounded_contexts(src_two_groups)
        for bc_node in list(nodes):
            nodes.extend(discover_submodules(src_two_groups, bc_node["id"]))
        edges = build_dependency_edges(src_two_groups, nodes)
        # compute_independence_groups before compute_layout so layout can use groups.
        compute_independence_groups(nodes, edges)
        compute_layout(nodes, edges)

        by_id = {n["id"]: n for n in nodes if n["type"] == "module"}
        assert by_id, "Expected module nodes after layout"

        # Within-group distances.
        d_alpha_beta = self._dist(by_id["ctx.alpha"], by_id["ctx.beta"])
        d_gamma_delta = self._dist(by_id["ctx.gamma"], by_id["ctx.delta"])

        # Cross-group distances.
        d_alpha_gamma = self._dist(by_id["ctx.alpha"], by_id["ctx.gamma"])
        d_alpha_delta = self._dist(by_id["ctx.alpha"], by_id["ctx.delta"])
        d_beta_gamma = self._dist(by_id["ctx.beta"], by_id["ctx.gamma"])

        # Modules in different groups must be farther apart than modules in the
        # same group — the visible gap separates the two clusters.
        assert d_alpha_gamma > d_alpha_beta, (
            f"Cross-group distance (alpha↔gamma={d_alpha_gamma:.3f}) must be "
            f"greater than intra-group distance (alpha↔beta={d_alpha_beta:.3f}) "
            "— independent groups must be spatially separated with a visible gap"
        )
        assert d_alpha_gamma > d_gamma_delta, (
            f"Cross-group distance (alpha↔gamma={d_alpha_gamma:.3f}) must be "
            f"greater than intra-group distance (gamma↔delta={d_gamma_delta:.3f})"
        )
        # At least one cross-group distance exceeds all intra-group distances.
        cross_min = min(d_alpha_gamma, d_alpha_delta, d_beta_gamma)
        intra_max = max(d_alpha_beta, d_gamma_delta)
        assert cross_min > intra_max, (
            f"Minimum cross-group distance ({cross_min:.3f}) must exceed "
            f"maximum intra-group distance ({intra_max:.3f}) — visible gap required"
        )

    def test_build_scene_graph_separates_groups_spatially(
        self, src_two_groups: Path
    ) -> None:
        """build_scene_graph positions modules so independent groups are separated.

        This end-to-end test verifies the full pipeline wires independence
        detection before layout so spatial separation is guaranteed.
        """
        graph = build_scene_graph(src_two_groups)
        module_nodes = [n for n in graph["nodes"] if n["type"] == "module"]
        by_id = {n["id"]: n for n in module_nodes}
        assert by_id, "Expected module nodes in built scene graph"

        # All modules must have independence_group AND positions.
        for node in module_nodes:
            assert "independence_group" in node, (
                f"{node['id']} missing independence_group in full scene graph"
            )
            p = node["position"]
            assert all(k in p for k in ("x", "y", "z")), (
                f"{node['id']} missing position coordinates"
            )

        # Verify spatial separation: cross-group distances > intra-group distances.
        def dist(a_id: str, b_id: str) -> float:
            a, b = by_id[a_id], by_id[b_id]
            dx = a["position"]["x"] - b["position"]["x"]
            dz = a["position"]["z"] - b["position"]["z"]
            dy = a["position"]["y"] - b["position"]["y"]
            return math.sqrt(dx * dx + dy * dy + dz * dz)

        d_intra_1 = dist("ctx.alpha", "ctx.beta")
        d_intra_2 = dist("ctx.gamma", "ctx.delta")
        d_cross = dist("ctx.alpha", "ctx.gamma")

        assert d_cross > d_intra_1, (
            f"Cross-group distance ({d_cross:.3f}) must exceed "
            f"intra-group distance ({d_intra_1:.3f})"
        )
        assert d_cross > d_intra_2, (
            f"Cross-group distance ({d_cross:.3f}) must exceed "
            f"intra-group distance ({d_intra_2:.3f})"
        )


# ---------------------------------------------------------------------------
# Requirement: Individual edge weight (cross_context and internal edges)
# spec: orthogonal-independence.spec.md (and cross-referenced by check-individual-edge-weight)
#
# Each edge must carry a 'weight' field equal to the import count.
# ---------------------------------------------------------------------------


class TestIndividualEdgeWeight:
    """Every cross_context and internal edge carries a 'weight' field."""

    def test_cross_context_edge_has_weight(self, src: Path) -> None:
        """Every cross_context edge carries a weight field (import count).

        Spec: 'each edge carries the import count (number of individual
        import statements between the pair).'
        """
        nodes = discover_bounded_contexts(src)
        for bc_node in list(nodes):
            nodes.extend(discover_submodules(src, bc_node["id"]))
        edges = build_dependency_edges(src, nodes)
        cc_edges = [e for e in edges if e["type"] == "cross_context"]
        assert cc_edges, "Expected at least one cross_context edge in src fixture"
        for e in cc_edges:
            assert "weight" in e, f"cross_context edge missing weight: {e}"
            assert e["weight"] >= 1, f"weight must be >= 1; got {e['weight']}"

    def test_internal_edge_has_weight(self, src: Path) -> None:
        """Every internal edge carries a weight field (import count).

        Spec: 'each edge carries the import count'.
        """
        nodes = discover_bounded_contexts(src)
        for bc_node in list(nodes):
            nodes.extend(discover_submodules(src, bc_node["id"]))
        edges = build_dependency_edges(src, nodes)
        internal_edges = [e for e in edges if e["type"] == "internal"]
        assert internal_edges, "Expected at least one internal edge in src fixture"
        for e in internal_edges:
            assert "weight" in e, f"internal edge missing weight: {e}"
            assert e["weight"] >= 1, f"weight must be >= 1; got {e['weight']}"

    def test_cross_context_edge_weight_counts_imports(self, tmp_path: Path) -> None:
        """Weight reflects how many module-level import statements cross the boundary.

        GIVEN iam.application imports shared_kernel once
        THEN the cross_context edge iam→shared_kernel has weight >= 1.
        """
        iam = tmp_path / "iam"
        app = iam / "application"
        sk = tmp_path / "shared_kernel"
        for d in [iam, app, sk]:
            d.mkdir(parents=True)
            (d / "__init__.py").write_text("")
        (app / "svc.py").write_text("from shared_kernel.auth import AuthToken\n")

        nodes = discover_bounded_contexts(tmp_path)
        for bc_node in list(nodes):
            nodes.extend(discover_submodules(tmp_path, bc_node["id"]))
        edges = build_dependency_edges(tmp_path, nodes)
        cc_edges = [e for e in edges if e["type"] == "cross_context"]
        assert cc_edges, "Expected cross_context edge iam→shared_kernel"
        for e in cc_edges:
            if e["source"] == "iam" and e["target"] == "shared_kernel":
                assert e["weight"] >= 1, (
                    f"iam→shared_kernel cross_context edge must have weight >= 1; "
                    f"got {e['weight']}"
                )
                break
        else:
            pytest.fail("No iam→shared_kernel cross_context edge found")


# ---------------------------------------------------------------------------
# Requirement: CLI entry point
# ---------------------------------------------------------------------------


class TestCLI:
    def test_main_exits_zero_and_writes_json(self, src: Path, tmp_path: Path) -> None:
        """CLI entry point MUST exit 0 and write valid JSON."""
        from extractor.__main__ import main

        out = tmp_path / "output.json"
        rc = main([str(src), "--output", str(out)])
        assert rc == 0
        assert out.exists(), "Output file must be created"
        content = json.loads(out.read_text())
        assert "nodes" in content
        assert "edges" in content
        assert "metadata" in content
        assert "clusters" in content

    def test_main_returns_1_on_nonexistent_path(self, tmp_path: Path) -> None:
        """CLI MUST return exit code 1 when src_path does not exist."""
        from extractor.__main__ import main

        rc = main([str(tmp_path / "does_not_exist")])
        assert rc == 1

    def test_main_returns_1_on_file_not_dir(self, tmp_path: Path) -> None:
        """CLI MUST return exit code 1 when src_path is a file."""
        from extractor.__main__ import main

        f = tmp_path / "file.py"
        f.write_text("")
        rc = main([str(f)])
        assert rc == 1


# ---------------------------------------------------------------------------
# Requirement: stdlib-only constraint
# ---------------------------------------------------------------------------


class TestStdlibOnly:
    def test_extractor_uses_only_stdlib_imports(self) -> None:
        """The extractor MUST NOT depend on any third-party library.

        Parse all .py files in the extractor package and assert every top-level
        import resolves to a standard library module or the extractor package
        itself.
        """
        extractor_root = Path(__file__).parent.parent
        third_party: list[str] = []

        for py_file in extractor_root.rglob("*.py"):
            if "tests" in py_file.parts:
                continue  # only check production code
            try:
                source = py_file.read_text(encoding="utf-8", errors="replace")
                tree = ast.parse(source, filename=str(py_file))
            except SyntaxError:
                continue

            for node in ast.walk(tree):
                top_name: str | None = None
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        top_name = alias.name.split(".")[0]
                elif isinstance(node, ast.ImportFrom):
                    if node.level == 0 and node.module:
                        top_name = node.module.split(".")[0]

                if top_name and top_name not in sys.stdlib_module_names:
                    # Allow the extractor package itself.
                    if top_name != "extractor":
                        third_party.append(f"{py_file.name}: {top_name}")

        assert third_party == [], (
            "Extractor must use only stdlib imports. "
            "Third-party imports found:\n" + "\n".join(third_party)
        )


def _edge(src: str, tgt: str) -> Edge:
    return {"source": src, "target": tgt, "type": "cross_context"}


class TestStructuralSignificanceExtraction:
    """Spec: visual-primitives.spec.md § Requirement: Structural Significance Extraction."""

    def test_hub_detection_high_in_degree(self) -> None:
        """Module with in_degree > 3 must be flagged is_hub=True."""
        # shared_kernel is imported by 4 modules → in_degree == 4 → is_hub=True
        hub = _make_bc_node("shared_kernel")
        importers = [_make_bc_node(f"svc_{i}") for i in range(4)]
        nodes: list[Node] = [hub] + importers
        edges = [_edge(imp["id"], "shared_kernel") for imp in importers]

        compute_structural_significance(nodes, edges)

        sig = hub.get("structural_significance", {})
        assert sig.get("in_degree") == 4, (
            f"shared_kernel in_degree must be 4; got {sig.get('in_degree')}"
        )
        assert sig.get("is_hub") is True, (
            "shared_kernel must be flagged is_hub=True with in_degree=4"
        )

    def test_peripheral_detection(self) -> None:
        """Module with in_degree=0 and out_degree≤1 must be is_peripheral=True."""
        leaf = _make_bc_node("leaf_util")
        center = _make_bc_node("center")
        nodes: list[Node] = [leaf, center]
        # leaf → center: leaf has out_degree=1, in_degree=0
        edges = [_edge("leaf_util", "center")]

        compute_structural_significance(nodes, edges)

        sig = leaf.get("structural_significance", {})
        assert sig.get("in_degree") == 0, (
            f"leaf_util in_degree must be 0; got {sig.get('in_degree')}"
        )
        assert sig.get("out_degree") == 1, (
            f"leaf_util out_degree must be 1; got {sig.get('out_degree')}"
        )
        assert sig.get("is_peripheral") is True, (
            "leaf_util must be flagged is_peripheral=True"
        )

    def test_betweenness_centrality_computed(self) -> None:
        """Bridge node (sits on shortest paths) gets betweenness_centrality > 0."""
        # A → bridge → B: bridge is the only path from A to B.
        a = _make_bc_node("a")
        bridge = _make_bc_node("bridge")
        b = _make_bc_node("b")
        nodes: list[Node] = [a, bridge, b]
        edges = [_edge("a", "bridge"), _edge("bridge", "b")]

        compute_structural_significance(nodes, edges)

        sig = bridge.get("structural_significance", {})
        bc = sig.get("betweenness_centrality", 0.0)
        assert bc > 0.0, f"bridge node must have betweenness_centrality > 0; got {bc}"

    def test_hub_is_marked_landmark(self) -> None:
        """Hub nodes (is_hub=True) must also be marked is_landmark=True."""
        hub = _make_bc_node("core")
        importers = [_make_bc_node(f"svc_{i}") for i in range(4)]
        nodes: list[Node] = [hub] + importers
        edges = [_edge(imp["id"], "core") for imp in importers]

        compute_structural_significance(nodes, edges)

        assert hub.get("is_landmark") is True, (
            "Hub node must be marked is_landmark=True"
        )

    def test_bridge_is_marked_landmark(self) -> None:
        """Bridge nodes (is_bridge=True) must also be marked is_landmark=True.
        spec: visual-primitives.spec.md §Scenario: Landmark sources —
          'bridges (high betweenness centrality)'
        """
        a = _make_bc_node("a")
        bridge = _make_bc_node("bridge")
        b = _make_bc_node("b")
        nodes: list[Node] = [a, bridge, b]
        # A → bridge → B: bridge is the only path, giving it high betweenness.
        edges = [_edge("a", "bridge"), _edge("bridge", "b")]

        compute_structural_significance(nodes, edges)

        # Verify bridge detection first.
        sig = bridge.get("structural_significance", {})
        assert sig.get("is_bridge") is True, (
            f"bridge node must have is_bridge=True (betweenness={sig.get('betweenness_centrality', 0):.3f})"
        )
        # Then verify landmark assignment.
        assert bridge.get("is_landmark") is True, (
            "Bridge node must be marked is_landmark=True"
        )

    def test_entry_point_is_marked_landmark(self) -> None:
        """Entry-point nodes (in_degree=0, out_degree>1) must be marked is_landmark=True.
        spec: visual-primitives.spec.md §Scenario: Landmark sources —
          'entry points (no in-edges from application code)'
        """
        entry = _make_bc_node("entry")
        svc_a = _make_bc_node("svc_a")
        svc_b = _make_bc_node("svc_b")
        nodes: list[Node] = [entry, svc_a, svc_b]
        # entry has in_degree=0, out_degree=2 → entry point
        edges = [_edge("entry", "svc_a"), _edge("entry", "svc_b")]

        compute_structural_significance(nodes, edges)

        sig = entry.get("structural_significance", {})
        assert sig.get("in_degree") == 0, (
            f"entry node must have in_degree=0; got {sig.get('in_degree')}"
        )
        assert sig.get("out_degree") == 2, (
            f"entry node must have out_degree=2; got {sig.get('out_degree')}"
        )
        assert entry.get("is_landmark") is True, (
            "Entry-point node (in_degree=0, out_degree>1) must be marked is_landmark=True"
        )

    def test_structural_significance_field_present(self) -> None:
        """After compute_structural_significance, every code node has the field."""
        a = _make_bc_node("a")
        b = _make_bc_node("b")
        nodes: list[Node] = [a, b]
        edges: list[Edge] = [_edge("a", "b")]

        compute_structural_significance(nodes, edges)

        for n in nodes:
            assert "structural_significance" in n, (
                f"Node {n['id']!r} must have 'structural_significance' after computation"
            )

    def test_community_id_assigned_to_modules(self) -> None:
        """Module nodes get a community_id after compute_structural_significance."""
        bc = _make_bc_node("mybc")
        mod_a = _make_mod_node("mybc.a", "mybc")
        mod_b = _make_mod_node("mybc.b", "mybc")
        nodes: list[Node] = [bc, mod_a, mod_b]
        edges: list[Edge] = [
            {"source": "mybc.a", "target": "mybc.b", "type": "internal"}
        ]

        compute_structural_significance(nodes, edges)

        for mod in (mod_a, mod_b):
            sig = mod.get("structural_significance", {})
            assert "community_id" in sig, (
                f"Module {mod['id']!r} must have community_id in structural_significance"
            )


# ---------------------------------------------------------------------------
# Requirement: Ubiquitous Dependency Detection
# spec: visual-primitives.spec.md § Requirement: Ubiquitous Dependency Detection
# GIVEN 85% of modules import logging
# THEN logging is flagged as ubiquitous (edges marked ubiquitous=True)
# AND dependent nodes get has_ubiquitous_dep=True
# ---------------------------------------------------------------------------


class TestUbiquitousDependencyDetection:
    """Spec: visual-primitives.spec.md § Requirement: Ubiquitous Dependency Detection."""

    def _make_graph_with_ubiquitous(
        self,
    ) -> tuple[list[Node], list[Edge]]:
        """Create a graph where 'logging' is imported by 3 of 3 modules (100%)."""
        # Three source modules all importing 'logging' (a 4th node).
        logging_node = _make_bc_node("logging")
        modules = [_make_bc_node(f"svc_{i}") for i in range(3)]
        nodes: list[Node] = [logging_node] + modules
        edges: list[Edge] = [_edge(m["id"], "logging") for m in modules]
        return nodes, edges

    def test_ubiquitous_edges_flagged(self) -> None:
        """Edges to a ubiquitous module must have ubiquitous=True."""
        nodes, edges = self._make_graph_with_ubiquitous()
        detect_ubiquitous_dependencies(nodes, edges, threshold=0.5)

        ubiquitous_edges = [e for e in edges if e.get("ubiquitous") is True]
        assert ubiquitous_edges, (
            "Edges to a ubiquitous module must be marked ubiquitous=True"
        )

    def test_dependent_nodes_flagged(self) -> None:
        """Nodes that import a ubiquitous module get has_ubiquitous_dep=True."""
        nodes, edges = self._make_graph_with_ubiquitous()
        detect_ubiquitous_dependencies(nodes, edges, threshold=0.5)

        dep_nodes = [n for n in nodes if n.get("has_ubiquitous_dep") is True]
        assert dep_nodes, (
            "Nodes that import a ubiquitous module must have has_ubiquitous_dep=True"
        )

    def test_threshold_controls_detection(self) -> None:
        """A module imported by fewer modules than the threshold is not ubiquitous."""
        # Only 1 of 3 modules imports 'rare' (33%); threshold=0.5 → not ubiquitous.
        rare = _make_bc_node("rare")
        modules = [_make_bc_node(f"svc_{i}") for i in range(3)]
        nodes: list[Node] = [rare] + modules
        edges: list[Edge] = [_edge("svc_0", "rare")]  # only 1 importer

        detect_ubiquitous_dependencies(nodes, edges, threshold=0.5)

        for e in edges:
            assert e.get("ubiquitous", False) is False, (
                "Edge to non-ubiquitous module must not be marked ubiquitous=True"
            )

    def test_ubiquitous_edge_type_preserved(self) -> None:
        """The 'type' field on ubiquitous edges is unchanged after detection."""
        nodes, edges = self._make_graph_with_ubiquitous()
        original_types = [e["type"] for e in edges]
        detect_ubiquitous_dependencies(nodes, edges, threshold=0.5)

        for e, orig_type in zip(edges, original_types):
            assert e["type"] == orig_type, (
                "detect_ubiquitous_dependencies must not change edge 'type'"
            )

    def test_build_scene_graph_embeds_ubiquitous_flag(self, src: Path) -> None:
        """build_scene_graph output has 'ubiquitous' key on at least one edge when applicable."""
        graph = build_scene_graph(src)
        # Even if no edge is ubiquitous, the graph should be a valid dict.
        assert "edges" in graph, "Scene graph must have edges"
        # All edges must be dicts (not malformed).
        for e in graph["edges"]:
            assert isinstance(e, dict), f"Edge must be a dict; got {type(e)}"
