# Code Extraction Specification

## Purpose
Extract structural information from a Python codebase into a JSON scene graph that can be consumed by the 3D visualization engine.

## Requirements

### Requirement: Module Discovery
The system MUST discover all Python modules in a target codebase and represent them as nodes in a scene graph.

#### Scenario: Discovering kartograph's bounded contexts
- GIVEN the kartograph codebase at a specified path
- WHEN the extractor runs
- THEN it discovers all top-level bounded contexts (iam, graph, management, query, shared_kernel, infrastructure)
- AND each is represented as a node with a name, path, and type

#### Scenario: Discovering nested modules
- GIVEN a bounded context with internal layers (domain, application, infrastructure, presentation)
- WHEN the extractor runs
- THEN it discovers the internal modules within each bounded context
- AND represents the containment relationship (module X is inside bounded context Y)

### Requirement: Dependency Extraction
The system MUST extract import-based dependencies between modules.

#### Scenario: Cross-context dependency
- GIVEN that the graph context imports from shared_kernel
- WHEN the extractor analyzes imports
- THEN a dependency edge is created from graph to shared_kernel
- AND the edge includes the direction of the dependency

#### Scenario: Internal dependency
- GIVEN that iam.application.services imports from iam.domain
- WHEN the extractor analyzes imports
- THEN a dependency edge is created within the iam context
- AND the edge is distinguishable from cross-context dependencies

### Requirement: Complexity Metrics
The system SHOULD compute basic complexity metrics for each module.

#### Scenario: Module size
- GIVEN a module with Python source files
- WHEN the extractor runs
- THEN it computes the total lines of code for the module
- AND this metric is included in the node's metadata

### Requirement: JSON Scene Graph Output
The system MUST output a JSON file that describes nodes, edges, containment, and metadata.

#### Scenario: Output format
- GIVEN a completed extraction
- WHEN the output is written
- THEN the JSON contains a list of nodes (id, name, type, parent, metrics)
- AND a list of edges (source, target, type)
- AND the format is consumable by the Godot visualization without transformation

### Requirement: Spec Extraction
The system SHOULD extract structure from spec files alongside the codebase, for use in conformance mode.

#### Scenario: Kartograph specs
- GIVEN spec files exist in the target codebase's specs/ directory
- WHEN the extractor runs with spec extraction enabled
- THEN spec-defined components are represented as a parallel set of nodes
- AND spec nodes are distinguishable from code-derived nodes
