# Scene Graph Schema Specification

## Purpose
Define the JSON scene graph format that serves as the sole interface contract between the Python extractor and the Godot application.

## Requirements

### Requirement: Schema Structure
The JSON scene graph MUST contain nodes, edges, metadata, and clusters as top-level fields.

#### Scenario: Top-level structure
- GIVEN a completed extraction
- WHEN the JSON file is written
- THEN it contains a `nodes` array, an `edges` array, a `metadata` object, and a `clusters` array
- AND no other top-level fields are present

### Requirement: Node Schema
Each node MUST contain an id, name, type, position, size, and optional parent reference. Module nodes MAY carry an `independence_group` identifier.

#### Scenario: Bounded context node
- GIVEN the kartograph IAM bounded context
- WHEN it is represented as a node
- THEN it has a unique `id` (e.g. "iam")
- AND a `name` (e.g. "IAM")
- AND a `type` field indicating its level (e.g. "bounded_context")
- AND a `position` object with `x`, `y`, `z` coordinates
- AND a `size` value derived from its complexity metric
- AND `parent` is null (top-level node)

#### Scenario: Module node inside a bounded context
- GIVEN the domain layer inside the IAM context
- WHEN it is represented as a node
- THEN it has a unique `id` (e.g. "iam.domain")
- AND a `parent` field referencing its containing node's id (e.g. "iam")
- AND a `type` field indicating its level (e.g. "module")
- AND `position` coordinates relative to its parent

#### Scenario: Module with independence group
- GIVEN two structurally independent groups within the IAM context
- WHEN the modules are represented as nodes
- THEN each module has an `independence_group` field (e.g. "iam:0", "iam:1")
- AND modules in the same group share the same identifier
- AND modules with no internal dependencies to any peer are each their own group

### Requirement: Edge Schema
Each edge MUST contain a source node id, target node id, and type. Edges MAY carry a weight indicating the number of individual imports they represent.

#### Scenario: Cross-context dependency edge
- GIVEN that the graph context imports from shared_kernel
- WHEN the dependency is represented as an edge
- THEN it has a `source` field (e.g. "graph")
- AND a `target` field (e.g. "shared_kernel")
- AND a `type` field (e.g. "cross_context")

#### Scenario: Internal dependency edge
- GIVEN that iam.application imports from iam.domain
- WHEN the dependency is represented as an edge
- THEN it has a `source` field (e.g. "iam.application")
- AND a `target` field (e.g. "iam.domain")
- AND a `type` field (e.g. "internal")

#### Scenario: Weighted edge
- GIVEN that context A has 12 individual import statements referencing modules in context B
- WHEN the edges are represented
- THEN individual module-level edges each have `weight: 1` (or weight omitted, defaulting to 1)
- AND the extractor also emits an aggregate edge with `source: "A"`, `target: "B"`, `type: "aggregate"`, and `weight: 12`
- AND aggregate edges are used for far-distance rendering; individual edges for near-distance

### Requirement: Metadata
The metadata object MUST contain information about the extraction.

#### Scenario: Extraction metadata
- GIVEN a completed extraction
- WHEN the JSON file is written
- THEN the metadata contains the source codebase path
- AND the timestamp of extraction

### Requirement: Pre-Computed Layout
Node positions MUST be computed by the Python extractor, not by the Godot application. The extractor is responsible for running a layout algorithm that positions nodes so that coupled nodes are closer together.

#### Scenario: Layout in JSON
- GIVEN a set of extracted nodes and edges
- WHEN the extractor computes the layout
- THEN each node's `position` field contains x, y, z coordinates
- AND tightly coupled nodes have smaller distances between them
- AND child nodes are positioned within the spatial bounds of their parent
- AND the Godot application renders nodes at these positions without recomputing layout

### Requirement: Cluster Schema
The `clusters` array MUST contain pre-computed suggestions for groups of tightly-coupled modules that the human may choose to collapse into supernodes.

#### Scenario: Cluster suggestion
- GIVEN the extractor identifies modules A, B, C within context X as having mutual coupling scores above the threshold
- WHEN the clusters array is written
- THEN it contains an entry with `id` (e.g. "x:cluster_0"), `members` (array of node ids: ["x.a", "x.b", "x.c"]), `context` (parent bounded context id: "x"), and `aggregate_metrics` (object with `total_loc`, `in_degree`, `out_degree`)
- AND the cluster entry does not prescribe the collapsed position — Godot computes the supernode position as the centroid of member positions

#### Scenario: No clusters found
- GIVEN a bounded context with no module pairs exceeding the coupling threshold
- WHEN the clusters array is written
- THEN it is an empty array
- AND the Godot application renders no collapse suggestions for that context

### Requirement: Cascade Depth in Simulation Output
When the system computes failure cascade analysis, each affected node MUST carry a `depth` value indicating its hop distance from the failure origin.

#### Scenario: Cascade with depth
- GIVEN the human simulates failure of node X
- AND node A directly depends on X, and node B directly depends on A
- WHEN the cascade is computed
- THEN node A is marked with depth 1 and node B with depth 2
- AND the depth values are available to the visualization for gradient encoding and wave animation
