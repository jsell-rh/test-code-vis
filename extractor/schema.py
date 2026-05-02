"""
Scene graph schema definitions.

Defines the JSON format that serves as the sole interface contract
between the Python extractor and the Godot application.
"""

from __future__ import annotations

from typing import Literal, NotRequired, TypedDict


class Position(TypedDict):
    """3D position in scene space."""

    x: float
    y: float
    z: float


NodeType = Literal["bounded_context", "module", "spec"]
EdgeType = Literal[
    "cross_context",
    "internal",
    "aggregate",
    "inherits",
    "has_a",
    "direct_call",
    "dynamic_call",
]

# ---------------------------------------------------------------------------
# Visual-primitive support types (visual-primitives.spec.md)
# ---------------------------------------------------------------------------

SymbolVisibility = Literal["public", "private"]
SymbolKind = Literal["function", "class", "constant", "variable"]


# ---------------------------------------------------------------------------
# Annotation types (visual-primitives.spec.md § Purpose-Level Annotation)
# ---------------------------------------------------------------------------


class BeaconInfo(TypedDict):
    """A recognized programming pattern attached to a node.

    Spec: visual-primitives.spec.md § Requirement: Purpose-Level Annotation
    / Scenario: Beacon recognition

    Beacon ``pattern`` values are open-vocabulary strings — the LLM names what
    it finds.  Unlike Badges (which have a closed fixed vocabulary), beacon
    pattern names are NOT validated against any fixed list.  New patterns are
    discovered without a schema change.
    """

    pattern: str
    """Short canonical name of the recognized pattern.

    Examples: ``'retry_loop'``, ``'accumulator'``, ``'observer_dispatch'``,
    ``'circuit_breaker'``, ``'command_pattern'``, ``'repository_pattern'``.
    Open vocabulary — the LLM names what it finds.
    """

    description: str
    """One sentence explaining the specific instance of this pattern."""


class InvariantInfo(TypedDict):
    """A business rule or structural constraint enforced collectively by a node.

    Spec: visual-primitives.spec.md § Requirement: Purpose-Level Annotation
    / Scenario: Invariant annotation
    """

    rule: str
    """One sentence stating the invariant in domain language.

    Example: ``'Order cannot ship if payment is pending.'``
    Must be non-empty.
    """

    enforced_by: list[str]
    """Node IDs of the modules or functions that enforce this invariant.

    May be empty when the enforcement path is unclear.
    """


BadgeType = Literal[
    "pure",
    "io",
    "async",
    "stateful",
    "error_handling",
    "test",
    "entry_point",
    "deprecated",
]


class SymbolInfo(TypedDict):
    """A named entity extracted from a module's symbol table.

    Spec: visual-primitives.spec.md § Requirement: Symbol Table Extraction
    """

    name: str
    """Identifier as it appears in source code."""

    visibility: SymbolVisibility
    """'public' for names without a leading underscore, 'private' otherwise."""

    kind: SymbolKind
    """Category of the symbol."""

    signature: NotRequired[str]
    """Human-readable parameter and return-type string for functions/methods.

    Example: ``'(order: Order, *, strict: bool = False) -> Result'``
    Omitted for non-callable symbols.
    """


class StructuralSignificanceMetrics(TypedDict):
    """Graph-theoretic significance measures for a node.

    Spec: visual-primitives.spec.md § Requirement: Structural Significance Extraction
    """

    in_degree: int
    """Number of edges arriving at this node from other nodes."""

    out_degree: int
    """Number of edges leaving this node to other nodes."""

    is_hub: bool
    """True when in_degree exceeds the hub threshold (most-depended-upon nodes)."""

    is_bridge: bool
    """True when betweenness_centrality exceeds the bridge threshold."""

    is_peripheral: bool
    """True when in_degree == 0 and out_degree <= 1 (leaf utility nodes)."""

    betweenness_centrality: float
    """Fraction of shortest paths between other node pairs that pass through this node.

    Range [0.0, 1.0].  A value of 0.0 means the node is not on any shortest path.
    """

    community_id: NotRequired[str]
    """Detected community identifier (e.g. ``'community_0'``).

    Set by community-detection analysis.  Absent when community detection
    has not been run.
    """

    community_drift: NotRequired[bool]
    """True when the detected community differs from the declared package.

    A module flagged as ``community_drift=True`` is structurally closer to a
    different bounded context than the one it is declared in.
    """


class NodeMetrics(TypedDict):
    """Raw complexity metrics for a node."""

    loc: int
    """Total lines of code (Python source files, recursive)."""


class Node(TypedDict):
    """A node in the scene graph.

    Represents a bounded context or module extracted from the codebase.
    """

    id: str
    """Unique identifier, e.g. 'iam' or 'iam.domain'."""

    name: str
    """Human-readable display name, e.g. 'IAM' or 'Domain'."""

    type: NodeType
    """Level of the node: 'bounded_context' or 'module'."""

    position: Position
    """Pre-computed 3D position. Coordinates are relative to the parent node."""

    size: float
    """Visual size derived from the node's complexity metric."""

    parent: str | None
    """ID of the containing node, or null for top-level nodes."""

    metrics: NotRequired[NodeMetrics]
    """Raw complexity metrics. Present for code-derived nodes."""

    independence_group: NotRequired[str]
    """Identifier for the structural independence group, e.g. 'iam:0'.

    Module nodes within the same bounded context that share internal
    dependencies (directly or transitively) share the same group identifier.
    Modules with no internal dependencies to any peer each form their own group.
    """

    depth: NotRequired[int]
    """Cascade depth from a failure-simulation origin node.

    Present only in simulation output.  A node at depth 1 directly depends on
    the origin; depth 2 means it depends on a depth-1 node; and so on.
    """

    # ── Structural Significance (visual-primitives.spec.md) ──────────────────
    # Flat fields set by compute_structural_significance() for backward compat.

    in_degree: NotRequired[int]
    """Number of edges arriving at this node from other nodes.

    Computed by compute_structural_significance().  Used to identify hubs.
    """

    out_degree: NotRequired[int]
    """Number of edges leaving this node toward other nodes.

    Computed by compute_structural_significance().  Used to identify peripheral nodes.
    """

    is_hub: NotRequired[bool]
    """True when this node has the highest in-degree (most depended-upon).

    Hub nodes become Landmarks in the Godot renderer: they are always visible
    regardless of LOD level and receive distinctive visual treatment.
    Spec: visual-primitives.spec.md § Structural Significance Extraction / Hub detection.
    """

    is_bridge: NotRequired[bool]
    """True when this node is a graph articulation point (bridge).

    Removing a bridge node would disconnect the module graph.  Bridge nodes
    become Landmarks to help humans spot structural bottlenecks.
    Spec: visual-primitives.spec.md § Structural Significance Extraction / Bridge detection.
    """

    is_peripheral: NotRequired[bool]
    """True when in_degree == 0 and out_degree <= 1 (leaf utility node).

    Peripheral nodes are candidates for de-emphasis at overview zoom levels.
    Spec: visual-primitives.spec.md § Structural Significance Extraction / Peripheral detection.
    """

    community_id: NotRequired[int]
    """Connected-component community identifier assigned by community detection.

    Nodes in the same strongly-connected component share the same identifier.
    Spec: visual-primitives.spec.md § Structural Significance Extraction / Community detection.
    """

    community_drift: NotRequired[bool]
    """True when the detected community spans more than one bounded context.

    A module whose community includes nodes from a different bounded context
    may be poorly co-located with its structural peers.
    Spec: visual-primitives.spec.md § Structural Significance Extraction / Community detection.
    """

    # ------------------------------------------------------------------
    # Visual-primitive fields (visual-primitives.spec.md)
    # ------------------------------------------------------------------

    symbols: NotRequired[list[SymbolInfo]]
    """Symbol table for this module: named entities with visibility and kind.

    Spec: visual-primitives.spec.md § Requirement: Symbol Table Extraction
    Present for 'module' nodes only.
    """

    badges: NotRequired[list[str]]
    """Set of Badge types attached to this node (subset of BadgeType literals).

    Spec: visual-primitives.spec.md § Requirement: Badge Primitive
    Each badge encodes a cross-cutting aspect (e.g. 'io', 'async', 'pure').
    """

    is_landmark: NotRequired[bool]
    """True when this node is designated a Landmark.

    Spec: visual-primitives.spec.md § Requirement: Landmark Primitive
    Landmarks persist at all zoom levels and serve as orientation anchors.
    Derived from structural significance (hub, bridge) or explicit designation.
    """

    structural_significance: NotRequired[StructuralSignificanceMetrics]
    """Graph-theoretic significance measures.

    Spec: visual-primitives.spec.md § Requirement: Structural Significance Extraction
    Present after compute_structural_significance() has run.
    """

    has_ubiquitous_dep: NotRequired[bool]
    """True when this node imports at least one ubiquitous dependency.

    Spec: visual-primitives.spec.md § Requirement: Ubiquitous Dependency Detection
    When True, the renderer displays a power-rail indicator on this node.
    """

    # ------------------------------------------------------------------
    # Purpose-Level Annotation fields (visual-primitives.spec.md)
    # These fields are populated by LLM-based annotation agents, NOT by
    # the deterministic extractor pipeline.  They remain absent in purely
    # extractor-produced outputs.
    # ------------------------------------------------------------------

    purpose_annotation: NotRequired[str | None]
    """Human-readable sentence describing what this node is FOR, not what it does.

    Spec: visual-primitives.spec.md § Requirement: Purpose-Level Annotation
    / Scenario: LLM-generated purpose annotation

    Present on ``'module'`` and ``'bounded_context'`` nodes only.
    - string: authored purpose description.
    - null: annotation key present but intentionally blank.
    - absent: annotation has not been computed for this node.
    """

    beacons: NotRequired[list[BeaconInfo]]
    """Recognized programming patterns attached to this node.

    Spec: visual-primitives.spec.md § Requirement: Purpose-Level Annotation
    / Scenario: Beacon recognition

    May be present on any node type.  Absent when no beacon analysis has run.
    Empty array when analysis ran but no patterns were recognized.
    Each entry names an open-vocabulary pattern the LLM recognized in the
    node's implementation.
    """

    invariants: NotRequired[list[InvariantInfo]]
    """Business rules or structural constraints collectively enforced by this node.

    Spec: visual-primitives.spec.md § Requirement: Purpose-Level Annotation
    / Scenario: Invariant annotation

    Present on ``'module'`` and ``'bounded_context'`` nodes only.
    Absent when no invariant analysis has run.
    Empty array when analysis ran but no invariants were identified.
    """


class Edge(TypedDict):
    """A directed dependency edge between two nodes."""

    source: str
    """ID of the node that has the dependency."""

    target: str
    """ID of the node being depended upon."""

    type: EdgeType
    """'cross_context' for inter-bounded-context deps, 'internal' for intra-context,
    'aggregate' for a rolled-up cross-context summary edge."""

    weight: NotRequired[int]
    """Number of individual import statements this edge represents.

    Omitting weight implies weight=1.  Aggregate edges carry the sum of all
    individual import counts between the two bounded contexts.
    For 'direct_call' edges, weight is the number of call sites from source
    to target within the source module's function bodies.
    """

    ubiquitous: NotRequired[bool]
    """True when the target of this edge is a ubiquitous dependency.

    Ubiquitous dependencies are imported by more than the configured fraction
    of all module nodes.  The Godot renderer suppresses drawing these edges by
    default (power-rail notation) and instead shows a small indicator on the
    source node.
    Spec: visual-primitives.spec.md § Ubiquitous Dependency Detection.
    """


class Metadata(TypedDict):
    """Extraction metadata recorded alongside the graph."""

    source_path: str
    """Absolute path to the source codebase that was analysed."""

    timestamp: str
    """ISO-8601 UTC timestamp of when the extraction was performed."""

    ubiquity_threshold: NotRequired[float]
    """Fraction of modules that must import a dependency for it to be flagged
    as ubiquitous (default 0.5 = 50%).

    Recorded so the Godot renderer and human can understand which suppression
    rule was applied.
    Spec: visual-primitives.spec.md § Ubiquitous Dependency Detection / Threshold.
    """


class AggregateMetrics(TypedDict):
    """Complexity and connectivity summary for a cluster of modules."""

    total_loc: int
    """Sum of lines-of-code across all member modules."""

    in_degree: int
    """Number of edges arriving at cluster members from outside the cluster."""

    out_degree: int
    """Number of edges leaving cluster members to nodes outside the cluster."""


class Cluster(TypedDict):
    """A pre-computed suggestion for a group of tightly-coupled modules.

    The human may choose to collapse the members into a supernode.
    The Godot application computes the supernode position as the centroid
    of the member positions — the cluster entry does NOT prescribe a position.
    """

    id: str
    """Unique cluster identifier, e.g. 'iam:cluster_0'."""

    members: list[str]
    """Node IDs of the modules belonging to this cluster."""

    context: str
    """ID of the parent bounded context that contains all members."""

    aggregate_metrics: AggregateMetrics
    """Rolled-up complexity and connectivity metrics for the cluster."""


class SceneGraph(TypedDict):
    """Root of the JSON scene graph file.

    This is the complete contract between the Python extractor and the
    Godot application.  The JSON file MUST contain exactly these four
    top-level fields.
    """

    nodes: list[Node]
    edges: list[Edge]
    metadata: Metadata
    clusters: list[Cluster]


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

_REQUIRED_NODE_KEYS: frozenset[str] = frozenset(
    {"id", "name", "type", "position", "size", "parent"}
)
_REQUIRED_POSITION_KEYS: frozenset[str] = frozenset({"x", "y", "z"})
_REQUIRED_EDGE_KEYS: frozenset[str] = frozenset({"source", "target", "type"})
_REQUIRED_METADATA_KEYS: frozenset[str] = frozenset({"source_path", "timestamp"})
_REQUIRED_GRAPH_KEYS: frozenset[str] = frozenset(
    {"nodes", "edges", "metadata", "clusters"}
)
_REQUIRED_CLUSTER_KEYS: frozenset[str] = frozenset(
    {"id", "members", "context", "aggregate_metrics"}
)
_REQUIRED_AGGREGATE_METRICS_KEYS: frozenset[str] = frozenset(
    {"total_loc", "in_degree", "out_degree"}
)


def validate_scene_graph(graph: object) -> None:
    """Assert that *graph* conforms to the scene graph schema.

    Raises :class:`ValueError` with a descriptive message if any required
    field is absent or has the wrong type.  Designed to be called by the
    output writer (task-006) before persisting the JSON file.

    Args:
        graph: The object to validate — must be a dict with the four
               top-level keys ``nodes``, ``edges``, ``metadata``, and
               ``clusters``.

    Raises:
        ValueError: If any required field is missing or has the wrong type.
    """
    if not isinstance(graph, dict):
        raise ValueError(f"Scene graph must be a dict, got {type(graph).__name__!r}")

    missing = _REQUIRED_GRAPH_KEYS - graph.keys()
    if missing:
        raise ValueError(f"Scene graph missing top-level key(s): {sorted(missing)}")

    extra = set(graph.keys()) - _REQUIRED_GRAPH_KEYS
    if extra:
        raise ValueError(
            f"Scene graph has unexpected top-level key(s): {sorted(extra)}"
        )

    if not isinstance(graph["nodes"], list):
        raise ValueError("'nodes' must be a list")
    if not isinstance(graph["edges"], list):
        raise ValueError("'edges' must be a list")
    if not isinstance(graph["metadata"], dict):
        raise ValueError("'metadata' must be a dict")
    if not isinstance(graph["clusters"], list):
        raise ValueError("'clusters' must be a list")

    for i, node in enumerate(graph["nodes"]):
        if not isinstance(node, dict):
            raise ValueError(f"nodes[{i}] must be a dict, got {type(node).__name__!r}")
        missing_node = _REQUIRED_NODE_KEYS - node.keys()
        if missing_node:
            raise ValueError(
                f"nodes[{i}] missing required key(s): {sorted(missing_node)}"
            )
        pos = node.get("position")
        if not isinstance(pos, dict):
            raise ValueError(
                f"nodes[{i}]['position'] must be a dict, got {type(pos).__name__!r}"
            )
        missing_pos = _REQUIRED_POSITION_KEYS - pos.keys()
        if missing_pos:
            raise ValueError(
                f"nodes[{i}]['position'] missing key(s): {sorted(missing_pos)}"
            )
        for coord in ("x", "y", "z"):
            if not isinstance(pos[coord], (int, float)):
                raise ValueError(
                    f"nodes[{i}]['position'][{coord!r}] must be numeric, "
                    f"got {type(pos[coord]).__name__!r}"
                )

        # Validate optional 'depth' field (cascade simulation output).
        # When present: must be an integer >= 1.
        # When absent: valid — static scene graph nodes do not carry depth.
        depth = node.get("depth")
        if depth is not None:
            if isinstance(depth, bool) or not isinstance(depth, int):
                raise ValueError(
                    f"nodes[{i}]['depth'] must be an integer, "
                    f"got {type(depth).__name__!r}"
                )
            if depth < 1:
                raise ValueError(f"nodes[{i}]['depth'] must be >= 1, got {depth!r}")

        # Validate optional 'purpose_annotation' (Purpose-Level Annotation).
        # When present: must be a string or None.
        # When absent: valid — annotation not yet computed.
        if "purpose_annotation" in node:
            pa = node["purpose_annotation"]
            if pa is not None and not isinstance(pa, str):
                raise ValueError(
                    f"nodes[{i}]['purpose_annotation'] must be a string or null, "
                    f"got {type(pa).__name__!r}"
                )

        # Validate optional 'beacons' (Purpose-Level Annotation / Beacon).
        # When present: must be a list; each entry must have pattern (non-empty
        # string) and description (string).  pattern is open-vocabulary — NOT
        # validated against a fixed list.
        # When absent: valid — beacon analysis has not run.
        if "beacons" in node:
            beacons = node["beacons"]
            if not isinstance(beacons, list):
                raise ValueError(
                    f"nodes[{i}]['beacons'] must be a list, "
                    f"got {type(beacons).__name__!r}"
                )
            for j, beacon in enumerate(beacons):
                if not isinstance(beacon, dict):
                    raise ValueError(
                        f"nodes[{i}]['beacons'][{j}] must be a dict, "
                        f"got {type(beacon).__name__!r}"
                    )
                if "pattern" not in beacon:
                    raise ValueError(
                        f"nodes[{i}]['beacons'][{j}] missing required key 'pattern'"
                    )
                if not isinstance(beacon["pattern"], str):
                    raise ValueError(
                        f"nodes[{i}]['beacons'][{j}]['pattern'] must be a string, "
                        f"got {type(beacon['pattern']).__name__!r}"
                    )
                if not beacon["pattern"]:
                    raise ValueError(
                        f"nodes[{i}]['beacons'][{j}]['pattern'] must be non-empty"
                    )
                if "description" not in beacon:
                    raise ValueError(
                        f"nodes[{i}]['beacons'][{j}] missing required key 'description'"
                    )
                if not isinstance(beacon["description"], str):
                    raise ValueError(
                        f"nodes[{i}]['beacons'][{j}]['description'] must be a string, "
                        f"got {type(beacon['description']).__name__!r}"
                    )

        # Validate optional 'invariants' (Purpose-Level Annotation / Invariant).
        # When present: must be a list; each entry must have rule (non-empty
        # string) and enforced_by (list of strings, may be empty).
        # When absent: valid — invariant analysis has not run.
        if "invariants" in node:
            invariants = node["invariants"]
            if not isinstance(invariants, list):
                raise ValueError(
                    f"nodes[{i}]['invariants'] must be a list, "
                    f"got {type(invariants).__name__!r}"
                )
            for j, inv in enumerate(invariants):
                if not isinstance(inv, dict):
                    raise ValueError(
                        f"nodes[{i}]['invariants'][{j}] must be a dict, "
                        f"got {type(inv).__name__!r}"
                    )
                if "rule" not in inv:
                    raise ValueError(
                        f"nodes[{i}]['invariants'][{j}] missing required key 'rule'"
                    )
                if not isinstance(inv["rule"], str):
                    raise ValueError(
                        f"nodes[{i}]['invariants'][{j}]['rule'] must be a string, "
                        f"got {type(inv['rule']).__name__!r}"
                    )
                if not inv["rule"]:
                    raise ValueError(
                        f"nodes[{i}]['invariants'][{j}]['rule'] must be non-empty"
                    )
                if "enforced_by" not in inv:
                    raise ValueError(
                        f"nodes[{i}]['invariants'][{j}] missing required key"
                        " 'enforced_by'"
                    )
                if not isinstance(inv["enforced_by"], list):
                    raise ValueError(
                        f"nodes[{i}]['invariants'][{j}]['enforced_by'] must be a list,"
                        f" got {type(inv['enforced_by']).__name__!r}"
                    )

    for i, edge in enumerate(graph["edges"]):
        if not isinstance(edge, dict):
            raise ValueError(f"edges[{i}] must be a dict, got {type(edge).__name__!r}")
        missing_edge = _REQUIRED_EDGE_KEYS - edge.keys()
        if missing_edge:
            raise ValueError(
                f"edges[{i}] missing required key(s): {sorted(missing_edge)}"
            )

    meta = graph["metadata"]
    missing_meta = _REQUIRED_METADATA_KEYS - meta.keys()
    if missing_meta:
        raise ValueError(f"metadata missing key(s): {sorted(missing_meta)}")

    for i, cluster in enumerate(graph["clusters"]):
        if not isinstance(cluster, dict):
            raise ValueError(
                f"clusters[{i}] must be a dict, got {type(cluster).__name__!r}"
            )
        missing_cluster = _REQUIRED_CLUSTER_KEYS - cluster.keys()
        if missing_cluster:
            raise ValueError(
                f"clusters[{i}] missing required key(s): {sorted(missing_cluster)}"
            )
        if not isinstance(cluster["members"], list):
            raise ValueError(f"clusters[{i}]['members'] must be a list")
        am = cluster.get("aggregate_metrics")
        if not isinstance(am, dict):
            raise ValueError(
                f"clusters[{i}]['aggregate_metrics'] must be a dict, "
                f"got {type(am).__name__!r}"
            )
        missing_am = _REQUIRED_AGGREGATE_METRICS_KEYS - am.keys()
        if missing_am:
            raise ValueError(
                f"clusters[{i}]['aggregate_metrics'] missing key(s): {sorted(missing_am)}"
            )
