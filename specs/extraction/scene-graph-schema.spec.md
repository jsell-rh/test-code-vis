# Scene Graph Schema Specification

## Purpose
Define the JSON scene graph format that serves as the sole interface contract between the Python extractor and the Godot application.

## Requirements

### Requirement: Schema Structure
The JSON scene graph MUST contain nodes, edges, and metadata as top-level fields.

#### Scenario: Top-level structure
- GIVEN a completed extraction
- WHEN the JSON file is written
- THEN it contains a `nodes` array, an `edges` array, and a `metadata` object
- AND no other top-level fields are present

### Requirement: Node Schema
Each node MUST contain an id, name, type, position, size, and optional parent reference.

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

### Requirement: Edge Schema
Each edge MUST contain a source node id, target node id, and type.

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
