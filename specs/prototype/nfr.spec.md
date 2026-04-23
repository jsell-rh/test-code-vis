# Non-Functional Requirements Specification

## Purpose
Define technology choices, constraints, and quality attributes for the prototype.

## Requirements

### Requirement: Godot 4.6 Engine
The visualization application MUST be built using Godot 4.6.x. All GDScript MUST use API calls valid in Godot 4.6 (e.g. `FileAccess.get_as_text()`, not deprecated or nonexistent methods).

#### Scenario: Engine version
- GIVEN the project repository
- WHEN a developer opens it
- THEN it opens in Godot 4.6.x
- AND all scripts use GDScript
- AND all API calls are valid for the Godot 4.6 API

### Requirement: Python Extractor
The code extraction stage MUST be implemented in Python.

#### Scenario: Running the extractor
- GIVEN the kartograph codebase
- WHEN the user runs the extractor
- THEN it runs as a standalone Python script or CLI tool
- AND it requires no dependencies beyond the Python standard library and tree-sitter (or ast module)

### Requirement: JSON Interface Contract
The JSON scene graph file MUST be the sole interface between the Python extractor and the Godot application. Neither component has direct knowledge of the other.

#### Scenario: Decoupled pipeline
- GIVEN a valid JSON scene graph
- WHEN the Godot application loads it
- THEN it does not need access to the Python extractor or the source codebase
- AND the JSON file is self-contained

### Requirement: Desktop Platform
The prototype MUST run as a native desktop application on Linux (Fedora).

#### Scenario: Running the prototype
- GIVEN a Linux desktop (Fedora 42)
- WHEN the user launches the Godot application
- THEN it runs natively without browser, container, or VM dependencies

### Requirement: Performance at Kartograph Scale
The prototype MUST render kartograph's full structure (6 bounded contexts, ~50 modules, ~100 files) without perceptible lag during navigation.

#### Scenario: Smooth navigation
- GIVEN kartograph's scene graph is loaded
- WHEN the user pans, zooms, or orbits
- THEN the frame rate remains above 30fps
- AND there is no perceptible stutter or pop-in

### Requirement: Prototype Disposability
The prototype SHOULD be built for learning, not longevity. Code quality matters less than speed of iteration. It is acceptable to throw the prototype away entirely based on what we learn.

#### Scenario: Pivoting after prototype
- GIVEN the prototype has been built and evaluated
- WHEN the team decides the approach needs fundamental changes
- THEN the prototype can be discarded without loss
- AND the JSON scene graph format is the only artifact worth preserving
