# Prototype Scope Specification

## Purpose
Define the scope and goals of the first prototype. The prototype exists to test one hypothesis: does navigating a software system's structure in 3D space produce genuine architectural understanding that flat diagrams do not? Everything is scoped to answering that question with minimum effort.

## Requirements

### Requirement: Target Codebase
The prototype MUST use the kartograph codebase (~/code/kartograph) as its target system.

#### Scenario: Loading kartograph
- GIVEN the kartograph codebase
- WHEN the prototype is launched
- THEN kartograph's structure is visualized in 3D space
- AND the visualization reflects the actual structure of the codebase

### Requirement: Two-Stage Pipeline
The system MUST operate as a two-stage pipeline: a Python extractor produces a JSON scene graph, and a Godot application consumes it.

#### Scenario: Extraction then visualization
- GIVEN the kartograph codebase
- WHEN the user runs the extractor
- THEN a JSON scene graph file is produced
- AND the Godot application can load that file and render the scene

### Requirement: Top-Down Architectural View
The prototype MUST provide a top-down camera view showing the overall system architecture.

#### Scenario: Viewing kartograph from above
- GIVEN kartograph's scene graph is loaded
- WHEN the user is in top-down view
- THEN all bounded contexts are visible as distinct volumes
- AND their relative positions reflect their coupling (tightly coupled contexts are closer together)
- AND dependencies between contexts are visible as connections

### Requirement: Zoom to Detail
The prototype MUST allow the user to zoom into a bounded context to see its internal structure.

#### Scenario: Zooming into IAM
- GIVEN the top-down view showing all bounded contexts
- WHEN the user zooms into the IAM context
- THEN the internal layers become visible (domain, application, infrastructure, presentation)
- AND internal dependencies are shown
- AND the user can see relative sizes of internal modules

### Requirement: Abstract Visual Language
The prototype MUST use abstract volumes (boxes, spheres, or similar primitives) rather than metaphorical representations. No buildings, terrain, or thematic decoration.

#### Scenario: Visual representation
- GIVEN any structural element in the scene
- WHEN it is rendered
- THEN it appears as a labeled geometric volume
- AND its size reflects its relative complexity
- AND its position reflects its coupling relationships
- AND containment is shown by nesting (smaller volumes inside larger ones)

### Requirement: Readable Labels
The prototype MUST label all visible structural elements with their names.

#### Scenario: Identifying a module
- GIVEN a volume in the scene
- WHEN the user looks at it
- THEN the module's name is visible as a text label
- AND the label remains readable at the current zoom level

### Requirement: Dependency Visualization
The prototype MUST show dependencies between modules as visible connections.

#### Scenario: Cross-context dependency
- GIVEN two bounded contexts with a dependency between them
- WHEN both are visible
- THEN a line or connection is drawn between them
- AND the direction of the dependency is discernible

### Requirement: Navigation
The prototype MUST support basic spatial navigation.

#### Scenario: Moving through the space
- GIVEN the 3D scene is loaded
- WHEN the user interacts with the application
- THEN they can pan, zoom, and rotate the view
- AND they can smoothly transition between overview and detail levels
