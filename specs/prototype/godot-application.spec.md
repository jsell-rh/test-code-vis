# Godot Application Specification

## Purpose
Define the Godot application that loads a JSON scene graph and renders it as a navigable 3D space.

## Requirements

### Requirement: JSON Scene Graph Loading
The application MUST load a JSON scene graph file produced by the Python extractor and generate the 3D scene from it.

#### Scenario: Loading kartograph's scene graph
- GIVEN a JSON scene graph file describing kartograph's structure
- WHEN the Godot application starts
- THEN it reads the JSON file
- AND generates 3D volumes for each node
- AND generates connections for each edge
- AND positions elements according to the layout data in the JSON

### Requirement: Containment Rendering
The application MUST render containment relationships as nested volumes — child nodes are visually inside their parent node.

#### Scenario: Modules inside a bounded context
- GIVEN a bounded context node containing module nodes
- WHEN the scene is rendered
- THEN the bounded context appears as a larger translucent volume
- AND its child modules appear as smaller opaque volumes inside it
- AND the boundary of the parent is visually distinct from the children

### Requirement: Dependency Rendering
The application MUST render dependency edges as visible lines between connected nodes.

#### Scenario: Rendering a cross-context dependency
- GIVEN an edge from graph context to shared_kernel context
- WHEN the scene is rendered
- THEN a line connects the two context volumes
- AND the line's direction is visually indicated

### Requirement: Size Encoding
The application MUST encode complexity metrics as the visual size of volumes.

#### Scenario: Large module vs small module
- GIVEN two modules with different lines-of-code metrics
- WHEN the scene is rendered
- THEN the module with more code appears as a larger volume
- AND the relative sizes are proportional to the metric

### Requirement: Camera Controls
The application MUST provide camera controls for navigating the scene.

#### Scenario: Top-down overview
- GIVEN the scene is loaded
- WHEN the application starts
- THEN the camera defaults to a top-down view showing the entire system

#### Scenario: Zooming in
- GIVEN the top-down view
- WHEN the user scrolls or zooms toward a bounded context
- THEN the camera moves closer
- AND internal structure becomes visible as the camera approaches
- AND labels scale to remain readable

#### Scenario: Orbiting
- GIVEN any camera position
- WHEN the user uses mouse controls to orbit
- THEN the camera rotates around the current focal point
- AND orientation remains intuitive (up stays up)

### Requirement: Godot 4
The application MUST be built using Godot 4.x with GDScript.

#### Scenario: Engine version
- GIVEN the project is opened in Godot
- WHEN the project settings are inspected
- THEN it uses Godot 4.x
- AND all scripts are GDScript
